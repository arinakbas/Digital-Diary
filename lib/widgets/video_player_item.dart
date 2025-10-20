import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerItem extends StatefulWidget {
  final String videoUrl;
  final bool isLocalFile;
  // This new onTap callback allows us to customize the tap behavior from outside.
  final VoidCallback? onTap;

  const VideoPlayerItem({
    super.key,
    required this.videoUrl,
    this.isLocalFile = false,
    this.onTap,
  });

  @override
  State<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<VideoPlayerItem> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.isLocalFile
        ? VideoPlayerController.asset(widget.videoUrl)
        : VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));

    _controller.initialize().then((_) {
      if (mounted) {
        setState(() {});
      }
    });

    _controller.addListener(() {
      final isCurrentlyPlaying = _controller.value.isPlaying;
      if (_isPlaying != isCurrentlyPlaying) {
        if (mounted) {
          setState(() {
            _isPlaying = isCurrentlyPlaying;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      // THE FIX: If an onTap is provided, use it. Otherwise, fall back to play/pause.
      onTap: widget.onTap ?? _togglePlay,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          // Only show the play icon if the custom onTap is NOT present (i.e., we are in full-screen mode)
          if (!_isPlaying && widget.onTap == null)
            Icon(
              Icons.play_arrow,
              color: Colors.white.withOpacity(0.7),
              size: 60,
            ),
          // If a custom onTap IS present (i.e., we are on the profile page), show a fullscreen icon
           if (widget.onTap != null)
            const Icon(
              Icons.fullscreen,
              color: Colors.white70,
              size: 40,
            ),
        ],
      ),
    );
  }
}

