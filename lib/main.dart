import 'package:flutter/material.dart';
import 'package:get_the_memo/pages/history_page.dart';
import 'package:get_the_memo/pages/record_page.dart';
import 'package:get_the_memo/services/database_service.dart';
import 'package:get_the_memo/services/process_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_the_memo/services/notification_service.dart';
import 'package:get_the_memo/services/background_service.dart';

//flutter emulators --launch Pixel_3a_API_34_extension_level_7_x86_64
//flutter run --verbose-system-logs=false

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Załaduj zmienne środowiskowe
  await dotenv.load();
  
  // Initialize background service
  await BackgroundService.initializeService();
  
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
      create: (context) => ProcessService(),
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
