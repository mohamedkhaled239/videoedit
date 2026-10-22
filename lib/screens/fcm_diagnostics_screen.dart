import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/notification_service.dart';
import '../utils/app_colors.dart';

class FcmDiagnosticsScreen extends StatefulWidget {
  const FcmDiagnosticsScreen({super.key});

  @override
  State<FcmDiagnosticsScreen> createState() => _FcmDiagnosticsScreenState();
}

class _FcmDiagnosticsScreenState extends State<FcmDiagnosticsScreen> {
  static const MethodChannel _diagnosticsChannel = MethodChannel(
    'videoedit/fcm_diagnostics',
  );

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final List<String> _messages = [];

  bool _loading = true;
  bool _firebaseInitialized = false;
  bool _messagingInitialized = false;
  bool? _autoInitEnabled;
  AuthorizationStatus? _permissionStatus;
  String? _apnsToken;
  String? _fcmToken;
  String? _bundleIdentifier;
  FirebaseOptions? _firebaseOptions;

  bool get _isApplePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  void initState() {
    super.initState();
    unawaited(_loadStatus());
  }

  Future<void> _loadStatus() async {
    _setLoading(true);
    try {
      _firebaseInitialized = Firebase.apps.isNotEmpty;
      if (!_firebaseInitialized) {
        _addMessage('Firebase is not initialized.');
        return;
      }

      final app = Firebase.app();
      _firebaseOptions = app.options;
      final service = NotificationService();
      await service.initialize();
      _messagingInitialized = service.isInitialized;
      _autoInitEnabled = _messaging.isAutoInitEnabled;
      _permissionStatus =
          (await _messaging.getNotificationSettings()).authorizationStatus;

      if (_isApplePlatform) {
        _bundleIdentifier = await _diagnosticsChannel.invokeMethod<String>(
          'getBundleIdentifier',
        );
        _apnsToken = await _messaging.getAPNSToken();
      }

      _fcmToken = service.token;
      if (_fcmToken == null && (!_isApplePlatform || _apnsToken != null)) {
        _fcmToken = await service.refreshToken(maxAttempts: 1);
      }

      _addMessage('Diagnostic status refreshed.');
    } catch (error) {
      _addMessage('Status check failed: $error');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _refreshFcmToken() async {
    _setLoading(true);
    try {
      final token = await NotificationService().refreshToken(maxAttempts: 3);
      if (!mounted) return;
      setState(() => _fcmToken = token);
      _addMessage(
        token == null
            ? 'FCM token is unavailable. Check the APNs token first.'
            : 'FCM token refreshed successfully.',
      );
    } catch (error) {
      _addMessage('FCM token refresh failed: $error');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _recheckApnsToken() async {
    _setLoading(true);
    try {
      String? token;
      for (var attempt = 0; attempt < 10 && token == null; attempt++) {
        token = await _messaging.getAPNSToken();
        if (token == null) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
      if (!mounted) return;
      setState(() => _apnsToken = token);
      _addMessage(
        token == null
            ? 'APNs token is still unavailable after 10 seconds.'
            : 'APNs token is available.',
      );
    } catch (error) {
      _addMessage('APNs token check failed: $error');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _copyFcmToken() async {
    final token = _fcmToken;
    if (token == null) return;
    await Clipboard.setData(ClipboardData(text: token));
    _addMessage('FCM token copied to the clipboard.');
  }

  void _clearMessages() {
    if (!mounted) return;
    setState(_messages.clear);
  }

  void _addMessage(String message) {
    if (!mounted) return;
    setState(() {
      _messages.insert(0, '${DateTime.now().toIso8601String()}  $message');
    });
  }

  void _setLoading(bool value) {
    if (!mounted) return;
    setState(() => _loading = value);
  }

  @override
  Widget build(BuildContext context) {
    final options = _firebaseOptions;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('FCM Diagnostics')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_loading) const LinearProgressIndicator(),
          _statusRow('Permission', _permissionStatus?.name ?? 'Unknown'),
          _statusRow('APNs token', _tokenStatus(_apnsToken)),
          _statusRow('FCM token', _tokenStatus(_fcmToken)),
          _statusRow('Firebase App ID', options?.appId ?? 'Unavailable'),
          _statusRow(
            'Firebase Project ID',
            options?.projectId ?? 'Unavailable',
          ),
          _statusRow(
            'Current iOS Bundle ID',
            _bundleIdentifier ?? 'Unavailable',
          ),
          _statusRow(
            'Firebase iOS Bundle ID',
            options?.iosBundleId ?? 'Unavailable',
          ),
          _statusRow(
            'Firebase initialized',
            _firebaseInitialized ? 'Yes' : 'No',
          ),
          _statusRow(
            'Messaging initialized',
            _messagingInitialized ? 'Yes' : 'No',
          ),
          _statusRow(
            'FCM auto-init enabled',
            _autoInitEnabled == null
                ? 'Unknown'
                : (_autoInitEnabled! ? 'Yes' : 'No'),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _loading || _fcmToken == null ? null : _copyFcmToken,
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy FCM Token'),
              ),
              OutlinedButton.icon(
                onPressed: _loading ? null : _refreshFcmToken,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh FCM Token'),
              ),
              OutlinedButton.icon(
                onPressed: _loading || !_isApplePlatform
                    ? null
                    : _recheckApnsToken,
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Recheck APNs Token'),
              ),
              TextButton.icon(
                onPressed: _messages.isEmpty ? null : _clearMessages,
                icon: const Icon(Icons.clear_all_rounded),
                label: const Text('Clear Status'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Diagnostic messages',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_messages.isEmpty)
            const Text('No messages.')
          else
            ..._messages.map(
              (message) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SelectableText(message),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusRow(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            SelectableText(value),
          ],
        ),
      ),
    );
  }

  String _tokenStatus(String? token) {
    if (token == null || token.isEmpty) return 'Unavailable';
    return token;
  }
}
