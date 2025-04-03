import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get_the_memo/models/meeting.dart';
import 'package:get_the_memo/services/database_service.dart';
import 'package:get_the_memo/services/process_service.dart';
import 'package:url_launcher/url_launcher.dart';

class DetailsViewModel extends ChangeNotifier {
  Meeting? meeting;
  String? _meetingId;
  String? transcript;
  String? summary;
  List<String> tasks = [];
  StepStatus transcriptionStatus = StepStatus.none;
  StepStatus summaryStatus = StepStatus.none;
  StepStatus tasksStatus = StepStatus.none;

  final ProcessService processService;

  // Constructor that accepts meetingId
  DetailsViewModel({required this.processService, String? meetingId}) {
    if (meetingId != null) {
      loadMeeting(meetingId);
    }
    processService.addListener(_onProcessServiceChanged);
  }

  // Load meeting data
  Future<void> loadMeeting(String meetingId) async {
    _meetingId = meetingId;

    try {
      transcriptionStatus = await getStepStatus(
        meetingId,
        ProcessType.transcription,
      );
      summaryStatus = await getStepStatus(meetingId, ProcessType.summarize);
      tasksStatus = await getStepStatus(meetingId, ProcessType.actionPoints);
      meeting = await DatabaseService.getMeeting(meetingId);

      //await DatabaseService.debugListAllTranscriptions();

      transcript = await DatabaseService.getTranscription(meetingId);
      print('Loaded transcript: $transcript');

      summary = await DatabaseService.getSummary(meetingId);
      var tasksJson = await DatabaseService.getTasks(meetingId);
      tasks = List<String>.from(jsonDecode(tasksJson ?? '[]'));
    } catch (e, stackTrace) {
      print('Failed to load meeting details: $e\nStack trace:\n$stackTrace');
    }

    notifyListeners();
  }

  Future<void> createTranscript(BuildContext context, String meetingId) async {
    String audioPath = meeting?.audioUrl ?? '';

    await processService.process_Meeting(context, meeting!, [
      ProcessType.transcription,
    ]);

    notifyListeners();
  }

  Future<void> createSummary(BuildContext context, String meetingId) async {
    await processService.process_Meeting(context, meeting!, [
      ProcessType.summarize,
    ]);
    notifyListeners();
  }

  Future<void> createTasks(BuildContext context, String meetingId) async {
    await processService.process_Meeting(context, meeting!, [
      ProcessType.actionPoints,
    ]);
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

  Future<StepStatus> getStepStatus(String meetingId, ProcessType type) async {
    StepStatus status = StepStatus.none;

    if (processService.exists(meetingId)) {
      final process = processService.getProcess(meetingId, [type]);
      if (process != null) {
        final step = process.steps.firstWhere(
          (element) => element.type == type,
        );
        status = step.status;
      }
    }

    return status;
  }

  Widget getTranscriptionSection(BuildContext context) {
    var _transcriptionStatus = transcriptionStatus;
    if (transcript != null && transcript!.isNotEmpty) {
      _transcriptionStatus = StepStatus.completed;
    }
    switch (_transcriptionStatus) {
      case StepStatus.none:
        return ElevatedButton(
          onPressed: () {
            createTranscript(context, meeting!.id);
          },
          child: const Text('Create Transcript'),
        );
      case StepStatus.queue:
        return ElevatedButton(
          onPressed: null,
          child: const Text('Transcription in queue'),
        );
      case StepStatus.inProgress:
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
      case StepStatus.completed:
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
      case StepStatus.failed:
        return ElevatedButton(
          onPressed: () {
            createTranscript(context, meeting!.id);
          },
          child: const Text('Retry Transcription'),
        );
    }
  }

  getSummarySection(BuildContext context) {
    if (transcript == null || transcript!.isEmpty) {
      return const SizedBox.shrink();
    }
    var _summaryStatus = summaryStatus;
    if (summary != null && summary!.isNotEmpty) {
      _summaryStatus = StepStatus.completed;
    }

    switch (_summaryStatus) {
      case StepStatus.none:
        return ElevatedButton(
          onPressed: () {
            createSummary(context, meeting!.id);
          },
          child: const Text('Create Summary'),
        );
      case StepStatus.queue:
        return ElevatedButton(
          onPressed: null,
          child: const Text('Summary in queue'),
        );
      case StepStatus.inProgress:
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
      case StepStatus.completed:
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
      case StepStatus.failed:
        return ElevatedButton(
          onPressed: () {
            createSummary(context, meeting!.id);
          },
          child: const Text('Retry Summary'),
        );
    }
  }

  Widget getActionPointsSection(BuildContext context) {
    if (transcript == null || transcript!.isEmpty) {
      return const SizedBox.shrink();
    }
    var _tasksStatus = tasksStatus;
    if (!tasks.isEmpty) {
      _tasksStatus = StepStatus.completed;
    }

    switch (_tasksStatus) {
      case StepStatus.none:
        return ElevatedButton(
          onPressed: () {
            createTasks(context, meeting!.id);
          },
          child: const Text('Create Action Points'),
        );
      case StepStatus.queue:
        return ElevatedButton(
          onPressed: null,
          child: const Text('Action Points in queue'),
        );
      case StepStatus.inProgress:
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
      case StepStatus.completed:
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
      case StepStatus.failed:
        return ElevatedButton(
          onPressed: () {
            createTasks(context, meeting!.id);
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

  void _onProcessServiceChanged() {
    loadMeeting(meeting!.id);
  }
}

//enum TranscriptionStatus { notStarted, inProgress, completed, failed }

//enum SummaryStatus { notStarted, inProgress, completed, failed }

//enum TasksStatus { notStarted, inProgress, completed, failed }
