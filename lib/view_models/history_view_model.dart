import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_the_memo/pages/details_page.dart';
import 'package:get_the_memo/services/database_service.dart';
import 'package:get_the_memo/models/meeting.dart';
import 'package:get_the_memo/services/process_service.dart';
import 'package:get_the_memo/services/whisper_service.dart';
import 'package:just_audio/just_audio.dart';

class HistoryViewModel extends ChangeNotifier {
  HistoryViewModel({required this.processService}) {
    loadMeetings();
  }

  // List of meetings
  List<Meeting> _meetings = [];
  bool _isLoading = true;
  String? _error;

  // Audio player instance
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _currentPlayingId;

  final ProcessService processService;
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

  Future<void> showDetails(BuildContext context, String meetingId) async {
    // Navigate to details page
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DetailsPage(meetingId: meetingId),
      ),
    );

    await loadMeetings();
  }

  Widget getHistoryIcon(BuildContext context, String meetingId) {
    if (isProcessing(meetingId)) {
      return CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
          Theme.of(context).colorScheme.onPrimary,
        ),
      );
    } else {
      return IconButton(
        icon: Icon(Icons.delete),
        onPressed: () {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Text('Delete Meeting'),
                  content: Text(
                    'Are you sure you want to delete this meeting?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        deleteMeeting(meetingId);
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: Text(
                        'Delete',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onError,
                        ),
                      ),
                    ),
                  ],
                ),
          );
        },
      );
    }
  }

  bool isProcessing(String meetingId) {

    var processes = processService.getProcesses(meetingId);

    if (processes.isEmpty) {
      return false;
    }

    return processes.any((process) =>
    
     process.steps.any((step) => step.status == StepStatus.inProgress));
  }
}
