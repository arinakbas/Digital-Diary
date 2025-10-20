import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:digital_diary/widgets/video_player_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:video_compress/video_compress.dart';

class SaveVideoScreen extends StatefulWidget {
  final File videoFile;
  const SaveVideoScreen({super.key, required this.videoFile});

  @override
  State<SaveVideoScreen> createState() => _SaveVideoScreenState();
}

class _SaveVideoScreenState extends State<SaveVideoScreen> {
  final _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPublic = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  UploadTask? _uploadTask;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _uploadVideo() async {
    print("--- UPLOAD PROCESS STARTED ---");
    if (!_formKey.currentState!.validate()) {
      print("[DEBUG] Form validation failed.");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("[DEBUG] ERROR: User is not logged in.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            backgroundColor: Colors.red,
            content: Text('Error: You are not logged in.')),
      );
      return;
    }
    final currentUserId = user.uid;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      // 1. COMPRESSION
      print("[DEBUG] Step 1: Starting video compression...");
      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        widget.videoFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
      );

      if (mediaInfo == null || mediaInfo.path == null) {
        throw Exception('Video compression returned null.');
      }
      final compressedFile = File(mediaInfo.path!);
      final fileSize = await compressedFile.length();
      print("[DEBUG] Step 1 COMPLETE: Compression finished. New file size: $fileSize bytes");

      // 2. UPLOAD TO FIREBASE STORAGE
      print("[DEBUG] Step 2: Preparing to upload to Firebase Storage...");
      final storageRef = FirebaseStorage.instance.ref();
      final videosRef = storageRef.child(
          'videos/$currentUserId/${DateTime.now().millisecondsSinceEpoch}.mp4');

      _uploadTask = videosRef.putFile(compressedFile);
      print("[DEBUG] Step 2 IN PROGRESS: Upload task started.");

      _uploadTask!.snapshotEvents.listen((taskSnapshot) {
        final progress = taskSnapshot.bytesTransferred / taskSnapshot.totalBytes;
        setState(() {
          _uploadProgress = progress;
        });
      });

      final snapshot = await _uploadTask!;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print("[DEBUG] Step 2 COMPLETE: File uploaded. Download URL: $downloadUrl");

      // 3. GET USER DATA
      print("[DEBUG] Step 3: Fetching user data from Firestore...");
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      final username = userDoc.data()?['username'] ?? 'Anonymous';
      final profilePicUrl = userDoc.data()?['profilePicUrl'] ?? '';
      print("[DEBUG] Step 3 COMPLETE: Fetched user data.");

      // 4. SAVE TO FIRESTORE
      print("[DEBUG] Step 4: Saving video metadata to Firestore...");
      await FirebaseFirestore.instance.collection('videos').add({
        'uid': currentUserId,
        'username': username,
        'profilePicUrl': profilePicUrl,
        'title': _titleController.text,
        'videoUrl': downloadUrl,
        'isPublic': _isPublic,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [],
      });
      print("[DEBUG] Step 4 COMPLETE: Firestore document created.");
      print("--- UPLOAD PROCESS SUCCEEDED ---");

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Video uploaded successfully!')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      print("[DEBUG] AN ERROR OCCURRED: $e");
      print("--- UPLOAD PROCESS FAILED ---");
      setState(() {
        _isUploading = false;
        _uploadTask = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: Colors.red,
              content: Text('Upload failed: ${e.toString()}')),
        );
      }
    }
  }

  void _cancelUpload() {
    _uploadTask?.cancel();
    setState(() {
      _isUploading = false;
      _uploadTask = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Save Your Diary Entry'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 300,
                child: VideoPlayerItem(
                  videoUrl: widget.videoFile.path,
                  isLocalFile: true,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Make this video public?'),
                subtitle: const Text('Anyone will be able to see and like it.'),
                value: _isPublic,
                onChanged: (value) {
                  setState(() {
                    _isPublic = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              if (_isUploading)
                Column(
                  children: [
                    LinearProgressIndicator(value: _uploadProgress),
                    const SizedBox(height: 8),
                    Text(
                        'Uploading... ${(_uploadProgress * 100).toStringAsFixed(0)}%'),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel'),
                      onPressed: _cancelUpload,
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ],
                )
              else
                ElevatedButton.icon(
                  onPressed: _uploadVideo,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Save & Upload'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

