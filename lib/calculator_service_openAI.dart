// calculator_service_openAI.dart - AI-powered with OpenAI integration
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class CalculatorService {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  static const String _openAiEndpoint = 'https://api.openai.com/v1/chat/completions';

  // State variables
  String _lastWords = '';
  String _result = '';
  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isTtsSpeaking = false;
  double _soundLevel = 0.0;
  bool _soundDetected = false;
  bool _waitingForNewInput = false;
  bool _isProcessing = false;

  // Stream controllers
  final StreamController<CalculatorState> _stateController = StreamController<CalculatorState>.broadcast();
  final StreamController<double> _soundLevelController = StreamController<double>.broadcast();

  // Getters for streams
  Stream<CalculatorState> get stateStream => _stateController.stream;
  Stream<double> get soundLevelStream => _soundLevelController.stream;

  // Getters for current state
  bool get isListening => _isListening;
  bool get isSpeaking => _isTtsSpeaking;
  bool get speechEnabled => _speechEnabled;
  String get lastWords => _lastWords;
  String get result => _result;
  double get soundLevel => _soundLevel;
  bool get soundDetected => _soundDetected;
  bool get isProcessing => _isProcessing;

  Future<void> initialize() async {
    await _initSpeech();
    await _initTts();
    _updateState();
  }

  Future<void> _initSpeech() async {
    var status = await Permission.microphone.status;

    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        _speechEnabled = false;
        return;
      }
    }

    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (errorNotification) {
          _isListening = false;
          _soundLevel = 0.0;
          _soundDetected = false;

          _lastWords = 'Error: ${errorNotification.errorMsg}';
          _updateState();

          Future.delayed(Duration(seconds: 2), () {
            if (!_isListening && !_isTtsSpeaking && !_isProcessing) {
              _lastWords = 'Touch screen to start listening';
              _updateState();
            }
          });
        },
        onStatus: (status) {
          print('Speech recognition status: $status');
          if (status == 'notListening' && _isListening) {
            _isListening = false;
            _soundLevel = 0.0;
            _soundDetected = false;
            _updateState();
          }
        },
      );
    } catch (e) {
      print('Speech initialization error: $e');
      _speechEnabled = false;
    }
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.7);
    await _flutterTts.setVolume(0.8);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      _isTtsSpeaking = false;
      _updateState();

      if (_waitingForNewInput) {
        _waitingForNewInput = false;
        Future.delayed(Duration(milliseconds: 2000), () {
          _prepareForNewInput();
        });
      }
    });

    _flutterTts.setStartHandler(() {
      _isTtsSpeaking = true;
      _updateState();
    });
  }

  void _prepareForNewInput() {
    _lastWords = 'Touch screen to start listening';
    _result = '';
    _updateState();
  }

  Future<void> startListening() async {
    if (!_speechEnabled) {
      await _initSpeech();
      if (!_speechEnabled) {
        _lastWords = 'Microphone permission required';
        _updateState();
        return;
      }
    }

    if (_isTtsSpeaking) {
      await _flutterTts.stop();
      await Future.delayed(Duration(milliseconds: 500));
    }

    try {
      _soundLevel = 0.0;
      _soundDetected = false;
      _lastWords = 'Listening...';
      _result = '';
      _isListening = true;
      _isProcessing = false;
      _updateState();

      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenFor: Duration(minutes: 2),
        pauseFor: Duration(seconds: 5),
        partialResults: true,
        onSoundLevelChange: (level) {
          _soundLevel = level;
          _soundDetected = level > 0.15;
          _soundLevelController.add(level);
          _updateState();
        },
        cancelOnError: false,
        listenMode: ListenMode.confirmation,
        localeId: "en_US",
      );

      if (!_speechToText.isListening) {
        _isListening = false;
        _lastWords = 'Failed to start listening. Touch to try again.';
        _updateState();
      }
    } catch (e) {
      print('Error starting listening: $e');
      _isListening = false;
      _lastWords = 'Touch screen to start listening';
      _updateState();
    }
  }

  Future<void> stopListening() async {
    if (_isListening && _speechToText.isListening) {
      await _speechToText.stop();
      await Future.delayed(Duration(milliseconds: 300));
    }

    _isListening = false;
    _soundLevel = 0.0;
    _soundDetected = false;

    if (!_isTtsSpeaking && _result.isEmpty && !_isProcessing) {
      _lastWords = 'Touch screen to start listening';
    }

    _updateState();
  }

  void _onSpeechResult(result) {
    String words = result.recognizedWords ?? '';
    bool isFinal = result.finalResult;

    if (words.isNotEmpty) {
      _lastWords = words;
      _updateState();
    }

    if (isFinal) {
      _isListening = false;
      _soundLevel = 0.0;
      _soundDetected = false;
      _updateState();

      if (words.isNotEmpty) {
        _calculateResultWithAI(words);
      } else {
        _lastWords = 'No speech detected. Touch screen to try again.';
        _updateState();
      }
    }
  }

  Future<void> _calculateResultWithAI(String expression) async {
    _isProcessing = true;
    _lastWords = 'Processing with AI...';
    _updateState();

    try {
      // Convert natural language to mathematical expression using OpenAI
      String mathExpression = await _convertToMathWithAI(expression);

      if (mathExpression.isNotEmpty && mathExpression != 'ERROR') {
        // Evaluate the mathematical expression
        double result = await _evaluateWithAI(mathExpression);
        _result = _formatResult(result);
        _isProcessing = false;
        _updateState();

        _waitingForNewInput = true;

        // Speak the result
        Future.delayed(Duration(milliseconds: 1500), () {
          speakResult();
        });
      } else {
        _result = 'Could not understand the expression';
        _isProcessing = false;
        _updateState();
        _speakWithCallback("I couldn't understand that. Please try again.");
        _waitingForNewInput = true;
      }
    } catch (e) {
      print('AI calculation error: $e');
      _result = 'Error processing with AI';
      _isProcessing = false;
      _updateState();
      _speakWithCallback("There was an error. Please try again.");
      _waitingForNewInput = true;
    }
  }

  Future<String> _convertToMathWithAI(String naturalLanguage) async {
    try {
      final response = await http.post(
        Uri.parse(_openAiEndpoint),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4',
          'messages': [
            {
              'role': 'system',
              'content': '''You are a mathematical expression converter. Convert natural language mathematical expressions to standard mathematical notation.

Rules:
1. Convert spoken numbers to digits (e.g., "two point five million" -> "2.5 * 1000000")
2. Convert operation words to symbols (+, -, *, /)
3. Return ONLY the mathematical expression, nothing else
4. If you cannot parse it, return "ERROR"
5. Handle decimals, fractions, and large numbers correctly
6. Examples:
   - "two plus three" -> "2 + 3"
   - "two point five million" -> "2.5 * 1000000"  
   - "one thousand times one thousand" -> "1000 * 1000"
   - "three and a half plus two" -> "3.5 + 2"'''
            },
            {
              'role': 'user',
              'content': naturalLanguage
            }
          ],
          'max_tokens': 100,
          'temperature': 0.1,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String result = data['choices'][0]['message']['content'].trim();

        // Clean up the result
        result = result.replaceAll(RegExp(r'[^\d+\-*/.() ]'), '');
        result = result.replaceAll(RegExp(r'\s+'), '');

        return result;
      } else {
        print('OpenAI API error: ${response.statusCode}');
        return 'ERROR';
      }
    } catch (e) {
      print('Error calling OpenAI API: $e');
      return 'ERROR';
    }
  }

  Future<double> _evaluateWithAI(String mathExpression) async {
    try {
      final response = await http.post(
        Uri.parse(_openAiEndpoint),
        headers: {
          'Content-Type': 'application/json',

        },
        body: jsonEncode({
          'model': 'gpt-4',
          'messages': [
            {
              'role': 'system',
              'content': '''You are a precise calculator. Calculate the given mathematical expression and return ONLY the numerical result.

Rules:
1. Perform accurate arithmetic calculations
2. Return only the number, no explanations
3. Use proper decimal precision
4. If there's an error, return "ERROR"'''
            },
            {
              'role': 'user',
              'content': 'Calculate: $mathExpression'
            }
          ],
          'max_tokens': 50,
          'temperature': 0,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String result = data['choices'][0]['message']['content'].trim();

        // Try to parse as double
        return double.tryParse(result) ?? 0.0;
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error evaluating with AI: $e');
      throw e;
    }
  }

  Future<void> _speakWithCallback(String message) async {
    _isTtsSpeaking = true;
    _updateState();
    await _flutterTts.speak(message);
  }

  Future<void> speakResult() async {
    if (_result.isNotEmpty &&
        _result != 'Could not understand the expression' &&
        _result != 'Error processing with AI') {
      String spokenResult = _result;
      if (_result.contains('.') && _result.endsWith('.0')) {
        spokenResult = _result.replaceAll('.0', '');
      }
      _speakWithCallback("The answer is $spokenResult");
    } else if (_result.isNotEmpty) {
      _speakWithCallback(_result);
    }
  }

  String _formatResult(double result) {
    if (result == result.roundToDouble()) {
      return result.round().toString();
    }

    String formatted = result.toStringAsFixed(6);
    formatted = formatted.replaceAll(RegExp(r'0*$'), '');
    formatted = formatted.replaceAll(RegExp(r'\.$'), '');
    return formatted;
  }

  void _updateState() {
    _stateController.add(CalculatorState(
      isListening: _isListening,
      isSpeaking: _isTtsSpeaking,
      lastWords: _lastWords,
      result: _result,
      speechEnabled: _speechEnabled,
      soundLevel: _soundLevel,
      soundDetected: _soundDetected,
      isProcessing: _isProcessing,
    ));
  }

  void dispose() {
    _speechToText.stop();
    _flutterTts.stop();
    _stateController.close();
    _soundLevelController.close();
  }
}

class CalculatorState {
  final bool isListening;
  final bool isSpeaking;
  final String lastWords;
  final String result;
  final bool speechEnabled;
  final double soundLevel;
  final bool soundDetected;
  final bool isProcessing;

  CalculatorState({
    required this.isListening,
    required this.isSpeaking,
    required this.lastWords,
    required this.result,
    required this.speechEnabled,
    required this.soundLevel,
    required this.soundDetected,
    required this.isProcessing,
  });
}