import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/app_config.dart';

class AppConfigProvider extends ChangeNotifier {
  static const String _collectionName = 'videoapp-config';
  static const String _documentName = 'config';
  static const String _downloadCollectionName = 'editvideo';
  static const String _downloadDocumentName = 'editvideo';
  static const String _downloadFieldName = 'editvideo';

  AppConfig _config = AppConfig.defaultConfig();
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _downloadSubscription;
  Timer? _downloadAvailabilityTimer;
  bool _documentDownloadEnabled = false;

  AppConfig get config => _config;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  /// This is deliberately false until Firestore confirms the flag from the
  /// server. Cached values never enable a network-only feature.
  bool get documentDownloadEnabled => _documentDownloadEnabled;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _configDocument =>
      _firestore.collection(_collectionName).doc(_documentName);

  AppConfigProvider() {
    loadConfig().then((_) => listenToConfigChanges());
    _monitorDocumentDownloadFeature();
  }

  DocumentReference<Map<String, dynamic>> get _downloadConfigDocument =>
      _firestore.collection(_downloadCollectionName).doc(_downloadDocumentName);

  void _monitorDocumentDownloadFeature() {
    unawaited(refreshDocumentDownloadAvailability());
    _downloadSubscription = _downloadConfigDocument
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
          // A cached true value must not expose the page while offline.
          if (snapshot.metadata.isFromCache) return;
          _setDocumentDownloadEnabled(
            snapshot.data()?[_downloadFieldName] == true,
          );
        }, onError: (_) => _setDocumentDownloadEnabled(false));
    _downloadAvailabilityTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(refreshDocumentDownloadAvailability()),
    );
  }

  Future<void> refreshDocumentDownloadAvailability() async {
    try {
      final snapshot = await _downloadConfigDocument
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 5));
      _setDocumentDownloadEnabled(
        snapshot.exists && snapshot.data()?[_downloadFieldName] == true,
      );
    } catch (_) {
      _setDocumentDownloadEnabled(false);
    }
  }

  void _setDocumentDownloadEnabled(bool value) {
    if (_documentDownloadEnabled == value) return;
    _documentDownloadEnabled = value;
    notifyListeners();
  }

  Future<void> loadConfig() async {
    try {
      _isLoading = true;
      notifyListeners();

      final doc = await _configDocument.get();

      if (doc.exists && doc.data() != null) {
        _config = AppConfig.fromFirestore(doc.data()!);
      } else {
        await createDefaultConfig();
      }

      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'خطأ في تحميل الإعدادات: $e';
      _isLoading = false;
      _config = AppConfig.defaultConfig();
      notifyListeners();
    }
  }

  Future<void> createDefaultConfig() async {
    try {
      final defaultConfig = AppConfig.defaultConfig();
      await _configDocument.set(defaultConfig.toMap());
      _config = defaultConfig;
    } catch (e) {
      debugPrint('خطأ في إنشاء الإعدادات الافتراضية: $e');
    }
  }

  Future<void> updateConfig(AppConfig newConfig) async {
    try {
      await _configDocument.set(newConfig.toMap(), SetOptions(merge: true));
      _config = newConfig;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'خطأ في تحديث الإعدادات: $e';
      notifyListeners();
    }
  }

  void listenToConfigChanges() {
    try {
      _subscription?.cancel();
      _subscription = _configDocument.snapshots().listen(
        (snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            _config = AppConfig.fromFirestore(snapshot.data()!);
            notifyListeners();
          }
        },
        onError: (error) {
          _errorMessage = 'خطأ في الاستماع للتغييرات: $error';
          notifyListeners();
        },
      );
    } catch (error) {
      _errorMessage = 'تعذر تشغيل تحديثات الإعدادات: $error';
      debugPrint(_errorMessage);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _downloadSubscription?.cancel();
    _downloadAvailabilityTimer?.cancel();
    super.dispose();
  }
}
