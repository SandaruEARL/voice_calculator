import 'package:flutter/material.dart';
import 'dart:math';

class DynamicWaveform extends StatelessWidget {
  final AnimationController animationController;
  final Color color;
  final int waveCount;
  final double baseAmplitude;
  final double frequency;
  final double soundLevel;
  final bool isSpeaking; // Added to differentiate TTS speaking

  const DynamicWaveform({
    Key? key,
    required this.animationController,
    required this.color,
    this.waveCount = 3,
    this.baseAmplitude = 20.0,
    this.frequency = 0.02,
    required this.soundLevel,
    this.isSpeaking = false, // Default to false
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        return CustomPaint(
          painter: WaveformPainter(
            animationValue: animationController.value,
            color: color,
            waveCount: waveCount,
            baseAmplitude: baseAmplitude,
            frequency: frequency,
            soundLevel: soundLevel,
            isSpeaking: isSpeaking,
          ),
          size: const Size(double.infinity, 180),
        );
      },
    );
  }
}

class WaveformPainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final int waveCount;
  final double baseAmplitude;
  final double frequency;
  final double soundLevel;
  final bool isSpeaking;

  WaveformPainter({
    required this.animationValue,
    required this.color,
    required this.waveCount,
    required this.baseAmplitude,
    required this.frequency,
    required this.soundLevel,
    required this.isSpeaking,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final paint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Check if we should show flat line (zero amplitude)
    bool showFlatLine = !isSpeaking && soundLevel < 1.0;

    if (showFlatLine) {
      // Draw a simple flat line when there's no activity
      paint.color = color.withOpacity(0.4);
      paint.strokeWidth = 1.5;

      final path = Path();
      path.moveTo(0, centerY);
      path.lineTo(size.width, centerY);
      canvas.drawPath(path, paint);

      // Add subtle breathing effect to the flat line
      double breathingOffset = sin(animationValue * 2 * pi * 0.5) * 2.0;
      paint.color = color.withOpacity(0.2);
      final breathingPath = Path();
      breathingPath.moveTo(0, centerY + breathingOffset);
      breathingPath.lineTo(size.width, centerY + breathingOffset);
      canvas.drawPath(breathingPath, paint);

      return;
    }

    // Dynamic waveform for listening or speaking
    for (int i = 0; i < waveCount; i++) {
      double amplitudeScale;
      double waveFrequency;
      double phaseSpeed;

      if (isSpeaking) {
        // TTS speaking animation - more rhythmic and structured
        amplitudeScale = (0.8 + sin(animationValue * 2 * pi * 3) * 0.3).clamp(0.5, 1.2);
        waveFrequency = 3.0 + i * 0.5; // Different frequency per wave
        phaseSpeed = 1.5 + i * 0.3; // Varying speeds for layered effect
      } else {
        // Listening animation - responsive to sound level
        amplitudeScale = (soundLevel / 50.0).clamp(0.3, 1.5);

        // If sound level is very low, show minimal wave
        if (soundLevel < 2.0) {
          amplitudeScale = 0.4;
        }

        waveFrequency = 4.0; // Standard frequency for listening
        phaseSpeed = 2.0; // Standard speed for listening
      }

      final amplitude = (baseAmplitude + i * 8.0) * amplitudeScale;
      final phase = animationValue * 2 * pi * phaseSpeed + (i * pi / 3);

      final path = Path();
      bool firstPoint = true;

      // Generate waving points
      for (double x = 0; x <= size.width; x += 1.5) {
        double waveX = (x / size.width) * waveFrequency * pi;
        double y;

        if (isSpeaking) {
          // More complex wave pattern for TTS
          double primaryWave = sin(waveX + phase);
          double secondaryWave = sin(waveX * 1.5 + phase * 0.7) * 0.3;
          double modulationWave = sin(animationValue * 2 * pi * 2 + i) * 0.2;

          y = centerY + amplitude * (primaryWave + secondaryWave + modulationWave);
        } else {
          // Simpler wave for listening
          y = centerY + amplitude * sin(waveX + phase);
        }

        if (firstPoint) {
          path.moveTo(x, y);
          firstPoint = false;
        } else {
          path.lineTo(x, y);
        }
      }

      // Create gradient opacity for layered effect
      double opacity = isSpeaking ? 0.9 - (i * 0.15) : 0.9 - (i * 0.2);
      paint.color = color.withOpacity(opacity);

      // Adjust stroke width based on wave layer
      paint.strokeWidth = isSpeaking ? 2.5 - (i * 0.3) : 2.0;

      canvas.drawPath(path, paint);
    }

    // Add extra visual effects for TTS speaking
    if (isSpeaking) {
      // Add pulsing center line
      paint.color = color.withOpacity(0.3);
      paint.strokeWidth = 1.0;

      double pulseOffset = sin(animationValue * 2 * pi * 4) * 3.0;
      final pulsePath = Path();
      pulsePath.moveTo(0, centerY + pulseOffset);
      pulsePath.lineTo(size.width, centerY + pulseOffset);
      canvas.drawPath(pulsePath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return animationValue != oldDelegate.animationValue ||
        soundLevel != oldDelegate.soundLevel ||
        color != oldDelegate.color ||
        isSpeaking != oldDelegate.isSpeaking;
  }
}