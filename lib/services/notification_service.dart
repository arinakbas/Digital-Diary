    import 'package:cloud_firestore/cloud_firestore.dart';
    import 'package:firebase_auth/firebase_auth.dart';
    import 'package:firebase_messaging/firebase_messaging.dart';

    class NotificationService {
      final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

      Future<void> initialize() async {
        // Request permission from the user
        await _firebaseMessaging.requestPermission();

        // Get the unique device token
        final fcmToken = await _firebaseMessaging.getToken();

        if (fcmToken != null) {
          print('FCM Token: $fcmToken');
          await _saveTokenToDatabase(fcmToken);
        }

        // Listen for token refreshes and save them
        _firebaseMessaging.onTokenRefresh.listen(_saveTokenToDatabase);
      }

      Future<void> _saveTokenToDatabase(String token) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        // Save the token to the user's document in Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          // Using FieldValue.arrayUnion ensures no duplicate tokens are saved
          'fcmTokens': FieldValue.arrayUnion([token]),
        });
      }
    }
    
