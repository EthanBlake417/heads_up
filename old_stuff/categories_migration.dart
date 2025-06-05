import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:guess_it/categories.dart'; // Import your static Categories class

/// This utility class helps migrate the static categories data to Firestore
/// You would run this once in development to populate your Firebase database
class CategoriesMigration {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = Uuid();
  
  /// Upload all categories and words to Firestore
  Future<void> migrateCategoriesToFirestore() async {
    // Get the current timestamp for version tracking
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    // First, create the metadata document
    await _firestore.collection('metadata').doc('version').set({
      'timestamp': timestamp,
      'versionName': '1.0'
    });
    
    // Migrate all categories from the static Categories class
    for (String categoryName in Categories.allCategories) {
      // Create a unique ID for this category
      final categoryId = _uuid.v4();
      
      // Map category names to icon names
      String iconName = _getCategoryIcon(categoryName);
      
      // Add the category document
      await _firestore.collection('categories').doc(categoryId).set({
        'name': categoryName,
        'icon': iconName,
        'lastUpdated': timestamp
      });
      
      // Get words for this category
      final List<String> categoryWords = Categories.categoryWords[categoryName] ?? [];
      
      // Add batch functionality to improve performance
      final batch = _firestore.batch();
      int batchCount = 0;
      
      // Add all words for this category
      for (String word in categoryWords) {
        final wordRef = _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('words')
          .doc(_uuid.v4());
          
        batch.set(wordRef, {'word': word});
        batchCount++;
        
        // Commit in batches of 500 to avoid hitting Firestore limits
        if (batchCount >= 500) {
          await batch.commit();
          batchCount = 0;
        }
      }
      
      // Commit any remaining operations
      if (batchCount > 0) {
        await batch.commit();
      }
      
      // Log progress
      print('Migrated category: $categoryName with ${categoryWords.length} words');
    }
    
    print('Migration completed successfully!');
  }
  
  /// Helper method to map category names to icon names
  String _getCategoryIcon(String categoryName) {
    switch(categoryName) {
      case 'Animals': return 'pets';
      case 'Movies': return 'movie';
      case 'Food': return 'restaurant';
      case 'Sports': return 'sports_soccer';
      case 'Music': return 'music_note';
      case 'Countries': return 'public';
      case 'Celebrities': return 'star';
      case 'Professions': return 'work';
      case 'Science': return 'science';
      case 'Literature': return 'book';
      case 'History': return 'history';
      case 'TV Shows': return 'tv';
      case 'Brands': return 'branding_watermark';
      case 'Famous Landmarks': return 'landmark';
      case 'Slang': return 'emoji_emotions';
      case 'Every Day Objects': return 'kitchen';
      case 'Technology': return 'lightbulb';
      case 'Mythology': return 'auto_stories';
      case 'Video Games': return 'gamepad';
      case 'Nature': return 'nature';
      case 'Fashion': return 'shopping_bag';
      case 'Disney': return 'crown';
      case 'Olympic Sports': return 'sports_gymnastics';
      case 'Board Games': return 'casino';
      case 'Lord of the Rings': return 'ring';
      case 'Chess': return 'chess_knight';
      case 'Harry Potter': return 'wand_sparkles';
      case 'Bible': return 'book_bible';
      case 'Cornerstone': return 'church';
      case 'Pop Songs': return 'music_note';
      case 'Classical Pieces': return 'music_note';
      case 'Act It Out': return 'theater_comedy';
      case 'Impressions': return 'face';
      default: return 'category';
    }
  }
  
  /// For testing - allows you to check if a category exists in Firestore
  Future<bool> checkIfCategoryExists(String categoryName) async {
    final QuerySnapshot snapshot = await _firestore
        .collection('categories')
        .where('name', isEqualTo: categoryName)
        .get();
    
    return snapshot.docs.isNotEmpty;
  }
  
  /// For testing - get a count of words for a specific category
  Future<int> countWordsForCategory(String categoryName) async {
    // First, find the category document
    final QuerySnapshot categorySnapshot = await _firestore
        .collection('categories')
        .where('name', isEqualTo: categoryName)
        .get();
    
    if (categorySnapshot.docs.isEmpty) {
      return 0;
    }
    
    // Get the category ID
    final String categoryId = categorySnapshot.docs.first.id;
    
    // Count words in that category
    final QuerySnapshot wordSnapshot = await _firestore
        .collection('categories')
        .doc(categoryId)
        .collection('words')
        .get();
    
    return wordSnapshot.docs.length;
  }
  
  /// For testing - debug function to print all categories
  Future<void> printAllCategories() async {
    final QuerySnapshot snapshot = await _firestore.collection('categories').get();
    
    print('Found ${snapshot.docs.length} categories in Firestore:');
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      print('- ${data['name']} (icon: ${data['icon']})');
    }
  }
}