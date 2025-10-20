import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:digital_diary/widgets/video_player_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PrivateDiaryScreen extends StatefulWidget {
  const PrivateDiaryScreen({super.key});

  @override
  State<PrivateDiaryScreen> createState() => _PrivateDiaryScreenState();
}

class _PrivateDiaryScreenState extends State<PrivateDiaryScreen> {
  // --- NEW: A future that completes once we have a validated user ---
  late Future<User?> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = _getValidatedUser();
  }

  Future<User?> _getValidatedUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // This is the key step: it forces a token refresh and waits for it.
      await user.getIdToken(true);
    }
    // Return the user object after the token is guaranteed to be fresh.
    return FirebaseAuth.instance.currentUser;
  }
  // --- END NEW ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Diary'),
        automaticallyImplyLeading: false,
      ),
      // --- MODIFIED: Use a FutureBuilder to wait for the user ---
      body: FutureBuilder<User?>(
        future: _userFuture,
        builder: (context, userSnapshot) {
          // While waiting for the user validation, show a loading spinner.
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // If there's no user data after waiting, show a message.
          if (!userSnapshot.hasData || userSnapshot.data == null) {
            return const Center(
                child: Text("Not logged in. Please restart the app."));
          }

          // Once we have a validated user, we can build the list.
          final user = userSnapshot.data!;

          // This StreamBuilder will now only run AFTER the user is validated.
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('videos')
                .where('uid', isEqualTo: user.uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text("You haven't recorded any videos yet."),
                );
              }

              final videoDocs = snapshot.data!.docs;

              return ListView.builder(
                itemCount: videoDocs.length,
                itemBuilder: (context, index) {
                  final videoData =
                      videoDocs[index].data() as Map<String, dynamic>;
                  final Timestamp timestamp =
                      videoData['createdAt'] ?? Timestamp.now();
                  final date = timestamp.toDate();
                  final formattedDate = DateFormat.yMMMMd().add_jm().format(date);

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            formattedDate,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey),
                          ),
                        ),
                        VideoPlayerItem(videoUrl: videoData['videoUrl']),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            videoData['title'] ?? 'No Title',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      // --- END MODIFICATION ---
    );
  }
}

