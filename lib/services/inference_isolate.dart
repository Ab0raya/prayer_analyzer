import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'yolo_service.dart';
import '../models/analysis_report.dart';

// Commands
enum InferenceCommand { init, detect, close }

class InferenceRequest {
  final InferenceCommand command;
  final SendPort? sendPort;
  final Uint8List? frameData;
  final RootIsolateToken? token; // Needed for platform channels (assets)
  final Uint8List? modelBytes;

  InferenceRequest.init(this.sendPort, this.token, this.modelBytes)
    : command = InferenceCommand.init,
      frameData = null;

  InferenceRequest.detect(this.frameData)
    : command = InferenceCommand.detect,
      sendPort = null,
      token = null,
      modelBytes = null;

  InferenceRequest.close()
    : command = InferenceCommand.close,
      sendPort = null,
      frameData = null,
      token = null,
      modelBytes = null;
}

class InferenceResponse {
  final Pose pose;
  final int inferenceTimeMs;

  InferenceResponse(this.pose, this.inferenceTimeMs);
}

Future<void> inferenceWorker(SendPort mainSendPort) async {
  final ReceivePort isolateReceivePort = ReceivePort();
  mainSendPort.send(isolateReceivePort.sendPort);

  YoloService? _yoloService;

  await for (final dynamic message in isolateReceivePort) {
    if (message is InferenceRequest) {
      if (message.command == InferenceCommand.init) {
        // Initialize background isolate
        _yoloService = YoloService();
        try {
          final bytes = message.modelBytes;
          if (bytes != null) {
            await _yoloService.loadModel(bytes);
            message.sendPort?.send(true); // Signal success
          } else {
            print("Init Error: Model bytes missing");
            message.sendPort?.send(false);
          }
        } catch (e) {
          print('Inference Isolate Init Error: $e');
          message.sendPort?.send(false);
        }
      } else if (message.command == InferenceCommand.detect) {
        if (_yoloService != null && message.frameData != null) {
          final stopwatch = Stopwatch()..start();
          try {
            final pose = await _yoloService.detectPose(message.frameData!);
            stopwatch.stop();
            mainSendPort.send(
              InferenceResponse(pose, stopwatch.elapsedMilliseconds),
            );
          } catch (e) {
            print('Inference Isolate Detect Error: $e');
            mainSendPort.send(InferenceResponse(Pose.unknown, 0));
          }
        }
      } else if (message.command == InferenceCommand.close) {
        // _yoloService?.close(); // Implement close if needed
        Isolate.exit();
      }
    }
  }
}
