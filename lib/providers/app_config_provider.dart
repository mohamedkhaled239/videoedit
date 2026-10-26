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
    _initialDownloadAvailabilityCheck =
        _initializeDocumentDownloadAvailability();
    unawaited(_initialDownloadAvailabilityCheck);
  }

  final FirebaseFirestore _firestore;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _downloadSubscription;
  AppConfig _config = AppConfig.defaultConfig();
  bool _isLoading = true;
  String? _errorMessage;
  bool _documentDownloadEnabled = false;
  late final Future<void> _initialDownloadAvailabilityCheck;

  AppConfig get config => _config;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get documentDownloadEnabled => _documentDownloadEnabled;
  Future<void> get initialDownloadAvailabilityCheck =>
      _initialDownloadAvailabilityCheck;

  DocumentReference<Map<String, dynamic>> get _configDocument =>
      _firestore.collection(_collectionName).doc(_documentName);

  DocumentReference<Map<String, dynamic>> get _downloadConfigDocument =>
      _firestore.collection(_downloadCollectionName).doc(_downloadDocumentName);

  /// Loads the remote switches once. Calling this explicitly performs a fresh
  /// server read, but no realtime listener is kept after startup.
  Future<void> loadConfig() async {
    _isLoading = true;
    notifyListeners();
    var hasCachedConfig = false;
    try {
      final projectId = _firestore.app.options.projectId;
      debugPrint(
        '[RemoteSettings] Reading project=$projectId '
        'path=$_collectionName/$_documentName',
      );

      try {
        final cachedSnapshot = await _configDocument.get(
          const GetOptions(source: Source.cache),
        );
        if (cachedSnapshot.exists && cachedSnapshot.data() != null) {
          hasCachedConfig = true;
          _config = AppConfig.fromFirestore(cachedSnapshot.data()!);
          _applyAdsConfig();
          notifyListeners();
        }
      } catch (cacheError) {
        debugPrint('[RemoteSettings] Cache unavailable: $cacheError');
      }

      final snapshot = await _configDocument
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 3));
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
      if (!hasCachedConfig) _config = AppConfig.defaultConfig();
      final code = error is FirebaseException ? error.code : 'unknown';
      _errorMessage = 'تعذر تحميل إعدادات التنزيل ($code).';
      debugPrint('[RemoteSettings] Failed code=$code error=$error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isLoading = false;
      _applyAdsConfig();
      notifyListeners();
    }
  }

  void _applyAdsConfig() {
    final wasEnabled = AdService.adsEnabled;
    AdService.setAdsEnabled(_config.enableAds);
    if (_config.enableAds && !wasEnabled) {
      unawaited(
        AdService.initialize().then((_) {
          if (!AdService.canLoadAds) return;
          AdService.loadInterstitialAd();
          AdService.loadAppOpenAd();
        }),
      );
    }
  }

  Future<void> _initializeDocumentDownloadAvailability() async {
    _setDocumentDownloadEnabled(false);
    await refreshDocumentDownloadAvailability();
    _listenToDocumentDownloadAvailability();
  }

  Future<void> refreshDocumentDownloadAvailability() async {
    try {
      final snapshot = await _downloadConfigDocument
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 3));
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
            // This feature is fail-closed: only a fresh server response may
            // expose it. Firestore's persisted cache is never authoritative.
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
