import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:record/record.dart'; // For audio recording
import 'package:permission_handler/permission_handler.dart'; // For handling permissions

class AudioService {
  
  static const String _audioDirectory = 'audio_recordings';
  static AudioRecorder? _audioRecorder;
  static bool _isPaused = false;

  // Get the audio directory path
  static Future<String> _getAudioDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory(path.join(appDir.path, _audioDirectory));
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return audioDir.path;
  }

  // Save audio file and return its path
  static Future<String> saveAudio({
    required File audioFile,
    required String fileName,
  }) async {
    final audioDir = await _getAudioDirectory();
    final savedFilePath = path.join(audioDir, '$fileName.wav');

    try {
      await audioFile.copy(savedFilePath);
      return savedFilePath;
    } catch (e) {
      throw AudioServiceException('Failed to save audio file: $e');
    }
  }

  // Get audio file from path
  static Future<File?> getAudio(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (e) {
      throw AudioServiceException('Failed to get audio file: $e');
    }
  }

  // Delete audio file
  static Future<void> deleteAudio(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw AudioServiceException('Failed to delete audio file: $e');
    }
  }

  // Start recording with optimized settings
  static Future<void> startRecording(String filePath) async {
    try {
      print('Start recording to: $filePath'); // Debug log
      _audioRecorder = AudioRecorder();
      _isPaused = false;

      // Check and request permissions if needed
      if (!await Permission.microphone.isGranted) {
        final status = await Permission.microphone.request();
        if (status != PermissionStatus.granted) {
          throw AudioServiceException('Microphone permission denied');
        }
      }

      await _audioRecorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.wav, // Using WAV for better quality
          bitRate: 256000,
          sampleRate: 16000, // Optimized for Whisper
          numChannels: 1,    // Mono for Whisper
        ),
        path: filePath,
      );

      // Verify recording started
      if (!await _audioRecorder!.isRecording()) {
        throw AudioServiceException('Failed to start recording');
      }
    } catch (e) {
      _audioRecorder = null;
      throw AudioServiceException('Failed to start recording: $e');
    }
  }

  // Pause recording
  static Future<void> pauseRecording() async {
    try {
      print('Pause recording'); // Debug log
      if (_audioRecorder != null) {
        await _audioRecorder!.pause();
        _isPaused = true;
      }
    } catch (e) {
      throw AudioServiceException('Failed to pause recording: $e');
    }
  }

  // Resume recording
  static Future<void> resumeRecording() async {
    try {
      print('Resume recording'); // Debug log
      if (_audioRecorder != null) {
        await _audioRecorder!.resume();
        _isPaused = false;
      }
    } catch (e) {
      throw AudioServiceException('Failed to resume recording: $e');
    }
  }

  // Stop recording and return the file path
  static Future<String?> stopRecording() async {
    try {
      print('Stop recording'); // Debug log
      if (_audioRecorder == null) {
        throw AudioServiceException('Recorder not initialized');
      }

      final path = await _audioRecorder!.stop();
      print('Recording stopped, path: $path'); // Debug log

      // Reset state
      _audioRecorder = null;
      _isPaused = false;

      return path;
    } catch (e) {
      print('Error stopping recording: $e'); // Debug log
      _audioRecorder = null;
      _isPaused = false;
      throw AudioServiceException('Failed to stop recording: $e');
    }
  }

  // Check if currently recording
  static Future<bool> isRecording() async {
    return _audioRecorder?.isRecording() ?? false;
  }

  // Check if recording is paused
  static bool isPaused() {
    return _isPaused;
  }

  // Cleanup method
  static Future<void> dispose() async {
    await _audioRecorder?.dispose();
    _audioRecorder = null;
    _isPaused = false;
  }
}

// Custom exception for audio operations
class AudioServiceException implements Exception {
  final String message;
  AudioServiceException(this.message);

  @override
  String toString() => 'AudioServiceException: $message';
}
