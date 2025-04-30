class WordModel {
  final String id;
  final String categoryId;
  final String word;

  WordModel({
    required this.id,
    required this.categoryId,
    required this.word,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoryId': categoryId,
      'word': word,
    };
  }

  factory WordModel.fromMap(Map<String, dynamic> map) {
    return WordModel(
      id: map['id'],
      categoryId: map['categoryId'],
      word: map['word'],
    );
  }

  factory WordModel.fromFirestore(Map<String, dynamic> map, String documentId, String categoryId) {
    return WordModel(
      id: documentId,
      categoryId: categoryId,
      word: map['word'] ?? '',
    );
  }
}