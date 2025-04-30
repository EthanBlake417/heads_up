// lib/online_decks_screen.dart
import 'package:flutter/material.dart';
import 'package:heads_up/database_helper.dart';
import 'package:heads_up/repositories/category_repository.dart';
import 'package:heads_up/services/firebase_service.dart';

class OnlineDecksScreen extends StatefulWidget {
  final VoidCallback refreshHomeTab; // Added callback to refresh home tab

  const OnlineDecksScreen({
    Key? key, 
    required this.refreshHomeTab,
  }) : super(key: key);

  @override
  _OnlineDecksScreenState createState() => _OnlineDecksScreenState();
}

class _OnlineDecksScreenState extends State<OnlineDecksScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final CategoryRepository _categoryRepository = CategoryRepository();
  
  bool _isLoading = true;
  bool _isDownloading = false;
  List<Map<String, dynamic>> _onlineDecks = [];
  String _currentlyDownloadingId = '';
  Set<String> _downloadedDeckIds = {};
  
  @override
  void initState() {
    super.initState();
    _loadOnlineDecks();
  }
  
  Future<void> _loadOnlineDecks() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // First get list of already downloaded deck IDs
      final localDecks = await _categoryRepository.getAllCategories();
      final localDeckIds = localDecks.where((deck) => deck.containsKey('id'))
          .map((deck) => deck['id'] as String)
          .toSet();
      
      // Get categories from Firebase
      final categories = await _firebaseService.getCategories();
      
      // Convert to a list of maps for easier use in the UI
      final decks = categories.map((category) {
        return {
          'id': category.id,
          'name': category.name,
          'icon': category.icon,
          'lastUpdated': category.lastUpdated,
          'isDownloaded': localDeckIds.contains(category.id),
        };
      }).toList();
      
      setState(() {
        _onlineDecks = decks;
        _downloadedDeckIds = localDeckIds;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading online decks: $e');
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading online decks: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
Future<void> _downloadDeck(Map<String, dynamic> deck) async {
  if (_isDownloading) return; // Prevent multiple downloads
  
  setState(() {
    _isDownloading = true;
    _currentlyDownloadingId = deck['id'];
  });
  
  try {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading ${deck['name']}...'))
    );
    
    // Download the deck
    final categoryId = deck['id'];
    final categoryName = deck['name'] as String;
    final success = await _categoryRepository.downloadDeck(categoryId);
    
    if (success) {
      // Update local state
      setState(() {
        _downloadedDeckIds.add(categoryId);
        // Update the downloaded status in the list
        for (var d in _onlineDecks) {
          if (d['id'] == categoryId) {
            d['isDownloaded'] = true;
          }
        }
      });
      
      // Run diagnostics to confirm download
      final dbHelper = DatabaseHelper();
      // Use category name directly instead of getting by ID
      await dbHelper.diagnoseDatabaseIssue(categoryName);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${deck['name']} downloaded successfully!'),
          backgroundColor: Colors.green,
        )
      );
      
      // Refresh home tab to show the new deck - VERY IMPORTANT
      widget.refreshHomeTab();
      
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download ${deck['name']}'),
          backgroundColor: Colors.red,
        )
      );
    }
  } catch (e) {
    print('Error downloading deck: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error downloading deck: ${e.toString()}'),
        backgroundColor: Colors.red,
      )
    );
  } finally {
    setState(() {
      _isDownloading = false;
      _currentlyDownloadingId = '';
    });
  }
}

  
  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Online Decks'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadOnlineDecks,
            tooltip: 'Refresh decks',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _onlineDecks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No online decks available',
                        style: TextStyle(fontSize: 18),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadOnlineDecks,
                        child: Text('Refresh'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadOnlineDecks,
                  child: ListView.builder(
                    itemCount: _onlineDecks.length,
                    itemBuilder: (context, index) {
                      final deck = _onlineDecks[index];
                      final bool isDownloaded = deck['isDownloaded'] ?? false;
                      final bool isCurrentlyDownloading = _isDownloading && _currentlyDownloadingId == deck['id'];
                      
                      return Card(
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: Icon(
                            _categoryRepository.getIconForCategory(deck['icon'] ?? 'category'),
                            color: Colors.blue.shade700,
                            size: 32,
                          ),
                          title: Text(
                            deck['name'] ?? 'Unnamed Deck',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Last updated: ${_formatDate(deck['lastUpdated'] ?? 0)}',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: isDownloaded
                              ? Chip(
                                  label: Text('Downloaded'),
                                  backgroundColor: Colors.green.shade100,
                                  labelStyle: TextStyle(color: Colors.green.shade800),
                                  avatar: Icon(Icons.check_circle, color: Colors.green.shade800, size: 18),
                                )
                              : isCurrentlyDownloading
                                  ? SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : ElevatedButton(
                                      child: Text('Download'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue.shade700,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: _isDownloading ? null : () => _downloadDeck(deck),
                                    ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}