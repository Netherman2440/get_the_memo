import 'dart:convert';

import 'package:dart_openai/dart_openai.dart';
import 'package:get_the_memo/prompts/summarize.dart';
import 'package:get_the_memo/prompts/action_points.dart';
import 'package:get_the_memo/prompts/auto_title.dart';
import 'package:get_the_memo/services/api_key_service.dart';
import 'package:get_the_memo/services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OpenAIService {
  final String model = "o3-mini";

  Future<void> init() async {
    final apiKeyService = ApiKeyService();
    OpenAI.apiKey = await apiKeyService.getApiKey();
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
      return completionText;
    } catch (e) {
      print(e);
      await DatabaseService.updateSummary(meetingId, 'Error: $e');

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
      return tasksJson;
    } catch (e) {
      print(e);
      await DatabaseService.updateTasks(meetingId, 'Error: $e');
      return '';
    }
  }

  Future<String> autoTitle(String transcript, String id) async {
    final messages = [
      OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.system,
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(autoTitlePrompt),
        ],
      ),
      OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.user,
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(transcript),
        ],
      ),
    ];
    final completion = await chat(messages);
    final completionText = completion.content!.first.text!;
    print('Completion Text: $completionText');
    var json = jsonDecode(completionText);
    print('JSON: $json');
    await DatabaseService.insertAutoTitle(id, json['title'], json['description']);
    return json['title'];
  }
}
