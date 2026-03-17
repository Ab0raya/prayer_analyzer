import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:prayer_analyzer/services/native_prayer_service.dart';
import 'package:prayer_analyzer/widgets/native_camera_preview.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NativePrayerService _nativeService = NativePrayerService();
  StreamSubscription? _subscription;
  StreamSubscription? _videoSubscription;
  bool _isAnalyzing = false;
  bool _isVideoAnalyzing = false;
  double _videoProgress = 0.0;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  // To display results
  String _label = "Waiting...";
  String _confidence = "0.0%";
  String _time = "0ms";

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _videoSubscription?.cancel();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    await Permission.camera.request();
  }

  Future<void> _pickAndAnalyzeImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        _stopLiveAnalysis();
        _clearSelection();

        setState(() {
          _selectedImage = File(image.path);
          _label = "Analyzing Image...";
        });

        final result = await _nativeService.analyzeImage(image.path);

        if (mounted && result != null) {
          setState(() {
            _label = result.label;
            _confidence = "${(result.confidence * 100).toStringAsFixed(1)}%";
            _time = "${result.inferenceTime}ms";
          });
        } else if (mounted) {
          setState(() {
            _label = "Analysis Failed";
          });
        }
      }
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  Future<void> _pickAndAnalyzeVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        _stopLiveAnalysis();
        _clearSelection();

        setState(() {
          _selectedImage = null;
          _label = "Analyzing Video...";
          _confidence = "";
          _time = "";
          _isVideoAnalyzing = true;
          _videoProgress = 0.0;
        });

        _videoSubscription = _nativeService.postureStream.listen((result) {
          if (mounted) {
            setState(() {
              _label = result.label;
              _confidence = "${(result.confidence * 100).toStringAsFixed(1)}%";
              _time = "${result.inferenceTime}ms";
              _videoProgress = result.progress;
            });
            print("Video Analysis: ${result.label} (${_confidence}) - Progress: ${(_videoProgress * 100).toStringAsFixed(1)}%");
          }
        });

        final results = await _nativeService.analyzeVideo(video.path);

        _videoSubscription?.cancel();
        _videoSubscription = null;

        if (mounted) {
          setState(() {
            _isVideoAnalyzing = false;
            _label = "Video Analysis Complete";
          });
          _showVideoReport(results);
        }
      }
    } catch (e) {
      print("Error picking video: $e");
    }
  }

  void _showVideoReport(List<VideoAnalysisResult> results) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Video Analysis Report",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final item = results[index];
                    final timeSec = (item.timestampMs / 1000).toStringAsFixed(
                      1,
                    );
                    return ListTile(
                      leading: Text("${timeSec}s"),
                      title: Text(item.label),
                      subtitle: Text(
                        "Confidence: ${(item.confidence * 100).toStringAsFixed(1)}%",
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _stopLiveAnalysis() {
    if (_isAnalyzing) {
      _nativeService.stopInference();
      _subscription?.cancel();
      _subscription = null;
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedImage = null;
      _label = "Waiting...";
      _confidence = "0.0%";
      _time = "0ms";
    });
  }

  void _clearImage() => _clearSelection();

  void _toggleAnalysis() {
    if (_isAnalyzing) {
      _stopLiveAnalysis();
      setState(() {
        _label = "Stopped";
      });
    } else {
      // Ensure we are in camera mode
      _clearSelection();

      _nativeService.startInference();
      setState(() => _isAnalyzing = true);

      // Listen to the stream
      _subscription = _nativeService.postureStream.listen((result) {
        print("Dart received: ${result.label} ${result.confidence}");
        if (mounted) {
          setState(() {
            _label = result.label;
            _confidence = "${(result.confidence * 100).toStringAsFixed(1)}%";
            _time = "${result.inferenceTime}ms";
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Prayer Posture Analyzer")),
      body: Stack(
        children: [
          // Background: Camera Preview OR Static Image
          Positioned.fill(
            child: _selectedImage != null
                ? Image.file(_selectedImage!, fit: BoxFit.cover)
                : const NativeCameraPreview(),
          ),

          if (_selectedImage != null)
            Positioned(
              top: 20,
              right: 20,
              child: FloatingActionButton.small(
                onPressed: _clearImage,
                backgroundColor: Colors.red,
                child: const Icon(Icons.close, color: Colors.white),
              ),
            ),

          // Foreground: Controls and Results
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Posture: $_label",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (_isVideoAnalyzing) ...[
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: _videoProgress,
                      backgroundColor: Colors.white24,
                      color: Colors.green,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    "Confidence: $_confidence  |  Time: $_time",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 20,
                    runSpacing: 20,
                    children: [
                      if (_selectedImage == null) ...[
                        ElevatedButton(
                          onPressed: _toggleAnalysis,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isAnalyzing
                                ? Colors.red
                                : Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                          ),
                          child: Text(_isAnalyzing ? "Stop" : "Live"),
                        ),
                        FloatingActionButton(
                          heroTag: "toggle",
                          onPressed: () {
                            _nativeService.toggleCamera();
                          },
                          backgroundColor: Colors.white,
                          child: const Icon(
                            Icons.cameraswitch,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                      FloatingActionButton(
                        heroTag: "gallery",
                        onPressed: _pickAndAnalyzeImage,
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.image, color: Colors.orange),
                      ),
                      FloatingActionButton(
                        heroTag: "video",
                        onPressed: _pickAndAnalyzeVideo,
                        backgroundColor: Colors.white,
                        child: const Icon(
                          Icons.video_library,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
