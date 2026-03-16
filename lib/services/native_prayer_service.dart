import 'package:flutter/services.dart';

class NativePrayerService {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.example.prayer_analyzer/method',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.example.prayer_analyzer/stream',
  );

  Stream<PrayerPostureResult>? _postureStream;

  Stream<PrayerPostureResult> get postureStream {
    _postureStream ??= _eventChannel.receiveBroadcastStream().map(
      (event) => PrayerPostureResult.fromMap(Map<String, dynamic>.from(event)),
    );
    return _postureStream!;
  }

  Future<void> startInference() async {
    try {
      await _methodChannel.invokeMethod('startInference');
    } on PlatformException catch (e) {
      print("Failed to start inference: '${e.message}'.");
    }
  }

  Future<void> stopInference() async {
    try {
      await _methodChannel.invokeMethod('stopInference');
    } on PlatformException catch (e) {
      print("Failed to stop inference: '${e.message}'.");
    }
  }

  Future<void> toggleCamera() async {
    try {
      await _methodChannel.invokeMethod('toggleCamera');
    } on PlatformException catch (e) {
      print("Failed to toggle camera: '${e.message}'.");
    }
  }

  Future<PrayerPostureResult?> analyzeImage(String path) async {
    try {
      final Map<dynamic, dynamic>? result = await _methodChannel.invokeMethod(
        'analyzeImage',
        {'path': path},
      );
      if (result != null) {
        return PrayerPostureResult.fromMap(Map<String, dynamic>.from(result));
      }
    } on PlatformException catch (e) {
      print("Failed to analyze image: '${e.message}'.");
    }
    return null;
  }

  Future<List<VideoAnalysisResult>> analyzeVideo(String path) async {
    try {
      final List<dynamic>? results = await _methodChannel.invokeMethod(
        'analyzeVideo',
        {'path': path},
      );
      if (results != null) {
        return results
            .map(
              (e) => VideoAnalysisResult.fromMap(Map<String, dynamic>.from(e)),
            )
            .toList();
      }
    } on PlatformException catch (e) {
      print("Failed to analyze video: '${e.message}'.");
    }
    return [];
  }
}

class VideoAnalysisResult {
  final int timestampMs;
  final String label;
  final double confidence;

  VideoAnalysisResult({
    required this.timestampMs,
    required this.label,
    required this.confidence,
  });

  factory VideoAnalysisResult.fromMap(Map<String, dynamic> map) {
    return VideoAnalysisResult(
      timestampMs: (map['timestampMs'] as num).toInt(),
      label: map['label'] as String,
      confidence: (map['confidence'] as num).toDouble(),
    );
  }
}

class PrayerPostureResult {
  final String label;
  final double confidence;
  final int inferenceTime;

  PrayerPostureResult({
    required this.label,
    required this.confidence,
    required this.inferenceTime,
  });

  factory PrayerPostureResult.fromMap(Map<String, dynamic> map) {
    return PrayerPostureResult(
      label: map['label'] as String,
      confidence: (map['confidence'] as num).toDouble(),
      inferenceTime: (map['inferenceTime'] as num).toInt(),
    );
  }

  @override
  String toString() {
    return 'Posture: $label (${(confidence * 100).toStringAsFixed(1)}%) - ${inferenceTime}ms';
  }
}
