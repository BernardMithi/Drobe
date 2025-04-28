import 'package:flutter/material.dart';
import 'wardrobeCategory.dart';
import 'package:drobe/settings/profile.dart'; // Correct import for ProfilePage
import 'package:drobe/settings/profileAvatar.dart';
import 'package:drobe/auth/authService.dart';
import 'package:drobe/models/fabricModel.dart';
import 'package:drobe/Fabrics/fabricTipDetail.dart';

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
            _buildCapsuleWardrobeBanner(context),
            const SizedBox(height: 5),
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

  Widget _buildCapsuleWardrobeBanner(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FabricTipDetailPage(tip: fabricTips.firstWhere((tip) => tip.id == '9')),
          ),
        );
      },
      child: Container(
        height: 110,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(2),
          image: DecorationImage(
            image: const NetworkImage(
              'https://images.unsplash.com/photo-1560243563-062bfc001d68?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1000&q=80',
            ),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.white.withOpacity(0.85),
              BlendMode.lighten,
            ),
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.1),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'CAPSULE WARDROBE TIPS',
                    style: TextStyle(
                      fontFamily: 'Avenir',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Quality over quantity: Create a versatile collection',
                    style: TextStyle(
                      fontFamily: 'Avenir',
                      fontSize: 14,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Icon(
                    Icons.arrow_forward,
                    size: 20,
                    color: Colors.grey[800],
                  ),
                ],
              ),
            ),
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
          minimumSize: const Size.fromHeight(100),
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
