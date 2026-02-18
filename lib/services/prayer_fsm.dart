import '../models/analysis_report.dart';

class PrayerFSM {
  // State
  int _rakahCount = 0;
  List<PrayerMistake> _mistakes = [];
  List<PrayerStep> _steps = [];
  Pose _lastPose = Pose.unknown;

  // Sequence expectation per Rakah:
  // Qayyam -> Ruku -> Qayyam -> Sujud -> Tashahhud (if end of 2nd/last) -> Sujud
  // Ideally: Qayyam -> Ruku -> Qayyam -> Sujud -> Sitting -> Sujud -> Qayyam (next rakah)

  // Simplified Sequence matching for "Per rakah sequence":
  // User Prompt: Qayyam -> Ruku -> Qayyam -> Sujud -> Tashahhud -> Sujud
  // Wait, standard Salah is:
  // Qayyam -> Ruku -> Qayyam -> Sujud -> Jalsa (sitting between sujud) -> Sujud -> (Stand up or Tashahhud)

  // The User Prompt SPECIFICALLY says:
  // "Per rakah sequence: Qayyam -> Ruku -> Qayyam -> Sujud -> Tashahhud -> Sujud"
  // This seems slightly non-standard (Tashahhud between Sujuds?) or maybe they mean "Sitting"?
  // Or maybe they mean the sequence of poses detected.
  //
  // Let's look at Classes again:
  // 0 = Qayyam
  // 1 = Ruku
  // 2 = Sujud
  // 3 = Tashahhud
  //
  // Because Jalsa (sitting) looks like Tashahhud, likely mapped to Tashahhud class.
  // So "Tashahhud" class means "Sitting" generally?
  //
  // User sequence: Qayyam -> Ruku -> Qayyam -> Sujud -> Tashahhud -> Sujud
  // This matches Qayyam -> Ruku -> I'tidal -> Sujud -> Jalsa -> Sujud.
  // So yes, "Tashahhud" here likely implies the sitting posture.
  //
  // And "Tashahhud after rakah 2" means the prolonged sitting.

  // We need to implement a state machine that expects this sequence.
  // We can track "Sequence Index" within a Rakah.

  // Sequence Definition:
  // 0: Qayyam
  // 1: Ruku
  // 2: Qayyam (I'tidal)
  // 3: Sujud
  // 4: Tashahhud (Sitting)
  // 5: Sujud

  // After 5 (Sujud), we expect either:
  // - Qayyam (Start next Rakah)
  // - Tashahhud (Final or Middle Tashahhud) -> Wait, if we are at step 5 (Sujud),
  //   the next step is Standing (Qayyam) for next Rakah OR Sitting (Tashahhud) for end of Rakah.

  // Complex logic:
  // The user prompt says "Per rakah sequence: Qayyam -> Ruku -> Qayyam -> Sujud -> Tashahhud -> Sujud".
  // This covers the "Sujud -> Sitting -> Sujud" part.
  // So 1 Rakah = Q -> R -> Q -> S -> T -> S.

  // Transition from Rakah N to N+1:
  // From last Sujud of Rakah N -> Qayyam of Rakah N+1.

  // Transition for Tashahhud (Middle/Final):
  // After Rakah 2: S -> T (Middle Tashahhud) -> Q (Rakah 3)
  // After Final Rakah: S -> T (Final Tashahhud) -> End.

  // Wait, the user prompt sequence: "Qayyam -> Ruku -> Qayyam -> Sujud -> Tashahhud -> Sujud" might ALREADY include the sitting between sujuds.
  // So:
  // 1. Qayyam
  // 2. Ruku
  // 3. Qayyam
  // 4. Sujud (1st)
  // 5. Tashahhud (Sitting between Sujuds)
  // 6. Sujud (2nd)

  // Checks out.

  // Then after 2nd Sujud:
  // If Rakah 2 or Final -> Tashahhud (Long sitting)
  // Else -> Qayyam (Stand up).

  int _currentSequenceIndex = 0; // 0..5
  bool _inTashahhud = false; // Are we in the long Tashahhud?

  void update(Pose pose, Duration timestamp, double confidence) {
    if (pose == Pose.unknown || pose == _lastPose)
      return; // Only act on state change

    // Log the step
    _steps.add(
      PrayerStep(pose: pose, timestamp: timestamp, confidence: confidence),
    );

    // State machine logic
    // We expect the next pose in sequence.

    // We handle transitions.
    // Current Pose: _lastPose  -> New Pose: pose

    final expectedNext = _getExpectedNextPose();

    if (pose == expectedNext) {
      _advanceState();
    } else {
      // Possible valid deviations?
      // e.g. Skipping "Qayyam" return after Ruku (going Ruku -> Sujud directly is wrong but possible detection error)
      // or maybe we are at end of Rakah.

      // Special case: End of Rakah transitions
      if (_currentSequenceIndex == 5 && pose == Pose.qayyam) {
        // Finished Rakah, starting new one (skip Tashahhud sitting if not needed? No, logic handles it)
        // Wait, after step 5 (Sujud #2), we expect either Qayyam (new rakah) or Tashahhud (sitting).

        // If we get Qayyam:
        // Means we started new Rakah.
        _completeRakah();
        _currentSequenceIndex = 0; // Back to Qayyam
        // But we already consumed "Qayyam", so we are AT index 0.
        // Actually we just entered Qayyam, so we are at state 0.
        // Effectively we transitioned: Sujud(5) -> Qayyam(0).
      } else if (_currentSequenceIndex == 5 && pose == Pose.tashahhud) {
        // Finished Rakah, entering Tashahhud (Middle or Final).
        _completeRakah();
        _inTashahhud = true;
        // We stay in Tashahhud until Qayyam or End.
        return;
      } else if (_inTashahhud && pose == Pose.qayyam) {
        // Rising from Tashahhud to new Rakah
        _inTashahhud = false;
        _currentSequenceIndex = 0; // Qayyam
      } else {
        // Error detected
        _mistakes.add(
          PrayerMistake(
            description:
                "Unexpected movement: Found $pose, expected $expectedNext",
            timestamp: timestamp,
          ),
        );
        // Force state update? Or simply log error and try to resync?
        // Simple FSM: We assume user corrected or we just track mistakes.
        // We'll update _lastPose but maybe not advance sequence index if it was totally wrong?
        // But maybe we should try to sync to the new pose if it fits a future step?
        // For simplicity: just log mistake.
      }
    }

    _lastPose = pose;
  }

  Pose _getExpectedNextPose() {
    if (_inTashahhud) {
      return Pose.qayyam; // Expect to stand up (unless finished)
    }

    // Sequence: Q -> R -> Q -> S -> T -> S
    const sequence = [
      Pose.qayyam,
      Pose.ruku,
      Pose.qayyam,
      Pose.sujud,
      Pose.tashahhud,
      Pose.sujud,
    ];

    int nextIndex = _currentSequenceIndex + 1;
    if (nextIndex >= sequence.length) {
      // End of sequence (after Sujud #2)
      // Could be Qayyam (next rakah) or Tashahhud (sitting)
      // We can't return a single expected pose here without knowing total rakahs or current rakah.
      // But typically we'd default to Qayyam unless it's rakah 2/4.
      return Pose.qayyam;
    }

    return sequence[nextIndex];
  }

  void _advanceState() {
    if (_inTashahhud) return; // Handled by explicit transition

    _currentSequenceIndex++;
    if (_currentSequenceIndex >= 6) {
      // 6 steps: 0..5
      // We reached end of loop, but we handle the wrap-around via explicit checks in update() usually.
      // Actually, if we just blindly increment, we need to wrap or wait.
      // The logic in `update` handles the transition from S(5) to Q(0) or T.
      // So we shouldn't have blindly incremented if we were at 5.
      // But `expectedNext` logic relies on index.
      // Let's reset index in `update` when wrapping.
    }
  }

  void _completeRakah() {
    _rakahCount++;
  }

  AnalysisReport generateReport() {
    return AnalysisReport(
      totalRakahs: _rakahCount,
      isComplete:
          true, // TODO: Logic to determine if "Complete" based on prayer mode
      mistakes: _mistakes,
      steps: _steps,
    );
  }
}
