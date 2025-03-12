import 'package:dart_openai/dart_openai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_the_memo/prompts/summarize.dart'; 
import 'package:get_the_memo/prompts/action_points.dart';

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

Future<String> summarize(String text) async {
  final service = OpenAiService();
  final messages = [
    OpenAIChatCompletionChoiceMessageModel(
      role: OpenAIChatMessageRole.system,
      content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(summarizePrompt)],
    ),
    OpenAIChatCompletionChoiceMessageModel(
      role: OpenAIChatMessageRole.user,
      content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(text)],
    ),
  ];
  final completion = await service.chat(messages);
  return completion.content!.first.text!;
}

Future<String> actionPoints(String text) async {
  final service = OpenAiService();
  final messages = [
    OpenAIChatCompletionChoiceMessageModel(
      role: OpenAIChatMessageRole.system,
      content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(actionPointsPrompt)],
    ),
    OpenAIChatCompletionChoiceMessageModel(
      role: OpenAIChatMessageRole.user,
      content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(text)],
    ),
  ];  
  final completion = await service.chat(messages);
  return completion.content!.first.text!;
}

