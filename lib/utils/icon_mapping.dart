// lib/utils/icon_mapping.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class IconMapping {
  // Static map of category display names to their corresponding icons
  static final Map<String, IconData> availableIcons = {
    'Category': Icons.category,
    'Animals': Icons.pets,
    'Movies': Icons.movie,
    'Food': Icons.restaurant,
    'Sports': Icons.sports_soccer,
    'Music': Icons.music_note,
    'Countries': Icons.public,
    'Celebrities': Icons.star,
    'Professions': Icons.work,
    'Science': Icons.science,
    'Literature': Icons.book,
    'History': Icons.history,
    'TV Shows': Icons.tv,
    'Brands': Icons.branding_watermark,
    'Slang': Icons.emoji_emotions,
    'Objects': Icons.kitchen,
    'Technology': Icons.lightbulb,
    'Mythology': Icons.auto_stories,
    'Video Games': Icons.gamepad,
    'Nature': Icons.nature,
    'Fashion': Icons.shopping_bag,
    'Disney': FontAwesomeIcons.crown,
    'Board Games': Icons.casino,
    'Fantasy': FontAwesomeIcons.dragon,
    'Religion': Icons.church,
    'Theater': Icons.theater_comedy,
    'Characters': Icons.face,
    'Art': Icons.palette,
    'Hobbies': Icons.emoji_events,
    'Travel': Icons.flight,
    'Cars': Icons.directions_car,
    'Space': Icons.rocket,
    'Medical': Icons.medical_services,
    'Weather': Icons.wb_sunny,
    'School': Icons.school,
    'Business': Icons.business,
    'Math': Icons.calculate,
    'Transportation': Icons.directions_bus,
    'Buildings': Icons.apartment,
    'Furniture': Icons.chair,
    'Colors': Icons.color_lens,
    'Instruments': Icons.piano,
    'Ocean': FontAwesomeIcons.water,
    'Computer': Icons.computer,
    'Photography': Icons.camera_alt,
    'Party': Icons.celebration,
    'Holiday': Icons.card_giftcard,
    'Fitness': Icons.fitness_center,
    'Comedy': Icons.sentiment_very_satisfied,
    'Drama': Icons.theaters,
    'Mystery': Icons.search,
    'Horror': FontAwesomeIcons.ghost,
  };

  // Convert a display name to a storage key
  static String displayNameToKey(String displayName) {
    return displayName.toLowerCase().replaceAll(' ', '_');
  }

  // Convert a storage key to a display name
  static String keyToDisplayName(String key) {
    return key
        .split('_')
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
        .join(' ');
  }

  // Get icon from a storage key
  static IconData getIconFromKey(String key) {
    // Try to convert the key to a display name first
    String displayName = keyToDisplayName(key);
    
    // Check for exact match by display name
    if (availableIcons.containsKey(displayName)) {
      return availableIcons[displayName]!;
    }
    
    // Check for exact match of the key itself (case-insensitive)
    for (var entry in availableIcons.entries) {
      String entryKey = displayNameToKey(entry.key);
      if (entryKey == key.toLowerCase()) {
        return entry.value;
      }
    }
    
    // Check for partial matches (case-insensitive)
    for (var entry in availableIcons.entries) {
      if (entry.key.toLowerCase().contains(key.toLowerCase()) ||
          key.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    
    // Default to category icon if no match
    return Icons.category;
  }
  
  // Check if an icon is a FontAwesome icon
  static bool isFontAwesomeIcon(IconData icon) {
    return icon.fontFamily == 'FontAwesomeSolid' || 
           icon.fontFamily == 'FontAwesomeRegular' || 
           icon.fontFamily == 'FontAwesomeBrands';
  }
}