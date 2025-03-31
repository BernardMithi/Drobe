import 'package:flutter/material.dart';
import 'wardrobeCategory.dart';
import 'package:drobe/settings/profile.dart'; // Correct import for ProfilePage
import 'package:drobe/settings/profileAvatar.dart';
import 'package:drobe/auth/authService.dart';

class WardrobePage extends StatefulWidget { // Changed to StatefulWidget
  const WardrobePage({super.key});

  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> {
  // Key to force refresh of the avatar
  Key _avatarKey = ValueKey('wardrobe_avatar_${DateTime.now().millisecondsSinceEpoch}');

  void _refreshAvatar() {
    setState(() {
      _avatarKey = ValueKey('wardrobe_avatar_${DateTime.now().millisecondsSinceEpoch}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
            'YOUR WARDROBE',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                ).then((_) {
                  // Refresh when returning from profile page
                  _refreshAvatar();
                });
              },
              child: FutureBuilder<Map<String, String>>(
                future: AuthService().getCurrentUser(),
                builder: (context, snapshot) {
                  final userData = snapshot.data ?? {'id': '', 'name': '', 'email': ''};
                  return ProfileAvatar(
                    key: _avatarKey,
                    size: 42,
                    userId: userData['id'] ?? '',
                    name: userData['name'] ?? '',
                    email: userData['email'] ?? '',
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildCategoryButton(context, 'LAYERS'),
            _buildCategoryButton(context, 'SHIRTS'),
            _buildCategoryButton(context, 'BOTTOMS'),
            _buildCategoryButton(context, 'SHOES'),
            _buildCategoryButton(context, 'ACCESSORIES'),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryButton(BuildContext context, String category) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: OutlinedButton(
        onPressed: () {
          // Navigate to WardrobeCategoryPage with category name
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WardrobeCategoryPage(category: category),
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(120),
          side: const BorderSide(color: Colors.grey),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ),
        child: Text(
          category,
          style: const TextStyle(
            fontFamily: 'Avenir',
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

