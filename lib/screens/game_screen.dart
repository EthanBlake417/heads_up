import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter_sensors/flutter_sensors.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:guess_it/repositories/category_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'results_screen.dart';
import 'package:guess_it/utils/game_constants.dart';

enum DevicePositionState {
  NEUTRAL,
  CORRECT_POSITION,
  PASS_POSITION,
  ACTION_TRIGGERED
}

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
  int remainingTime = GameConstants.defaultGameDuration;
  bool isGameStarted = false;
  bool _isLoading = true;

  StreamSubscription? _accelerometerSubscription;

  List<Color> _backgroundColors = [Colors.blue.shade700, Colors.blue.shade300];
  String _displayText = '';
  
  // Device position state tracking
  DevicePositionState _deviceState = DevicePositionState.NEUTRAL;
  DateTime? _stateEnteredTime;
  
  DateTime? _lastWordChangeTime;

  final Set<String> correctWords = {};
  final Set<String> passedWords = {};

  double _dragStartX = 0.0;

  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlacingOnForehead = true;
  bool _isCountingDown = false;

  bool _soundEnabled = true;
  int _gameDuration = GameConstants.defaultGameDuration;

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
        _gameDuration = prefs.getInt('gameDuration') ?? GameConstants.defaultGameDuration;
        remainingTime = _gameDuration;
      });
    } catch (e) {
      // Use default values if loading fails
    }
  }

  Future<void> _loadWords() async {
    try {
      setState(() {
        _isLoading = true;
        _displayText = 'Loading...';
      });
      
      final wordsList = await _categoryRepository.getWordsForCategory(widget.deckName);
      
      if (mounted) {
        // Filter out words that have already been used
        final usedWordsSet = widget.usedWords.toSet();
        final filteredWords = wordsList.where((word) => !usedWordsSet.contains(word)).toList();
        
        setState(() {
          words = filteredWords;
          usedWords = List.filled(words.length, false);
          _isLoading = false;
          currentWord = getNextWord();
          _displayText = 'Place on Forehead';
          _startListeningToAccelerometer();
        });
      }
    } catch (e) {
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
    setState(() {
      _isCountingDown = true;
    });
    
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
        _deviceState = DevicePositionState.NEUTRAL;
        _lastWordChangeTime = DateTime.now();
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
      final double zAccel = event.data[2]; // Z-axis acceleration
      
      if (_isPlacingOnForehead) {
        // Logic for detecting when phone is placed on forehead
        if (zAccel.abs() < 3) {
          // Phone is roughly horizontal
          setState(() {
            _isPlacingOnForehead = false;
            _backgroundColors = [
              Colors.purple.shade700,
              Colors.purple.shade300
            ];
          });
          
          Future.delayed(Duration.zero, () {
            startCountdown();
          });
        }
        return; // Exit early if we're still in placement phase
      } 
      
      if (_isCountingDown || !isGameStarted) {
        return; // Exit if countdown is active or game hasn't started
      }
      
      // Check if we're in the lock period after word change
      if (_lastWordChangeTime != null && 
          DateTime.now().difference(_lastWordChangeTime!) < GameConstants.wordChangeDelay) {
        return;
      }
      
      // Main game accelerometer logic with improved state management
      _processAccelerometerReading(zAccel);
    });
  }

  void _processAccelerometerReading(double zAccel) {
    // Determine the new state based on accelerometer readings and current state
    DevicePositionState newState = _deviceState;
    
    switch (_deviceState) {
      case DevicePositionState.NEUTRAL:
        // From neutral, can go to either CORRECT or PASS position
        if (zAccel <= GameConstants.correctTriggerThreshold) {
          newState = DevicePositionState.CORRECT_POSITION;
          _stateEnteredTime = DateTime.now();
        } else if (zAccel >= GameConstants.passTriggerThreshold) {
          newState = DevicePositionState.PASS_POSITION;
          _stateEnteredTime = DateTime.now();
        }
        break;
        
      case DevicePositionState.CORRECT_POSITION:
        // Check if we should trigger the action (maintained position for required time)
        if (zAccel > GameConstants.correctResetThreshold) {
          // No longer in correct position, reset to neutral without action
          newState = DevicePositionState.NEUTRAL;
        } else if (_stateEnteredTime != null && 
                  DateTime.now().difference(_stateEnteredTime!) >= GameConstants.positionConfirmTime) {
          // Position held long enough, trigger the action
          onCorrect();
          newState = DevicePositionState.ACTION_TRIGGERED;
        }
        break;
        
      case DevicePositionState.PASS_POSITION:
        // Check if we should trigger the action (maintained position for required time)
        if (zAccel < GameConstants.passResetThreshold) {
          // No longer in pass position, reset to neutral without action
          newState = DevicePositionState.NEUTRAL;
        } else if (_stateEnteredTime != null && 
                  DateTime.now().difference(_stateEnteredTime!) >= GameConstants.positionConfirmTime) {
          // Position held long enough, trigger the action
          onPass();
          newState = DevicePositionState.ACTION_TRIGGERED;
        }
        break;
        
      case DevicePositionState.ACTION_TRIGGERED:
        // After action is triggered, wait for return to neutral position
        if (zAccel.abs() < GameConstants.neutralThreshold) {
          moveToNextWord();
          newState = DevicePositionState.NEUTRAL;
        }
        break;
    }
    
    // Only update the state if it changed
    if (newState != _deviceState) {
      setState(() {
        _deviceState = newState;
      });
    }
  }

  void onCorrect() {
    if (correctWords.contains(currentWord) || passedWords.contains(currentWord)) return;
    Vibration.vibrate(duration: 350);
    _playSound('correct.mp3');
    setState(() {
      score++;
      correctWords.add(currentWord);
      _backgroundColors = [Colors.green.shade700, Colors.green.shade300];
      _displayText = 'CORRECT!';
    });
  }

  void onPass() {
    if (correctWords.contains(currentWord) || passedWords.contains(currentWord)) return;
    Vibration.vibrate(duration: 350);
    if (mounted) {
      setState(() {
        passedWords.add(currentWord);
        _backgroundColors = [Colors.orange.shade700, Colors.orange.shade300];
        _displayText = 'PASS';
      });
    }
  }

  void moveToNextWord() {
    setState(() {
      _backgroundColors = [Colors.blue.shade700, Colors.blue.shade300];
      currentWord = getNextWord();
      _displayText = currentWord;
      _lastWordChangeTime = DateTime.now();
    });
  }

  void endGame() {
    timer.cancel();
    _playSound('times_up.mp3');

    // Capture the word that was on screen when time ran out, if it was never resolved
    final String? skippedWord = (
      currentWord != 'No More Words in this Deck' &&
      !correctWords.contains(currentWord) &&
      !passedWords.contains(currentWord)
    ) ? currentWord : null;

    setState(() {
      _displayText = "Time's Up!";
      _backgroundColors = [Colors.red.shade700, Colors.red.shade300];
    });
    Vibration.vibrate(duration: 1500);

    if (skippedWord != null) passedWords.add(skippedWord);

    widget.usedWords.addAll(correctWords);
    widget.usedWords.addAll(passedWords);

    Future.delayed(const Duration(seconds: 1), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultsScreen(
            score: score,
            deckName: widget.deckName,
            correctWords: correctWords.toList(),
            passedWords: passedWords.toList(),
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
                      if (isGameStarted)
                        const SizedBox(height: 8),
                      if (_isPlacingOnForehead || _isCountingDown || isGameStarted)
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                            child: AutoSizeText(
                              _displayText,
                              style: const TextStyle(
                                fontSize: 100,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              minFontSize: 12,
                            ),
                          ),
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