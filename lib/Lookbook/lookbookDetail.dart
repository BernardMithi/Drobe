import 'dart:io';
import 'package:flutter/material.dart';
import 'package:drobe/models/lookbookItem.dart';
import 'package:drobe/services/lookbookStorage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'addLookbookItem.dart';
import 'package:drobe/theme/drobe_icon.dart';

class LookbookDetailPage extends StatefulWidget {
  final String id;

  const LookbookDetailPage({Key? key, required this.id}) : super(key: key);

  @override
  State<LookbookDetailPage> createState() => _LookbookDetailPageState();
}

class _TwoLineMenuIcon extends StatelessWidget {
  const _TwoLineMenuIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 14,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 18,
            height: 2,
            decoration: BoxDecoration(
              color: const Color(0xFF242424),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 12,
            height: 2,
            decoration: BoxDecoration(
              color: const Color(0xFF242424),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class _LookbookDetailPageState extends State<LookbookDetailPage> {
  LookbookItem? _item;
  bool _isLoading = true;
  String? _resolvedImagePath;
  List<LookbookItem> _similarItems = [];
  final Map<String, String?> _similarPaths = {};

  @override
  void initState() {
    super.initState();
    _loadItem();
  }

  Future<void> _loadItem() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final item = await LookbookStorageService.getItem(widget.id);

      if (item != null && item.imageUrl != null) {
        _resolvedImagePath = await _resolveFilePath(item.imageUrl!);
      }

      setState(() {
        _item = item;
        _isLoading = false;
      });

      if (item != null) {
        _loadSimilarItems(item);
      }
    } catch (e) {
      print('Error loading lookbook item: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSimilarItems(LookbookItem current) async {
    try {
      final all = await LookbookStorageService.getAllItems();
      final currentTags = current.tags.map((t) => t.toLowerCase()).toSet();

      final similar = all.where((item) {
        if (item.id == current.id) return false;
        if (currentTags.isEmpty) return false;
        return item.tags.any((t) => currentTags.contains(t.toLowerCase()));
      }).toList();

      // Sort by most shared tags
      similar.sort((a, b) {
        final aShared = a.tags.where((t) => currentTags.contains(t.toLowerCase())).length;
        final bShared = b.tags.where((t) => currentTags.contains(t.toLowerCase())).length;
        return bShared.compareTo(aShared);
      });

      // Resolve paths for each
      for (final item in similar) {
        if (item.imageUrl != null) {
          _similarPaths[item.id!] = await _resolveFilePath(item.imageUrl!);
        }
      }

      if (mounted) {
        setState(() {
          _similarItems = similar;
        });
      }
    } catch (e) {
      print('Error loading similar items: $e');
    }
  }

  Future<String?> _resolveFilePath(String imagePath) async {
    try {
      // If it's a network image, return as is
      if (imagePath.startsWith('http')) {
        return imagePath;
      }

      // Try to use the path directly first
      if (await File(imagePath).exists()) {
        return imagePath;
      }

      // Get the app's documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = path.basename(imagePath);

      // Try to find the file in various directories
      final List<String> possiblePaths = [
        imagePath,
        path.join(appDir.path, fileName),
        path.join(appDir.path, 'wardrobe_images', fileName),
        path.join(appDir.path, 'lookbook_images', fileName),
      ];

      for (final possiblePath in possiblePaths) {
        if (await File(possiblePath).exists()) {
          return possiblePath;
        }
      }

      print('Could not resolve path for: $imagePath');
      return null;
    } catch (e) {
      print('Error resolving path: $e');
      return null;
    }
  }

  Future<void> _deleteItem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Inspiration'),
        content:
            const Text('Are you sure you want to delete this inspiration?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && _item != null) {
      try {
        await LookbookStorageService.deleteItem(_item!.id!);
        if (mounted) {
          Navigator.pop(context, true); // Pop with refresh flag
        }
      } catch (e) {
        print('Error deleting lookbook item: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting item: $e')),
          );
        }
      }
    }
  }

  void _shareItem() async {
    if (_item == null) return;

    try {
      String message = 'Check out this outfit inspiration: ${_item!.name}';

      if (_item!.notes != null && _item!.notes!.isNotEmpty) {
        message += '\n\n${_item!.notes}';
      }

      if (_item!.source != null && _item!.source!.isNotEmpty) {
        message += '\n\nSource: ${_item!.source}';
      }

      // Show a simple share dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Share'),
          content: Text('This would share: $message'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error sharing: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF242424),
          elevation: 0,
          title: const Text(
            'LOOKBOOK',
            style: TextStyle(
              fontFamily: 'BarlowCondensed',
              fontSize: 20,
              fontWeight: FontWeight.w300,
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_item == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF242424),
          elevation: 0,
          title: const Text(
            'LOOKBOOK',
            style: TextStyle(
              fontFamily: 'BarlowCondensed',
              fontSize: 20,
              fontWeight: FontWeight.w300,
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(
          child: Text('Item not found'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF242424),
        elevation: 0,
        title: const Text(
          'LOOKBOOK',
          style: TextStyle(
            fontFamily: 'BarlowCondensed',
            fontSize: 20,
            fontWeight: FontWeight.w300,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: PopupMenuButton<String>(
              tooltip: 'Options',
              color: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE4DDD5)),
              ),
              position: PopupMenuPosition.under,
              onSelected: (value) async {
                switch (value) {
                  case 'share':
                    _shareItem();
                    break;
                  case 'edit':
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AddLookbookItemPage(existingItem: _item),
                      ),
                    );

                    if (result == true) {
                      _loadItem();
                    }
                    break;
                  case 'delete':
                    _deleteItem();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'share',
                  child: Text('Share'),
                ),
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Text('Edit'),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ],
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: _TwoLineMenuIcon(),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image with name + date overlay
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.55,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _resolvedImagePath != null
                        ? _resolvedImagePath!.startsWith('http')
                            ? Image.network(
                                _resolvedImagePath!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  color: const Color(0xFFF2EEE8),
                                  child: const Center(
                                    child: Icon(Icons.broken_image, size: 48, color: Color(0xFFBDB5AB)),
                                  ),
                                ),
                              )
                            : Image.file(
                                File(_resolvedImagePath!),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  color: const Color(0xFFF2EEE8),
                                  child: const Center(
                                    child: Icon(Icons.broken_image, size: 48, color: Color(0xFFBDB5AB)),
                                  ),
                                ),
                              )
                        : Container(
                            color: const Color(0xFFF2EEE8),
                            child: const Center(
                              child: Icon(Icons.image_not_supported, size: 48, color: Color(0xFFBDB5AB)),
                            ),
                          ),
                    // Gradient overlay
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.58),
                            ],
                            stops: const [0.45, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Name + date at bottom of image
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 36, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _item!.name,
                              style: const TextStyle(
                                fontFamily: 'BarlowCondensed',
                                fontSize: 28,
                                fontWeight: FontWeight.w300,
                                color: Colors.white,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM d, yyyy').format(_item!.createdAt),
                              style: TextStyle(
                                fontFamily: 'BarlowCondensed',
                                fontSize: 14,
                                fontWeight: FontWeight.w300,
                                color: Colors.white.withOpacity(0.72),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Tags
            if (_item!.tags.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _item!.tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2EDE8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        fontFamily: 'BarlowCondensed',
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                        color: Color(0xFF5F5A54),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Notes
            if (_item!.notes != null && _item!.notes!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F5F1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NOTES',
                      style: TextStyle(
                        fontFamily: 'BarlowCondensed',
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.8,
                        color: Color(0xFFADA59C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _item!.notes!,
                      style: const TextStyle(
                        fontFamily: 'BarlowCondensed',
                        fontSize: 17,
                        fontWeight: FontWeight.w300,
                        color: Color(0xFF4A4540),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Source
            if (_item!.source != null && _item!.source!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F5F1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SOURCE',
                            style: TextStyle(
                              fontFamily: 'BarlowCondensed',
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 1.8,
                              color: Color(0xFFADA59C),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _item!.source!,
                            style: const TextStyle(
                              fontFamily: 'BarlowCondensed',
                              fontSize: 15,
                              fontWeight: FontWeight.w300,
                              color: Color(0xFF4A4540),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.arrow_forward_ios, size: 13, color: Color(0xFFBDB5AB)),
                  ],
                ),
              ),
            ],

            // Similar looks
            if (_similarItems.isNotEmpty) ...[
              const SizedBox(height: 28),
              Row(
                children: [
                  Container(width: 28, height: 1.5, color: const Color(0xFFD8CEC3)),
                  const SizedBox(width: 10),
                  const Text(
                    'SIMILAR LOOKS',
                    style: TextStyle(
                      fontFamily: 'BarlowCondensed',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.8,
                      color: Color(0xFF8A847D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 190,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _similarItems.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final similar = _similarItems[index];
                    final resolvedPath = _similarPaths[similar.id];
                    return GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LookbookDetailPage(id: similar.id!),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 140,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Image
                              resolvedPath != null
                                  ? (resolvedPath.startsWith('http')
                                      ? Image.network(resolvedPath, fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF2EEE8)))
                                      : Image.file(File(resolvedPath), fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF2EEE8))))
                                  : Container(color: const Color(0xFFF2EEE8)),
                              // Gradient
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
                                      stops: const [0.5, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              // Name
                              Positioned(
                                bottom: 10,
                                left: 10,
                                right: 10,
                                child: Text(
                                  similar.name,
                                  style: const TextStyle(
                                    fontFamily: 'BarlowCondensed',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w300,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
