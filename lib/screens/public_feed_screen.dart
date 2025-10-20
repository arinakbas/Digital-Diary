import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:digital_diary/widgets/public_video_card.dart';
import 'package:flutter/material.dart';

class PublicFeedScreen extends StatefulWidget {
  const PublicFeedScreen({super.key});

  @override
  State<PublicFeedScreen> createState() => _PublicFeedScreenState();
}

class _PublicFeedScreenState extends State<PublicFeedScreen> {
  @override
  Widget build(BuildContext context) {
    // Calculate the timestamp for 48 hours ago
    final fortyEightHoursAgo =
        DateTime.now().subtract(const Duration(hours: 48));
    final timestamp48hAgo = Timestamp.fromDate(fortyEightHoursAgo);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Public Feed'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Query to get public videos from the last 48 hours
        stream: FirebaseFirestore.instance
            .collection('videos')
            .where('isPublic', isEqualTo: true)
            .where('createdAt', isGreaterThanOrEqualTo: timestamp48hAgo)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            // This will likely be an index error at first
            return Center(
                child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                  'Error: ${snapshot.error}\n\nThis probably requires a new Firestore index. Check the debug console for a link to create it.',
                  textAlign: TextAlign.center),
            ));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No public videos in the last 48 hours.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          final videoDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: videoDocs.length,
            itemBuilder: (context, index) {
              final videoData =
                  videoDocs[index].data() as Map<String, dynamic>;
              final videoId = videoDocs[index].id;
              return PublicVideoCard(
                videoData: videoData,
                videoId: videoId,
              );
            },
          );
        },
      ),
    );
  }
}

