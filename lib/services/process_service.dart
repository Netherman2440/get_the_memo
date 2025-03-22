import 'package:get_the_memo/models/meeting.dart';
import 'package:get_the_memo/services/database_service.dart';
import 'package:get_the_memo/services/openai_service.dart';
import 'package:get_the_memo/services/whisper_service.dart';
import 'package:flutter/foundation.dart';

class ProcessService extends ChangeNotifier {
  final openai_service = OpenAIService();
  final whisper_service = WhisperService();
  List<Process> processes = [];

  Future<void> process_Meeting(
    Meeting meeting,
    List<ProcessType> request,
  ) async {
    try {
      Process process;
      //check if there is a process for this meeting
      if (processes.any((element) => element.meetingId == meeting.id)) {
        //check if there is a process for this meeting
        process = processes.firstWhere(
          (element) => element.meetingId == meeting.id,
        );

        if (process.steps.any((element) => request.contains(element.type))) {
          throw Exception(
            'Process already contains steps that are in the request',
          );
        }
      } else {
        process = Process(meetingId: meeting.id, steps: []);
        processes.add(process);
      }


      for (var type in request) {
        process.steps.add(Step(type: type));
      }


      //get transcript
      String? transcript;
      if (request.contains(ProcessType.transcription)) {
        Step step = process.steps[request.indexOf(ProcessType.transcription)];
        step.status = ProcessStatus.processing;
        try {
          transcript = await whisper_service.processTranscription(
            audioPath: meeting.audioUrl!,
          );

          step.status = ProcessStatus.completed;
          step.result = transcript;
        } catch (e) {
          step.status = ProcessStatus.failed;
          step.error = e.toString();
        }
      } else {
        //get transcript from database
        transcript = await DatabaseService.getTranscription(meeting.id);
      }

      if (transcript == null) {
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
      //TODO: add more steps here


      final results = await Future.wait(steps);
    } catch (e) {
      throw Exception('Error processing meeting: $e');
    }
  }

  Future<void> summarize(String transcript, String meetingId) async {
    Process process = processes.firstWhere(
      (element) => element.meetingId == meetingId,
    );
    int index = process.steps.indexWhere(
      (element) => element.type == ProcessType.summarize,
    );
    Step step = process.steps[index];
    step.status = ProcessStatus.processing;
    try {
      step.result = await openai_service.summarize(transcript, meetingId);
      step.status = ProcessStatus.completed;
    } catch (e) {
      step.status = ProcessStatus.failed;
      step.error = e.toString();
    }
  }

  Future<void> actionPoints(String transcript, String meetingId) async {
    Process process = getProcess(meetingId, [ProcessType.actionPoints]);
    int index = process.steps.indexWhere(
      (element) => element.type == ProcessType.actionPoints,
    );
    Step step = process.steps[index];
    step.status = ProcessStatus.processing;
    try {
      step.result = await openai_service.actionPoints(transcript, meetingId);
      step.status = ProcessStatus.completed;
    } catch (e) {
      step.status = ProcessStatus.failed;
      step.error = e.toString();
    }
  }

  Process getProcess(String meetingId, List<ProcessType> request) {
    Process process;

    if (processes.any((element) => element.meetingId == meetingId)) {
      //check if there is a process for this meeting
      process = processes.firstWhere(
        (element) => element.meetingId == meetingId,
      );

      if (process.steps.any((element) => request.contains(element.type))) {
        throw Exception(
          'Process already contains steps that are in the request',
        );
      }
    } else {
      process = Process(meetingId: meetingId, steps: []);
      processes.add(process);
    }

    return process;
  }
}

class Process extends ChangeNotifier {
  String meetingId;
  List<Step> steps;
  Process({required this.meetingId, required this.steps});
}

class Step extends ChangeNotifier {
  ProcessType type;
  String? result;
  String? error;
  ProcessStatus _status = ProcessStatus.none;

  ProcessStatus get status => _status;
  set status(ProcessStatus value) {
    if (_status != value) {
      _status = value;
      notifyListeners();
    }
  }

  Step({required this.type, this.result, this.error});
}

enum ProcessType { none, transcription, summarize, actionPoints, autoTitle, send }

enum ProcessStatus { none, processing, completed, failed }
