import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:digital_diary/screens/fullscreen_video_screen.dart';
import 'package:digital_diary/widgets/video_player_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart'; // Import the intl package for date formatting

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _changeProfilePicture() async {
    // This function will only be callable if the edit button is visible.
    final imagePicker = ImagePicker();
    final XFile? pickedImage =
        await imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (pickedImage == null) return;

    try {
      final file = File(pickedImage.path);
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('${widget.userId}.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'profilePicUrl': url});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change picture: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the current user's ID
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    // Check if the profile being viewed belongs to the current user
    final bool isMyProfile = widget.userId == currentUserId;

    return Scaffold(
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(widget.userId).get(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!userSnapshot.hasData || userSnapshot.data == null) {
            return const Center(child: Text('User not found.'));
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          final profilePicUrl = userData['profilePicUrl'] as String?;
          final username = userData['username'] ?? 'Anonymous';

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250.0,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(username),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                       if (profilePicUrl != null && profilePicUrl.isNotEmpty)
                        Image.network(
                          profilePicUrl,
                          fit: BoxFit.cover,
                        ),
                       // Add a gradient so the title is readable
                       const DecoratedBox(
                         decoration: BoxDecoration(
                           gradient: LinearGradient(
                             begin: Alignment.topCenter,
                             end: Alignment.bottomCenter,
                             colors: [Colors.transparent, Colors.black54],
                           )
                         )
                       )
                    ],
                  ),
                ),
                actions: [
                   // Only show the edit button if it's the user's own profile
                  if (isMyProfile)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: _changeProfilePicture,
                      tooltip: 'Change Profile Picture',
                    )
                ],
              ),
              SliverToBoxAdapter(
                 child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    "Public Videos", 
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('videos')
                    .where('uid', isEqualTo: widget.userId)
                    .where('isPublic', isEqualTo: true)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, videoSnapshot) {
                  if (videoSnapshot.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
                  }
                  if (!videoSnapshot.hasData || videoSnapshot.data!.docs.isEmpty) {
                    return const SliverToBoxAdapter(child: Center(child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text('This user has no public videos.'),
                    )));
                  }

                  final videos = videoSnapshot.data!.docs;

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final videoData = videos[index].data() as Map<String, dynamic>;
                        final videoUrl = videoData['videoUrl'];
                        final videoTitle = videoData['title'] ?? 'Untitled Video';
                        final timestamp = videoData['createdAt'] as Timestamp?;
                        String formattedDate = 'Date not available';
                        if (timestamp != null) {
                           // Note: Ensure you have the 'intl' package in your pubspec.yaml for this formatting
                          formattedDate = DateFormat.yMMMMd().format(timestamp.toDate());
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          clipBehavior: Clip.antiAlias,
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Stack(
                            alignment: Alignment.bottomLeft,
                            children: [
                              VideoPlayerItem(
                                videoUrl: videoUrl,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FullscreenVideoScreen(videoUrl: videoUrl),
                                    ),
                                  );
                                },
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.center,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                     Text(
                                      formattedDate,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      videoTitle,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        shadows: [Shadow(blurRadius: 2, color: Colors.black54)],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: videos.length,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

