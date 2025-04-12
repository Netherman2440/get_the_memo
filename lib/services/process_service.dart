import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get_the_memo/models/meeting.dart';
import 'package:get_the_memo/services/database_service.dart';
import 'package:get_the_memo/services/openai_service.dart';
import 'package:get_the_memo/services/whisper_service.dart';
import 'package:get_the_memo/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  SharedPreferences? prefs;
  bool _betterResults = false;
  List<Process> processes = [];

  Future<void> process_Meeting(
    BuildContext context,
    Meeting meeting,
    List<ProcessType> request,
  ) async {
    try {
      showSnackBar(
        context,
        'Rozpoczynanie nowego procesu...',
        MessageType.success,
      );
      prefs = await SharedPreferences.getInstance();
      _betterResults = prefs?.getBool('better_results') ?? false;
      Process? process = getProcess(meeting.id, request);
      //check if there is a process for this meeting
      if (process != null) {
        //check if the process contains all the steps in the request
        for (var type in request) {
          if (process.steps.any(
            (element) =>
                element.type == type && element.status == StepStatus.inProgress,
          )) {
            showSnackBar(
              context,
              'Proces już zawiera kroki, które są w żądaniu',
              MessageType.error,
            );
            throw Exception('Proces już zawiera kroki, które są w żądaniu');
          }
        }
      }

      process = Process(meetingId: meeting.id, steps: []);
      processes.add(process);

      for (var type in request) {
        process.steps.add(Step(type: type));
      }

      //get transcript
      String? transcript;
      if (request.contains(ProcessType.transcription)) {
        if (meeting.audioUrl == null) {
          throw Exception('Audio URL is null');
        }

        transcript = await generateTranscript(meeting.audioUrl!, meeting.id);

        /*Step step = process.steps[request.indexOf(ProcessType.transcription)];
        step.status = StepStatus.inProgress;
        //
          transcript = await whisper_service.processTranscription(
            audioPath: meeting.audioUrl!,
            meetingId: meeting.id,
          );

          step.status = StepStatus.completed;
          step.result = transcript;
        } catch (e) {
          step.status = StepStatus.failed;

          // Handle specific OpenAI errors
          if (e is InvalidAPIKeyException) {
            step.error =
                'Invalid API key. Please check your OpenAI API settings.';
            showSnackBar(
              context,
              'Invalid API key. Please check your settings.',
              MessageType.error,
              duration: 5,
            );
          } else if (e is InsufficientFundsException) {
            step.error = 'Insufficient funds in your OpenAI account.';
            showSnackBar(
              context,
              'Insufficient funds in your OpenAI account. Please add credits.',
              MessageType.error,
              duration: 5,
            );
          } else {
            step.error = e.toString();
            showSnackBar(
              context,
              'Error during transcription: $e',
              MessageType.error,
            );
          }
          rethrow;
        }
        */
      } else {
        //get transcript from database
        transcript = await DatabaseService.getTranscription(meeting.id);
      }

      if (transcript == null) {
        showSnackBar(
          context,
          'Transkrypcja nie powiodła się',
          MessageType.error,
        );
        throw Exception('Transkrypcja nie powiodła się');
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
      // Don't show additional error notification if it's already handled
      if (!(e is InvalidAPIKeyException || e is InsufficientFundsException)) {
        NotificationService.showNotification(
          id: meeting.id.hashCode,
          title: 'Błąd przetwarzania',
          body: 'Nie udało się przetworzyć spotkania: ${e.toString()}',
        );
      }
      print('Błąd przetwarzania spotkania: $e \n$stackTrace');

      showSnackBar(
        context,
        'Błąd przetwarzania spotkania: $e',
        MessageType.error,
      );
      throw Exception('Błąd przetwarzania spotkania: $e');
    }
  }

  Future<String> generateTranscript(String audioPath, String meetingId) async {
    Process process = getProcess(meetingId, [ProcessType.transcription])!;
    int index = process.steps.indexWhere(
      (element) => element.type == ProcessType.transcription,
    );

    Step step = process.steps[index];
    step.status = StepStatus.inProgress;
    try {
      step.result = await whisper_service.processTranscription(
        audioPath: audioPath,
        meetingId: meetingId,
      );

      if (_betterResults) {
        step.result = await openai_service.fixTranscript(step.result!, meetingId);
      }

      step.status = StepStatus.completed;
      return step.result!;
    } catch (e) {
      step.status = StepStatus.failed;
      throw e;
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
      throw e;
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
      if (_betterResults) {
        List<Future<String>> actionPoints = [
          openai_service.actionPoints(transcript, meetingId),
          openai_service.actionPoints(transcript, meetingId),
          openai_service.actionPoints(transcript, meetingId),
        ];
        var results = await Future.wait(actionPoints);
        step.result = await openai_service.batchTasks(results, meetingId);
      } else {
        step.result = await openai_service.actionPoints(transcript, meetingId);
      }
      step.status = StepStatus.completed;
    } catch (e) {
      step.status = StepStatus.failed;
      step.error = e.toString();
      throw e;
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
      throw e;
    }
  }

  // Add this method to update notification for a process
  void _updateProcessNotification(Process process) {
    print('Aktualizacja powiadomienia dla procesu: ${process.meetingId}');

    final hasErrors = process.steps.any((s) => s.status == StepStatus.failed);
    final allCompleted = process.steps.every(
      (s) => s.status == StepStatus.completed,
    );
    print('hasErrors: $hasErrors');
    print('allCompleted: $allCompleted');

    String title = 'Status przetwarzania spotkania';
    String body;

    if (allCompleted) {
      body = 'Wszystkie kroki zakończone! Sprawdź wyniki.';
    } else if (hasErrors) {
      body = 'Przetwarzanie nie powiodło się. Spróbuj ponownie.';
    } else {
      // Find first in-progress step
      var inProgressStep = process.steps.firstWhere(
        (step) => step.status == StepStatus.inProgress,
        orElse: () => process.steps.first,
      );

      // Count completed steps
      var completedCount =
          process.steps.where((s) => s.status == StepStatus.completed).length;

      // Format process type name
      String stepName = switch (inProgressStep.type) {
        ProcessType.transcription => 'Transkrypcja',
        ProcessType.summarize => 'Podsumowanie',
        ProcessType.actionPoints => 'Punkty akcji',
        ProcessType.autoTitle => 'Automatyczny tytuł',
        ProcessType.send => 'Wysyłanie',
        ProcessType.none => 'Przetwarzanie',
      };

      body = '$stepName w toku... ($completedCount/${process.steps.length})';
    }

    print('Showing notification - Title: $title, Body: $body');

    NotificationService.showNotification(
          id: process.meetingId.hashCode,
          title: title,
          body: body,
          sound: allCompleted || hasErrors,
        )
        .then((_) {
          print('Notification shown successfully');
        })
        .catchError((error) {
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

  void showSnackBar(BuildContext context, String message, MessageType type) {
    Color backgroundColor = switch (type) {
      MessageType.success => Theme.of(context).colorScheme.primary,
      MessageType.error => Theme.of(context).colorScheme.error,
      _ => Theme.of(context).colorScheme.primary,
    };
    Color textColor = switch (type) {
      MessageType.success => Theme.of(context).colorScheme.onPrimary,
      MessageType.error => Theme.of(context).colorScheme.onError,
      _ => Theme.of(context).colorScheme.onPrimary,
    };
    ScaffoldMessenger.of(context).clearSnackBars();
    int duration = type == MessageType.error ? 3 : 1;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: textColor)),
        duration: Duration(seconds: duration),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 10, left: 10, right: 10),
        backgroundColor: backgroundColor,
      ),
    );
  }
}

enum MessageType { success, error }

class Process {
  String meetingId;
  List<Step> steps;
  Process({required this.meetingId, required this.steps});

  bool isInProgress() {
    return steps.any(
      (step) =>
          step.status == StepStatus.inProgress ||
          step.status == StepStatus.none,
    );
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
        (p) => p.steps.contains(this),
      );
      ProcessService._instance?._updateProcessNotification(process!);
      ProcessService._instance?.notifyListeners();
    }
  }

  Step({required this.type, this.result, this.error}) {
    _status = StepStatus.queue;
  }
}

enum ProcessType {
  none,
  transcription,
  summarize,
  actionPoints,
  autoTitle,
  send,
}

enum StepStatus { none, queue, inProgress, completed, failed }
