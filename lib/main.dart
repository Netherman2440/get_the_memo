import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:get_the_memo/pages/history_page.dart';
import 'package:get_the_memo/pages/record_page.dart';
import 'package:get_the_memo/services/database_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_the_memo/services/notification_service.dart';
import 'package:get_the_memo/services/background_service.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
//flutter emulators --launch Pixel_3a_API_34_extension_level_7_x86_64
/*
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();
  
  // Create notification channel for Android
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'transcription_service', // id
    'Transcription Service', // title
    description: 'Used for the transcription background service', // description
    importance: Importance.low,
  );
  
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
      
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: channel.id,
      initialNotificationTitle: 'Transcription Service',
      initialNotificationContent: 'Initializing',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  // For Android, bring to foreground
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    
    // Set notification info immediately to avoid "Bad notification" error
    service.setForegroundNotificationInfo(
      title: "Transcription Service",
      content: "Running in background",
    );
  }
  
  // Listen for startTranscription command
  service.on('startTranscription').listen((event) async {
    if (event == null) return;
    
    try {
      final audioPath = event['audioPath'] as String;
      final meetingId = event['meetingId'] as String;
      final maxFileSizeMB = event['maxFileSizeMB'] as int? ?? 20;
      
      print('Background service received transcription request for meeting: $meetingId');
      
      // Import your WhisperService here
      // This is a simplified version - you'll need to adapt it to your actual implementation
      final prefs = await SharedPreferences.getInstance();
      
      try {
        // Here you would implement the actual transcription logic
        // For now, let's simulate progress updates
        for (int i = 1; i <= 10; i++) {
          // Update progress
          await prefs.setDouble('transcription_progress_$meetingId', i / 10);
          
          // Update notification to show progress
          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: "Transcribing audio",
              content: "Progress: ${i * 10}%",
            );
          }
          
          await Future.delayed(Duration(seconds: 2));
        }
        
        // Simulate completed transcription
        final mockTranscription = {
          'text': 'This is a mock transcription for testing purposes.',
          'segments': []
        };
        
        // Save result
        await prefs.setBool('transcription_in_progress_$meetingId', false);
        await prefs.setBool('transcription_completed_$meetingId', true);
        await prefs.setString('transcription_$meetingId', jsonEncode(mockTranscription));
        
        print('Transcription completed for meeting: $meetingId');
        
        // Update notification
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "Transcription Complete",
            content: "Audio has been transcribed successfully",
          );
        }
      } catch (e) {
        print('Error in background transcription: $e');
        await prefs.setBool('transcription_in_progress_$meetingId', false);
        await prefs.setBool('transcription_error_$meetingId', true);
        await prefs.setString('transcription_error_message_$meetingId', e.toString());
        
        // Update notification
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "Transcription Error",
            content: "An error occurred during transcription",
          );
        }
      }
    } catch (e) {
      print('Error processing transcription request: $e');
    }
  });
  
  // Keep the service alive
  Timer.periodic(Duration(seconds: 30), (timer) {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Transcription Service",
        content: "Running in background",
      );
    }
    
    // You can also update the UI with this data
    service.invoke('update', {
      'current_date': DateTime.now().toIso8601String(),
    });
  });
}
*/
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Załaduj zmienne środowiskowe
  await dotenv.load();
  
  // Initialize background service
  await BackgroundServiceManager.initializeService();
  
  // Inicjalizacja powiadomień
  await NotificationService.initialize();
  await NotificationService.requestPermissions();
  
  await DatabaseService.init();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'Get the Memo',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        ),
        home: HomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  var current = WordPair.random();

  var favorites = <WordPair>[];

  void toggleFavorite() {
    if (favorites.contains(current)) {
      favorites.remove(current);
    } else {
      favorites.add(current);
    }
    print(favorites);
    notifyListeners();
  }

  void getNext() {
    current = WordPair.random();
    notifyListeners();
  }
}

class HomePage extends StatefulWidget {
  static const List<BottomNavigationBarItem> items = [
    BottomNavigationBarItem(icon: Icon(Icons.mic), label: 'Record'),
    BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
  ];

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Widget> pages = [RecordPage(), HistoryPage()];
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (value) {
          setState(() {
            selectedIndex = value;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mic_outlined),
            selectedIcon: Icon(Icons.mic),
            label: 'Record',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
      body: pages[selectedIndex],
    );
  }
}
