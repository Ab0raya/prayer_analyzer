import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/analysis_report.dart';
import 'inference_isolate.dart';

class AnalysisService extends ChangeNotifier {
  // Isolate Management
  Isolate? _inferenceIsolate;
  SendPort? _isolateSendPort;
  ReceivePort? _mainReceivePort;
  Completer<void>? _isolateReady;

  // Analysis State
  bool _isAnalyzing = false;
  bool get isAnalyzing => _isAnalyzing;

  Pose _currentPose = Pose.unknown;
  Pose get currentPose => _currentPose;

  Future<void> initialize() async {
    if (_inferenceIsolate != null) return;

    _isolateReady = Completer<void>();
    _mainReceivePort = ReceivePort();

    try {
      // Spawn isolate
      _inferenceIsolate = await Isolate.spawn(
        inferenceWorker,
        _mainReceivePort!.sendPort,
      );

      // Listen for messages from isolate
      _mainReceivePort!.listen((message) {
        if (message is SendPort) {
          _isolateSendPort = message;
          _initModelInIsolate();
        } else if (message is bool) {
          // Model loaded success/fail
          if (message) {
            if (!_isolateReady!.isCompleted) _isolateReady!.complete();
          } else {
            if (!_isolateReady!.isCompleted)
              _isolateReady!.completeError('Failed to load model in isolate');
          }
        } else if (message is InferenceResponse) {
          _handleInferenceResult(message);
        }
      });

      await _isolateReady?.future;
    } catch (e) {
      print('Failed to initialize analysis service: $e');
      _cleanupIsolate();
    }
  }

  void _initModelInIsolate() async {
    // Pass root isolate token for platform channels
    RootIsolateToken? token = RootIsolateToken.instance;
    try {
      final modelData = await rootBundle.load('assets/models/best_int8.tflite');
      final modelBytes = modelData.buffer.asUint8List();

      _isolateSendPort?.send(
        InferenceRequest.init(_mainReceivePort!.sendPort, token, modelBytes),
      );
    } catch (e) {
      print("Failed to load model asset in main isolate: $e");
      _cleanupIsolate();
    }
  }

  Future<void> analyzeImage(Uint8List imageBytes) async {
    if (_inferenceIsolate == null) await initialize();

    _isAnalyzing = true;
    _currentPose = Pose.unknown;
    notifyListeners();

    try {
      // Send image to isolate
      _isolateSendPort!.send(InferenceRequest.detect(imageBytes));
    } catch (e) {
      print("Analysis Error: $e");
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  void _handleInferenceResult(InferenceResponse result) {
    _isAnalyzing = false; // Single image analysis is done once result returns
    _currentPose = result.pose;
    print("Inference Result: $_currentPose");
    notifyListeners();
  }

  void _cleanupIsolate() {
    _mainReceivePort?.close();
    _inferenceIsolate?.kill();
    _inferenceIsolate = null;
  }

  @override
  void dispose() {
    _cleanupIsolate();
    super.dispose();
  }
}
