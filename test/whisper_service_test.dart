// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_the_memo/services/whisper_service.dart';

void main() async {
  // Setup - load environment variables before running tests
  try {
    setUpAll(() async {
      dotenv.load(fileName: ".env");
    });

  test('WhisperService transcribes audio correctly', () async {
    final service = WhisperService();
    // Use a test audio file in your test assets
    final result = await service.transcribeLargeAudio(
        'D:\\Ignacy\\Audio\\production_24.01.2025\\production_24.01.2025.mp3');
    print(result);
    // Verify the result contains expected data
    expect(result, contains('"text":')); // Basic check for JSON response
  });
  } catch (e) {
    print(e);
  }
}
