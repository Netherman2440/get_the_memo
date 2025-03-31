import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  // Initialize the notification service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    // Initialization settings for both platforms
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    // Initialize the plugin
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        print('Notification clicked: ${response.payload}');
      },
    );

    _isInitialized = true;
  }

  // Request notification permissions
  static Future<void> requestPermissions() async {
    await initialize();

    // Request permissions for iOS
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Request permissions for Android (for Android 13+)
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
  }

  // Add method to check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    final platform = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (platform != null) {
      final result = await platform.areNotificationsEnabled();
      print('Notifications enabled: $result');
      return result ?? false;
    }
    return false;
  }

  // Modify showNotification to check permissions first
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
    bool sound = false,
  }) async {
    print('Attempting to show notification');
    await initialize();
    
    final enabled = await areNotificationsEnabled();
    if (!enabled) {
      print('Notifications are not enabled!');
      await requestPermissions();
    }
    print('Showing notification with sound: $sound');
    // Android notification details
    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'process_channel', // Channel ID
          'Process Notifications', // Channel name
          channelDescription:
              'Notifications for meeting processing status', // Channel description
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          playSound: sound,
        );

    // iOS notification details
    final DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: sound,
        );

    // General notification details
    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );

    // Show the notification
    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  

  // Cancel a specific notification
  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  // Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}
