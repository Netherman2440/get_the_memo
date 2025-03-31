import 'package:flutter/material.dart';
import 'package:get_the_memo/pages/history_page.dart';
import 'package:get_the_memo/pages/record_page.dart';
import 'package:get_the_memo/pages/settings_page.dart';
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
  
  final processService = ProcessService();

  // Initialize notifications
  await NotificationService.initialize();
  await NotificationService.requestPermissions();
  
  await DatabaseService.init();
  runApp(MyApp(processService: processService));
}

class MyApp extends StatelessWidget {
  final ProcessService processService;
  const MyApp({super.key, required this.processService});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProcessService>(
      create: (_) => processService,
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
      appBar: AppBar(
        title: const Text('Get the Memo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Add settings page navigation logic here
              showDialog(context: context, builder: (context) => SettingsPage());
            },
          ),
        ],
      ),
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
