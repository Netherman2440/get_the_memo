import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:whisper_library_dart/whisper_library_dart.dart';

class WhisperService {
  static const String modelFileName = 'ggml-tiny.bin';
  
  WhisperLibrary? _whisperLibrary;
  bool _isInitialized = false;
  
  // Initialize whisper service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('Initializing Whisper service...');
      
      // Get local whisper model
      final modelPath = await _getLocalModelPath();
      final modelFile = File(modelPath);
      
      if (!await modelFile.exists()) {
        debugPrint('Model file not found, downloading...');
        await _downloadWhisperModel(modelPath);
      } else {
        debugPrint('Model file found at: $modelPath');
        debugPrint('File size: ${await modelFile.length()} bytes');
      }
      
      // Initialize the whisper library
      debugPrint('Creating WhisperLibrary instance...');
      _whisperLibrary = WhisperLibrary();
      
      debugPrint('Ensuring library is initialized...');
      await _whisperLibrary!.ensureInitialized();
      
      // Load the model
      debugPrint('Loading Whisper model from: $modelPath');
      final isLoaded = _whisperLibrary!.loadWhisperModel(
        whisperModelPath: modelPath,
      );
      
      debugPrint('Model loading result: $isLoaded');
      
      if (!isLoaded) {
        throw Exception('Failed to load Whisper model');
      }
      
      _isInitialized = true;
      debugPrint('Whisper service initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('Error initializing Whisper service: $e');
      debugPrint('Stack trace: $stackTrace');
      _isInitialized = false;
      rethrow;
    }
  }
  
  // Get path to local model file
  Future<String> _getLocalModelPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${appDir.path}/whisper_models');
    
    // Ensure directory exists
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    
    return '${modelDir.path}/$modelFileName';
  }
  
  // Download whisper model from Hugging Face
  Future<void> _downloadWhisperModel(String destinationPath) async {
    try {
      // Create directory if it doesn't exist
      final directory = Directory(path.dirname(destinationPath));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      // URL to the Whisper GGML model
      final modelUrl = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$modelFileName';
      
      debugPrint('Downloading Whisper model from: $modelUrl');
      
      // Download the file
      final response = await http.get(Uri.parse(modelUrl));
      
      if (response.statusCode == 200) {
        // Save the downloaded model to local storage
        await File(destinationPath).writeAsBytes(response.bodyBytes);
        debugPrint('Whisper model downloaded successfully');
        debugPrint('Downloaded file size: ${response.bodyBytes.length} bytes');
      } else {
        throw Exception('Failed to download Whisper model: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error downloading Whisper model: $e');
      rethrow;
    }
  }

  // Method to transcribe audio file with improved quality
  Future<String> transcribeAudio(String audioFilePath) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      
      final fileWav = File(audioFilePath);
      
      if (!await fileWav.exists()) {
        throw Exception('Audio file not found: $audioFilePath');
      }
      
      debugPrint('Transcribing audio file: $audioFilePath');
      debugPrint('Audio file size: ${await fileWav.length()} bytes');
      
      // Check if the whisper library is initialized
      if (_whisperLibrary == null) {
        throw Exception('Whisper library not initialized');
      }
      
      // Improved transcription with better parameters
      final result = await _whisperLibrary!.transcribeToJson(
        fileWav: fileWav,
       
        language: 'pl',
        useCountProccecors: 1,
        useCountThread: 1,

        // Add more parameters as needed
      );
      
      debugPrint('Transcription result: $result');
      
      // Extract the text from the result
      if (result.containsKey('text')) {
        return result['text'] as String;
      } else {
        // Check for segments if text is not directly available
        if (result.containsKey('segments') && result['segments'] is List && (result['segments'] as List).isNotEmpty) {
          final segments = result['segments'] as List;
          final combinedText = segments
              .map((segment) => segment['text'] as String?)
              .where((text) => text != null && text.isNotEmpty)
              .join(' ');
          
          return combinedText.isNotEmpty ? combinedText : 'No transcription available';
        }
        return 'No transcription available';
      }
    } catch (e) {
      debugPrint('Error transcribing audio: $e');
      return 'Error transcribing audio: $e';
    }
  }
  
  // Dispose resources
  void dispose() {
    if (_isInitialized && _whisperLibrary != null) {
      _whisperLibrary!.dispose();
      _whisperLibrary = null;
      _isInitialized = false;
    }
  }
}