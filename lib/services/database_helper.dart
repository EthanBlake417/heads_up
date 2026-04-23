import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:guess_it/models/category_model.dart';
import 'package:guess_it/models/word_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'guess_it.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDb,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories(
        id TEXT PRIMARY KEY,
        name TEXT,
        icon TEXT,
        lastUpdated INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE words(
        id TEXT PRIMARY KEY,
        categoryId TEXT,
        word TEXT,
        FOREIGN KEY (categoryId) REFERENCES categories (id)
      )
    ''');
  }

  // Category operations
  Future<void> insertCategory(CategoryModel category) async {
    final db = await database;
    await db.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertCategories(List<CategoryModel> categories) async {
    final db = await database;
    final batch = db.batch();
    
    for (var category in categories) {
      batch.insert(
        'categories',
        category.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
  }

  Future<List<CategoryModel>> getCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('categories');
    
    return List.generate(maps.length, (i) {
      return CategoryModel.fromMap(maps[i]);
    });
  }

  Future<CategoryModel?> getCategoryByName(String name) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'name = ?',
      whereArgs: [name],
    );
    
    if (maps.isNotEmpty) {
      return CategoryModel.fromMap(maps.first);
    }
    return null;
  }

  Future<int> getLastUpdatedTimestamp() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(lastUpdated) as lastUpdated FROM categories'
    );
    
    return result.first['lastUpdated'] as int? ?? 0;
  }

  // Word operations
  Future<void> insertWord(WordModel word) async {
    final db = await database;
    await db.insert(
      'words',
      word.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertWords(List<WordModel> words) async {
    final db = await database;
    final batch = db.batch();
    
    for (var word in words) {
      batch.insert(
        'words',
        word.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
  }

  Future<void> clearWordsForCategory(String categoryId) async {
    final db = await database;
    await db.delete(
      'words',
      where: 'categoryId = ?',
      whereArgs: [categoryId],
    );
  }

  Future<List<WordModel>> getWordsByCategory(String categoryId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'words',
      where: 'categoryId = ?',
      whereArgs: [categoryId],
    );
    
    return List.generate(maps.length, (i) {
      return WordModel.fromMap(maps[i]);
    });
  }

  Future<List<String>> getWordStringsByCategory(String categoryName) async {
  final category = await getCategoryByName(categoryName);
  if (category == null) {
    return [];
  }
  
  final db = await database;
  
  try {
    final List<Map<String, dynamic>> maps = await db.query(
      'words',
      columns: ['word'],
      where: 'categoryId = ?',
      whereArgs: [category.id],
    );
    
    
    return List.generate(maps.length, (i) => maps[i]['word'] as String);
  } catch (e) {
    
    // Try a raw query as fallback
    try {
      final result = await db.rawQuery(
        'SELECT word FROM words WHERE categoryId = ?',
        [category.id]
      );
      
      return result.map((row) => row['word'] as String).toList();
    } catch (e) {
      return [];
    }
  }
}

  Future<List<String>> getAllWords() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'words',
      columns: ['word'],
    );
    
    return List.generate(maps.length, (i) => maps[i]['word'] as String);
  }

  // Utility methods
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('words');
    await db.delete('categories');
  }

Future<int> deleteCategory(String categoryId) async {
  final db = await database;
  
  // First delete all words for this category (due to foreign key constraint)
  await db.delete(
    'words',
    where: 'categoryId = ?',
    whereArgs: [categoryId],
  );
  
  // Then delete the category
  return await db.delete(
    'categories',
    where: 'id = ?',
    whereArgs: [categoryId],
  );
}
}