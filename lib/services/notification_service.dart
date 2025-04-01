import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  // Define channel IDs as constants
  static const String quietChannelId = 'quiet_process_channel';
  static const String loudChannelId = 'process_channel';

  // Initialize the notification service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Create both notification channels with different settings
    final AndroidNotificationChannel quietChannel = AndroidNotificationChannel(
      quietChannelId,
      'Quiet Process Notifications',
      description: 'Silent notifications for process status',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      enableLights: false,
    );

    final AndroidNotificationChannel loudChannel = AndroidNotificationChannel(
      loudChannelId,
      'Process Notifications',
      description: 'Important process notifications',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    // Create both channels
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(quietChannel);
    await androidPlugin?.createNotificationChannel(loudChannel);

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
    bool sound = false,  // This parameter determines which channel to use
  }) async {
    await initialize();
    
    // Choose channel and settings based on sound parameter
    final String channelId = sound ? loudChannelId : quietChannelId;
    
    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          channelId,
          sound ? 'Process Notifications' : 'Quiet Process Notifications',
          channelDescription: sound 
              ? 'Important process notifications'
              : 'Silent notifications for process status',
          importance: sound ? Importance.high : Importance.low,
          priority: sound ? Priority.high : Priority.low,
          playSound: sound,
          enableVibration: sound,
          enableLights: sound,
          showWhen: false,
        );

    final DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: sound,
        );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // Add this utility method to clean up channels if needed during development
  static Future<void> deleteNotificationChannels() async {
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.deleteNotificationChannel(quietChannelId);
    await androidPlugin?.deleteNotificationChannel(loudChannelId);
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
