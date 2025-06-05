// lib/online_decks_screen.dart
import 'package:flutter/material.dart';
import 'package:guess_it/database_helper.dart';
import 'package:guess_it/repositories/category_repository.dart';
import 'package:guess_it/services/firebase_service.dart';
import 'package:guess_it/utils/icon_mapping.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  
  bool _isLoading = true;
  bool _isDownloading = false;
  bool _isDeleting = false;
  List<Map<String, dynamic>> _onlineDecks = [];
  String _currentlyProcessingId = '';
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
        final iconData = IconMapping.getIconFromKey(category.icon);
        
        return {
          'id': category.id,
          'name': category.name,
          'icon': iconData,
          'iconKey': category.icon,
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
    if (_isDownloading || _isDeleting) return; // Prevent multiple operations
    
    setState(() {
      _isDownloading = true;
      _currentlyProcessingId = deck['id'];
    });
    
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloading ${deck['name']}...'))
      );
      
      // Download the deck
      final categoryId = deck['id'];
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
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${deck['name']} downloaded successfully!'),
            backgroundColor: Colors.green,
          )
        );
        
        // Refresh home tab to show the new deck
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
        _currentlyProcessingId = '';
      });
    }
  }

  Future<void> _deleteLocalDeck(Map<String, dynamic> deck) async {
    if (_isDownloading || _isDeleting) return; // Prevent multiple operations
    
    // Confirm deletion
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Deck Locally'),
        content: Text('Are you sure you want to delete "${deck['name']}" from your device? You can download it again later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete'),
          ),
        ],
      ),
    );
    
    if (shouldDelete != true) return;
    
    setState(() {
      _isDeleting = true;
      _currentlyProcessingId = deck['id'];
    });
    
    try {
      // Delete the deck LOCALLY ONLY - even in admin mode
      final categoryId = deck['id'];
      
      // Use DatabaseHelper directly to ensure we only delete locally
      await _databaseHelper.clearWordsForCategory(categoryId);
      await _databaseHelper.deleteCategory(categoryId);
      
      // Update local state
      setState(() {
        _downloadedDeckIds.remove(categoryId);
        // Update the downloaded status in the list
        for (var d in _onlineDecks) {
          if (d['id'] == categoryId) {
            d['isDownloaded'] = false;
          }
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${deck['name']} removed from your device'),
          backgroundColor: Colors.blue,
        )
      );
      
      // Refresh home tab to update the list
      widget.refreshHomeTab();
      
    } catch (e) {
      print('Error deleting local deck: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting deck from device: ${e.toString()}'),
          backgroundColor: Colors.red,
        )
      );
    } finally {
      setState(() {
        _isDeleting = false;
        _currentlyProcessingId = '';
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
        title: Text('Deck Store'),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade200, Colors.blue.shade100],
          ),
        ),
        child: _isLoading
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
                        final bool isCurrentlyProcessing = 
                            (_isDownloading || _isDeleting) && _currentlyProcessingId == deck['id'];
                        final IconData iconData = deck['icon'];
                        
                        return Card(
                          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ListTile(
                              leading: IconMapping.isFontAwesomeIcon(iconData)
                                  ? FaIcon(iconData, color: Colors.blue.shade700, size: 32)
                                  : Icon(iconData, color: Colors.blue.shade700, size: 32),
                              title: Text(
                                deck['name'] ?? 'Unnamed Deck',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 4),
                                  Text(
                                    'Last updated: ${_formatDate(deck['lastUpdated'] ?? 0)}',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  if (isDownloaded)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        'Status: Downloaded to your device',
                                        style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: isCurrentlyProcessing
                                  ? SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : isDownloaded
                                      ? ElevatedButton.icon(
                                          icon: Icon(Icons.delete_outline),
                                          label: Text('Remove'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () => _deleteLocalDeck(deck),
                                        )
                                      : ElevatedButton.icon(
                                          icon: Icon(Icons.download),
                                          label: Text('Download'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue.shade700,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: _isDownloading || _isDeleting ? null : () => _downloadDeck(deck),
                                        ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}