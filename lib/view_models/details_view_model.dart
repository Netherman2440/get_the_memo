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

  // Add these to the class properties
  bool isTranscriptEditing = false;
  bool isSummaryEditing = false;

  // Add these to store original values when editing starts
  String? originalTranscript;
  String? originalSummary;

  // Add new properties for editing states
  bool isTitleEditing = false;
  bool isDescriptionEditing = false;
  String? originalTitle;
  String? originalDescription;

  // Add these properties to track action point editing
  int? editingActionPointIndex;
  String? originalActionPoint;

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
      try {
        tasks = List<String>.from(jsonDecode(tasksJson ?? '[]'));
      } catch (e) {
        print('Error decoding tasks: $e');
        tasks = [];
      }
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

  // Add new method to cancel all edits
  void cancelAllEditing() {
    if (isTitleEditing) {
      isTitleEditing = false;
      meeting?.title = originalTitle ?? '';
    }
    if (isDescriptionEditing) {
      isDescriptionEditing = false;
      meeting?.description = originalDescription ?? '';
    }
    if (isTranscriptEditing) {
      isTranscriptEditing = false;
      transcript = originalTranscript;
    }
    if (isSummaryEditing) {
      isSummaryEditing = false;
      summary = originalSummary;
    }
    if (editingActionPointIndex != null) {
      cancelActionPointEditing();
    }
    notifyListeners();
  }

  // Update all start editing methods
  void startTitleEditing() {
    cancelAllEditing();
    isTitleEditing = true;
    originalTitle = meeting?.title;
    notifyListeners();
  }

  void startDescriptionEditing() {
    cancelAllEditing();
    isDescriptionEditing = true;
    originalDescription = meeting?.description;
    notifyListeners();
  }

  void startTranscriptEditing() {
    cancelAllEditing();
    isTranscriptEditing = true;
    originalTranscript = transcript;
    notifyListeners();
  }

  void startSummaryEditing() {
    cancelAllEditing();
    isSummaryEditing = true;
    originalSummary = summary;
    notifyListeners();
  }

  // Update the expansion handler
  void handleSectionExpansion(String section) {
    cancelAllEditing();
  }

  Future<void> regenerateTranscript(BuildContext context) async {
    isTranscriptEditing = false;
    transcript = null;
    notifyListeners();
    await createTranscript(context, meeting!.id);
  }

  Future<void> regenerateSummary(BuildContext context) async {
    isSummaryEditing = false;
    summary = null;
    notifyListeners();
    await createSummary(context, meeting!.id);
  }

  Future<void> regenerateActionPoints(BuildContext context) async {
    tasks = [];
    notifyListeners();
    await createTasks(context, meeting!.id);
  }

  Future<void> regenerateTitle(BuildContext context) async {
    isTitleEditing = false;
    meeting?.title = '';
    notifyListeners();
    await processService.process_Meeting(context, meeting!, [
      ProcessType.autoTitle,
    ]);
  }

  Future<void> regenerateDescription(BuildContext context) async {
    isDescriptionEditing = false;
    meeting?.description = '';
    notifyListeners();
    await processService.process_Meeting(context, meeting!, [
      ProcessType.autoTitle,
    ]);
  }

  Widget getTranscriptionSection(BuildContext context) {
    switch (transcriptionStatus) {
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
          margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
          color: Colors.transparent,
          elevation: 0,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
              title: Row(
                children: [
                  Text(
                    'Transcript',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (transcriptionStatus == StepStatus.inProgress)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              onExpansionChanged: (isExpanded) {
                handleSectionExpansion('transcript');
              },
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      startTranscriptEditing();
                    },
                    child:
                        isTranscriptEditing
                            ? Column(
                              children: [
                                TextField(
                                  controller: TextEditingController(
                                    text: transcript,
                                  ),
                                  maxLines: null,
                                  autofocus: true,
                                  style: TextStyle(fontSize: 12),
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(),
                                    hintText: 'Enter transcript here',
                                  ),
                                  onChanged: (value) {
                                    transcript = value;
                                  },
                                ),
                                SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextButton.icon(
                                      onPressed:
                                          () => regenerateTranscript(context),
                                      icon: Icon(Icons.refresh),
                                      label: Text('Regenerate'),
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        TextButton(
                                          onPressed: () {
                                            isTranscriptEditing = false;
                                            transcript = originalTranscript;
                                            notifyListeners();
                                          },
                                          child: Text('Cancel'),
                                        ),
                                        SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: () {
                                            isTranscriptEditing = false;
                                            editTranscript(transcript!);
                                            notifyListeners();
                                          },
                                          child: Text('Save'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            )
                            : Text(
                              transcript ?? '',
                              style: TextStyle(fontSize: 12),
                            ),
                  ),
                ),
              ],
            ),
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
    switch (summaryStatus) {
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
          margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
          color: Colors.transparent,
          elevation: 0,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
              title: Row(
                children: [
                  Text(
                    'Summary',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (summaryStatus == StepStatus.inProgress)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              onExpansionChanged: (isExpanded) {
                handleSectionExpansion('summary');
              },
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      startSummaryEditing();
                    },
                    child:
                        isSummaryEditing
                            ? Column(
                              children: [
                                TextField(
                                  controller: TextEditingController(
                                    text: summary,
                                  ),
                                  maxLines: null,
                                  autofocus: true,
                                  style: TextStyle(fontSize: 12),
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(),
                                    hintText: 'Enter summary here',
                                  ),
                                  onChanged: (value) {
                                    summary = value;
                                  },
                                ),
                                SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextButton.icon(
                                      onPressed:
                                          () => regenerateSummary(context),
                                      icon: Icon(Icons.refresh),
                                      label: Text('Regenerate'),
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        TextButton(
                                          onPressed: () {
                                            isSummaryEditing = false;
                                            summary = originalSummary;
                                            notifyListeners();
                                          },
                                          child: Text('Cancel'),
                                        ),
                                        SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: () {
                                            isSummaryEditing = false;
                                            editSummary(summary!);
                                            notifyListeners();
                                          },
                                          child: Text('Save'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            )
                            : Text(
                              summary ?? '',
                              style: TextStyle(fontSize: 12),
                            ),
                  ),
                ),
              ],
            ),
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
    switch (tasksStatus) {
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
          margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
          color: Colors.transparent,
          elevation: 0,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
              title: Row(
                children: [
                  Text(
                    'Action Points',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (tasksStatus == StepStatus.inProgress)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // First show the list of action points
                      ..._buildActionPointsList(tasks, context),
                      // Then show the buttons below
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: () => regenerateActionPoints(context),
                            icon: Icon(Icons.refresh),
                            label: Text('Regenerate'),
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          SizedBox(width: 16),
                          TextButton.icon(
                            onPressed: () {
                              showEditDialog(
                                context: context,
                                title: 'Add New Action Point',
                                initialContent: '',
                                onSave: (newValue) => addActionPoint(newValue),
                              );
                            },
                            icon: Icon(Icons.add),
                            label: Text('Add'),
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
    List<Widget> widgets = [];

    for (var i = 0; i < actionPointsText.length; i++) {
      final line = actionPointsText[i];
      final index = i;
      final isEditing = editingActionPointIndex == index;

      widgets.add(
        Card(
          margin: const EdgeInsets.only(bottom: 8.0),
          child: ListTile(
            title: GestureDetector(
              onTap: () {
                startActionPointEditing(index);
              },
              child: isEditing
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: TextEditingController(text: line),
                          maxLines: null,
                          autofocus: true,
                          style: TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Enter action point here',
                          ),
                          onChanged: (value) {
                            tasks[index] = value;
                          },
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                cancelActionPointEditing();
                              },
                              child: Text('Cancel'),
                            ),
                            SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                saveActionPointEdit();
                              },
                              child: Text('Save'),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Text(line, style: TextStyle(fontSize: 12)),
            ),
            trailing: isEditing
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      deleteActionPoint(line);
                    },
                  ),
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
              maxLines: null,
              style: TextStyle(fontSize: 12),
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

  // Add these methods to handle action point editing
  void startActionPointEditing(int index) {
    cancelAllEditing(); // Cancel any other editing in progress
    editingActionPointIndex = index;
    originalActionPoint = tasks[index];
    notifyListeners();
  }

  void cancelActionPointEditing() {
    if (editingActionPointIndex != null && originalActionPoint != null) {
      tasks[editingActionPointIndex!] = originalActionPoint!;
    }
    editingActionPointIndex = null;
    originalActionPoint = null;
    notifyListeners();
  }

  Future<void> saveActionPointEdit() async {
    if (editingActionPointIndex != null) {
      await editTasks(tasks);
      editingActionPointIndex = null;
      originalActionPoint = null;
      notifyListeners();
    }
  }
}

//enum TranscriptionStatus { notStarted, inProgress, completed, failed }

//enum SummaryStatus { notStarted, inProgress, completed, failed }

//enum TasksStatus { notStarted, inProgress, completed, failed }
