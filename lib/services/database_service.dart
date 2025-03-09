import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

import 'package:get_the_memo/models/meeting.dart';


class DatabaseService {
  static Database? db;
  
  // Constants for database setup
  static const String _databaseName = 'meetings.db';
  static const int _databaseVersion = 3;
  
  // Constants for meetings table
  static const String tableMeetings = 'meetings';
  static const String columnId = 'id';
  static const String columnTitle = 'title';
  static const String columnDescription = 'description';
  static const String columnCreatedAt = 'createdAt';
  static const String columnAudioPath = 'audioUrl';
  static const String columnDuration = 'duration';
  
  // Constants for transcriptions table
  static const String tableTranscriptions = 'transcriptions';
  static const String columnTranscriptionId = 'id';
  static const String columnMeetingId = 'meetingId';
  static const String columnTranscriptionText = 'transcriptionText';
  static const String columnTranscriptionCreatedAt = 'createdAt';

  static Future<void> init() async {
    // Get the application documents directory
    WidgetsFlutterBinding.ensureInitialized();
    
    final appDir = await getDatabasesPath();
    final dbPath = path.join(appDir, _databaseName);
    
    // Open/create database
    db = await openDatabase(
      dbPath,
      version: _databaseVersion,
      onCreate: _createDb,
      onUpgrade: _onUpgrade,
    );
  }

  // Create database tables
  static Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableMeetings (
        $columnId TEXT PRIMARY KEY,
        $columnTitle TEXT NOT NULL,
        $columnDescription TEXT NOT NULL,
        $columnCreatedAt TEXT NOT NULL,
        $columnAudioPath TEXT NOT NULL,
        $columnDuration INTEGER
      )
    ''');
    
    await db.execute('''
      CREATE TABLE $tableTranscriptions (
        $columnTranscriptionId TEXT PRIMARY KEY,
        $columnMeetingId TEXT NOT NULL,
        $columnTranscriptionText TEXT NOT NULL,
        $columnTranscriptionCreatedAt TEXT NOT NULL,
        FOREIGN KEY ($columnMeetingId) REFERENCES $tableMeetings ($columnId) ON DELETE CASCADE
      )
    ''');
  }

  // Handle database upgrades
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // For simplicity, drop all data and recreate tables
    if (oldVersion < newVersion) {
      // Drop existing tables if they exist
      await db.execute('DROP TABLE IF EXISTS $tableTranscriptions');
      await db.execute('DROP TABLE IF EXISTS $tableMeetings');
      
      // Recreate all tables
      await _createDb(db, newVersion);
      
      print('Database upgraded to version 3: Created transcriptions table');
    }
  }

  // Insert new meeting
  static Future<void> insertMeeting(Meeting meeting) async {
    await db?.insert(
      tableMeetings,
      meeting.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all meetings
  static Future<List<Meeting>> getMeetings() async {
    final List<Map<String, dynamic>> maps = await db?.query(tableMeetings) ?? [];
    return maps.map((map) => Meeting.fromJson(map)).toList();
  }

  // Get single meeting by id
  static Future<Meeting?> getMeeting(String id) async {
    final List<Map<String, dynamic>> maps = await db?.query(
      tableMeetings,
      where: '$columnId = ?',
      whereArgs: [id],
      limit: 1,
    ) ?? [];
    
    if (maps.isEmpty) return null;
    return Meeting.fromJson(maps.first);
  }

  // Update meeting
  static Future<void> updateMeeting(Meeting meeting) async {
    await db?.update(
      tableMeetings,
      meeting.toJson(),
      where: '$columnId = ?',
      whereArgs: [meeting.id],
    );
  }

  // Delete meeting
  static Future<void> deleteMeeting(String id) async {
    await db?.delete(
      tableMeetings,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Methods for transcriptions
  
  // Insert new transcription
  static Future<void> insertTranscription(String meetingId, String transcriptionText) async {
    final transcriptionId = 'trans_${DateTime.now().millisecondsSinceEpoch}_$meetingId';
    await db?.insert(
      tableTranscriptions,
      {
        columnTranscriptionId: transcriptionId,
        columnMeetingId: meetingId,
        columnTranscriptionText: transcriptionText,
        columnTranscriptionCreatedAt: DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  // Get transcription for a meeting
  static Future<String?> getTranscription(String meetingId) async {
    final List<Map<String, dynamic>> maps = await db?.query(
      tableTranscriptions,
      columns: [columnTranscriptionText],
      where: '$columnMeetingId = ?',
      whereArgs: [meetingId],
      orderBy: '$columnTranscriptionCreatedAt DESC',
      limit: 1,
    ) ?? [];
    
    if (maps.isEmpty) return null;
    return maps.first[columnTranscriptionText];
  }
  
  // Update transcription
  static Future<void> updateTranscription(String transcriptionId, String transcriptionText) async {
    await db?.update(
      tableTranscriptions,
      {
        columnTranscriptionText: transcriptionText,
        columnTranscriptionCreatedAt: DateTime.now().toIso8601String(),
      },
      where: '$columnTranscriptionId = ?',
      whereArgs: [transcriptionId],
    );
  }
  
  // Delete transcription
  static Future<void> deleteTranscription(String transcriptionId) async {
    await db?.delete(
      tableTranscriptions,
      where: '$columnTranscriptionId = ?',
      whereArgs: [transcriptionId],
    );
  }
  
  // Delete all transcriptions for a meeting
  static Future<void> deleteTranscriptionsForMeeting(String meetingId) async {
    await db?.delete(
      tableTranscriptions,
      where: '$columnMeetingId = ?',
      whereArgs: [meetingId],
    );
  }
}