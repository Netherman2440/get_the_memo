import 'package:flutter/material.dart';
import 'package:get_the_memo/models/meeting.dart';
import 'package:get_the_memo/services/audio_service.dart';
import 'package:get_the_memo/services/database_service.dart';
import 'package:get_the_memo/services/process_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';

class RecordViewModel extends ChangeNotifier {
  RecordingState _state = RecordingState.idle;
  String? _currentFileName;
  RecordingState get state => _state;
  Meeting? currentMeeting;
  final ProcessService processService;//todo: use it
  
  static const int SEGMENT_DURATION = 600; // 10 minutes in seconds
  int _currentSegment = 0;
  DateTime? _recordingStartTime;
  Timer? _segmentTimer;
  String? _recordingDirectory;
  
  RecordViewModel({required this.processService}) {
    
  }

  // Toggle recording state and handle audio operations
  Future<void> toggleRecording() async {
    try {
      switch (_state) {
        case RecordingState.idle:
          _currentFileName = DateTime.now().millisecondsSinceEpoch.toString();
          _recordingDirectory = await _createRecordingDirectory(_currentFileName!);
          await _startNewSegment();
          _state = RecordingState.recording;
          _startSegmentTimer();

        case RecordingState.recording:
          await AudioService.pauseRecording();
          _segmentTimer?.cancel();
          _state = RecordingState.paused;

        case RecordingState.paused:
          await AudioService.resumeRecording();
          _state = RecordingState.recording;
          _startSegmentTimer();
      }
      notifyListeners();
    } catch (e) {
      print('Error toggling recording: $e');
      rethrow;
    }
  }

  Future<String> _createRecordingDirectory(String meetingId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final recordingDir = Directory('${appDir.path}/recordings/$meetingId');
    await recordingDir.create(recursive: true);
    return recordingDir.path;
  }

  void _startSegmentTimer() {
    _recordingStartTime = DateTime.now();
    print('Starting segment timer. Current segment: $_currentSegment');
    _segmentTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
      final elapsedSeconds = DateTime.now().difference(_recordingStartTime!).inSeconds;
      print('Elapsed time: $elapsedSeconds seconds');
      if (elapsedSeconds >= SEGMENT_DURATION) {
        print('Segment duration reached. Starting new segment...');
        await _startNewSegment();
      }
    });
  }

  Future<void> _startNewSegment() async {
    try {
      print('\n--- Starting new segment ---');
      if (_state == RecordingState.recording) {
        print('Stopping current segment recording...');
        final previousPath = await AudioService.stopRecording();
        print('Previous segment saved at: $previousPath');
      }
      
      final segmentPath = '$_recordingDirectory/segment_${_currentSegment.toString().padLeft(3, '0')}.wav';
      print('Starting new segment recording at: $segmentPath');
      await AudioService.startRecording(segmentPath);
      
      print('Segment $_currentSegment started successfully');
      _currentSegment++;
      _recordingStartTime = DateTime.now();
    } catch (e) {
      print('Error during segment transition: $e');
      rethrow;
    }
  }

  // Save recording and reset state
  Future<void> saveRecording() async {
    try {
      print('\n--- Saving recording ---');
      _segmentTimer?.cancel();
      if (_currentFileName != null) {
        print('Stopping final segment...');
        final path = await AudioService.stopRecording();
        print('Final segment saved at: $path');
        
        // Get total duration by summing up all segments
        print('\nCalculating total duration...');
        int totalDuration = 0;
        final directory = Directory(_recordingDirectory!);
        final files = directory.listSync()
            .where((f) => f.path.endsWith('.wav'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
        
        print('Found ${files.length} segments:');
        for (var file in files) {
          print('Processing segment: ${file.path}');
          final player = AudioPlayer();
          await player.setFilePath(file.path);
          final duration = player.duration?.inSeconds ?? 0;
          totalDuration += duration;
          print('Segment duration: ${duration}s');
          await player.dispose();
        }
        
        print('Total recording duration: ${totalDuration}s');

        currentMeeting = Meeting(
          id: _currentFileName!,
          title: 'New Meeting',
          description: 'Description',
          createdAt: DateTime.now(),
          audioUrl: _recordingDirectory!,
          duration: totalDuration,
        );
        
        print('Saving meeting to database...');
        await DatabaseService.insertMeeting(currentMeeting!);
        print('Meeting saved successfully');
      }
    } catch (e) {
      print('Error saving recording: $e');
    } finally {
      _cleanup();
    }
  }

  // Cancel recording
  Future<void> cancelRecording() async {
    try {
      _segmentTimer?.cancel();
      if (_recordingDirectory != null) {
        final directory = Directory(_recordingDirectory!);
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      }
    } catch (e) {
      print('Error canceling recording: $e');
    } finally {
      _cleanup();
    }
  }

  void _cleanup() {
    _state = RecordingState.idle;
    _currentFileName = null;
    _currentSegment = 0;
    _recordingDirectory = null;
    _recordingStartTime = null;
    notifyListeners();
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
        return 'Nagrywanie...';
      case RecordingState.paused:
        return 'Nagrywanie wstrzymane';
      case RecordingState.idle:
        return 'Gotowy do nagrywania';
    }
  }

  Future<void> processMeeting(BuildContext context, Meeting meeting, List<ProcessType> request) async {
    await processService.process_Meeting(context, meeting, request);
  }


  @override
  void dispose() {
    AudioService.dispose();
    super.dispose();
  }
}

enum RecordingState { idle, recording, paused }
