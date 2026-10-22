import 'dart:async';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String channelKey = 'high_importance_channel';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  bool _initialized = false;
  String? _token;

  String? get token => _token;
  bool get isInitialized => _initialized;

  bool get _isApplePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> initialize() async {
    if (_initialized) return;

    await AwesomeNotifications().initialize(
      defaultTargetPlatform == TargetPlatform.android
          ? 'resource://drawable/ic_stat_notification'
          : null,
      [
        NotificationChannel(
          channelKey: channelKey,
          channelName: 'إشعارات التطبيق',
          channelDescription: 'التنبيهات والتحديثات المهمة',
          defaultColor: const Color(0xFF4EDCAF),
          ledColor: Colors.white,
          importance: NotificationImportance.Max,
          channelShowBadge: true,
          onlyAlertOnce: true,
          playSound: true,
          enableVibration: true,
        ),
      ],
      debug: false,
    );

    await AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
      onNotificationCreatedMethod: onNotificationCreatedMethod,
      onNotificationDisplayedMethod: onNotificationDisplayedMethod,
      onDismissActionReceivedMethod: onDismissActionReceivedMethod,
    );

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _showRemoteNotification,
      onError: (Object error) => debugPrint('FCM foreground error: $error'),
    );
    _tokenSubscription = _messaging.onTokenRefresh.listen(
      (token) {
        _token = token;
        if (kDebugMode) debugPrint('FCM token refreshed.');
      },
      onError: (Object error) => debugPrint('FCM token refresh error: $error'),
    );

    _initialized = true;
    await _requestPermission();

    // Foreground messages are rendered by Awesome Notifications. Keeping the
    // native Firebase presentation disabled avoids duplicate alerts on iOS.
    if (_isApplePlatform) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
    }
    unawaited(refreshToken());

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('Opened from notification: ${initialMessage.messageId}');
    }
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => debugPrint('Notification opened: ${message.messageId}'),
    );
  }

  Future<String?> refreshToken({int maxAttempts = 3}) async {
    if (_isApplePlatform) {
      final apnsToken = await _waitForApnsToken();
      if (apnsToken == null) {
        debugPrint('APNs token was not available after waiting 30 seconds.');
        return null;
      }
    }

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        _token = await _messaging.getToken();
        if (_token != null) {
          if (kDebugMode) debugPrint('FCM token is available.');
          return _token;
        }
      } catch (error) {
        debugPrint('FCM token attempt $attempt/$maxAttempts failed: $error');
      }

      if (attempt < maxAttempts) {
        await Future<void>.delayed(Duration(seconds: attempt * 3));
      }
    }
    return null;
  }

  Future<String?> _waitForApnsToken() async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    var attempt = 0;
    while (DateTime.now().isBefore(deadline)) {
      attempt++;
      try {
        final token = await _messaging.getAPNSToken();
        if (token != null) {
          debugPrint('APNs token is ready after $attempt attempt(s).');
          return token;
        }
      } catch (error) {
        debugPrint('APNs token check failed: $error');
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    return null;
  }

  /* Internal notification test helper disabled for production.
  Future<bool> showTestNotification() async {
    return AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: channelKey,
        title: 'الإشعارات تعمل بنجاح',
        body: 'هذا إشعار اختبار محلي من التطبيق.',
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Status,
      ),
    );
  }
  */

  Future<void> _requestPermission() async {
    var isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      isAllowed = await AwesomeNotifications()
          .requestPermissionToSendNotifications();
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint(
      'Notification permission: local=$isAllowed, FCM=${settings.authorizationStatus.name}',
    );
  }

  Future<void> _showRemoteNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();

    if (title == null && body == null) {
      debugPrint('FCM message has no displayable title/body: ${message.data}');
      return;
    }

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id:
            message.messageId?.hashCode.abs().remainder(100000) ??
            DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: channelKey,
        title: title ?? 'إشعار جديد',
        body: body ?? '',
        notificationLayout: NotificationLayout.Default,
        payload: message.data.map((key, value) => MapEntry(key, '$value')),
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<void> onNotificationCreatedMethod(
    ReceivedNotification receivedNotification,
  ) async {
    debugPrint('Notification created: ${receivedNotification.id}');
  }

  @pragma('vm:entry-point')
  static Future<void> onNotificationDisplayedMethod(
    ReceivedNotification receivedNotification,
  ) async {
    debugPrint('Notification displayed: ${receivedNotification.id}');
  }

  @pragma('vm:entry-point')
  static Future<void> onDismissActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    debugPrint('Notification dismissed: ${receivedAction.id}');
  }

  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    debugPrint('Notification action: ${receivedAction.payload}');
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _openedSubscription?.cancel();
    _initialized = false;
  }
}
