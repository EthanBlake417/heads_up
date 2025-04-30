import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter_sensors/flutter_sensors.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:heads_up/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:heads_up/repositories/category_repository.dart';
import 'package:heads_up/results_screen.dart';
import 'package:vibration/vibration.dart';

class GameScreen extends StatefulWidget {
  final String deckName;
  final List<String> usedWords;

  const GameScreen({Key? key, required this.deckName, required this.usedWords}) : super(key: key);

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final CategoryRepository _categoryRepository = CategoryRepository();
  late List<String> words;
  late List<bool> usedWords;
  late String currentWord;
  int score = 0;
  late Timer timer;
  int remainingTime = 60; // Default game time
  bool isGameStarted = false;
  bool _isLoading = true;

  StreamSubscription? _accelerometerSubscription;

  List<Color> _backgroundColors = [Colors.blue.shade700, Colors.blue.shade300];
  String _displayText = '';
  bool _isTriggered = false;

  List<String> correctWords = [];
  List<String> passedWords = [];

  double _dragStartX = 0.0;

  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlacingOnForehead = true;
  bool _isCountingDown = false;

  bool _soundEnabled = true;
  int _gameDuration = 60;

  bool _isActionCooldown = false;
  final _cooldownDuration = const Duration(milliseconds: 350); // cooldown

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _loadSettings();
    _loadWords();
    _displayText = 'Loading...';
  }

  void _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _soundEnabled = prefs.getBool('soundEnabled') ?? true;
        _gameDuration = prefs.getInt('gameDuration') ?? 60;
        remainingTime = _gameDuration;
      });
    } catch (e) {
      print('Error loading settings: $e');
      // Use default values if loading fails
    }
  }

  // Fix for updated_game_screen.dart
// Add this method to properly handle loading words from the repository and ensure it works with custom icons

Future<void> _loadWords() async {
  try {
    setState(() {
      _isLoading = true;
      _displayText = 'Loading...';
    });
    
    // Get words for the selected deck with debugging
    print('Loading words for deck: ${widget.deckName}');
    final wordsList = await _categoryRepository.getWordsForCategory(widget.deckName);
    print('Word list loaded, found ${wordsList.length} words');
    
    if (mounted) {
      // Log the found words for debugging
      if (wordsList.isEmpty) {
        print('No words found for ${widget.deckName}');
      } else {
        print('First few words: ${wordsList.take(5).join(", ")}');
      }
      
      // Check if we have words
      if (wordsList.isEmpty) {
        // Try getting the words directly from the database
        final categoryModel = await _categoryRepository.getCategoryByName(widget.deckName);
        print('Direct category lookup: ${categoryModel?.id ?? "Not found"}');
        
        if (categoryModel != null) {
          // Try direct DB query as a fallback
          final dbHelper = DatabaseHelper();
          final directWords = await dbHelper.getWordsByCategory(categoryModel.id);
          print('Direct DB query found ${directWords.length} words');
          
          if (directWords.isNotEmpty) {
            final directWordsList = directWords.map((w) => w.word).toList();
            
            // Filter out used words
            directWordsList.removeWhere((word) => widget.usedWords.contains(word));
            
            setState(() {
              words = directWordsList;
              usedWords = List.filled(words.length, false);
              _isLoading = false;
              
              if (words.isEmpty) {
                _displayText = 'All words have been played!';
              } else {
                currentWord = getNextWord();
                _displayText = 'Place on Forehead';
                _startListeningToAccelerometer();
              }
            });
            return;
          }
        }
        
        // No words found by any method
        setState(() {
          _isLoading = false;
          words = [];
          _displayText = 'No words available for this deck!';
        });
        return;
      }
      
      // Filter out words that have already been used
      wordsList.removeWhere((word) => widget.usedWords.contains(word));
      
      setState(() {
        words = wordsList;
        usedWords = List.filled(words.length, false);
        _isLoading = false;
        
        if (words.isEmpty) {
          _displayText = 'All words have been played!';
        } else {
          currentWord = getNextWord();
          _displayText = 'Place on Forehead';
          _startListeningToAccelerometer();
        }
      });
    }
  } catch (e) {
    print('Error loading words: $e');
    if (mounted) {
      setState(() {
        _isLoading = false;
        _displayText = 'Error loading words';
      });
    }
  }
}

  void startCountdown() {
    int count = 3;
    Timer.periodic(const Duration(seconds: 1), (timer) {
      _processCountdown(count, timer);
      count--;
    });
  }

  Future<void> _processCountdown(int count, Timer timer) async {
    if (count > 0) {
      setState(() {
        _backgroundColors = [Colors.blue.shade700, Colors.blue.shade300];
        _displayText = count.toString();
      });

      _playSound('countdown.mp3');

      await Future.delayed(Duration(milliseconds: 150));
      Vibration.vibrate(duration: 100);
    } else if (count == 0) {
      setState(() {
        _displayText = 'GO!';
      });

      _playSound('countdown.mp3');

      await Future.delayed(Duration(milliseconds: 100));
      Vibration.vibrate(duration: 100);
    } else {
      timer.cancel();
      setState(() {
        isGameStarted = true;
        _isCountingDown = false;
        _displayText = currentWord;
      });
      startTimer();
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    if (isGameStarted) {
      timer.cancel();
    }
    _accelerometerSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  String getNextWord() {
    if (words.isEmpty || usedWords.every((used) => used)) {
      return 'No More Words in this Deck';
    }
    
    final random = Random();
    int index;
    do {
      index = random.nextInt(words.length);
    } while (usedWords[index]);
    
    usedWords[index] = true;
    return words[index];
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (remainingTime > 0) {
          remainingTime--;
          if (remainingTime <= 10) {
            Vibration.vibrate(duration: (15 + (10 - remainingTime) * 10));
          }
        } else {
          endGame();
        }
      });
    });
  }

  void _startListeningToAccelerometer() async {
    final stream = await SensorManager().sensorUpdates(
      sensorId: Sensors.ACCELEROMETER,
      interval: Sensors.SENSOR_DELAY_GAME,
    );
    _accelerometerSubscription = stream.listen((SensorEvent event) {
      if (_isPlacingOnForehead) {
        if (event.data[2].abs() < 3) {
          // Phone is roughly horizontal
          setState(() {
            _isPlacingOnForehead = false;
            _backgroundColors = [
              Colors.purple.shade700,
              Colors.purple.shade300
            ];
          });
          Future.delayed(Duration(milliseconds: 0), () {
            setState(() {
              _isCountingDown = true;
            });
            startCountdown();
          });
        }
      } else if (isGameStarted && !_isActionCooldown) {
        if (event.data[2].abs() > 9 && !_isTriggered) {
          if (event.data[2] > 0) {
            onPass();
          } else {
            onCorrect();
          }
          _isTriggered = true;
          _startActionCooldown();
        } else if (event.data[2].abs() < 5 && _isTriggered) {
          _resetToNeutral();
        }
      }
    });
  }

  void _startActionCooldown() {
    setState(() {
      _isActionCooldown = true;
    });
    Future.delayed(_cooldownDuration, () {
      setState(() {
        _isActionCooldown = false;
      });
    });
  }

  void onCorrect() {
    if (_isActionCooldown) return;
    Vibration.vibrate(duration: 350);
    _playSound('correct.mp3');
    setState(() {
      score++;
      correctWords.add(currentWord);
      _backgroundColors = [Colors.green.shade700, Colors.green.shade300];
      _displayText = 'CORRECT!';
    });
    _startActionCooldown();
  }

  void onPass() {
    if (_isActionCooldown) return;
    Vibration.vibrate(duration: 175);
    if (mounted) {
      setState(() {
        passedWords.add(currentWord);
        _backgroundColors = [Colors.orange.shade700, Colors.orange.shade300];
        _displayText = 'PASS';
      });
    }
    _startActionCooldown();
  }

  void _resetToNeutral() {
    if (_isActionCooldown) return;
    setState(() {
      _isTriggered = false;
      _backgroundColors = [Colors.blue.shade700, Colors.blue.shade300];
      currentWord = getNextWord();
      _displayText = currentWord;
    });
  }

  void endGame() {
    timer.cancel();
    _playSound('times_up.mp3');
    setState(() {
      _displayText = "Time's Up!";
      _backgroundColors = [Colors.red.shade700, Colors.red.shade300];
    });
    Vibration.vibrate(duration: 1000);

    widget.usedWords.addAll(correctWords);
    widget.usedWords.addAll(passedWords);

    Future.delayed(const Duration(seconds: 1), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultsScreen(
            score: score,
            deckName: widget.deckName,
            correctWords: correctWords,
            passedWords: passedWords,
            usedWords: widget.usedWords,
          ),
        ),
      );
    });
  }

  Future<void> _playSound(String soundFile) async {
    if (_soundEnabled) {
      try {
        await _audioPlayer.play(AssetSource(soundFile));
      } catch (e) {
        print('Error playing sound: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: (details) {
        if (isGameStarted) _dragStartX = details.globalPosition.dx;
      },
      onHorizontalDragEnd: (details) {
        if (isGameStarted) {
          double dragDistance = (details.globalPosition.dx - _dragStartX).abs();
          double screenWidth = MediaQuery.of(context).size.width;

          if (dragDistance > screenWidth * 0.3) {
            endGame();
          }
        }
      },
      child: Scaffold(
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _isLoading
                  ? [Colors.grey.shade700, Colors.grey.shade300]
                  : _isPlacingOnForehead
                      ? [Colors.purple.shade700, Colors.purple.shade300]
                      : _backgroundColors,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: _isLoading
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Loading words...',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isGameStarted)
                          Text(
                            'Time: $remainingTime',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        const SizedBox(height: 40),
                        if (words.isEmpty)
                          Text(
                            'No words available for this deck!',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          )
                        else if (_isPlacingOnForehead || _isCountingDown || isGameStarted)
                          Text(
                            _displayText,
                            style: const TextStyle(
                              fontSize: 100,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}