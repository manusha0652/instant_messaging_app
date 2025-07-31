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

    return await openDatabase(
      path,
      version: 3, // Increment to version 3 to force migration
      onCreate: _createTables,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Users table with phone column included
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT UNIQUE NOT NULL,
        bio TEXT,
        profilePicture TEXT,
        pinHash TEXT,
        socketId TEXT,
        isOnline INTEGER DEFAULT 0,
        lastSeen INTEGER,
        createdAt INTEGER NOT NULL
      )
    ''');

    // Contacts table for QR code connections
    await db.execute('''
      CREATE TABLE contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        contactPhone TEXT NOT NULL,
        contactName TEXT NOT NULL,
        contactBio TEXT,
        contactAvatar TEXT,
        addedAt INTEGER NOT NULL,
        isBlocked INTEGER DEFAULT 0,
        FOREIGN KEY (userId) REFERENCES users (id),
        UNIQUE(userId, contactPhone)
      )
    ''');

    // Chat sessions table
    await db.execute('''
      CREATE TABLE chat_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        contactPhone TEXT NOT NULL,
        contactName TEXT NOT NULL,
        contactAvatar TEXT,
        lastMessage TEXT,
        lastMessageTime INTEGER,
        unreadCount INTEGER DEFAULT 0,
        isActive INTEGER DEFAULT 1,
        FOREIGN KEY (userId) REFERENCES users (id)
      )
    ''');

    // Messages table with enhanced features
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId INTEGER NOT NULL,
        content TEXT NOT NULL,
        isFromMe INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        messageType TEXT DEFAULT 'text',
        isRead INTEGER DEFAULT 0,
        isDelivered INTEGER DEFAULT 0,
        isSent INTEGER DEFAULT 1,
        FOREIGN KEY (sessionId) REFERENCES chat_sessions (id)
      )
    ''');

    // Settings table
    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY,
        userId INTEGER,
        notificationsEnabled INTEGER DEFAULT 1,
        darkModeEnabled INTEGER DEFAULT 1,
        biometricEnabled INTEGER DEFAULT 0,
        FOREIGN KEY (userId) REFERENCES users (id)
      )
    ''');
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns to users table
      try {
        await db.execute('ALTER TABLE users ADD COLUMN socketId TEXT');
        await db.execute('ALTER TABLE users ADD COLUMN isOnline INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE users ADD COLUMN lastSeen INTEGER');
      } catch (e) {
        print('Error adding columns to users table (might already exist): $e');
      }

      // Create contacts table if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS contacts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          userId INTEGER NOT NULL,
          contactPhone TEXT NOT NULL,
          contactName TEXT NOT NULL,
          contactBio TEXT,
          contactAvatar TEXT,
          addedAt INTEGER NOT NULL,
          isBlocked INTEGER DEFAULT 0,
          FOREIGN KEY (userId) REFERENCES users (id),
          UNIQUE(userId, contactPhone)
        )
      ''');

      // Add userId column to chat_sessions table if it doesn't exist
      try {
        await db.execute('ALTER TABLE chat_sessions ADD COLUMN userId INTEGER');
      } catch (e) {
        print('Error adding userId to chat_sessions (might already exist): $e');
      }

      // Create updated messages table with new columns if they don't exist
      try {
        await db.execute('ALTER TABLE messages ADD COLUMN isDelivered INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE messages ADD COLUMN isSent INTEGER DEFAULT 1');
      } catch (e) {
        print('Error adding columns to messages table (might already exist): $e');
      }

      // Create settings table if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          id INTEGER PRIMARY KEY,
          userId INTEGER,
          notificationsEnabled INTEGER DEFAULT 1,
          darkModeEnabled INTEGER DEFAULT 1,
          biometricEnabled INTEGER DEFAULT 0,
          FOREIGN KEY (userId) REFERENCES users (id)
        )
      ''');

      print('Database upgraded from version $oldVersion to $newVersion');
    }
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
      'isDelivered': 0,
      'isSent': 1,
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

  Future<int> markMessagesAsRead(int sessionId) async {
    final db = await database;
    return await db.update(
      'messages',
      {'isRead': 1},
      where: 'sessionId = ? AND isFromMe = 0 AND isRead = 0',
      whereArgs: [sessionId],
    );
  }

  // Contact operations for QR code connections
  Future<int> addContact({
    required int userId,
    required String contactPhone,
    required String contactName,
    String? contactBio,
    String? contactAvatar,
  }) async {
    final db = await database;
    return await db.insert('contacts', {
      'userId': userId,
      'contactPhone': contactPhone,
      'contactName': contactName,
      'contactBio': contactBio,
      'contactAvatar': contactAvatar,
      'addedAt': DateTime.now().millisecondsSinceEpoch,
      'isBlocked': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getUserContacts(int userId) async {
    final db = await database;
    return await db.query(
      'contacts',
      where: 'userId = ? AND isBlocked = 0',
      whereArgs: [userId],
      orderBy: 'contactName ASC',
    );
  }

  Future<Map<String, dynamic>?> getContactByPhone(int userId, String phone) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'contacts',
      where: 'userId = ? AND contactPhone = ?',
      whereArgs: [userId, phone],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  // Chat session operations with userId
  Future<int> createChatSessionForUser({
    required int userId,
    required String contactName,
    required String contactPhone,
    String? contactAvatar,
  }) async {
    final db = await database;
    return await db.insert('chat_sessions', {
      'userId': userId,
      'contactName': contactName,
      'contactPhone': contactPhone,
      'contactAvatar': contactAvatar,
      'lastMessage': 'Tap to start chatting',
      'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
      'unreadCount': 0,
      'isActive': 1,
    });
  }

  Future<List<Map<String, dynamic>>> getUserChatSessions(int userId) async {
    final db = await database;
    return await db.query(
      'chat_sessions',
      where: 'userId = ? AND isActive = ?',
      whereArgs: [userId, 1],
      orderBy: 'lastMessageTime DESC',
    );
  }

  Future<Map<String, dynamic>?> getChatSessionByUserAndPhone(int userId, String phone) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_sessions',
      where: 'userId = ? AND contactPhone = ?',
      whereArgs: [userId, phone],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
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
