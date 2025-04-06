import 'dart:convert';

import 'package:dart_openai/dart_openai.dart';
import 'package:get_the_memo/prompts/summarize.dart';
import 'package:get_the_memo/prompts/action_points.dart';
import 'package:get_the_memo/prompts/auto_title.dart';
import 'package:get_the_memo/services/api_key_service.dart';
import 'package:get_the_memo/services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum OpenAIModel {
  gpt4oMini('gpt-4o-mini'),
  gpt4o('gpt-4o'),
  gpt35Turbo('gpt-3.5-turbo'),
  o3Mini('o3-mini');

  final String modelId;
  const OpenAIModel(this.modelId);
}

class OpenAIException implements Exception {
  final String message;
  final String code;

  OpenAIException({required this.message, required this.code});

  @override
  String toString() => 'OpenAIException: $message (Code: $code)';
}

class InvalidAPIKeyException extends OpenAIException {
  InvalidAPIKeyException()
      : super(
          message: 'Invalid API key. Please check your OpenAI API key.',
          code: 'invalid_api_key',
        );
}

class InsufficientFundsException extends OpenAIException {
  InsufficientFundsException()
      : super(
          message: 'Insufficient funds in your OpenAI account.',
          code: 'insufficient_funds',
        );
}

class OpenAIService {
  late String model;

  Future<void> init() async {
    final apiKeyService = ApiKeyService();
    OpenAI.apiKey = await apiKeyService.getApiKey();
    OpenAI.requestsTimeOut = const Duration(seconds: 3600);
    
    final prefs = await SharedPreferences.getInstance();
    final savedModel = prefs.getString('openai_model') ?? OpenAIModel.o3Mini.modelId;
    model = savedModel;
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
      // Handle specific OpenAI errors
      if (e.toString().contains('401')) {
        throw InvalidAPIKeyException();
      } else if (e.toString().contains('insufficient_quota')) {
        throw InsufficientFundsException();
      }
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
    try {
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
    } catch (e) {
      print(e);
      throw Exception('Failed to generate auto title: $e');
    }
  }
}
