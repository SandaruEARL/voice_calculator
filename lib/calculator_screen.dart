import 'package:flutter/material.dart';
import 'calculator_service_old.dart';
import 'dynamic_waveform.dart';

class CalculatorScreen extends StatefulWidget {
  @override
  _CalculatorScreenState createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen>
    with TickerProviderStateMixin {
  late CalculatorService _calculatorService;
  late AnimationController _animationController;
  late AnimationController _cursorController;

  CalculatorState _currentState = CalculatorState(
    isListening: false,
    isSpeaking: false,
    lastWords: 'Touch screen to start listening',
    result: '',
    speechEnabled: false,
    soundLevel: 0.0,
    soundDetected: false,
  );

  String _displayText = 'Touch screen to start listening';
  bool _isTyping = false;
  bool _showCursor = false;
  bool _isProcessing = false;
  String _ttsText = '';

  @override
  void initState() {
    super.initState();
    _calculatorService = CalculatorService();
    _animationController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );
    _cursorController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _calculatorService.initialize();

    // Listen to state changes
    _calculatorService.stateStream.listen((state) {
      setState(() {
        _currentState = state;
      });

      // Control animation based on state
      if (state.isListening || state.isSpeaking) {
        if (!_animationController.isAnimating) {
          _animationController.repeat();
        }
      } else {
        // Keep a gentle animation for flat line breathing effect
        if (!_animationController.isAnimating) {
          _animationController.repeat();
        }
      }

      // Handle different text display scenarios
      if (state.isListening && state.lastWords != _currentState.lastWords && state.lastWords.isNotEmpty && state.lastWords != 'Listening...') {
        // User is speaking - show typing effect
        _typeTextWithCursor(state.lastWords);
      } else if (!state.isListening && !state.isSpeaking && state.result.isNotEmpty && !_isProcessing && _ttsText.isEmpty) {
        // Got result but not speaking yet - show processing (only once)
        _showProcessing();
      } else if (state.isSpeaking && state.result.isNotEmpty) {
        // TTS is speaking - show what it's saying
        if (_isProcessing || _ttsText.isEmpty) {
          _showTtsOutput(state.result);
        }
      } else if (!state.isListening && !state.isSpeaking && state.lastWords == 'Touch screen to start listening' && state.result.isEmpty) {
        // Reset to initial state (only when result is also empty)
        _resetDisplay();
      }

    });

    // Set initial state
    setState(() {
      _currentState = CalculatorState(
        isListening: false,
        isSpeaking: false,
        lastWords: _currentState.speechEnabled
            ? 'Touch screen to start listening'
            : 'Microphone permission required',
        result: '',
        speechEnabled: _calculatorService.speechEnabled,
        soundLevel: 0.0,
        soundDetected: false,
      );
      _displayText = _currentState.lastWords;
    });

    // Start gentle animation for flat line
    _animationController.repeat();
  }

  void _typeTextWithCursor(String text) async {
    if (_isTyping) return;

    _isTyping = true;
    _showCursor = true;
    _cursorController.repeat();

    setState(() {
      _displayText = '';
    });

    for (int i = 0; i <= text.length; i++) {
      if (mounted) {
        setState(() {
          _displayText = text.substring(0, i);
        });
        await Future.delayed(Duration(milliseconds: 50));
      }
    }

    _showCursor = false;
    _cursorController.stop();
    _isTyping = false;
    setState(() {});
  }

  void _showProcessing() {
    _isProcessing = true;
    setState(() {
      _displayText = 'Processing...';
      _showCursor = false;
    });
    _cursorController.stop();
  }

  void _showTtsOutput(String result) {
    _isProcessing = false;
    String spokenResult = result;
    if (result.contains('.') && result.endsWith('.0')) {
      spokenResult = result.replaceAll('.0', '');
    }
    _ttsText = "The answer is $spokenResult";

    setState(() {
      _displayText = _ttsText;
      _showCursor = false;
    });
    _cursorController.stop();
  }

  void _resetDisplay() {
    _isProcessing = false;
    _ttsText = '';
    _showCursor = false;
    _cursorController.stop();

    setState(() {
      _displayText = 'Touch screen to start listening';
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cursorController.dispose();
    _calculatorService.dispose();
    super.dispose();
  }

  void _onScreenTap() {
    if (_currentState.isListening) {
      _calculatorService.stopListening();
    } else if (_currentState.speechEnabled) {
      // Clear previous text and start listening
      setState(() {
        _displayText = 'Listening...';
        _showCursor = false;
        _isProcessing = false;
        _ttsText = '';
      });
      _cursorController.stop();
      _calculatorService.startListening();
    }
  }

  void _onHistoryTapped() {
    // TODO: Implement history functionality
    print('History button tapped');
  }

  void _onSettingsTapped() {
    // TODO: Implement settings functionality
    print('Settings button tapped');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.history,
            color: Colors.white,
            size: 28,
          ),
          onPressed: _onHistoryTapped,
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings,
              color: Colors.white,
              size: 28,
            ),
            onPressed: _onSettingsTapped,
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onTap: _onScreenTap,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue[600]!, Colors.blue[800]!],
            ),
          ),
          child: Column(
            children: [
              // Status bar spacing + app bar spacing
              SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight + 20),

              // Waveform Section
              Expanded(
                flex: 2,
                child: Container(
                  width: double.infinity,
                  child: DynamicWaveform(
                    animationController: _animationController,
                    color: _currentState.isSpeaking
                        ? Colors.green[300]!
                        : Colors.white,
                    waveCount: (_currentState.isListening || _currentState.isSpeaking) ? 3 : 1,
                    baseAmplitude: 30,
                    frequency: 0.02,
                    soundLevel: _currentState.isListening
                        ? _currentState.soundLevel * 10
                        : (_currentState.isSpeaking ? 50.0 : 0.0),
                    isSpeaking: _currentState.isSpeaking,
                  ),
                ),
              ),

              // Microphone permission message (when needed)
              if (!_currentState.speechEnabled)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  child: Text(
                    'Microphone access required',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Display Text Area - Direct on screen without container
              Expanded(
                flex: 2,
                child: Container(
                  padding: EdgeInsets.all(30),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: Text(
                                _displayText,
                                style: TextStyle(
                                  fontSize: 28,
                                  color: Colors.white,
                                  height: 1.4,
                                  fontWeight: FontWeight.w400,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.3),
                                      offset: Offset(0, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            // Animated cursor
                            if (_showCursor)
                              AnimatedBuilder(
                                animation: _cursorController,
                                builder: (context, child) {
                                  return Opacity(
                                    opacity: _cursorController.value > 0.5 ? 1.0 : 0.0,
                                    child: Container(
                                      width: 3,
                                      height: 32,
                                      margin: EdgeInsets.only(left: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(1.5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.3),
                                            offset: Offset(0, 1),
                                            blurRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),

                        // Sound detection indicator
                        if (_currentState.isListening && _currentState.soundDetected)
                          Padding(
                            padding: EdgeInsets.only(top: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.graphic_eq,
                                  color: Colors.white.withOpacity(0.8),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Sound detected',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Status Indicator
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentState.isListening
                            ? Colors.red
                            : _currentState.isSpeaking
                            ? Colors.green
                            : Colors.grey.withOpacity(0.5),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      _currentState.isListening
                          ? 'Listening...'
                          : _currentState.isSpeaking
                          ? 'Speaking...'
                          : 'Ready to listen',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom padding
              SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
            ],
          ),
        ),
      ),
    );
  }
}