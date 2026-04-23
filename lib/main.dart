import 'package:flutter/material.dart';
import 'package:guess_it/screens/game_screen.dart';
import 'package:guess_it/screens/settings_screen.dart';
import 'package:guess_it/repositories/category_repository.dart';
import 'package:guess_it/services/initialization_service.dart';
import 'package:guess_it/screens/deck_management_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:guess_it/screens/online_decks_screen.dart';
import 'package:guess_it/screens/ai_deck_generator_screen.dart';
import 'package:guess_it/utils/admin_mode_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize our app's services
  final initService = InitializationService();
  await initService.initialize();
  
  // Get shared preferences instance
  await SharedPreferences.getInstance();
  
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final List<String> usedWords = [];

  void resetUsedWords() {
    setState(() {
      usedWords.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guess It',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: MainTabScreen(usedWords: usedWords, resetUsedWords: resetUsedWords),
    );
  }
}

class MainTabScreen extends StatefulWidget {
  final List<String> usedWords;
  final VoidCallback resetUsedWords;
  
  const MainTabScreen({
    Key? key, 
    required this.usedWords, 
    required this.resetUsedWords
  }) : super(key: key);

  @override
  _MainTabScreenState createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;
  int _homeRefreshCount = 0;
  int _storeRefreshCount = 0;
  bool _isAdminMode = false;
  bool _showSearchBars = true;
  final AdminModeManager _adminManager = AdminModeManager();

  @override
  void initState() {
    super.initState();
    _checkAdminMode();
    _loadSearchBarSetting();
  }

  Future<void> _loadSearchBarSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showSearchBars = prefs.getBool('showSearchBars') ?? true;
      });
    }
  }

  void _onSearchBarSettingChanged(bool value) {
    setState(() {
      _showSearchBars = value;
    });
  }
  
  Future<void> _checkAdminMode() async {
    final isAdmin = await _adminManager.isAdminModeEnabled();
    if (mounted) {
      setState(() {
        _isAdminMode = isAdmin;
        // Ensure current index is valid with the new navigation state
        if (!_isAdminMode && _currentIndex == 1) {
          _currentIndex = 0;  // Reset to home if manage decks was selected
        }
      });
    }
  }
  
  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }
  
  void _refreshHomeTab() {
    setState(() {
      _homeRefreshCount++;
    });
  }

  void _refreshStoreTab() {
    setState(() {
      _storeRefreshCount++;
    });
  }
  
  // Listener for admin mode changes
  void _onAdminModeChanged() {
    _checkAdminMode();
  }
  
  @override
  Widget build(BuildContext context) {
    // Define navigation items based on admin mode
    final navItems = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.category),
        label: 'Play',
      ),
    ];
    
    // Add "Manage Decks" only in admin mode
    if (_isAdminMode) {
      navItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.edit),
        label: 'Manage Decks',
      ));
    }
    
    // Add common items for all users
    navItems.addAll([
      const BottomNavigationBarItem(
        icon: Icon(Icons.cloud_download),
        label: 'Store',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.settings),
        label: 'Settings',
      ),
    ]);
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomePage(
            key: ValueKey(_homeRefreshCount),
            title: 'Guess It',
            usedWords: widget.usedWords,
            resetUsedWords: widget.resetUsedWords,
            refreshStoreTab: _refreshStoreTab,
            showSearchBar: _showSearchBars,
          ),
          // Deck Management Screen (only accessible in admin mode)
          DeckManagementScreen(
            navigateToTab: _navigateToTab,
            refreshHomeTab: _refreshHomeTab,
            showSearchBar: _showSearchBars,
          ),
          // AI Deck Generator (hidden from bottom tabs)
          AIDeckGenerator(),
          // Online Decks Screen with refresh callback
          OnlineDecksScreen(
            key: ValueKey(_storeRefreshCount),
            refreshHomeTab: _refreshHomeTab,
            showSearchBar: _showSearchBars,
          ),
          // Settings page
          SettingsScreen(
            usedWords: widget.usedWords,
            resetUsedWords: widget.resetUsedWords,
            onAdminModeChanged: _onAdminModeChanged,
            onSearchBarSettingChanged: _onSearchBarSettingChanged,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _getAdjustedIndex(),
        onTap: (index) {
          final actualIndex = _getActualIndexFromTap(index);
          setState(() {
            _currentIndex = actualIndex;
          });
          
          // Refresh home page when switching to it
          if (actualIndex == 0) {
            _refreshHomeTab();
          }
        },
        items: navItems,
        selectedItemColor: Colors.blue.shade700,
        type: BottomNavigationBarType.fixed, // Ensures all labels are visible
      ),
    );
  }
  
  // Get the adjusted index for the navigation bar
  int _getAdjustedIndex() {
    if (_currentIndex == 0) return 0; // Home tab
    
    if (_isAdminMode) {
      // In admin mode:
      // 0 = Home
      // 1 = Manage Decks
      // 2 = AI Deck Generator (hidden)
      // 3 = Store
      // 4 = Settings
      if (_currentIndex == 1) return 1; // Manage decks
      if (_currentIndex == 3) return 2; // Store
      if (_currentIndex == 4) return 3; // Settings
      return 0; // Default to home for any other case (including hidden AI tab)
    } else {
      // In non-admin mode:
      // 0 = Home
      // 1 = Manage Decks (not accessible)
      // 2 = AI Deck Generator (hidden)
      // 3 = Store
      // 4 = Settings
      if (_currentIndex == 3) return 1; // Store (2nd position without admin tab)
      if (_currentIndex == 4) return 2; // Settings (3rd position without admin tab)
      return 0; // Default to home
    }
  }
  
  // Convert tapped index to actual content index
  int _getActualIndexFromTap(int tappedIndex) {
    if (_isAdminMode) {
      // In admin mode:
      switch (tappedIndex) {
        case 0: return 0; // Home
        case 1: return 1; // Manage Decks
        case 2: return 3; // Store (skip AI generator)
        case 3: return 4; // Settings
        default: return 0;
      }
    } else {
      // In non-admin mode (no Manage Decks tab):
      switch (tappedIndex) {
        case 0: return 0; // Home
        case 1: return 3; // Store (skip Manage Decks & AI generator)
        case 2: return 4; // Settings
        default: return 0;
      }
    }
  }
}

class HomePage extends StatefulWidget {
  final String title;
  final List<String> usedWords;
  final VoidCallback resetUsedWords;
  final VoidCallback? refreshStoreTab;
  final bool showSearchBar;

  const HomePage({
    Key? key,
    required this.title,
    required this.usedWords,
    required this.resetUsedWords,
    this.refreshStoreTab,
    this.showSearchBar = true,
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final CategoryRepository _categoryRepository = CategoryRepository();
  List<Map<String, dynamic>> _decks = [];
  bool _isLoading = true;
  bool _isDragging = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> get _filteredDecks {
    if (_searchQuery.isEmpty) return _decks;
    final query = _searchQuery.toLowerCase();
    return _decks.where((d) {
      if (d['id'] == 'all_categories') return true;
      return (d['name'] as String).toLowerCase().contains(query);
    }).toList();
  }

  static const _orderPrefsKey = 'home_deck_order';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<List<String>> _loadOrder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_orderPrefsKey) ?? [];
  }

  Future<void> _saveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_orderPrefsKey, _decks.map((d) => d['id'] as String).toList());
  }

  Future<void> _loadCategories() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final categories = await _categoryRepository.getAllCategories();
      final savedOrder = await _loadOrder();

      var decks = <Map<String, dynamic>>[
        {'name': 'All Categories', 'icon': Icons.category, 'id': 'all_categories', 'isCustom': false},
        ...categories.map((category) => {
          ...category,
          'isCustom': category.containsKey('isCustom') ? category['isCustom'] : false,
        }),
      ];

      if (savedOrder.isNotEmpty) {
        final orderMap = <String, int>{for (var i = 0; i < savedOrder.length; i++) savedOrder[i]: i};
        decks.sort((a, b) {
          final aIdx = orderMap[a['id'] as String] ?? savedOrder.length;
          final bIdx = orderMap[b['id'] as String] ?? savedOrder.length;
          return aIdx.compareTo(bIdx);
        });
      }

      if (mounted) {
        _searchController.clear();
        setState(() {
          _decks = decks;
          _isLoading = false;
          _searchQuery = '';
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _decks = [{'name': 'All Categories', 'icon': Icons.category, 'id': 'all_categories', 'isCustom': false}];
      });
    }
  }

  void _onItemDrop(int fromIndex, int toIndex) {
    setState(() {
      final item = _decks.removeAt(fromIndex);
      _decks.insert(toIndex, item);
    });
    _saveOrder();
  }

  void _showDeleteDialog(BuildContext context, Map<String, dynamic> deck) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Remove "${deck['name']}" from your device?\n\nIt can be re-downloaded from the deck store.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final deleted = await _categoryRepository.deleteLocalOnly(deck['id'] as String);
              if (deleted && mounted) {
                widget.refreshStoreTab?.call();
                _loadCategories();
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    // When searching, show a plain non-draggable grid of filtered results
    if (_searchQuery.isNotEmpty) {
      final decks = _filteredDecks;
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: decks.length,
        itemBuilder: (context, index) {
          final deck = decks[index];
          return SimpleDeckCard(
            name: deck['name'],
            icon: deck['icon'],
            usedWords: widget.usedWords,
            isCustomDeck: deck['isCustom'] ?? false,
          );
        },
      );
    }

    // Normal view: draggable Wrap using full _decks list
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 48) / 2;
        final itemHeight = itemWidth / 1.5;

        return RefreshIndicator(
          onRefresh: _loadCategories,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: List.generate(_decks.length, (index) {
                final deck = _decks[index];
                return SizedBox(
                  width: itemWidth,
                  height: itemHeight,
                  child: DragTarget<int>(
                    onWillAccept: (data) => data != null && data != index,
                    onAccept: (fromIndex) => _onItemDrop(fromIndex, index),
                    builder: (ctx, candidateData, _) {
                      final isHovered = candidateData.isNotEmpty;
                      return LongPressDraggable<int>(
                        data: index,
                        onDragStarted: () => setState(() => _isDragging = true),
                        onDragEnd: (_) => setState(() => _isDragging = false),
                        feedback: Material(
                          borderRadius: BorderRadius.circular(12),
                          elevation: 8,
                          child: SizedBox(
                            width: itemWidth,
                            height: itemHeight,
                            child: SimpleDeckCard(
                              name: deck['name'],
                              icon: deck['icon'],
                              usedWords: widget.usedWords,
                              isCustomDeck: deck['isCustom'] ?? false,
                            ),
                          ),
                        ),
                        childWhenDragging: SizedBox(
                          width: itemWidth,
                          height: itemHeight,
                          child: Opacity(
                            opacity: 0.3,
                            child: SimpleDeckCard(
                              name: deck['name'],
                              icon: deck['icon'],
                              usedWords: widget.usedWords,
                              isCustomDeck: deck['isCustom'] ?? false,
                            ),
                          ),
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: isHovered
                                ? Border.all(color: Colors.blue.shade400, width: 2)
                                : null,
                          ),
                          child: SimpleDeckCard(
                            name: deck['name'],
                            icon: deck['icon'],
                            usedWords: widget.usedWords,
                            isCustomDeck: deck['isCustom'] ?? false,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrashZone(BuildContext context) {
    return ClipRect(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        height: _isDragging ? 96 : 0,
        child: DragTarget<int>(
          onWillAccept: (index) => index != null && _decks[index]['id'] != 'all_categories',
          onAccept: (index) => _showDeleteDialog(context, _decks[index]),
          builder: (ctx, candidateData, _) {
            final isHovered = candidateData.isNotEmpty;
            return Container(
              height: 80,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: isHovered
                    ? Colors.red.shade100.withOpacity(0.9)
                    : Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isHovered ? Colors.red.shade400 : Colors.white.withOpacity(0.6),
                  width: 2,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isHovered ? Icons.delete : Icons.delete_outline,
                      color: isHovered ? Colors.red.shade700 : Colors.white.withOpacity(0.85),
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Drop here to remove',
                      style: TextStyle(
                        color: isHovered ? Colors.red.shade700 : Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade300, Colors.blue.shade100],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (widget.showSearchBar)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search decks...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.9),
                        ),
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                    ),
                  Expanded(
                    child: (_searchQuery.isNotEmpty && _filteredDecks.length == 1)
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'No decks match your search',
                                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : _buildGrid(),
                  ),
                  _buildTrashZone(context),
                ],
              ),
      ),
    );
  }
}

class SimpleDeckCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final List<String> usedWords;
  final bool isCustomDeck;
  final VoidCallback? onLongPress;

  const SimpleDeckCard({
    Key? key,
    required this.name,
    required this.icon,
    required this.usedWords,
    this.isCustomDeck = false,
    this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCustomDeck ? Colors.purple.shade300 : Colors.transparent,
          width: isCustomDeck ? 2 : 0,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GameScreen(deckName: name, usedWords: usedWords),
            ),
          );
        },
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: isCustomDeck ? Colors.purple.shade700 : Colors.blue.shade700),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isCustomDeck ? Colors.purple.shade700 : Colors.blue.shade700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isCustomDeck)
                Flexible(
                  child: Text(
                    '(Custom)',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.purple.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

