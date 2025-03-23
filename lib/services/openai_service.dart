import 'dart:convert';

import 'package:dart_openai/dart_openai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_the_memo/prompts/summarize.dart';
import 'package:get_the_memo/prompts/action_points.dart';
import 'package:get_the_memo/services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OpenAIService {
  final String model = "o3-mini";
  OpenAIService() {
    OpenAI.apiKey = dotenv.get('OPENAI_API_KEY');
    OpenAI.requestsTimeOut = const Duration(seconds: 3600);
  }

  Future<OpenAIChatCompletionChoiceMessageModel> chat(
    List<OpenAIChatCompletionChoiceMessageModel> messages,
  ) async {
    try {
      final completion = await OpenAI.instance.chat.create(
        model: model,
        messages: messages,
      );
      return completion.choices.first.message;
    } catch (e) {
      print(e);
      return OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.assistant,
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text('Error: $e'),
        ],
      );
    }
  }

  Future<String> summarize(String text, String meetingId) async {
    try {
      final messages = [
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.system,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(
              summarizePrompt,
            ),
          ],
        ),
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.user,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(text),
          ],
        ),
      ];
      final completion = await chat(messages);
      final completionText = completion.content!.first.text!;
      await DatabaseService.insertSummary(meetingId, completionText);
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('summary_in_progress_$meetingId', false);
      prefs.setBool('summary_completed_$meetingId', true);
      return completionText;
    } catch (e) {
      print(e);
      await DatabaseService.updateSummary(meetingId, 'Error: $e');
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('summary_error_$meetingId', true);
      prefs.setBool('summary_in_progress_$meetingId', false);
      prefs.setBool('summary_completed_$meetingId', false);

      return '';
    }
  }

  List<String> formatActionPoints(String text) {
    // Split by newline and process each line
    return text
        .split('\n')
        .map((line) => line.trim())
        // Remove empty lines
        .where((line) => line.isNotEmpty)
        // Remove leading dash and whitespace
        .map((line) => line.replaceFirst(RegExp(r'^[-•*]\s*'), ''))
        .toList();
  }

  Future<String> actionPoints(String text, String meetingId) async {
    try {
      final messages = [
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.system,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(
              actionPointsPrompt,
            ),
          ],
        ),
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.user,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(text),
          ],
        ),
      ];
      final completion = await chat(messages);
      final completionText = completion.content!.first.text!;
      print('Completion Text: $completionText');

      final formattedTasks = formatActionPoints(completionText);
      var tasksJson = jsonEncode(formattedTasks);
      await DatabaseService.insertTasks(meetingId, tasksJson);
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('tasks_in_progress_$meetingId', false);
      prefs.setBool('tasks_completed_$meetingId', true);

      return tasksJson;
    } catch (e) {
      print(e);
      await DatabaseService.updateTasks(meetingId, 'Error: $e');
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('tasks_error_$meetingId', true);
      prefs.setBool('tasks_in_progress_$meetingId', false);
      prefs.setBool('tasks_completed_$meetingId', false);
      return '';
    }
  }
}
