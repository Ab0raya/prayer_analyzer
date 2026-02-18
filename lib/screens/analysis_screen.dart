import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/analysis_service.dart';

class AnalysisScreen extends StatefulWidget {
  final String imagePath;

  const AnalysisScreen({super.key, required this.imagePath});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  late AnalysisService _analysisService;

  @override
  void initState() {
    super.initState();
    _analysisService = AnalysisService();
    _startAnalysis();
  }

  Future<void> _startAnalysis() async {
    await _analysisService.initialize();
    if (mounted) {
      _analysisService.analyzeImage(widget.imagePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _analysisService,
      child: Scaffold(
        appBar: AppBar(title: const Text('Analyzing Image')),
        body: Consumer<AnalysisService>(
          builder: (context, service, child) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  if (widget.imagePath.isNotEmpty)
                    Image.file(File(widget.imagePath)),
                  const SizedBox(height: 20),
                  if (service.isAnalyzing)
                    const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text('Analyzing...'),
                      ],
                    )
                  else
                    Column(
                      children: [
                        const Text(
                          'Detected Pose:',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          service.currentPose
                              .toString()
                              .split('.')
                              .last
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
