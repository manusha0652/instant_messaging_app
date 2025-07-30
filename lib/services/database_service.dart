import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'chatlink.db');

    return await openDatabase(path, version: 1, onCreate: _createTables);
  }

  Future<void> _createTables(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT UNIQUE NOT NULL,
        bio TEXT,
        profilePicture TEXT,
        pinHash TEXT,
        createdAt INTEGER NOT NULL
      )
    ''');

    // Chat sessions table
    await db.execute('''
      CREATE TABLE chat_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contactName TEXT NOT NULL,
        contactPhone TEXT NOT NULL,
        contactAvatar TEXT,
        lastMessage TEXT,
        lastMessageTime INTEGER,
        unreadCount INTEGER DEFAULT 0,
        isActive INTEGER DEFAULT 1
      )
    ''');

    // Messages table
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId INTEGER NOT NULL,
        content TEXT NOT NULL,
        isFromMe INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        messageType TEXT DEFAULT 'text',
        isRead INTEGER DEFAULT 0,
        FOREIGN KEY (sessionId) REFERENCES chat_sessions (id)
      )
    ''');

    // Settings table
    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY,
        notificationsEnabled INTEGER DEFAULT 1,
        darkModeEnabled INTEGER DEFAULT 1,
        biometricEnabled INTEGER DEFAULT 0
      )
    ''');
  }

  // User operations
  Future<int> insertUser(User user) async {
    final db = await database;
    return await db.insert('users', user.toMap());
  }

  Future<User?> getUserByPhone(String phone) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'phone = ?',
      whereArgs: [phone],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateUser(User user) async {
    final db = await database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> deleteAllUsers() async {
    final db = await database;
    return await db.delete('users');
  }

  Future<bool> hasAnyUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM users',
    );
    final count = result.first['count'] as int;
    return count > 0;
  }

  // Chat session operations
  Future<int> createChatSession({
    required String contactName,
    required String contactPhone,
    String? contactAvatar,
  }) async {
    final db = await database;
    return await db.insert('chat_sessions', {
      'contactName': contactName,
      'contactPhone': contactPhone,
      'contactAvatar': contactAvatar,
      'lastMessage': 'Tap to start chatting',
      'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
      'unreadCount': 0,
      'isActive': 1,
    });
  }

  Future<Map<String, dynamic>?> getChatSessionByPhone(String phone) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_sessions',
      where: 'contactPhone = ?',
      whereArgs: [phone],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllChatSessions() async {
    final db = await database;
    return await db.query(
      'chat_sessions',
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'lastMessageTime DESC',
    );
  }

  Future<int> updateChatSession(int sessionId, Map<String, dynamic> updates) async {
    final db = await database;
    return await db.update(
      'chat_sessions',
      updates,
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<int> deleteChatSession(int sessionId) async {
    final db = await database;
    return await db.update(
      'chat_sessions',
      {'isActive': 0},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  // Message operations
  Future<int> insertMessage({
    required int sessionId,
    required String content,
    required bool isFromMe,
    String messageType = 'text',
  }) async {
    final db = await database;
    final messageId = await db.insert('messages', {
      'sessionId': sessionId,
      'content': content,
      'isFromMe': isFromMe ? 1 : 0,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'messageType': messageType,
      'isRead': isFromMe ? 1 : 0,
    });

    // Update chat session with last message
    await updateChatSession(sessionId, {
      'lastMessage': content,
      'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
    });

    return messageId;
  }

  Future<List<Map<String, dynamic>>> getMessagesForSession(int sessionId) async {
    final db = await database;
    return await db.query(
      'messages',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );
  }

  // Settings operations
  Future<Map<String, dynamic>> getSettings() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settings',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return maps.first;
    } else {
      // Create default settings
      await db.insert('settings', {
        'id': 1,
        'notificationsEnabled': 1,
        'darkModeEnabled': 1,
        'biometricEnabled': 0,
      });
      return {
        'notificationsEnabled': 1,
        'darkModeEnabled': 1,
        'biometricEnabled': 0,
      };
    }
  }

  Future<int> updateSettings(Map<String, dynamic> settings) async {
    final db = await database;
    return await db.update(
      'settings',
      settings,
      where: 'id = ?',
      whereArgs: [1],
    );
  }
}
