import 'package:camera/camera.dart';
// Using relative paths for local screens to ensure they are found correctly.
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// A global variable to hold the list of available cameras.
List<CameraDescription> cameras = [];

void main() async {
  // Ensure all Flutter bindings are initialized before doing async work.
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Initialize Firebase.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Firebase App Check for security.
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.appAttest,
    );

    // Fetch the available cameras from the device.
    cameras = await availableCameras();
  } catch (e) {
    // If initialization fails, print an error.
    print('Failed to initialize Firebase or cameras: $e');
  }
  // Run the main application widget.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Diary',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // The home property determines the first screen shown.
      // We use a StreamBuilder to listen to authentication changes.
      home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (ctx, userSnapshot) {
          // If the connection is still waiting, show a loading spinner.
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          // If the snapshot has user data, it means the user is logged in.
          if (userSnapshot.hasData) {
            // Show the HomeScreen.
            return const HomeScreen();
          }
          // If there is no user data, show the LoginScreen.
          return const LoginScreen();
        },
      ),
    );
  }
}

