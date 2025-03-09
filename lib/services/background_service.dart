import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_background_service_ios/flutter_background_service_ios.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'whisper_service.dart';

class BackgroundServiceManager {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

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
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  // Main background handler
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    
    // Load environment variables
    await dotenv.load();

    // Listen for commands from the main app
    service.on('startTranscription').listen((event) async {
      if (event == null) return;
      
      final audioPath = event['audioPath'] as String;
      final meetingId = event['meetingId'] as String;
      final maxFileSizeMB = event['maxFileSizeMB'] as int? ?? 20;
      
      // Update notification
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Transcribing Audio",
          content: "Processing meeting: $meetingId",
        );
      }
      
      try {
        // Create service instance
        final whisperService = WhisperService();
        
        // Process transcription
        final transcription = await whisperService.processTranscription(
          audioPath: audioPath,
          maxFileSizeMB: maxFileSizeMB,
          saveProgress: true,
          meetingId: meetingId,
        );
        
        // Save the result to shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('transcription_$meetingId', transcription);
        await prefs.setBool('transcription_completed_$meetingId', true);
        await prefs.setBool('transcription_in_progress_$meetingId', false);
        
        print('Background transcription completed for meeting: $meetingId');
        
        // Update notification
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "Transcription Complete",
            content: "Meeting $meetingId has been transcribed",
          );
        }
      } catch (e) {
        print('Background task failed: $e');
        
        // Mark as failed
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('transcription_in_progress_$meetingId', false);
        await prefs.setBool('transcription_error_$meetingId', true);
        await prefs.setString('transcription_error_message_$meetingId', e.toString());
        
        // Update notification
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "Transcription Failed",
            content: "Error: ${e.toString().substring(0, min(50, e.toString().length))}",
          );
        }
      }
    });
  }
} 