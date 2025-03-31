import 'package:flutter/material.dart';
import 'package:drobe/settings/profile.dart';
import 'fabricTipDetail.dart';
import 'package:drobe/models/fabricModel.dart';
import 'package:drobe/settings/profileAvatar.dart';
import 'package:drobe/auth/authService.dart';

class FabricTipsPage extends StatefulWidget {
  const FabricTipsPage({Key? key}) : super(key: key);

  @override
  State<FabricTipsPage> createState() => _FabricTipsPageState();
}

class _FabricTipsPageState extends State<FabricTipsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _isLoading = false;

  // List of available categories
  final List<String> _categories = [
    'All',
    'Cotton',
    'Wool',
    'Silk',
    'Synthetic',
    'Denim',
    'Leather',
    'Linen',
    'Cashmere',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Filter tips based on search query and selected category
  List<FabricTip> get filteredTips {
    return fabricTips.where((tip) {
      // Filter by search query
      final matchesSearch = _searchQuery.isEmpty ||
          tip.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          tip.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          tip.content.toLowerCase().contains(_searchQuery.toLowerCase());

      // Filter by category
      final matchesCategory = _selectedCategory == 'All' ||
          tip.categories.contains(_selectedCategory.toLowerCase());

      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FABRIC TIPS',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfilePage()),
                ).then((_) {
                  // Refresh when returning from profile page
                  setState(() {});
                });
              },
              child: FutureBuilder<Map<String, String>>(
                future: AuthService().getCurrentUser(),
                builder: (context, snapshot) {
                  final userData = snapshot.data ?? {'id': '', 'name': '', 'email': ''};
                  return ProfileAvatar(
                    key: ValueKey('outfits_avatar_${DateTime.now().millisecondsSinceEpoch}'),
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
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search fabric tips',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // Category filter
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    backgroundColor: Colors.grey[300],
                    selectedColor: Colors.grey[400],
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                  ),
                );
              },
            ),
          ),

          // Tips list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredTips.isEmpty
                ? _buildEmptyState()
                : _buildTipsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No fabric tips found',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          if (_searchQuery.isNotEmpty || _selectedCategory != 'All')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _selectedCategory = 'All';
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black,
                ),
                child: const Text('Clear filters'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTipsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredTips.length,
      itemBuilder: (context, index) {
        final tip = filteredTips[index];
        return _buildTipCard(tip);
      },
    );
  }

  Widget _buildTipCard(FabricTip tip) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FabricTipDetailPage(tip: tip),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              child: Image.network(
                tip.imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 180,
                  width: double.infinity,
                  color: Colors.grey[200],
                  child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    tip.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    tip.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Categories
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tip.categories.map((category) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[800],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

