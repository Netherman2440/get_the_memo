import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

import 'package:get_the_memo/models/meeting.dart';


class DatabaseService {
  static Database? db;
  
  // Constants for database setup
  static const String _databaseName = 'meetings.db';
  static const int _databaseVersion = 2;
  
  // Constants for meetings table
  static const String tableMeetings = 'meetings';
  static const String columnId = 'id';
  static const String columnTitle = 'title';
  static const String columnDescription = 'description';
  static const String columnCreatedAt = 'createdAt';
  static const String columnAudioPath = 'audioUrl';
  static const String columnTranscription = 'transcription';
  static const String columnDuration = 'duration';

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
        $columnTranscription TEXT,
        $columnDuration INTEGER
      )
    ''');
  }

  // Handle database upgrades
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion == 1) {
      // Add new column to existing table
      await db.execute('''
        ALTER TABLE $tableMeetings
        ADD COLUMN $columnDuration INTEGER
      ''');
      print('Database upgraded from version 1 to 2: Added duration column');
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
}