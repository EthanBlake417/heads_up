class CategoryModel {
  final String id;
  final String name;
  final String icon;
  final int lastUpdated;

  CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'lastUpdated': lastUpdated,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'],
      name: map['name'],
      icon: map['icon'],
      lastUpdated: map['lastUpdated'],
    );
  }

  factory CategoryModel.fromFirestore(Map<String, dynamic> map, String documentId) {
    return CategoryModel(
      id: documentId,
      name: map['name'] ?? '',
      icon: map['icon'] ?? 'category', // Default icon name
      lastUpdated: map['lastUpdated'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}