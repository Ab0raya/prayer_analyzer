import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/analysis_report.dart';

class YoloService {
  Interpreter? _interpreter;
  static const int _inputSize = 640;

  // Defines class labels mapping
  static const Map<int, Pose> _classMapping = {
    0: Pose.qayyam,
    1: Pose.ruku,
    2: Pose.sujud,
    3: Pose.tashahhud,
  };

  Future<void> loadModel(Uint8List modelBytes) async {
    InterpreterOptions options;
    if (Platform.isAndroid) {
      options = InterpreterOptions()..useNnApiForAndroid = true;
    } else {
      options = InterpreterOptions()..threads = 4;
    }

    try {
      _interpreter = Interpreter.fromBuffer(modelBytes, options: options);
    } catch (e) {
      print('Failed to init with NNAPI, falling back to 4 threads: $e');
      options = InterpreterOptions()..threads = 4;
      _interpreter = Interpreter.fromBuffer(modelBytes, options: options);
    }
    _interpreter?.allocateTensors();
  }

  Future<Pose> detectPose(Uint8List frameBytes) async {
    final image = img.decodeImage(frameBytes);
    if (image == null) return Pose.unknown;

    final resized = img.copyResize(
      image,
      width: _inputSize,
      height: _inputSize,
    );

    // Prepare input as flat Float32List [1 * 640 * 640 * 3]
    // Crucial: Must reshape to [1, 640, 640, 3] so TFLite knows it's 4D
    final float32Data = _imageToFloat32List(resized);
    var input = float32Data.reshape([1, _inputSize, _inputSize, 3]);

    // Output: [1, 8, 8400]
    // Use a flat Float32List for output to avoid JNI overhead
    var output = Float32List(1 * 8 * 8400).reshape([1, 8, 8400]);

    _interpreter!.run(input, output);

    // Post-process
    return _postProcess(output[0]);
  }

  // Optimize: Convert image to flat Float32List with normalization
  Float32List _imageToFloat32List(img.Image image) {
    var float32Bytes = Float32List(_inputSize * _inputSize * 3);
    var buffer = Float32List.view(float32Bytes.buffer);
    int pixelIndex = 0;

    for (var y = 0; y < _inputSize; y++) {
      for (var x = 0; x < _inputSize; x++) {
        final pixel = image.getPixel(x, y);
        buffer[pixelIndex++] = pixel.r / 255.0;
        buffer[pixelIndex++] = pixel.g / 255.0;
        buffer[pixelIndex++] = pixel.b / 255.0;
      }
    }
    return float32Bytes;
  }

  Pose _postProcess(List<dynamic> output) {
    // output is [8, 8400]
    // row 0-3: x, y, w, h
    // row 4-7: confidence for classes 0-3

    double maxScore = 0.0;
    int bestClassIndex = -1;
    int numAnchors = 8400;

    // Check bounds
    if (output.length < 8 || output[0].length < numAnchors) {
      // Fallback or print error
      return Pose.unknown;
    }

    for (int i = 0; i < numAnchors; i++) {
      for (int c = 0; c < 4; c++) {
        // Class scores start at row 4
        double score = output[4 + c][i];
        if (score > maxScore) {
          maxScore = score;
          bestClassIndex = c;
        }
      }
    }

    if (bestClassIndex != -1 && maxScore > 0.5) {
      return _classMapping[bestClassIndex] ?? Pose.unknown;
    }

    return Pose.unknown;
  }

  void close() {
    _interpreter?.close();
  }
}
