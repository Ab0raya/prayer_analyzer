import 'dart:collection';
import '../models/analysis_report.dart';

class PoseStabilizer {
  final int _windowSize;
  final Queue<Pose> _buffer = Queue<Pose>();

  PoseStabilizer({int windowSize = 3}) : _windowSize = windowSize;

  Pose addPrediction(Pose pose) {
    _buffer.addLast(pose);
    if (_buffer.length > _windowSize) {
      _buffer.removeFirst();
    }

    if (_buffer.length < _windowSize) {
      return Pose.unknown;
    }

    // Check if checks are consistent
    // Simple consistency check: majority vote or strictly same?
    // User says: "confirm pose after several frames"
    // Let's go with majority vote to handle some flicker,
    // or strictly all same for high precision.
    // Given video processing, let's use majority vote.

    Map<Pose, int> counts = {};
    for (var p in _buffer) {
      counts[p] = (counts[p] ?? 0) + 1;
    }

    var bestPose = Pose.unknown;
    int maxCount = 0;

    counts.forEach((key, value) {
      if (value > maxCount) {
        maxCount = value;
        bestPose = key;
      }
    });

    // Require majority
    if (maxCount > _windowSize / 2) {
      return bestPose;
    }

    return Pose.unknown;
  }

  void reset() {
    _buffer.clear();
  }
}
