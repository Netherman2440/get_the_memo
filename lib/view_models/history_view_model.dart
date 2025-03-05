import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get_the_memo/services/database_service.dart';
import 'package:get_the_memo/models/meeting.dart';
import 'package:get_the_memo/services/notification_service.dart';
import 'package:get_the_memo/services/whisper_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;

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

  // Getters
  List<Meeting> get meetings => _meetings;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isPlaying => _isPlaying;
  String? get currentPlayingId => _currentPlayingId;

  // Load meetings from database
  Future<void> loadMeetings() async {
    try {
      _isLoading = true;
      notifyListeners();

      _meetings = await DatabaseService.getMeetings();
      _error = null;
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

  // Play audio method
  Future<void> playAudio(String meetingId) async {
    try {
      final meeting = _meetings.firstWhere((m) => m.id == meetingId);
      print('Audio URL: ${meeting.audioUrl}');

      final file = File(meeting.audioUrl!);
      print('File exists: ${await file.exists()}');
      print('File size: ${await file.length()} bytes');

      // Read first few bytes to verify it's a valid WAV file
      final bytes = await file.openRead().take(4).toList();
      print(bytes);

      if (meeting.audioUrl == null) {
        _error = 'No audio file available';
        notifyListeners();
        return;
      }

      if (_isPlaying && _currentPlayingId == meetingId) {
        // Stop if already playing this audio
        await _audioPlayer.stop();
        _isPlaying = false;
        _currentPlayingId = null;
      } else {
        // Play new audio
        await _audioPlayer.stop(); // Stop any previous playback
        await _audioPlayer.setFilePath(meeting.audioUrl);
        await _audioPlayer.play();
        _isPlaying = true;
        _currentPlayingId = meetingId;

        // Add listener for when audio completes
        _audioPlayer.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            _currentPlayingId = null;
            notifyListeners();
          }
        });
      }
      notifyListeners();
    } catch (e) {
      _error = 'Failed to play audio';
      notifyListeners();
    }
  }

  Future<void> generateTranscription(String meetingId) async {
    try {
      final meeting = _meetings.firstWhere((m) => m.id == meetingId);

      // Generate transcription
      final transcription = await _whisperService.transcribeLargeAudio(
        meeting.audioUrl,
      );

      // Update meeting with new transcription
      final updatedMeeting = Meeting(
        id: meeting.id,
        title: meeting.title,
        transcription: transcription,
        createdAt: meeting.createdAt,
        audioUrl: meeting.audioUrl,
        description: meeting.description,
        duration: meeting.duration,
      );

      await saveEditedMeeting(updatedMeeting);
      await NotificationService.showTranscriptionCompleteNotification(
        meetingTitle: meeting.title,
      );
    } catch (e) {
      _error = 'Failed to generate transcription: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> generateTasks(String meetingId) async {
    try {
      final meeting = _meetings.firstWhere((m) => m.id == meetingId);

      if (meeting.transcription == null || meeting.transcription!.isEmpty) {
        _error = 'No transcription available to generate tasks';
        notifyListeners();
        return;
      }

      // TODO: Implement task generation logic
      // This will be implemented later when we add task generation functionality

      notifyListeners();
    } catch (e) {
      _error = 'Failed to generate tasks: ${e.toString()}';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
