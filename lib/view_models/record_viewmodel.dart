import 'package:flutter/material.dart';
import 'package:get_the_memo/models/meeting.dart';
import 'package:get_the_memo/services/audio_service.dart';
import 'package:get_the_memo/services/database_service.dart';
import 'package:just_audio/just_audio.dart';

class RecordViewModel extends ChangeNotifier {
  RecordingState _state = RecordingState.idle;
  String? _currentFileName;
  RecordingState get state => _state;

  RecordViewModel() {
    DatabaseService.init();
  }


  // Toggle recording state and handle audio operations
  Future<void> toggleRecording() async {
    try {
      switch (_state) {
        case RecordingState.idle:
          _currentFileName = DateTime.now().millisecondsSinceEpoch.toString();
          await AudioService.startRecording(_currentFileName!);
          _state = RecordingState.recording;
          
        case RecordingState.recording:
          await AudioService.pauseRecording();
          _state = RecordingState.paused;
          
        case RecordingState.paused:
          await AudioService.resumeRecording();
          _state = RecordingState.recording;
      }
      notifyListeners();
    } catch (e) {
      // Handle errors appropriately
      rethrow;
    }
  }

  // Save recording and reset state
  Future<void> saveRecording() async {
    try {
      if (_currentFileName != null) {
        final path = await AudioService.stopRecording();
        if (path == null) {
          throw AudioServiceException('No recording path returned');
        }

        // Get audio duration using AudioPlayer from just_audio
        final player = AudioPlayer();
        await player.setFilePath(path);
        final duration = player.duration;
        await player.dispose();

        Meeting meeting = Meeting(
          id: _currentFileName!,
          title: 'New Meeting',
          description: 'Description',
          createdAt: DateTime.now(),
          audioUrl: path,
          duration: duration?.inSeconds ?? 0
        );
        await DatabaseService.insertMeeting(meeting);

        final meetings = await DatabaseService.getMeetings();
        print('All meetings in database:');
        for (var meeting in meetings) {
          print('Meeting ID: ${meeting.id}, Audio Path: ${meeting.audioUrl}');
        }
      }
    } catch (e) {
      print('Error saving recording: $e');
    } finally {
      _state = RecordingState.idle;
      _currentFileName = null;
      notifyListeners();
    }
  }

  // Cancel recording
  Future<void> cancelRecording() async {
    try {
      if (_currentFileName != null) {
        final path = await AudioService.stopRecording();
        if (path != null) {
          await AudioService.deleteAudio(path);
        }
      }
    } catch (e) {
      print('Error canceling recording: $e');
    } finally {
      _state = RecordingState.idle;
      _currentFileName = null;
      notifyListeners();
    }
  }

  // Helper methods for UI
  IconData getRecordingIcon() {
    switch (_state) {
      case RecordingState.recording:
        return Icons.pause;
      case RecordingState.paused:
        return Icons.play_arrow;
      case RecordingState.idle:
        return Icons.mic;
    }
  }

  Color getButtonColor(BuildContext context) {
    switch (_state) {
      case RecordingState.recording:
        return Theme.of(context).colorScheme.error;
      case RecordingState.paused:
        return Theme.of(context).colorScheme.tertiary;
      case RecordingState.idle:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String getRecordingStatusText() {
    switch (_state) {
      case RecordingState.recording:
        return 'Recording...';
      case RecordingState.paused:
        return 'Recording Paused';
      case RecordingState.idle:
        return 'Ready to Record';
    }
  }

  @override
  void dispose() {
    AudioService.dispose();
    super.dispose();
  }
}

enum RecordingState { idle, recording, paused }