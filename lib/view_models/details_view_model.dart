import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get_the_memo/models/meeting.dart';
import 'package:get_the_memo/services/background_service.dart';
import 'package:get_the_memo/services/database_service.dart';
import 'package:get_the_memo/services/openai_service.dart' as OpenAiService;
import 'package:get_the_memo/services/whisper_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DetailsViewModel extends ChangeNotifier {
  Meeting? meeting;
  String? _meetingId;
  String? transcript;
  String? summary;
  String? tasks;
  TranscriptionStatus transcriptionStatus = TranscriptionStatus.notStarted;
  SummaryStatus summaryStatus = SummaryStatus.notStarted;
  TasksStatus tasksStatus = TasksStatus.notStarted;

  // Constructor that accepts meetingId
  DetailsViewModel({String? meetingId}) {
    if (meetingId != null) {
      loadMeeting(meetingId);
    }
  }

  // Load meeting data
  Future<void> loadMeeting(String meetingId) async {
    _meetingId = meetingId;

    try {
      transcriptionStatus = await getTranscriptionStatus(meetingId);
      summaryStatus = await getSummaryStatus(meetingId);
      meeting = await DatabaseService.getMeeting(meetingId);
      transcript = await DatabaseService.getTranscription(meetingId);
      summary = await DatabaseService.getSummary(meetingId);
    } catch (e) {
      print('Failed to load meeting details, $e');
    }

    notifyListeners();
  }

  Future<void> createTranscript(String meetingId) async {
    transcriptionStatus = TranscriptionStatus.inProgress;
    String audioPath = meeting?.audioUrl ?? '';
    notifyListeners();
    var transcriptionObj = await WhisperService().processTranscription(
      audioPath: audioPath,
      meetingId: meetingId,
      saveProgress: true,
    );
    final transcriptionJson = jsonDecode(transcriptionObj!);

    transcript = transcriptionJson['text'];
    transcriptionStatus = await getTranscriptionStatus(meetingId);
    print('Transcript created: $transcript');
    await DatabaseService.insertTranscription(meetingId, transcript!);

    notifyListeners();
  }

  Future<void> createSummary(String meetingId) async {
    summaryStatus = SummaryStatus.inProgress;
    notifyListeners();

    summary = await OpenAiService.summarize(transcript!, meetingId);

    summaryStatus = await getSummaryStatus(meetingId);
    notifyListeners();
  }

  Future<void> createTasks(String meetingId) async {
    tasksStatus = TasksStatus.inProgress;
    notifyListeners();
    tasks = await OpenAiService.actionPoints(transcript!);
    tasksStatus = TasksStatus.completed;
    notifyListeners();
  }

  Future<void> editTitle(String title) async {
    meeting?.title = title;
    await DatabaseService.updateMeeting(meeting!);
    notifyListeners();
  }

  Future<void> editDescription(String description) async {
    meeting?.description = description;
    await DatabaseService.updateMeeting(meeting!);
    notifyListeners();
  }

  Future<void> editTranscript(String transcript) async {
    this.transcript = transcript;
    await DatabaseService.updateTranscription(meeting!.id, transcript);
    notifyListeners();
  }

  void editSummary(String summary) async {
    this.summary = summary;
    await DatabaseService.updateSummary(meeting!.id, summary);
    notifyListeners();
  }

  // Reload current meeting if needed
  Future<void> refresh() async {
    if (_meetingId != null) {
      await loadMeeting(_meetingId!);
    }
  }

  Future<TranscriptionStatus> getTranscriptionStatus(String meetingId) async {
    TranscriptionStatus status = TranscriptionStatus.notStarted;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('transcription_in_progress_$meetingId') ?? false) {
      status = TranscriptionStatus.inProgress;
    } else if (prefs.getBool('transcription_completed_$meetingId') ?? false) {
      status = TranscriptionStatus.completed;
    } else if (prefs.getBool('transcription_error_$meetingId') ?? false) {
      status = TranscriptionStatus.failed;
    }

    return status;
  }

  Future<SummaryStatus> getSummaryStatus(String meetingId) async {
    SummaryStatus status = SummaryStatus.notStarted;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('summary_in_progress_$meetingId') ?? false) {
      status = SummaryStatus.inProgress;
    } else if (prefs.getBool('summary_completed_$meetingId') ?? false) {
      status = SummaryStatus.completed;
    } else if (prefs.getBool('summary_error_$meetingId') ?? false) {
      status = SummaryStatus.failed;
    }

    return status;
  }

  getSummarySection(BuildContext context) {
    if (transcript == null || transcript!.isEmpty) {
      return const SizedBox.shrink();
    }

    switch (summaryStatus) {
      case SummaryStatus.notStarted:
        return ElevatedButton(
          onPressed: () {
            createSummary(meeting!.id);
          },
          child: const Text('Create Summary'),
        );
      case SummaryStatus.inProgress:
        return ElevatedButton(
          onPressed: null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text('Summary in progress'),
            ],
          ),
        );
      case SummaryStatus.completed:
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: ListTile(
            title: Text('Summary'),
            subtitle: Text(summary!),
            onTap: () {
              showEditDialog(
                context: context,
                title: 'Edit Summary',
                initialContent: summary!,
                onSave: editSummary,
              );
            },
          ),
        );
      case SummaryStatus.failed:
        return ElevatedButton(
          onPressed: () {
            createSummary(meeting!.id);
          },
          child: const Text('Retry Summary'),
        );
    }
  }

  // Helper method to show edit dialog
  void showEditDialog({
    required BuildContext context,
    required String title,
    required String initialContent,
    required Function(String) onSave,
  }) {
    final TextEditingController controller = TextEditingController(text: initialContent);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: null, // Allows multiple lines
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter text here',
          ),
          autofocus: true,
          

        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(context);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }
}

enum TranscriptionStatus { notStarted, inProgress, completed, failed }

enum SummaryStatus { notStarted, inProgress, completed, failed }

enum TasksStatus { notStarted, inProgress, completed, failed }
