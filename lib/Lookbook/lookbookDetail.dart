import 'dart:io';
import 'package:flutter/material.dart';
import 'package:drobe/models/lookbookItem.dart';
import 'package:drobe/services/lookbookStorage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'addLookbookItem.dart';

class LookbookDetailPage extends StatefulWidget {
  final String id;

  const LookbookDetailPage({Key? key, required this.id}) : super(key: key);

  @override
  State<LookbookDetailPage> createState() => _LookbookDetailPageState();
}

class _LookbookDetailPageState extends State<LookbookDetailPage> {
  LookbookItem? _item;
  bool _isLoading = true;
  String? _resolvedImagePath;

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

      // Load the lookbook item
      final item = await LookbookStorageService.getItem(widget.id);

      if (item != null && item.imageUrl != null) {
        // Resolve the image path
        _resolvedImagePath = await _resolveFilePath(item.imageUrl!);
      }

      setState(() {
        _item = item;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading lookbook item: $e');
      setState(() {
        _isLoading = false;
      });
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
        content: const Text('Are you sure you want to delete this inspiration?'),
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
        appBar: AppBar(
          title: const Text('LOOKBOOK', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_item == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('LOOKBOOK', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: const Center(
          child: Text('Item not found'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('LOOKBOOK', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share,size: 20),
            onPressed: _shareItem,
          ),
          IconButton(
            icon: const Icon(Icons.edit,size: 20),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddLookbookItemPage(existingItem: _item),
                ),
              );

              if (result == true) {
                _loadItem();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete,size: 20),
            onPressed: _deleteItem,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with padding
            Padding(
              padding: const EdgeInsets.all(12.0), // Reduced padding by half
              child: _resolvedImagePath != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(
                    minHeight: 200,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: _resolvedImagePath!.startsWith('http')
                      ? Image.network(
                    _resolvedImagePath!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
                    ),
                  )
                      : Image.file(
                    File(_resolvedImagePath!),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
                    ),
                  ),
                ),
              )
                  : Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Center(
                  child: Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
                ),
              ),
            ),

            // Item details
            Padding(
                padding: const EdgeInsets.only(left: 25.0, right: 25.0, bottom: 25.0),              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and date
                  Text(
                    _item!.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Added on ${DateFormat('MMMM d, yyyy').format(_item!.createdAt)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tags
                  if (_item!.tags.isNotEmpty) ...[
                    const Text(
                      'Tags',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _item!.tags.map((tag) {
                        return Chip(
                          label: Text(tag),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Notes
                  if (_item!.notes != null && _item!.notes!.isNotEmpty) ...[
                    const Text(
                      'Notes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      child: Text(_item!.notes!),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Source
                  if (_item!.source != null && _item!.source!.isNotEmpty) ...[
                    const Text(
                      'Source',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_item!.source!),
                    const SizedBox(height: 16),
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

