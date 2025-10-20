import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:digital_diary/screens/profile_screen.dart';
import 'package:digital_diary/widgets/video_player_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PublicVideoCard extends StatefulWidget {
  // --- FIX: Added videoId as a required parameter ---
  final String videoId;
  final Map<String, dynamic> videoData;

  const PublicVideoCard({
    super.key,
    required this.videoId,
    required this.videoData,
  });
  // --- END FIX ---

  @override
  State<PublicVideoCard> createState() => _PublicVideoCardState();
}

class _PublicVideoCardState extends State<PublicVideoCard> {
  late List<String> _likes;
  late bool _isLiked;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    // Initialize from the widget data
    _likes = List<String>.from(widget.videoData['likes'] ?? []);
    _likeCount = _likes.length;
    final currentUser = FirebaseAuth.instance.currentUser;
    _isLiked = currentUser != null ? _likes.contains(currentUser.uid) : false;
  }

  Future<void> _toggleLike() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Optionally show a message to log in
      return;
    }

    final videoRef =
        FirebaseFirestore.instance.collection('videos').doc(widget.videoId);

    // Optimistically update the UI
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        _likeCount++;
      } else {
        _likeCount--;
      }
    });

    // Update the backend
    try {
      if (_isLiked) {
        await videoRef.update({
          'likes': FieldValue.arrayUnion([currentUser.uid])
        });
      } else {
        await videoRef.update({
          'likes': FieldValue.arrayRemove([currentUser.uid])
        });
      }
    } catch (e) {
      // If the backend update fails, revert the UI change
      setState(() {
        _isLiked = !_isLiked;
        if (_isLiked) {
          _likeCount++;
        } else {
          _likeCount--;
        }
      });
      print("Error updating likes: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final String creatorUid = widget.videoData['uid'];
    final String username = widget.videoData['username'] ?? 'Anonymous';
    final String profilePicUrl = widget.videoData['profilePicUrl'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundImage:
                  profilePicUrl.isNotEmpty ? NetworkImage(profilePicUrl) : null,
              child: profilePicUrl.isEmpty ? const Icon(Icons.person) : null,
            ),
            title:
                Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(userId: creatorUid),
                ),
              );
            },
          ),
          VideoPlayerItem(videoUrl: widget.videoData['videoUrl']),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        color: _isLiked ? Colors.red : Colors.grey,
                      ),
                      onPressed: _toggleLike,
                    ),
                    Text('$_likeCount likes'),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    widget.videoData['title'] ?? 'No Title',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

