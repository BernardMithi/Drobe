import 'package:flutter/material.dart';
import 'package:drobe/models/fabricModel.dart';
import 'package:drobe/Fabrics/fabricTipDetail.dart';

class FabricTipsPage extends StatefulWidget {
  const FabricTipsPage({Key? key}) : super(key: key);

  @override
  State<FabricTipsPage> createState() => _FabricTipsPageState();
}

class _FabricTipsPageState extends State<FabricTipsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<String> _selectedCategories = [];

  final List<String> _allCategories = [
    'cotton',
    'wool',
    'silk',
    'denim',
    'synthetic',
    'leather',
    'linen',
    'cashmere',
    'care',
    'washing',
    'sustainability',
    'capsule wardrobe'
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FabricTip> get filteredTips {
    return fabricTips.where((tip) {
      // Filter by search query
      final matchesQuery = _searchQuery.isEmpty ||
          tip.title.toLowerCase().contains(_searchQuery) ||
          tip.description.toLowerCase().contains(_searchQuery) ||
          tip.content.toLowerCase().contains(_searchQuery);

      // Filter by selected categories
      final matchesCategories = _selectedCategories.isEmpty ||
          tip.categories
              .any((category) => _selectedCategories.contains(category));

      return matchesQuery && matchesCategories;
    }).toList();
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FABRIC TIPS',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w300),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                fontFamily: 'BarlowCondensed',
                fontSize: 16,
                fontWeight: FontWeight.w300,
              ),
              decoration: InputDecoration(
                hintText: 'Search tips...',
                hintStyle: const TextStyle(
                  fontFamily: 'BarlowCondensed',
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  color: Color(0xFFBDB5AB),
                ),
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFFBDB5AB)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFEAE4DC)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFEAE4DC)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF8A847D)),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // Category filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: _allCategories.map((category) {
                  final isSelected = _selectedCategories.contains(category);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => _toggleCategory(category),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF1F1A17) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF1F1A17) : const Color(0xFFDED8CF),
                          ),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontFamily: 'BarlowCondensed',
                            fontSize: 14,
                            fontWeight: FontWeight.w300,
                            color: isSelected ? Colors.white : const Color(0xFF5F5A54),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
            ),
          ),

          // Tips list
          Expanded(
            child: filteredTips.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No fabric tips found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search or filters',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: filteredTips.length,
                    itemBuilder: (context, index) {
                      final tip = filteredTips[index];
                      return _buildTipCard(context, tip, featured: index == 0);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(BuildContext context, FabricTip tip, {bool featured = false}) {
    final imageHeight = featured ? 220.0 : 160.0;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FabricTipDetailPage(tip: tip),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Full-width image
            SizedBox(
              height: imageHeight,
              width: double.infinity,
              child: Image.network(
                tip.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFF2EEE8),
                  child: const Center(
                    child: Icon(Icons.image_not_supported, size: 36, color: Color(0xFFBDB5AB)),
                  ),
                ),
              ),
            ),
            // Content below image
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tip.categories.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        tip.categories.first.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'BarlowCondensed',
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 1.8,
                          color: Color(0xFFAD8B72),
                        ),
                      ),
                    ),
                  Text(
                    tip.title,
                    style: TextStyle(
                      fontFamily: 'BarlowCondensed',
                      fontSize: featured ? 22 : 19,
                      fontWeight: FontWeight.w300,
                      color: const Color(0xFF1C1A18),
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tip.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8A847D),
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (tip.categories.length > 1) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ...tip.categories.skip(1).take(2).map((cat) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2EEE8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              cat,
                              style: const TextStyle(
                                fontFamily: 'BarlowCondensed',
                                fontSize: 12,
                                fontWeight: FontWeight.w300,
                                color: Color(0xFF7A736B),
                              ),
                            ),
                          ),
                        )),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
