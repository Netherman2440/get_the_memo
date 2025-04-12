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
  List<Map<String, dynamic>> tasks = [];
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

  // Add these class properties
  Map<String, dynamic> _newActionPoint = {};

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
        tasks = List<Map<String, dynamic>>.from(tasksJson ?? []);
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

  Future<void> editTasks(List<Map<String, dynamic>> tasks) async {
    this.tasks = tasks;
    await DatabaseService.updateTasks(
      meeting!.id,
      jsonEncode({'tasks': tasks}),
    );
    notifyListeners();
  }

  Future<void> editActionPoint(int index, Map<String, dynamic> newValue) async {
    if (index >= 0 && index < tasks.length) {
      tasks[index] = newValue;
      await DatabaseService.updateTasks(
        meeting!.id,
        jsonEncode({'tasks': tasks}),
      );
      notifyListeners();
    }
  }

  Future<void> addActionPoint(Map<String, dynamic> actionPoint) async {
    tasks.add(actionPoint);
    await DatabaseService.updateTasks(
      meeting!.id,
      jsonEncode({'tasks': tasks}),
    );
    notifyListeners();
  }

  Future<void> deleteActionPoint(Map<String, dynamic> actionPoint) async {
    tasks.remove(actionPoint);
    await DatabaseService.updateTasks(
      meeting!.id,
      jsonEncode({'tasks': tasks}),
    );
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
    if (editingActionPointIndex != null) {
      cancelActionPointEditing();
    }
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
    // If we have transcript but no status, treat as completed
    if (transcript != null && transcriptionStatus == StepStatus.none) {
      transcriptionStatus = StepStatus.completed;
    }

    switch (transcriptionStatus) {
      case StepStatus.none:
        return ElevatedButton(
          onPressed: () {
            createTranscript(context, meeting!.id);
          },
          child: const Text('Utwórz transkrypcję'),
        );
      case StepStatus.queue:
        return ElevatedButton(
          onPressed: null,
          child: const Text('Transkrypcja w kolejce'),
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
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              const Text('Trwa transkrypcja'),
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
                    'Transkrypcja',
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Content first
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
                                    hintText: 'Wprowadź transkrypcję',
                                  ),
                                  onChanged: (value) {
                                    transcript = value;
                                  },
                                ),
                                SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        isTranscriptEditing = false;
                                        transcript = originalTranscript;
                                        notifyListeners();
                                      },
                                      child: Text('Anuluj'),
                                    ),
                                    SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () {
                                        isTranscriptEditing = false;
                                        editTranscript(transcript!);
                                        notifyListeners();
                                      },
                                      child: Text('Zapisz'),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  transcript ?? '',
                                  style: TextStyle(fontSize: 12),
                                ),
                                SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => regenerateTranscript(context),
                                      icon: Icon(Icons.refresh),
                                      label: Text('Powtórz'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: () {
                                        startTranscriptEditing();
                                      },
                                      icon: Icon(Icons.edit),
                                      label: Text('Edytuj'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                      ],
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
          child: const Text('Powtórz'),
        );
    }
  }

  getSummarySection(BuildContext context) {
    // If we have summary but no status, treat as completed
    if (summary != null && summaryStatus == StepStatus.none) {
      summaryStatus = StepStatus.completed;
    }

    switch (summaryStatus) {
      case StepStatus.none:
        return ElevatedButton(
          onPressed: () {
            createSummary(context, meeting!.id);
          },
          child: const Text('Utwórz podsumowanie'),
        );
      case StepStatus.queue:
        return ElevatedButton(
          onPressed: null,
          child: const Text('Podsumowanie w kolejce'),
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
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              const Text('Trwa podsumowanie'),
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
                    'Podsumowanie',
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Content first
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
                                    hintText: 'Wprowadź podsumowanie',
                                  ),
                                  onChanged: (value) {
                                    summary = value;
                                  },
                                ),
                                SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        isSummaryEditing = false;
                                        summary = originalSummary;
                                        notifyListeners();
                                      },
                                      child: Text('Anuluj'),
                                    ),
                                    SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () {
                                        isSummaryEditing = false;
                                        editSummary(summary!);
                                        notifyListeners();
                                      },
                                      child: Text('Zapisz'),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  summary ?? '',
                                  style: TextStyle(fontSize: 12),
                                ),
                                SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => regenerateSummary(context),
                                      icon: Icon(Icons.refresh),
                                      label: Text('Powtórz'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: () {
                                        startSummaryEditing();
                                      },
                                      icon: Icon(Icons.edit),
                                      label: Text('Edytuj'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                      ],
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
          child: const Text('Powtórz'),
        );
    }
  }

  Widget getActionPointsSection(BuildContext context) {
    // If we have tasks but no status, treat as completed
    if (tasks.isNotEmpty && tasksStatus == StepStatus.none) {
      tasksStatus = StepStatus.completed;
    }

    switch (tasksStatus) {
      case StepStatus.none:
        return ElevatedButton(
          onPressed: () {
            createTasks(context, meeting!.id);
          },
          child: const Text('Utwórz zadania'),
        );
      case StepStatus.queue:
        return ElevatedButton(
          onPressed: null,
          child: const Text('Zadania w kolejce'),
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
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              const Text('Trwa tworzenie zadań'),
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
                    'Zadania',
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
                            label: Text('Powtórz'),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          SizedBox(width: 16),
                          TextButton.icon(
                            onPressed: () {
                              _newActionPoint = {};
                              editingActionPointIndex =
                                  -1; // Special value for new item
                              notifyListeners();
                            },
                            icon: Icon(Icons.add),
                            label: Text('Dodaj'),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.primary,
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
          child: const Text('Powtórz'),
        );
    }
  }

  // Helper method to parse and build action points list
  List<Widget> _buildActionPointsList(
    List<Map<String, dynamic>> actionPoints,
    BuildContext context,
  ) {
    List<Widget> widgets = [];

    // Add existing action points first
    for (var i = 0; i < actionPoints.length; i++) {
      final task = actionPoints[i];
      final index = i;
      final isEditing = editingActionPointIndex == index;

      widgets.add(
        Card(
          margin: const EdgeInsets.only(bottom: 8.0),
          child: ListTile(
            onTap: () {
              startActionPointEditing(index);
            },
            title: GestureDetector(
              child:
                  isEditing
                      ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: TextEditingController(
                              text: task['title'],
                            ),
                            maxLines: null,
                            autofocus: true,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Tytuł',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              tasks[index]['title'] = value;
                            },
                          ),
                          SizedBox(height: 8),
                          TextField(
                            controller: TextEditingController(
                              text: task['assignee'],
                            ),
                            style: TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              labelText: 'Przydzielony do',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              tasks[index]['assignee'] = value;
                            },
                          ),
                          SizedBox(height: 8),
                          TextField(
                            controller: TextEditingController(
                              text: task['description'],
                            ),
                            maxLines: null,
                            style: TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              labelText: 'Opis',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              tasks[index]['description'] = value;
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
                                child: Text('Anuluj'),
                              ),
                              SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  saveActionPointEdit();
                                },
                                child: Text('Zapisz'),
                              ),
                            ],
                          ),
                        ],
                      )
                      : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task['title'] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (task['assignee']?.isNotEmpty == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                'Przydzielony do: ${task['assignee']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          if (task['description']?.isNotEmpty == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                // Take first 10 characters and add ellipsis
                                '${(task['description'] as String).length > 30 ? '${task['description'].substring(0, 30)}...' : task['description']}',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
            ),
            trailing:
                isEditing
                    ? null
                    : IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () {
                        deleteActionPoint(task);
                      },
                    ),
          ),
        ),
      );
    }

    // Add "Create New" card at the end if we're in creation mode
    if (editingActionPointIndex == -1) {
      widgets.add(
        Card(
          margin: const EdgeInsets.only(bottom: 8.0),
          child: ListTile(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: TextEditingController(),
                  maxLines: null,
                  autofocus: true,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Tytuł',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    _newActionPoint['title'] = value;
                  },
                ),
                SizedBox(height: 8),
                TextField(
                  controller: TextEditingController(),
                  style: TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Przydzielony do',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    _newActionPoint['assignee'] = value;
                  },
                ),
                SizedBox(height: 8),
                TextField(
                  controller: TextEditingController(),
                  maxLines: null,
                  style: TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Opis',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    _newActionPoint['description'] = value;
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
                      child: Text('Anuluj'),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        saveNewActionPoint();
                      },
                      child: Text('Zapisz'),
                    ),
                  ],
                ),
              ],
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
    required Function(Map<String, dynamic>) onSave,
  }) {
    final titleController = TextEditingController();
    final assigneeController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Tytuł',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: assigneeController,
                    style: TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'Przydzielony do',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    style: TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'Opis',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Anuluj'),
              ),
              TextButton(
                onPressed: () {
                  final newTask = {
                    'title': titleController.text,
                    'assignee': assigneeController.text,
                    'description': descriptionController.text,
                  };
                  onSave(newTask);
                  Navigator.pop(context);
                },
                child: Text('Zapisz'),
              ),
            ],
          ),
    );
  }

  Future<void> sendEmailWithMeetingDetails() async {
    final subject = 'Spotkanie: ${meeting?.title ?? "Brak tytułu"}';
    final body = '''
${meeting?.title?.toUpperCase() ?? "BRAK TYTUŁU"}

${meeting?.description ?? "Brak opisu"}


PODSUMOWANIE:
${summary ?? "Brak podsumowania"}


ZADANIA:
${tasks.isNotEmpty ? tasks.map((task) => '''
• ${task['title'] ?? 'Brak tytułu'}
  Przypisane do: ${task['assignee']?.isNotEmpty == true ? task['assignee'] : 'nie przypisano'}
  Opis: ${task['description']?.isNotEmpty == true ? task['description'] : 'brak opisu'}
''').join('\n') : "Brak zadań"}


TRANSKRYPCJA:
${transcript ?? "Brak transkrypcji"}


Wygenerowano automatycznie przez Meet Note''';

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      query: encodeQueryParameters({
        'subject': subject,
        'body': body,
      }),
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      throw 'Nie można uruchomić klienta poczty';
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
    originalActionPoint = tasks[index]['title'];
    notifyListeners();
  }

  void cancelActionPointEditing() {
    if (editingActionPointIndex == -1) {
      _newActionPoint = {};
    } else if (editingActionPointIndex != null && originalActionPoint != null) {
      tasks[editingActionPointIndex!]['title'] = originalActionPoint!;
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

  Future<void> saveNewActionPoint() async {
    if (_newActionPoint.isNotEmpty) {
      await addActionPoint(_newActionPoint);
      _newActionPoint = {};
      editingActionPointIndex = null;
      notifyListeners();
    }
  }
}

//enum TranscriptionStatus { notStarted, inProgress, completed, failed }

//enum SummaryStatus { notStarted, inProgress, completed, failed }

//enum TasksStatus { notStarted, inProgress, completed, failed }
