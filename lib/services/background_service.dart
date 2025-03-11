import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_background_service_ios/flutter_background_service_ios.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_the_memo/services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'whisper_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
class BackgroundService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();
    
    // Create notification channel for foreground service
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'transcription_service', // id
      'Transcription Service', // title
      description: 'Used for the transcription background service', // description
      importance: Importance.low, // importance must be at low or higher level
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
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'transcription_service',
        initialNotificationTitle: 'Transcription Service',
        initialNotificationContent: 'Initializing',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  // iOS background handler
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  // Main background handler
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Only available for flutter 3.0.0 and later
    DartPluginRegistrant.ensureInitialized();
    
    // For notifications in foreground service
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    
    // Handle foreground/background mode switching
    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });
  
      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    // Listen for commands from the main app
    service.on('startTranscription').listen((event) async {
      if (event == null) return;
      
      final audioPath = event['audioPath'] as String;
      final meetingId = event['meetingId'] as String;
      
      // Debug log
      print('Background service received transcription request for meeting: $meetingId');
      
      try {
        // Update notification to show transcription is in progress
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "Transcription in Progress",
            content: "Processing audio for meeting: $meetingId",
          );
        }
        
        // SIMPLIFIED: Instead of calling WhisperService, just simulate processing
        // This is to test if the background service works without the problematic dependency
        await Future.delayed(Duration(seconds: 5)); // Simulate processing time
        
        print('Simulated transcription completed for meeting: $meetingId');
        
        // Mark as completed using SharedPreferences (which is safe for background)
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('transcription_in_progress_$meetingId', false);
          await prefs.setBool('transcription_completed_$meetingId', true);
          await prefs.setString('transcription_result_$meetingId', 'Simulated transcription result');
          print('Transcription status updated for meeting: $meetingId');
        } catch (prefError) {
          print('SharedPreferences error: $prefError');
        }
        
        // Update notification to show completion
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "Transcription Complete",
            content: "Successfully processed meeting: $meetingId",
          );
        }
        
        // Stop the service after successful transcription
        await Future.delayed(Duration(seconds: 2));
        service.stopSelf();
        
      } catch (e) {
        print('Transcription error for meeting $meetingId: $e');
        
        // Mark as failed
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('transcription_in_progress_$meetingId', false);
          await prefs.setBool('transcription_error_$meetingId', true);
          await prefs.setString('transcription_error_message_$meetingId', e.toString());
        } catch (prefError) {
          print('SharedPreferences error: $prefError');
        }
        
        // Update notification to show error
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "Transcription Failed",
            content: "Error processing meeting: $meetingId",
          );
        }
        
        // Stop the service after error handling
        await Future.delayed(Duration(seconds: 5));
        service.stopSelf();
      }
    });
    
    // Add handler for manually stopping the service if needed
    service.on('stopService').listen((event) async {
      service.stopSelf();
    });
  }

  // Method to start transcription from the main app
  static Future<bool> startTranscription({
    required String audioPath,
    required String meetingId,
    int maxFileSizeMB = 20,
  }) async {
    final service = FlutterBackgroundService();
    
    // Mark as in progress
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('transcription_in_progress_$meetingId', true);
    await prefs.setBool('transcription_error_$meetingId', false);
    
    // Start the service if not running
    final isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
      
      // Give the service a moment to start properly
      await Future.delayed(Duration(milliseconds: 500));
    }
    
    // Send transcription data
    service.invoke('startTranscription', {
      'audioPath': audioPath,
      'meetingId': meetingId,
      'maxFileSizeMB': maxFileSizeMB,
    });
    
    return true;
  }
  
  /// Checks if a transcription is in progress
  static Future<bool> isTranscriptionInProgress(String meetingId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('transcription_in_progress_$meetingId') ?? false;
  }
  
  /// Checks if a transcription has completed
  static Future<bool> isTranscriptionCompleted(String meetingId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('transcription_completed_$meetingId') ?? false;
  }
  
  /// Checks if a transcription has failed
  static Future<bool> hasTranscriptionError(String meetingId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('transcription_error_$meetingId') ?? false;
  }
  
  /// Gets the error message if a transcription has failed
  static Future<String?> getTranscriptionErrorMessage(String meetingId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('transcription_error_message_$meetingId');
  }
} 