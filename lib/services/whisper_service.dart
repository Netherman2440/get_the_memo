import 'package:get_the_memo/services/api_key_service.dart';
import 'package:get_the_memo/services/database_service.dart';
import 'package:get_the_memo/services/openai_service.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class WhisperService {
  final ApiKeyService _apiKeyService = ApiKeyService();
  String apiKey = '';

  Future<void> init() async {
    apiKey = await _apiKeyService.getApiKey();
  }

  Future<String> transcribeAudio(String audioPath) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'multipart/form-data',
      });

      request.files.add(await http.MultipartFile.fromPath('file', audioPath));
      request.fields['model'] = 'whisper-1';
      request.fields['response_format'] = 'verbose_json';
      request.fields['timestamp_granularities[]'] = 'segment';

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseBody = await response.stream.bytesToString();
        return responseBody;
      } else {
        var error = await response.stream.bytesToString();
        var errorJson = jsonDecode(error);
        
        // Handle specific error cases
        if (response.statusCode == 401) {
          throw InvalidAPIKeyException();
        } else if (response.statusCode == 429 && 
                   errorJson['error']?['code'] == 'insufficient_quota') {
          throw InsufficientFundsException();
        }
        
        throw Exception('Failed to transcribe audio: ${response.statusCode} - ${errorJson['error']?['message'] ?? response.reasonPhrase}');
      }
    } catch (e) {
      if (e is InvalidAPIKeyException || e is InsufficientFundsException) {
        rethrow;
      }
      throw Exception('Failed to transcribe audio: $e');
    }
  }

  /// Checks if a transcription is in progress
  Future<bool> isTranscriptionInProgress(String meetingId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('transcription_in_progress_$meetingId') ?? false;
  }

  /// Gets the progress of a transcription (0.0 to 1.0)
  Future<double> getTranscriptionProgress(String meetingId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('transcription_progress_$meetingId') ?? 0.0;
  }

  /// Gets the completed transcription result
  Future<String?> getCompletedTranscription(String meetingId) async {
    final prefs = await SharedPreferences.getInstance();
    final isCompleted =
        prefs.getBool('transcription_completed_$meetingId') ?? false;

    if (isCompleted) {
      return prefs.getString('transcription_$meetingId');
    }

    return null;
  }

  /// Splits audio file into smaller chunks and transcribes each chunk
  Future<String> processTranscription({
    required String audioPath,
    required String meetingId,
    Function(double)? onProgressUpdate,
    bool saveProgress = false,
  }) async {
    try {
      print('Starting transcription process...');
      final directory = Directory(audioPath);
      
      // Get all audio files in the directory
      final List<FileSystemEntity> files = directory
          .listSync()
          .where((file) => file.path.endsWith('.m4a') || file.path.endsWith('.wav'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path)); // Sort by name to maintain order

      if (files.isEmpty) {
        throw Exception('No audio files found in directory: $audioPath');
      }

      final allTranscriptions = [];
      
      // Process each file
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        try {
          final transcription = await transcribeAudio(file.path);
          print('File ${file.path} transcription completed');
          final transcriptionJson = jsonDecode(transcription);
          allTranscriptions.add(transcriptionJson);

          // Update progress
          final progress = (i + 1) / files.length;
          _updateProgress(progress, onProgressUpdate, saveProgress, meetingId);
        } catch (e) {
          print('Error transcribing file ${file.path}: $e');
          rethrow;
        }
      }

      // Combine all transcriptions
      final combinedResult = _combineTranscriptions(allTranscriptions);
      print('Transcription completed successfully');

      String transcript = combinedResult['text'];
      await DatabaseService.insertTranscription(meetingId, transcript);
      
      return transcript;
    } catch (e) {
      print('Error during transcription: $e');
      rethrow;
    }
  }

  // Helper to update progress in multiple ways
  Future<void> _updateProgress(
    double progress,
    Function(double)? progressCallback,
    bool saveProgress,
    String? meetingId,
  ) async {
    // Call the callback if provided
    if (progressCallback != null) {
      progressCallback(progress);
    }

    // Save to persistent storage if requested
    if (saveProgress && meetingId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('transcription_progress_$meetingId', progress);
    }
  }

  /// Combines multiple transcription results into one
  Map<String, dynamic> _combineTranscriptions(List<dynamic> transcriptions) {
    if (transcriptions.isEmpty) return {};

    final result = Map<String, dynamic>.from(transcriptions.first);
    final allSegments = List<Map<String, dynamic>>.from(
      result['segments'] ?? [],
    );

    double lastEndTime = 0;

    // Start from second transcription
    for (int i = 1; i < transcriptions.length; i++) {
      final currentTranscription = transcriptions[i];
      final currentSegments = List<Map<String, dynamic>>.from(
        currentTranscription['segments'] ?? [],
      );

      // Adjust timestamps for current segments
      for (final segment in currentSegments) {
        segment['start'] = (segment['start'] as double) + lastEndTime;
        segment['end'] = (segment['end'] as double) + lastEndTime;
        allSegments.add(segment);
      }

      // Update last end time
      if (currentSegments.isNotEmpty) {
        lastEndTime = currentSegments.last['end'];
      }

      // Append text
      result['text'] =
          (result['text'] ?? '') + ' ' + (currentTranscription['text'] ?? '');
    }

    result['segments'] = allSegments;
    return result;
  }
}
