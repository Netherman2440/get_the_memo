import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:convert';

class WhisperService {

  final apiKey = dotenv.get('OPENAI_API_KEY');

  Future<String> transcribeAudio(String audioPath) async {
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
      throw Exception('Failed to transcribe audio');
    }
  }

  /// Splits audio file into smaller chunks and transcribes each chunk
  Future<String> transcribeLargeAudio(String audioPath, {int maxFileSizeMB = 20}) async {
    final File audioFile = File(audioPath);
    final int fileSizeBytes = await audioFile.length();
    final int fileSizeMB = fileSizeBytes ~/ (1024 * 1024);
    
    // If file is already small enough, just transcribe it directly
    if (fileSizeMB <= maxFileSizeMB) {
      return transcribeAudio(audioPath);
    }
    
    // Create temporary directory for chunks
    final tempDir = await getTemporaryDirectory();
    final outputDir = Directory('${tempDir.path}/audio_chunks');
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    
    // Calculate how many chunks we need
    final int numChunks = (fileSizeMB / maxFileSizeMB).ceil();
    
    // Load the audio file
    final player = AudioPlayer();
    final duration = await player.setFilePath(audioPath);
    if (duration == null) {
      throw Exception('Could not determine audio duration');
    }
    
    final int chunkDurationMs = duration.inMilliseconds ~/ numChunks;
    final List<File> chunkFiles = [];
    
    // Create audio chunks using just_audio for analysis and manual file splitting
    for (int i = 0; i < numChunks; i++) {
      final int startMs = i * chunkDurationMs;
      final int endMs = min((i + 1) * chunkDurationMs, duration.inMilliseconds);
      
      // Create a new file for this chunk
      final chunkPath = '${outputDir.path}/chunk_${i.toString().padLeft(3, '0')}.mp3';
      final chunkFile = File(chunkPath);
      
      // Read the bytes from the original file for this segment
      // Note: This is a simplified approach and may not work perfectly for all audio formats
      // For a production app, you might need a more sophisticated audio processing library
      final RandomAccessFile raf = await audioFile.open(mode: FileMode.read);
      await raf.setPosition((startMs / duration.inMilliseconds * fileSizeBytes).round());
      final bytesToRead = ((endMs - startMs) / duration.inMilliseconds * fileSizeBytes).round();
      final bytes = await raf.read(bytesToRead);
      await raf.close();
      
      // Write the bytes to the chunk file
      await chunkFile.writeAsBytes(bytes);
      chunkFiles.add(chunkFile);
    }
    
    await player.dispose();
    
    // Transcribe each chunk
    final allTranscriptions = [];
    
    for (final chunk in chunkFiles) {
      try {
        final transcription = await transcribeAudio(chunk.path);
        final transcriptionJson = jsonDecode(transcription);
        allTranscriptions.add(transcriptionJson);
      } catch (e) {
        print('Error transcribing chunk ${chunk.path}: $e');
      } finally {
        // Clean up chunk after processing
        await chunk.delete();
      }
    }
    
    // Combine all transcriptions
    final combinedResult = _combineTranscriptions(allTranscriptions);
    return jsonEncode(combinedResult);
  }
  
  /// Combines multiple transcription results into one
  Map<String, dynamic> _combineTranscriptions(List<dynamic> transcriptions) {
    if (transcriptions.isEmpty) return {};
    
    final result = Map<String, dynamic>.from(transcriptions.first);
    final allSegments = List<Map<String, dynamic>>.from(result['segments'] ?? []);
    
    double lastEndTime = 0;
    
    // Start from second transcription
    for (int i = 1; i < transcriptions.length; i++) {
      final currentTranscription = transcriptions[i];
      final currentSegments = List<Map<String, dynamic>>.from(currentTranscription['segments'] ?? []);
      
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
      result['text'] = (result['text'] ?? '') + ' ' + (currentTranscription['text'] ?? '');
    }
    
    result['segments'] = allSegments;
    return result;
  }
}
