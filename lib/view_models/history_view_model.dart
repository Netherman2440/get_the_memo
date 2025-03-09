import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_the_memo/services/database_service.dart';
import 'package:get_the_memo/models/meeting.dart';
import 'package:get_the_memo/services/notification_service.dart';
import 'package:get_the_memo/services/whisper_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class HistoryViewModel extends ChangeNotifier {
  // List of meetings
  List<Meeting> _meetings = [];
  bool _isLoading = true;
  String? _error;

  // Audio player instance
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _currentPlayingId;

  final WhisperService _whisperService = WhisperService();
  
  // Timer to periodically check transcription status
  Timer? _transcriptionCheckTimer;

  // Getters
  List<Meeting> get meetings => _meetings;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isPlaying => _isPlaying;
  String? get currentPlayingId => _currentPlayingId;

  // Initialize and start checking for background transcriptions
  

  // Load meetings from database
  Future<void> loadMeetings() async {
    try {
      _isLoading = true;
      notifyListeners();

      _meetings = await DatabaseService.getMeetings();
      _error = null;
      
      // Check for any meetings that were being transcribed when app was closed

    } catch (e) {
      _error = 'Failed to load meetings';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteMeeting(String id) async {
    try {
      //remove audio file
      final filePath =
          _meetings.firstWhere((meeting) => meeting.id == id).audioUrl;
      if (filePath != null) {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      //remove from database
      await DatabaseService.deleteMeeting(id);
      _meetings.removeWhere((meeting) => meeting.id == id);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete meeting';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveEditedMeeting(Meeting meeting) async {
    try {
      _isLoading = true;
      notifyListeners();
      await DatabaseService.updateMeeting(meeting);
      _meetings[_meetings.indexWhere((m) => m.id == meeting.id)] = meeting;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to save edited meeting';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _transcriptionCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> updateMeeting(Meeting meeting) async {
    await DatabaseService.updateMeeting(meeting);
    _meetings[_meetings.indexWhere((m) => m.id == meeting.id)] = meeting;
    notifyListeners();
  }
}
