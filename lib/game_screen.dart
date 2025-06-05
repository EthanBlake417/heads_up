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

// Define the device position states
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
  int remainingTime = 60; // Default game time
  bool isGameStarted = false;
  bool _isLoading = true;

  StreamSubscription? _accelerometerSubscription;

  List<Color> _backgroundColors = [Colors.blue.shade700, Colors.blue.shade300];
  String _displayText = '';
  
  // Device position state tracking
  DevicePositionState _deviceState = DevicePositionState.NEUTRAL;
  DateTime? _stateEnteredTime;
  
  // Thresholds with hysteresis
  final double _correctTriggerThreshold = -9.0;     // Tilt down (negative Z)
  final double _correctResetThreshold = -5.0;      // Less strict for resetting
  final double _passTriggerThreshold = 9.0;        // Tilt up (positive Z)
  final double _passResetThreshold = 5.0;          // Less strict for resetting
  final double _neutralThreshold = 4.0;            // Consider neutral when abs(z) < this value
  
  // Timing controls
  final Duration _positionConfirmTime = Duration(milliseconds: 150);  // Time required in position to trigger
  final Duration _wordChangeDelay = Duration(milliseconds: 250);      // Lock period after word change
  DateTime? _lastWordChangeTime;

  List<String> correctWords = [];
  List<String> passedWords = [];

  double _dragStartX = 0.0;

  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlacingOnForehead = true;
  bool _isCountingDown = false;

  bool _soundEnabled = true;
  int _gameDuration = 60;

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

  Future<void> _loadWords() async {
    try {
      setState(() {
        _isLoading = true;
        _displayText = 'Loading...';
      });
      
      print('Loading words for deck: ${widget.deckName}');
      final wordsList = await _categoryRepository.getWordsForCategory(widget.deckName);
      print('Word list loaded, found ${wordsList.length} words');
      
      if (mounted) {
        // Filter out words that have already been used
        final filteredWords = wordsList.where((word) => !widget.usedWords.contains(word)).toList();
        print('After filtering used words: ${filteredWords.length} words remaining');
        
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
          if (remainingTime <= 10) {
            // Vibration.vibrate(duration: (15 + (10 - remainingTime) * 10));
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
          DateTime.now().difference(_lastWordChangeTime!) < _wordChangeDelay) {
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
        if (zAccel <= _correctTriggerThreshold) {
          newState = DevicePositionState.CORRECT_POSITION;
          _stateEnteredTime = DateTime.now();
        } else if (zAccel >= _passTriggerThreshold) {
          newState = DevicePositionState.PASS_POSITION;
          _stateEnteredTime = DateTime.now();
        }
        break;
        
      case DevicePositionState.CORRECT_POSITION:
        // Check if we should trigger the action (maintained position for required time)
        if (zAccel > _correctResetThreshold) {
          // No longer in correct position, reset to neutral without action
          newState = DevicePositionState.NEUTRAL;
        } else if (_stateEnteredTime != null && 
                  DateTime.now().difference(_stateEnteredTime!) >= _positionConfirmTime) {
          // Position held long enough, trigger the action
          onCorrect();
          newState = DevicePositionState.ACTION_TRIGGERED;
        }
        break;
        
      case DevicePositionState.PASS_POSITION:
        // Check if we should trigger the action (maintained position for required time)
        if (zAccel < _passResetThreshold) {
          // No longer in pass position, reset to neutral without action
          newState = DevicePositionState.NEUTRAL;
        } else if (_stateEnteredTime != null && 
                  DateTime.now().difference(_stateEnteredTime!) >= _positionConfirmTime) {
          // Position held long enough, trigger the action
          onPass();
          newState = DevicePositionState.ACTION_TRIGGERED;
        }
        break;
        
      case DevicePositionState.ACTION_TRIGGERED:
        // After action is triggered, wait for return to neutral position
        if (zAccel.abs() < _neutralThreshold) {
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
    setState(() {
      _displayText = "Time's Up!";
      _backgroundColors = [Colors.red.shade700, Colors.red.shade300];
    });
    Vibration.vibrate(duration: 1500);

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
                        if (_isPlacingOnForehead || _isCountingDown || isGameStarted)
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