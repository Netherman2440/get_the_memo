import 'package:get_the_memo/models/meeting.dart';
import 'package:get_the_memo/services/database_service.dart';
import 'package:get_the_memo/services/openai_service.dart';
import 'package:get_the_memo/services/whisper_service.dart';
import 'package:flutter/foundation.dart';
import 'package:get_the_memo/services/notification_service.dart';

class ProcessService extends ChangeNotifier {
  static ProcessService? _instance;
  
  ProcessService() {
    _instance = this;
    whisper_service.init();
    openai_service.init();
    addListener(_updateNotifications);
  }

  final openai_service = OpenAIService();
  final whisper_service = WhisperService();
  List<Process> processes = [];

  Future<void> process_Meeting(
    Meeting meeting,
    List<ProcessType> request,
  ) async {
    try {
      print('Starting process_Meeting for meetingId: ${meeting.id}');
      print('Requested processes: $request');
      print('Audio URL: ${meeting.audioUrl}');

      Process? process = getProcess(meeting.id, request);
      print('Existing process: ${process != null ? "found" : "not found"}');

      //check if there is a process for this meeting
      if (process != null) {
        print('Checking existing process steps...');
        //check if the process contains all the steps in the request
        for (var type in request) {
          if (process.steps.any(
            (element) =>
                element.type == type && element.status == StepStatus.inProgress,
          )) {
            print('Found conflicting step: $type already in progress');
            throw Exception(
              'Process already contains steps that are in the request',
            );
          }
        }
      }

      process = Process(meetingId: meeting.id, steps: []);
      processes.add(process);
      print('Created new process for meeting: ${meeting.id}');
      
      
      
      for (var type in request) {
        process.steps.add(Step(type: type));
      }
      print('Added steps: ${process.steps.map((e) => e.type).toList()}'); 

      //get transcript
      String? transcript;
      if (request.contains(ProcessType.transcription)) {
        print('Starting transcription process...');
        if (meeting.audioUrl == null) {
          throw Exception('Audio URL is null');
        }
        
        Step step = process.steps[request.indexOf(ProcessType.transcription)];
        step.status = StepStatus.inProgress;
        try {
          print('Calling whisper_service with audioPath: ${meeting.audioUrl}');
          transcript = await whisper_service.processTranscription(
            audioPath: meeting.audioUrl!,
            meetingId: meeting.id,
          );

          print('Transcription completed. Length: ${transcript?.length ?? 0}');
          step.status = StepStatus.completed;
          step.result = transcript;
        } catch (e, stackTrace) {
          print('Error during transcription: $e');
          print('Stack trace: $stackTrace');
          step.status = StepStatus.failed;
          step.error = e.toString();
          rethrow;
        }
      } else {
        //get transcript from database
        print('Fetching existing transcription from database...');
        transcript = await DatabaseService.getTranscription(meeting.id);
        print('Database transcript result: ${transcript != null ? "found" : "not found"}');
      }

      if (transcript == null) {
        print('No transcript available - neither from transcription nor database');
        throw Exception('Transcript not found');
      }

      //process steps

      List<Future<void>> steps = [];

      if (request.contains(ProcessType.summarize)) {
        steps.add(summarize(transcript, meeting.id));
      }
      if (request.contains(ProcessType.actionPoints)) {
        steps.add(actionPoints(transcript, meeting.id));
      }
      if (request.contains(ProcessType.autoTitle)) {
        steps.add(autoTitle(transcript, meeting.id));
      }
      //TODO: add more steps here


      final results = await Future.wait(steps);

      //update process
      notifyListeners();
      //processes.remove(process);  //TODO: there is a better way to do this
    } catch (e, stackTrace) {
      // Show error notification
      NotificationService.showNotification(
        id: meeting.id.hashCode,
        title: 'Processing Error',
        body: 'Failed to process meeting: ${e.toString()}',
      );
      throw Exception('Error processing meeting: $e, $stackTrace');
    }
  }

  Future<void> summarize(String transcript, String meetingId) async {
    Process process = getProcess(meetingId, [ProcessType.summarize])!;
    int index = process.steps.indexWhere(
      (element) => element.type == ProcessType.summarize,
    );

    Step step = process.steps[index];
    step.status = StepStatus.inProgress;
    try {
      step.result = await openai_service.summarize(transcript, meetingId);
      step.status = StepStatus.completed;
    } catch (e) {
      step.status = StepStatus.failed;
      step.error = e.toString();
    }
  }

  Future<void> actionPoints(String transcript, String meetingId) async {
    Process process = getProcess(meetingId, [ProcessType.actionPoints])!;
    int index = process.steps.indexWhere(
      (element) => element.type == ProcessType.actionPoints,
    );
    Step step = process.steps[index];
    step.status = StepStatus.inProgress;
    try {
      step.result = await openai_service.actionPoints(transcript, meetingId);
      step.status = StepStatus.completed;
    } catch (e) {
      step.status = StepStatus.failed;
      step.error = e.toString();
    }
  }

  bool exists(String meetingId) {
    return processes.any((element) => element.meetingId == meetingId);
  }

  Process? getProcess(String meetingId, List<ProcessType> request) {
    try {
      return processes.firstWhere(
        (element) =>
            element.meetingId == meetingId &&
            element.steps.any((step) => request.contains(step.type)),
      );
    } catch (e) {
      return null;
    }
  }

  List<Process> getProcesses(String meetingId) {
    return processes
        .where((element) => element.meetingId == meetingId)
        .toList();
  }
  
  Future<void> autoTitle(String transcript, String id) async {
    Process process = getProcess(id, [ProcessType.autoTitle])!;
    int index = process.steps.indexWhere(
      (element) => element.type == ProcessType.autoTitle,
    );
    Step step = process.steps[index];
    step.status = StepStatus.inProgress;
    try {
      step.result = await openai_service.autoTitle(transcript, id);
      step.status = StepStatus.completed;
    } catch (e) {
      step.status = StepStatus.failed;
      step.error = e.toString();
    }
  }

  // Add this method to update notification for a process
  void _updateProcessNotification(Process process) {
    print('Updating notification for process: ${process.meetingId}');
    
    final hasErrors = process.steps.any((s) => s.status == StepStatus.failed);
    final allCompleted = process.steps.every((s) => s.status == StepStatus.completed);
    print('hasErrors: $hasErrors');
    print('allCompleted: $allCompleted');
    
    String title = 'Meeting Processing Status';
    String body;
    
    if (allCompleted) {
      body = 'All steps completed! Check the results.';
    } else if (hasErrors) {
      body = 'Processing failed. Please try again.';
    } else {
      // Find first in-progress step
      var inProgressStep = process.steps.firstWhere(
        (step) => step.status == StepStatus.inProgress,
        orElse: () => process.steps.first,
      );
      
      // Count completed steps
      var completedCount = process.steps.where((s) => s.status == StepStatus.completed).length;
      
      // Format process type name
      String stepName = switch (inProgressStep.type) {
        ProcessType.transcription => 'Transcription',
        ProcessType.summarize => 'Summary',
        ProcessType.actionPoints => 'Action Points',
        ProcessType.autoTitle => 'Auto Title',
        ProcessType.send => 'Send',
        ProcessType.none => 'Processing',
      };
      
      body = '$stepName in progress... ($completedCount/${process.steps.length})';
    }

    print('Showing notification - Title: $title, Body: $body');
    
    NotificationService.showNotification(
      id: process.meetingId.hashCode,
      title: title,
      body: body,
      sound: allCompleted || hasErrors,
    ).then((_) {
      print('Notification shown successfully');
    }).catchError((error) {
      print('Error showing notification: $error');
    });
  }
  
  void _updateNotifications() {
    print('Updating notifications');
    for (var process in processes) {
      if (process.isInProgress()) {
        print('Process in progress: ${process.meetingId}');
        _updateProcessNotification(process);
      }
    }
  }
}

class Process {
  String meetingId;
  List<Step> steps;
  Process({required this.meetingId, required this.steps});

  bool isInProgress() {
    return steps.any((step) => step.status == StepStatus.inProgress || step.status == StepStatus.none);
  }
}

class Step {
  ProcessType type;
  String? result;
  String? error;
  StepStatus _status = StepStatus.none;

  StepStatus get status => _status;
  set status(StepStatus value) {
    if (_status != value) {
      _status = value;
      // Add direct notification update
      final process = ProcessService._instance?.processes.firstWhere(
        (p) => p.steps.contains(this)
        
      );
      ProcessService._instance?._updateProcessNotification(process!);
      ProcessService._instance?.notifyListeners();
    }
  }

  Step({required this.type, this.result, this.error});
}

enum ProcessType {
  none,
  transcription,
  summarize,
  actionPoints,
  autoTitle,
  send,
}

enum StepStatus { none, inProgress, completed, failed }
