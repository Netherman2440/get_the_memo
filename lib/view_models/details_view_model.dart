import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get_the_memo/models/meeting.dart';

import 'package:get_the_memo/services/database_service.dart';
import 'package:get_the_memo/services/openai_service.dart' as OpenAiService;
import 'package:get_the_memo/services/whisper_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class DetailsViewModel extends ChangeNotifier {
  Meeting? meeting;
  String? _meetingId;
  String? transcript;
  String? summary;
  List<String> tasks = [];
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
      tasksStatus = await getTasksStatus(meetingId);
      meeting = await DatabaseService.getMeeting(meetingId);
      transcript = await DatabaseService.getTranscription(meetingId);
      summary = await DatabaseService.getSummary(meetingId);
      var tasksJson = await DatabaseService.getTasks(meetingId);
      tasks = List<String>.from(jsonDecode(tasksJson ?? '[]'));
      print('Tasks: $tasks');
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

    var tasksJson = await OpenAiService.actionPoints(transcript!, meetingId);
    tasks = List<String>.from(jsonDecode(tasksJson));
    tasksStatus = await getTasksStatus(meetingId);
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

  Future<void> editTasks(List<String> tasks) async {
    this.tasks = tasks;
    await DatabaseService.updateTasks(meeting!.id, jsonEncode(tasks));
    notifyListeners();
  }

  Future<void> editActionPoint(int index, String newValue) async {
    // Check if index is valid
    if (index >= 0 && index < tasks.length) {
      // Update the specific task at the given index
      tasks[index] = newValue;
      // Save updated tasks to database
      await DatabaseService.updateTasks(meeting!.id, jsonEncode(tasks));
      notifyListeners();
    }
  }

  // Add a new method to add an action point
  Future<void> addActionPoint(String actionPoint) async {
    if (actionPoint.isNotEmpty) {
      tasks.add(actionPoint);
      await DatabaseService.updateTasks(meeting!.id, jsonEncode(tasks));
      notifyListeners();
    }
  }

  Future<void> deleteActionPoint(String actionPoint) async {
    tasks.remove(actionPoint);
    await DatabaseService.updateTasks(meeting!.id, jsonEncode(tasks));
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

  Future<TasksStatus> getTasksStatus(String meetingId) async {
    TasksStatus status = TasksStatus.notStarted;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('tasks_in_progress_$meetingId') ?? false) {
      status = TasksStatus.inProgress;
    } else if (prefs.getBool('tasks_completed_$meetingId') ?? false) {
      status = TasksStatus.completed;
    } else if (prefs.getBool('tasks_error_$meetingId') ?? false) {
      status = TasksStatus.failed;
    }

    return status;
  }

  Widget getTranscriptionSection(BuildContext context) {
    switch (transcriptionStatus) {
      case TranscriptionStatus.notStarted:
        return ElevatedButton(
          onPressed: () {
            createTranscript(meeting!.id);
          },
          child: const Text('Create Transcript'),
        );
      case TranscriptionStatus.inProgress:
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
              const Text('Transcription in progress'),
            ],
          ),
        );
      case TranscriptionStatus.completed:
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: ExpansionTile(
            title: Text('Transcript'),
            children: [
              ListTile(
                subtitle: Text(transcript!),
                onTap: () {
                  showEditDialog(
                    context: context,
                    title: 'Edit Transcript',
                    initialContent: transcript!,
                    onSave: editTranscript,
                  );
                },
              ),
            ],
          ),
        );
      case TranscriptionStatus.failed:
        return ElevatedButton(
          onPressed: () {
            createTranscript(meeting!.id);
          },
          child: const Text('Retry Transcription'),
        );
    }
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
          child: ExpansionTile(
            title: Text('Summary'),
            children: [
              ListTile(
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
            ],
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

  Widget getActionPointsSection(BuildContext context) {
    if (transcript == null || transcript!.isEmpty) {
      return const SizedBox.shrink();
    }

    switch (tasksStatus) {
      case TasksStatus.notStarted:
        return ElevatedButton(
          onPressed: () {
            createTasks(meeting!.id);
          },
          child: const Text('Create Action Points'),
        );
      case TasksStatus.inProgress:
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
              const Text('Action Points in progress'),
            ],
          ),
        );
      case TasksStatus.completed:
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: ExpansionTile(
            title: Text('Action Points'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildActionPointsList(tasks, context),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
                  child: FloatingActionButton.small(
                    onPressed: () {
                      // Show dialog to add a new action point
                      showEditDialog(
                        context: context,
                        title: 'Add New Action Point',
                        initialContent: '',
                        onSave: (newValue) => addActionPoint(newValue),
                      );
                    },
                    child: const Icon(Icons.add),
                  ),
                ),
              ),
            ],
          ),
        );
      case TasksStatus.failed:
        return ElevatedButton(
          onPressed: () {
            createTasks(meeting!.id);
          },
          child: const Text('Retry Action Points'),
        );
    }
  }

  // Helper method to parse and build action points list
  List<Widget> _buildActionPointsList(
    List<String> actionPointsText,
    BuildContext context,
  ) {
    // Split the text by new lines
    List<Widget> widgets = [];

    for (var i = 0; i < actionPointsText.length; i++) {
      final line = actionPointsText[i];
      final index = i; // Capture the index for use in callbacks

      widgets.add(
        Card(
          margin: const EdgeInsets.only(bottom: 8.0),
          child: ListTile(
            //leading: const Text('•', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            title: Text(line),
            trailing: IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () {
                deleteActionPoint(line);
              },
            ),
            onTap: () {
              // Call the edit dialog with the current action point
              showEditDialog(
                context: context,
                title: 'Edit Action Point',
                initialContent: line,
                onSave: (newValue) => editActionPoint(index, newValue),
              );
            },
          ),
        ),
      );
    }

    return widgets;
  }

  // Helper method to show edit dialog
  void showEditDialog({
    required BuildContext context,
    required String title,
    required String initialContent,
    required Function(String) onSave,
  }) {
    final TextEditingController controller = TextEditingController(
      text: initialContent,
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
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

  Future<void> sendEmailWithMeetingDetails() async {
    // Prepare email content
    final subject = 'Meeting: ${meeting?.title ?? "No title"}';
    final body = '''
Meeting Details:
Title: ${meeting?.title ?? "No title"}
Description: ${meeting?.description ?? "No description"}

Summary:
${summary ?? "No summary available"}

Action Points:
${tasks.isNotEmpty ? tasks.map((task) => "- $task").join("\n") : "No action points available"}

Transcript:
${transcript ?? "No transcript available"}
''';

    // Create the URL
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'zajacignacy@gmail.com', // recipient email address
      query: encodeQueryParameters({'subject': subject, 'body': body}),
    );

    // Launch the URL
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      throw 'Could not launch email client';
    }
  }

  // Helper method to encode query parameters
  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }
}

enum TranscriptionStatus { notStarted, inProgress, completed, failed }

enum SummaryStatus { notStarted, inProgress, completed, failed }

enum TasksStatus { notStarted, inProgress, completed, failed }
