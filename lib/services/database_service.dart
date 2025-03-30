import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

import 'package:get_the_memo/models/meeting.dart';

class DatabaseService {
  static Database? db;

  // Constants for database setup
  static const String _databaseName = 'meetings.db';
  static const int _databaseVersion = 5;

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

  // Constants for summary table
  static const String tableSummary = 'summaries';
  static const String columnSummaryId = 'id';
  static const String columnSummaryText = 'summaryText';
  static const String columnSummaryCreatedAt = 'createdAt';

  // Add new constants for tasks table
  static const String tableTasks = 'tasks';
  static const String columnTasksId = 'id';
  static const String columnTasksText = 'tasksText';
  static const String columnTasksCreatedAt = 'createdAt';

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

    await db.execute('''
      CREATE TABLE $tableSummary (
        $columnSummaryId TEXT PRIMARY KEY,
        $columnMeetingId TEXT NOT NULL,
        $columnSummaryText TEXT NOT NULL,
        $columnSummaryCreatedAt TEXT NOT NULL,
        FOREIGN KEY ($columnMeetingId) REFERENCES $tableMeetings ($columnId) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableTasks (
        $columnTasksId TEXT PRIMARY KEY,
        $columnMeetingId TEXT NOT NULL,
        $columnTasksText TEXT NOT NULL,
        $columnTasksCreatedAt TEXT NOT NULL,
        FOREIGN KEY ($columnMeetingId) REFERENCES $tableMeetings ($columnId) ON DELETE CASCADE
      )
    ''');

  }

  // Handle database upgrades
  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // For simplicity, drop all data and recreate tables
    if (oldVersion < newVersion) {
      // Drop existing tables if they exist
      await db.execute('DROP TABLE IF EXISTS $tableTranscriptions');
      await db.execute('DROP TABLE IF EXISTS $tableMeetings');
      await db.execute('DROP TABLE IF EXISTS $tableSummary');
      await db.execute('DROP TABLE IF EXISTS $tableTasks');
      // Recreate all tables
      await _createDb(db, newVersion);

      print('Database upgraded to version $_databaseVersion: Created transcriptions table');
    }
  }

  //region Meetings
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
    final List<Map<String, dynamic>> maps =
        await db?.query(tableMeetings) ?? [];
    return maps.map((map) => Meeting.fromJson(map)).toList();
  }

  // Get single meeting by id
  static Future<Meeting?> getMeeting(String id) async {
    final List<Map<String, dynamic>> maps =
        await db?.query(
          tableMeetings,
          where: '$columnId = ?',
          whereArgs: [id],
          limit: 1,
        ) ??
        [];

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
    await db?.delete(tableMeetings, where: '$columnId = ?', whereArgs: [id]);
  }
  //endregion

  //region Transcriptions
  // Methods for transcriptions

  // Insert new transcription
  static Future<void> insertTranscription(
    String meetingId,
    String transcription,
  ) async {
    print('Inserting transcription for meetingId: $meetingId'); // Debug log
    print('Transcription text: $transcription'); // Debug log
    
    final transcriptionId =
        'trans_${DateTime.now().millisecondsSinceEpoch}_$meetingId';
    
    final data = {
      columnTranscriptionId: transcriptionId,
      columnMeetingId: meetingId,
      columnTranscriptionText: transcription,
      columnTranscriptionCreatedAt: DateTime.now().toIso8601String(),
    };
    
      print('Inserting data: $data'); // Debug log
    
    try {
      await db?.insert(tableTranscriptions, data,
          conflictAlgorithm: ConflictAlgorithm.replace);
      print('Transcription inserted successfully'); // Debug log
    } catch (e) {
      print('Error inserting transcription: $e'); // Debug log
      rethrow;
    }
  }

  // Get transcription for a meeting
  static Future<String?> getTranscription(String meetingId) async {
    print('Fetching transcription for meetingId: $meetingId'); // Debug log
    
    final List<Map<String, dynamic>> maps =
        await db?.query(
          tableTranscriptions,
          where: '$columnMeetingId = ?',
          whereArgs: [meetingId],
          orderBy: '$columnTranscriptionCreatedAt DESC',
          limit: 1,
        ) ??
        [];

    print('Found transcriptions: $maps'); // Debug log
    
    if (maps.isEmpty) return null;
    return maps.first[columnTranscriptionText];
  }

  // Update transcription
  static Future<void> updateTranscription(
    String meetingId,
    String transcriptionText,
  ) async {
    await db?.update(
      tableTranscriptions,
      {
        columnTranscriptionText: transcriptionText,
        columnTranscriptionCreatedAt: DateTime.now().toIso8601String(),
      },
      where: '$columnMeetingId = ?',
      whereArgs: [meetingId],
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

  // Add debug method to list all transcriptions
  static Future<void> debugListAllTranscriptions() async {
    print('\n--- DEBUG: All Transcriptions ---');
    final List<Map<String, dynamic>> allTranscriptions =
        await db?.query(tableTranscriptions) ?? [];
    print('Total transcriptions found: ${allTranscriptions.length}');
    for (var trans in allTranscriptions) {
      print('Transcription: $trans');
    }
    print('-------------------------------\n');
  }
  //endregion

  //region Summary

  // Insert new summary
  static Future<void> insertSummary(String meetingId, String summary) async {
    final summaryId = 'sum_${DateTime.now().millisecondsSinceEpoch}_$meetingId';
    await db?.insert(tableSummary, {
      columnSummaryId: summaryId,
      columnMeetingId: meetingId,
      columnSummaryText: summary,
      columnSummaryCreatedAt: DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Get summary for a meeting
  static Future<String?> getSummary(String meetingId) async {
    final List<Map<String, dynamic>> maps =
        await db?.query(
          tableSummary,
          columns: [columnSummaryText],
          where: '$columnMeetingId = ?',
          whereArgs: [meetingId],
          orderBy: '$columnSummaryCreatedAt DESC',
          limit: 1,
        ) ??
        [];

    if (maps.isEmpty) return null;
    return maps.first[columnSummaryText];
  }

  static Future<void> updateSummary(String meetingId, String summary) async {
    await db?.update(
      tableSummary,
      {columnSummaryText: summary, columnSummaryCreatedAt: DateTime.now().toIso8601String()},
      where: '$columnMeetingId = ?',
      whereArgs: [meetingId],
    );
  }

  static Future<void> deleteSummary(String summaryId) async {
    await db?.delete(
      tableSummary,
      where: '$columnSummaryId = ?',
      whereArgs: [summaryId],
    );
  }
  //endregion

  // Add CRUD methods for tasks
  static Future<void> insertTasks(String meetingId, String tasks) async {
    final tasksId = 'task_${DateTime.now().millisecondsSinceEpoch}_$meetingId';
    await db?.insert(tableTasks, {
      columnTasksId: tasksId,
      columnMeetingId: meetingId,
      columnTasksText: tasks,
      columnTasksCreatedAt: DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<String?> getTasks(String meetingId) async {
    final List<Map<String, dynamic>> maps = await db?.query(
          tableTasks,
          columns: [columnTasksText],
          where: '$columnMeetingId = ?',
          whereArgs: [meetingId],
          orderBy: '$columnTasksCreatedAt DESC',
          limit: 1,
        ) ??
        [];

    if (maps.isEmpty) return null;
    return maps.first[columnTasksText];
  }

  static Future<void> updateTasks(String meetingId, String tasks) async {
    await db?.update(
      tableTasks,
      {
        columnTasksText: tasks,
        columnTasksCreatedAt: DateTime.now().toIso8601String(),
      },
      where: '$columnMeetingId = ?',
      whereArgs: [meetingId],
    );
  }

  //region AutoTitle
  static Future<void> insertAutoTitle(String meetingId, String title, String description) async {
    await db?.update(tableMeetings, {
      columnTitle: title,
      columnDescription: description,
    }, where: '$columnId = ?', whereArgs: [meetingId], conflictAlgorithm: ConflictAlgorithm.replace);
  }

  
  
}
