import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  // --- Profile Picture Logic ---
  Future<void> _changeProfilePicture() async {
    final imagePicker = ImagePicker();
    final XFile? pickedImage =
        await imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (pickedImage == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not found");

      final file = File(pickedImage.path);
      final ref = _storage.ref().child('profile_pictures').child('${user.uid}.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      await _firestore.collection('users').doc(user.uid).update({
        'profilePicUrl': url,
      });

      if (mounted) {
        _showSuccessSnackBar('Profile picture updated successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to update profile picture: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- Username Logic ---
  void _showChangeUsernameDialog() {
    final usernameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Username'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: usernameController,
            decoration: const InputDecoration(labelText: 'New Username'),
            validator: (value) {
              if (value == null || value.trim().length < 3) {
                return 'Username must be at least 3 characters long.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: const Text('Save'),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop();
                _updateUsername(usernameController.text.trim());
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _updateUsername(String newUsername) async {
    setState(() { _isLoading = true; });
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not found");

      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({'username': newUsername});

      if (mounted) {
        _showSuccessSnackBar('Username updated successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to update username: $e');
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }
  
  // --- Go Premium Logic ---
  void _showGoPremiumDialog() {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Go Premium!'),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unlock exclusive features:'),
                  SizedBox(height: 16),
                  Row(children: [
                    Icon(Icons.video_camera_back, color: Colors.amber),
                    SizedBox(width: 8),
                    Text('Record videos up to 5 minutes')
                  ]),
                  SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.cloud_upload, color: Colors.amber),
                    SizedBox(width: 8),
                    Text('Higher quality uploads')
                  ]),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Maybe Later')),
                ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _upgradeToPremium();
                    },
                    child: const Text('Upgrade Now'))
              ],
            ));
  }

  Future<void> _upgradeToPremium() async {
    setState(() { _isLoading = true; });
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not found");

      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({'isPremium': true});
      
      if(mounted) {
        _showSuccessSnackBar("Congratulations! You are now a Premium member.");
      }
    } catch(e) {
      if (mounted) {
        _showErrorSnackBar('Upgrade failed. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  // --- Change Email Logic ---
  void _showChangeEmailDialog() {
    final passwordController = TextEditingController();
    final newEmailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Change Email'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: newEmailController,
                      decoration: const InputDecoration(labelText: 'New Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) => (value == null || !value.contains('@'))
                          ? 'Please enter a valid email.'
                          : null,
                    ),
                    TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(labelText: 'Current Password'),
                      obscureText: true,
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Please enter your password.'
                          : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        Navigator.of(ctx).pop();
                        _changeEmail(passwordController.text, newEmailController.text);
                      }
                    },
                    child: const Text('Confirm'))
              ],
            ));
  }
  
  Future<void> _changeEmail(String password, String newEmail) async {
    setState(() { _isLoading = true; });
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) throw Exception("User not found");

      final cred = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(cred);
      await user.verifyBeforeUpdateEmail(newEmail);

      if(mounted) {
        _showSuccessSnackBar('Verification email sent to $newEmail.');
      }
    } on FirebaseAuthException catch (e) {
       if (mounted) {
         _showErrorSnackBar(e.message ?? 'An error occurred.');
       }
    } catch (e) {
      if(mounted) {
        _showErrorSnackBar('An unexpected error occurred.');
      }
    } finally {
      if (mounted) { setState(() { _isLoading = false; });}
    }
  }

  // --- Change Password Logic ---
  void _showChangePasswordDialog() {
     final oldPasswordController = TextEditingController();
     final newPasswordController = TextEditingController();
     final confirmPasswordController = TextEditingController();
     final formKey = GlobalKey<FormState>();

     showDialog(context: context, builder: (ctx) => AlertDialog(
       title: const Text('Change Password'),
       content: Form(
         key: formKey,
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
              TextFormField(
                controller: oldPasswordController,
                decoration: const InputDecoration(labelText: 'Old Password'),
                obscureText: true,
                validator: (v) => (v==null || v.isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: newPasswordController,
                decoration: const InputDecoration(labelText: 'New Password'),
                obscureText: true,
                 validator: (v) => (v==null || v.length < 6) ? 'Must be at least 6 characters' : null,
              ),
              TextFormField(
                controller: confirmPasswordController,
                decoration: const InputDecoration(labelText: 'Confirm New Password'),
                obscureText: true,
                validator: (v) => (v != newPasswordController.text) ? 'Passwords do not match' : null,
              )
           ],
         ),
       ),
       actions: [
         TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
         ElevatedButton(onPressed: () {
           if(formKey.currentState!.validate()) {
             Navigator.of(ctx).pop();
             _changePassword(oldPasswordController.text, newPasswordController.text);
           }
         }, child: const Text('Update'))
       ],
     ));
  }

  Future<void> _changePassword(String oldPassword, String newPassword) async {
    setState(() { _isLoading = true; });
    try {
       final user = _auth.currentUser;
       if (user == null || user.email == null) throw Exception("User not found");

       final cred = EmailAuthProvider.credential(email: user.email!, password: oldPassword);
       await user.reauthenticateWithCredential(cred);
       await user.updatePassword(newPassword);

       if(mounted) {
         _showSuccessSnackBar('Password updated successfully.');
       }

    } on FirebaseAuthException catch (e) {
      if(mounted) {
        _showErrorSnackBar(e.message ?? 'An error occurred.');
      }
    } catch (e) {
      if(mounted) {
        _showErrorSnackBar('An unexpected error occurred.');
      }
    } finally {
      if(mounted) { setState(() { _isLoading = false; }); }
    }
  }


  // --- Delete Account Logic ---
  void _showDeleteAccountDialog() {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             const Text('This is permanent. To continue, please enter your password.'),
             TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password'),)
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete My Account'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteAccount(passwordController.text);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(String password) async {
    setState(() { _isLoading = true; });
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) throw Exception("User not found");
      
      final cred = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(cred);
      
      // Add logic here to delete user's data from Firestore/Storage if needed
      await _firestore.collection('users').doc(user.uid).delete();
      await user.delete();

      if(mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        _showSuccessSnackBar('Account deleted successfully.');
      }

    } on FirebaseAuthException catch (e) {
      if(mounted) {
        _showErrorSnackBar(e.message ?? 'An error occurred.');
      }
    } catch(e) {
      if(mounted) {
        _showErrorSnackBar('An unexpected error occurred.');
      }
    } finally {
      if(mounted) { setState(() { _isLoading = false; }); }
    }
  }


  // --- Helper and SnackBar Functions ---
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.green, content: Text(message)));
  }

  void _showErrorSnackBar(String message) {
     ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: user != null ? _firestore.collection('users').doc(user.uid).snapshots() : null,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !_isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final userData = snapshot.data?.data() as Map<String, dynamic>?;
              final bool isPremium = userData?['isPremium'] ?? false;

              return ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.account_circle),
                    title: const Text('Change Profile Picture'),
                    onTap: _changeProfilePicture,
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('Change Username'),
                    onTap: _showChangeUsernameDialog,
                  ),
                  const Divider(),
                  if(isPremium)
                    const ListTile(
                      leading: Icon(Icons.star, color: Colors.amber),
                      title: Text('Premium Member'),
                      subtitle: Text('You have access to all premium features!'),
                    )
                  else
                    ListTile(
                      leading: const Icon(Icons.star_outline),
                      title: const Text('Go Premium'),
                      subtitle: const Text('Unlock 5-minute videos and more features'),
                      onTap: _showGoPremiumDialog,
                    ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: const Text('Change Email'),
                    onTap: _showChangeEmailDialog,
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock),
                    title: const Text('Change Password'),
                    onTap: _showChangePasswordDialog,
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.delete_forever, color: Colors.red.shade700),
                    title: Text(
                      'Delete Account',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                    onTap: _showDeleteAccountDialog,
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Sign Out'),
                    onTap: () {
                      FirebaseAuth.instance.signOut();
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                  ),
                ],
              );
            }
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

