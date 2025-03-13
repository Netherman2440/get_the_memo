import 'package:dart_openai/dart_openai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_the_memo/prompts/summarize.dart';
import 'package:get_the_memo/prompts/action_points.dart';
import 'package:get_the_memo/services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OpenAiService {
  final String model = "o3-mini";
  OpenAiService() {
    OpenAI.apiKey = dotenv.get('OPENAI_API_KEY');
    OpenAI.requestsTimeOut = const Duration(seconds: 3600);
  }

  Future<OpenAIChatCompletionChoiceMessageModel> chat(
    List<OpenAIChatCompletionChoiceMessageModel> messages,
  ) async {
    final completion = await OpenAI.instance.chat.create(
      model: model,
      messages: messages,
    );
    return completion.choices.first.message;
  }
}

Future<String> summarize(String text, String meetingId) async {
  try {
    final service = OpenAiService();
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
        content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(text)],
      ),
    ];
    final completion = await service.chat(messages);
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

Future<String> actionPoints(String text) async {
  final service = OpenAiService();
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
      content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(text)],
    ),
  ];
  final completion = await service.chat(messages);
  return completion.content!.first.text!;
}
