import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'wardrobeCategory.dart';
import 'package:drobe/settings/profile.dart';
import 'package:drobe/settings/profileAvatar.dart';
import 'package:drobe/auth/authService.dart';
import 'wardrobeTheme.dart';

class WardrobePage extends StatefulWidget {
  const WardrobePage({super.key});

  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> {
  Key _avatarKey =
      ValueKey('wardrobe_avatar_${DateTime.now().millisecondsSinceEpoch}');

  final List<String> _categories = const [
    'LAYERS',
    'SHIRTS',
    'BOTTOMS',
    'SHOES',
    'ACCESSORIES',
  ];

  final Map<String, String> _categoryIcons = const {
    'LAYERS': 'assets/icons/streamline/layer.png',
    'SHIRTS': 'assets/icons/streamline/t-shirt.png',
    'BOTTOMS': 'assets/icons/streamline/bottoms.png',
    'SHOES': 'assets/icons/streamline/shoes.png',
    'ACCESSORIES': 'assets/icons/streamline/accessories.png',
  };

  void _refreshAvatar() {
    setState(() {
      _avatarKey =
          ValueKey('wardrobe_avatar_${DateTime.now().millisecondsSinceEpoch}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WardrobeTheme.pageBackground,
      appBar: AppBar(
        backgroundColor: WardrobeTheme.pageBackground,
        foregroundColor: WardrobeTheme.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleSpacing: 0,
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('EDIT / CURATE / WEAR', style: WardrobeTheme.eyebrow),
            SizedBox(height: 2),
            Text('YOUR WARDROBE', style: WardrobeTheme.appBarTitle),
          ],
        ),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                ).then((_) => _refreshAvatar());
              },
              child: FutureBuilder<Map<String, String>>(
                future: AuthService().getCurrentUser(),
                builder: (context, snapshot) {
                  final userData =
                      snapshot.data ?? {'id': '', 'name': '', 'email': ''};
                  return Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: WardrobeTheme.line, width: 1),
                    ),
                    child: ProfileAvatar(
                      key: _avatarKey,
                      size: 40,
                      userId: userData['id'] ?? '',
                      name: userData['name'] ?? '',
                      email: userData['email'] ?? '',
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 760;
              final categorySpacing = compact ? 8.0 : 10.0;
              final sectionSpacing = compact ? 14.0 : 18.0;

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCapsuleWardrobeBanner(compact: compact),
                    SizedBox(height: sectionSpacing),
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 1,
                          color: WardrobeTheme.accent,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'CATEGORIES',
                          style: WardrobeTheme.sectionLabel,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ..._categories.map(
                      (category) => Padding(
                        padding: EdgeInsets.only(bottom: categorySpacing),
                        child: _buildCategoryTile(context, category),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCapsuleWardrobeBanner({required bool compact}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18, 18, 18, compact ? 16 : 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        image: const DecorationImage(
          image: NetworkImage(
            'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=1400&q=80',
          ),
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF4A392D).withValues(alpha: 0.62),
              const Color(0xFF7A604B).withValues(alpha: 0.38),
              const Color(0xFF2C211B).withValues(alpha: 0.76),
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, compact ? 16 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: const Text(
                  'EDITORIAL PICK',
                  style: TextStyle(
                    fontFamily: 'BarlowCondensed',
                    fontSize: 10.5,
                    letterSpacing: 1.7,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: compact ? 20 : 24),
              Text(
                compact
                    ? 'Build a capsule wardrobe\nthat feels personal'
                    : 'Build a capsule wardrobe\nthat still feels personal',
                style: TextStyle(
                  fontFamily: 'BarlowCondensed',
                  fontSize: compact ? 27 : 30,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.2,
                  height: 0.96,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: compact ? 8 : 10),
              Text(
                'Refine the pieces you actually wear and shape a wardrobe with more clarity, less noise, and better daily combinations.',
                maxLines: compact ? 3 : 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 12.2 : 13.0,
                  height: 1.42,
                  color: Colors.white.withValues(alpha: 0.84),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTile(BuildContext context, String category) {
    final iconPath =
        _categoryIcons[category] ?? 'assets/icons/streamline/layer.png';

    return Material(
      color: WardrobeTheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WardrobeCategoryPage(category: category),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: WardrobeTheme.line),
          ),
          alignment: Alignment.center,
          child: Text(
            category,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'BarlowCondensed',
              fontSize: 18,
              fontWeight: FontWeight.w300,
              letterSpacing: 0.25,
              color: WardrobeTheme.ink,
            ),
          ),
        ),
      ),
    );
  }
}
