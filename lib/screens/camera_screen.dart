import 'dart:io';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:digital_diary/main.dart';
import 'package:digital_diary/screens/save_video_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isLoading = true;
  bool _hasRecordedToday = false;
  CameraController? _controller;
  int _cameraIndex = 0;
  bool _isRecording = false;

  // State variables for zoom functionality
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  double _currentZoomLevel = 1.0;
  double _baseZoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    _checkAndInitialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isLoading) {
       _checkAndInitialize();
    }
  }

  Future<void> _checkAndInitialize() async {
    if(mounted) {
      setState(() { _isLoading = true; });
    }

    final hasRecorded = await _checkIfRecordedToday();
    if (mounted) {
      setState(() {
        _hasRecordedToday = hasRecorded;
        _isLoading = false;
      });
      if (!hasRecorded) {
        if(_controller == null) _initializeCamera();
      } else {
        await _controller?.dispose();
        _controller = null;
      }
    }
  }

  Future<bool> _checkIfRecordedToday() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return true;

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    try {
      final query = await FirebaseFirestore.instance
          .collection('videos')
          .where('uid', isEqualTo: user.uid)
          .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
          .where('createdAt', isLessThan: endOfDay)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      print("Error checking for today's video: $e");
      return true;
    }
  }

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) return;
    await _controller?.dispose();

    final camera = cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
    );
    try {
      await _controller!.initialize();
      _minZoomLevel = await _controller!.getMinZoomLevel();
      _maxZoomLevel = await _controller!.getMaxZoomLevel();
      _currentZoomLevel = _minZoomLevel;
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  // Made this function async to ensure initialization completes.
  Future<void> _switchCamera() async {
    if (cameras.length > 1 && !_isRecording) {
      _cameraIndex = (_cameraIndex + 1) % cameras.length;
      // Await the re-initialization to make it more robust.
      await _initializeCamera();
    }
  }

  Future<void> _toggleRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      print("Controller not ready");
      return;
    }

    try {
      // Use the controller's state as the source of truth
      if (_controller!.value.isRecordingVideo) {
        // --- STOP RECORDING ---
        final file = await _controller!.stopVideoRecording();
        // Update the UI state after the operation is complete
        setState(() { _isRecording = false; });

        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SaveVideoScreen(videoFile: File(file.path)),
            ),
          );
          // Re-check state after returning from the save screen
          _checkAndInitialize();
        }
      } else {
        // --- START RECORDING ---
        await _controller!.startVideoRecording();
        setState(() { _isRecording = true; });
      }
    } catch (e) {
      print('Error during video recording toggle: $e');
      // If an error occurs, reset the recording state to be safe.
      if (mounted) {
        setState(() { _isRecording = false; });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasRecordedToday) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            "You have already recorded your video for today. Please come back tomorrow.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: Text('Camera is not available.'),
      );
    }

    return GestureDetector(
      onScaleStart: (details) {
        _baseZoomLevel = _currentZoomLevel;
      },
      onScaleUpdate: (details) {
        final newZoomLevel = (_baseZoomLevel * details.scale)
            .clamp(_minZoomLevel, _maxZoomLevel);

        if (newZoomLevel != _currentZoomLevel) {
          _controller!.setZoomLevel(newZoomLevel);
          _currentZoomLevel = newZoomLevel;
        }
      },
      // This empty listener helps the GestureDetector win the gesture arena
      // against the PageView's horizontal swipe.
      onVerticalDragUpdate: (_) {},
      child: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const SizedBox(width: 64),
          GestureDetector(
            onTap: _toggleRecording,
            child: Icon(
              // Use the controller's value to be certain of the recording state
              _controller?.value.isRecordingVideo ?? false
                  ? Icons.stop_circle_outlined
                  : Icons.fiber_manual_record,
              color: Colors.red,
              size: 64,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
            onPressed: _isRecording ? null : _switchCamera,
            iconSize: 32,
          ),
        ],
      ),
    );
  }
}

