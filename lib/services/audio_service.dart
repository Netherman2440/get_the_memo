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
    final savedFilePath = path.join(audioDir, '$fileName.m4a');

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

  // Start recording
  static Future<void> startRecording(String fileName) async {
    try {
      print('Start recording'); // Debug log
      _audioRecorder = AudioRecorder();
      _isPaused = false;

      // Check and request permissions if needed
      if (!await Permission.microphone.isGranted) {
        final status = await Permission.microphone.request();
        if (status != PermissionStatus.granted) {
          throw AudioServiceException('Microphone permission denied');
        }
      }

      final audioDir = await _getAudioDirectory();
      final filePath = path.join(audioDir, '$fileName.wav');
      print('Recording to path: $filePath'); // Debug log

      await _audioRecorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          bitRate: 256000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      // Verify recording started
      if (_audioRecorder != null && !await _audioRecorder!.isRecording()) {
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
        await _audioRecorder?.pause();
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
        await _audioRecorder?.resume();
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

      // Allow stopping even if paused
      if (!await _audioRecorder!.isRecording() && !_isPaused) {
        throw AudioServiceException('Not currently recording or paused');
      }

      final recordedPath = await _audioRecorder?.stop();
      print('Recorded path: $recordedPath'); // Debug log

      // Reset state
      _audioRecorder = null;
      _isPaused = false;

      if (recordedPath == null) {
        throw AudioServiceException('Recording failed: no file path returned');
      }

      // Verify file exists and has content
      final file = File(recordedPath);
      if (!await file.exists()) {
        print('File does not exist at path: $recordedPath'); // Debug log
        throw AudioServiceException(
          'Recording failed: file not found at $recordedPath',
        );
      }

      final fileSize = await file.length();
      print('File size: $fileSize bytes'); // Debug log
      if (fileSize == 0) {
        await file.delete();
        throw AudioServiceException('Recording failed: file is empty');
      }

      // Ensure file is in our audio directory
      final audioDir = await _getAudioDirectory();
      final fileName = path.basename(recordedPath);
      final finalPath = path.join(audioDir, fileName);

      if (recordedPath != finalPath) {
        final newFile = await File(recordedPath).copy(finalPath);
        await File(recordedPath).delete();
        return newFile.path;
      }

      return recordedPath;
    } catch (e) {
      // Reset state on error
      _audioRecorder = null;
      _isPaused = false;
      throw AudioServiceException('Failed to stop recording: $e');
    }
  }

  // Check if currently recording or paused
  static Future<bool> isRecordingOrPaused() async {
    return (_audioRecorder != null &&
        (await _audioRecorder!.isRecording() || _isPaused));
  }

  // Check if recording is paused
  static Future<bool> isPaused() async {
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
