import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user_model.dart';
import '../models/chat_session_model.dart';
import '../models/message_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('chatlink.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        profilePicturePath TEXT,
        pinHash TEXT NOT NULL,
        biometricEnabled INTEGER NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');

    // Chat sessions table
    await db.execute('''
      CREATE TABLE chat_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        peerName TEXT NOT NULL,
        peerAvatar TEXT,
        peerQrData TEXT,
        startTime INTEGER NOT NULL,
        endTime INTEGER,
        isActive INTEGER NOT NULL,
        lastMessage TEXT,
        lastMessageTime INTEGER
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
        attachmentPath TEXT,
        FOREIGN KEY (sessionId) REFERENCES chat_sessions (id)
      )
    ''');
  }

  Future<void> initDatabase() async {
    await database;
  }

  // User operations
  Future<int> insertUser(UserModel user) async {
    final db = await instance.database;
    return await db.insert('users', user.toMap());
  }

  Future<UserModel?> getUser() async {
    final db = await instance.database;
    final maps = await db.query('users', limit: 1);
    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateUser(UserModel user) async {
    final db = await instance.database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<void> deleteUser() async {
    final db = await instance.database;
    await db.delete('users');
  }

  // Chat session operations
  Future<int> insertChatSession(ChatSessionModel session) async {
    final db = await instance.database;
    return await db.insert('chat_sessions', session.toMap());
  }

  Future<List<ChatSessionModel>> getChatSessions() async {
    final db = await instance.database;
    final maps = await db.query(
      'chat_sessions',
      orderBy: 'lastMessageTime DESC, startTime DESC',
    );
    return maps.map((map) => ChatSessionModel.fromMap(map)).toList();
  }

  Future<ChatSessionModel?> getChatSession(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'chat_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return ChatSessionModel.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateChatSession(ChatSessionModel session) async {
    final db = await instance.database;
    return await db.update(
      'chat_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<void> deleteChatSession(int id) async {
    final db = await instance.database;
    await db.delete('chat_sessions', where: 'id = ?', whereArgs: [id]);
    await db.delete('messages', where: 'sessionId = ?', whereArgs: [id]);
  }

  // Message operations
  Future<int> insertMessage(MessageModel message) async {
    final db = await instance.database;
    final messageId = await db.insert('messages', message.toMap());

    // Update last message in chat session
    await db.update(
      'chat_sessions',
      {
        'lastMessage': message.content,
        'lastMessageTime': message.timestamp.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [message.sessionId],
    );

    return messageId;
  }

  Future<List<MessageModel>> getMessages(int sessionId) async {
    final db = await instance.database;
    final maps = await db.query(
      'messages',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );
    return maps.map((map) => MessageModel.fromMap(map)).toList();
  }

  Future<void> deleteMessage(int id) async {
    final db = await instance.database;
    await db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
