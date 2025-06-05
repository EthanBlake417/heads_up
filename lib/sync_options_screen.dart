// sync_options_screen.dart
import 'package:flutter/material.dart';
import 'package:guess_it/repositories/category_repository.dart';

class SyncOptionsScreen extends StatefulWidget {
  @override
  _SyncOptionsScreenState createState() => _SyncOptionsScreenState();
}

class _SyncOptionsScreenState extends State<SyncOptionsScreen> {
  final CategoryRepository _categoryRepository = CategoryRepository();
  bool _isLoading = true;
  bool _isSyncing = false;
  Map<String, bool> _selectedDecks = {};
  bool _isHardSync = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final categories = await _categoryRepository.getAllCategories();
      
      setState(() {
        // Initialize all categories as selected
        _selectedDecks = {
          for (var category in categories) category['name'] as String: true
        };
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading categories: $e');
      setState(() {
        _isLoading = false;
        _selectedDecks = {};
      });
    }
  }

  Future<void> _syncSelectedDecks() async {
    if (_selectedDecks.isEmpty || !_selectedDecks.containsValue(true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select at least one deck to sync'))
      );
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      // Get the list of selected deck names
      final selectedDeckNames = _selectedDecks.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();
      
      final success = await _categoryRepository.syncSelectedDecks(
        selectedDeckNames, 
        _isHardSync
      );
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed. Check your internet connection.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error during sync: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during sync: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sync Options'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Synchronization Options',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Select decks to synchronize with Firebase:',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      SwitchListTile(
                        title: Text('Hard Synchronization'),
                        subtitle: Text(
                          'Replace local decks completely with server versions. Any local changes will be lost.'
                        ),
                        value: _isHardSync,
                        onChanged: (value) {
                          setState(() {
                            _isHardSync = value;
                          });
                        },
                      ),
                      Divider(),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _selectedDecks.length,
                    itemBuilder: (context, index) {
                      final entry = _selectedDecks.entries.elementAt(index);
                      final deckName = entry.key;
                      final isSelected = entry.value;
                      
                      return CheckboxListTile(
                        title: Text(deckName),
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            _selectedDecks[deckName] = value ?? false;
                          });
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          final allSelected = _selectedDecks.values.every((v) => v);
                          setState(() {
                            _selectedDecks.forEach((key, value) {
                              _selectedDecks[key] = !allSelected;
                            });
                          });
                        },
                        child: Text(
                          _selectedDecks.values.every((v) => v)
                              ? 'Deselect All'
                              : 'Select All',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '${_selectedDecks.values.where((v) => v).length} of ${_selectedDecks.length} selected',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    onPressed: _isSyncing ? null : _syncSelectedDecks,
                    child: _isSyncing
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Synchronize Selected Decks',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}