import 'package:digital_diary/widgets/video_player_item.dart';
import 'package:flutter/material.dart';

class FullscreenVideoScreen extends StatelessWidget {
  final String videoUrl;

  const FullscreenVideoScreen({super.key, required this.videoUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: VideoPlayerItem(videoUrl: videoUrl),
      ),
    );
  }
}