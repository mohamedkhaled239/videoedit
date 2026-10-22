import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/app_config.dart';
import '../services/ad_service.dart';

class AppConfigProvider extends ChangeNotifier {
  static const String _collectionName = 'vd-config';
  static const String _documentName = 'config';
  static const String _downloadCollectionName = 'editvideo';
  static const String _downloadDocumentName = 'editvideo';
  static const String _downloadFieldName = 'editvideo';

  AppConfigProvider({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance {
    unawaited(loadConfig());
    unawaited(refreshDocumentDownloadAvailability());
    _listenToDocumentDownloadAvailability();
  }

  final FirebaseFirestore _firestore;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _downloadSubscription;
  AppConfig _config = AppConfig.defaultConfig();
  bool _isLoading = true;
  String? _errorMessage;
  bool _documentDownloadEnabled = false;

  AppConfig get config => _config;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get documentDownloadEnabled => _documentDownloadEnabled;

  DocumentReference<Map<String, dynamic>> get _configDocument =>
      _firestore.collection(_collectionName).doc(_documentName);

  DocumentReference<Map<String, dynamic>> get _downloadConfigDocument =>
      _firestore.collection(_downloadCollectionName).doc(_downloadDocumentName);

  /// Loads the remote switches once. Calling this explicitly performs a fresh
  /// server read, but no realtime listener is kept after startup.
  Future<void> loadConfig() async {
    _isLoading = true;
    notifyListeners();
    try {
      final projectId = _firestore.app.options.projectId;
      debugPrint(
        '[RemoteSettings] Reading project=$projectId '
        'path=$_collectionName/$_documentName',
      );

      DocumentSnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _configDocument
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 8));
      } catch (serverError) {
        debugPrint(
          '[RemoteSettings] Server read failed; trying cache: $serverError',
        );
        snapshot = await _configDocument.get(
          const GetOptions(source: Source.cache),
        );
      }
      _config = snapshot.exists && snapshot.data() != null
          ? AppConfig.fromFirestore(snapshot.data()!)
          : AppConfig.defaultConfig();
      if (!snapshot.exists) {
        _errorMessage =
            'مستند الإعدادات غير موجود: $_collectionName/$_documentName';
      } else {
        _errorMessage = null;
      }
      debugPrint(
        '[RemoteSettings] exists=${snapshot.exists} '
        'enableVideoDownload=${_config.enableVideoDownload} '
        'enableAds=${_config.enableAds} '
        'resolverConfigured=${_config.resolverEnabled}',
      );
    } catch (error, stackTrace) {
      _config = AppConfig.defaultConfig();
      final code = error is FirebaseException ? error.code : 'unknown';
      _errorMessage = 'تعذر تحميل إعدادات التنزيل ($code).';
      debugPrint('[RemoteSettings] Failed code=$code error=$error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isLoading = false;
      AdService.setAdsEnabled(_config.enableAds);
      if (_config.enableAds) {
        unawaited(
          AdService.initialize().then((_) => AdService.loadInterstitialAd()),
        );
      }
      notifyListeners();
    }
  }

  Future<void> refreshDocumentDownloadAvailability() async {
    try {
      final snapshot = await _downloadConfigDocument
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 8));
      _setDocumentDownloadEnabled(
        snapshot.exists && snapshot.data()?[_downloadFieldName] == true,
      );
      debugPrint(
        '[DownloadFeature] path=$_downloadCollectionName/'
        '$_downloadDocumentName enabled=$_documentDownloadEnabled',
      );
    } catch (error) {
      _setDocumentDownloadEnabled(false);
      debugPrint('[DownloadFeature] Read failed: $error');
    }
  }

  void _listenToDocumentDownloadAvailability() {
    _downloadSubscription = _downloadConfigDocument
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) {
            // A cached true value must not expose a remotely disabled feature.
            if (snapshot.metadata.isFromCache) return;
            _setDocumentDownloadEnabled(
              snapshot.exists && snapshot.data()?[_downloadFieldName] == true,
            );
          },
          onError: (Object error) {
            _setDocumentDownloadEnabled(false);
            debugPrint('[DownloadFeature] Listener failed: $error');
          },
        );
  }

  void _setDocumentDownloadEnabled(bool value) {
    if (_documentDownloadEnabled == value) return;
    _documentDownloadEnabled = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
  }
}
