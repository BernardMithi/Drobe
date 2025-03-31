import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:drobe/models/lookbookItem.dart';
import 'package:drobe/services/lookbookStorage.dart';

class AddLookbookItemPage extends StatefulWidget {
  final LookbookItem? existingItem;

  const AddLookbookItemPage({Key? key, this.existingItem}) : super(key: key);

  @override
  State<AddLookbookItemPage> createState() => _AddLookbookItemPageState();
}

class _AddLookbookItemPageState extends State<AddLookbookItemPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();

  String? _imagePath;
  bool _isLoading = false;
  List<String> _tags = [];
  List<Color> _colorPalette = [];

  @override
  void initState() {
    super.initState();

    // If editing an existing item, populate the form fields
    if (widget.existingItem != null) {
      _nameController.text = widget.existingItem!.name;
      _notesController.text = widget.existingItem!.notes ?? '';
      _sourceController.text = widget.existingItem!.source ?? '';
      _imagePath = widget.existingItem!.imageUrl;
      _tags = List.from(widget.existingItem!.tags);
      _colorPalette = List.from(widget.existingItem!.colorPalette);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _sourceController.dispose();
    _tagController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (pickedFile != null) {
        // Copy the image to the app's documents directory
        final directory = await getApplicationDocumentsDirectory();
        final lookbookDir = Directory('${directory.path}/lookbook_images');

        // Create the directory if it doesn't exist
        if (!await lookbookDir.exists()) {
          await lookbookDir.create(recursive: true);
        }

        // Generate a unique filename
        final fileName = 'lookbook_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedPath = path.join(lookbookDir.path, fileName);

        // Copy the image
        final File imageFile = File(pickedFile.path);
        await imageFile.copy(savedPath);

        setState(() {
          _imagePath = savedPath;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _addImageFromUrl() async {
    // Show a dialog to enter the URL - matching the style from addItem.dart
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter Image URL"),
        content: TextField(
          controller: _imageUrlController,
          decoration: const InputDecoration(
            hintText: "https://example.com/image.jpg",
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final url = _imageUrlController.text.trim();
              if (url.isNotEmpty) {
                setState(() {
                  _imagePath = url;
                });
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              foregroundColor: Colors.black,
            ),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag.toLowerCase())) {
      setState(() {
        _tags.add(tag.toLowerCase());
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _saveItem() async {
    // Validate required fields
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }

    // Validate image
    if (_imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add an image')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create or update the lookbook item
      final item = LookbookItem(
        id: widget.existingItem?.id,
        name: _nameController.text.trim(),
        createdAt: widget.existingItem?.createdAt ?? DateTime.now(),
        imageUrl: _imagePath,
        tags: _tags,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        source: _sourceController.text.trim().isNotEmpty ? _sourceController.text.trim() : null,
        colorPalette: _colorPalette,
      );

      // Save to Hive storage
      if (widget.existingItem != null) {
        await LookbookStorageService.updateItem(item);
      } else {
        await LookbookStorageService.saveItem(item);
      }

      // Return to the previous screen
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error saving lookbook item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving item: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingItem != null ? 'EDIT INSPIRATION' : 'ADD INSPIRATION',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image picker
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  builder: (context) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Drag handle for a polished look
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_camera),
                          title: const Text('Take a photo'),
                          onTap: () {
                            Navigator.pop(context);
                            _pickImage(ImageSource.camera);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_library),
                          title: const Text('Choose from gallery'),
                          onTap: () {
                            Navigator.pop(context);
                            _pickImage(ImageSource.gallery);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.link),
                          title: const Text('Enter URL'),
                          onTap: () {
                            Navigator.pop(context);
                            _addImageFromUrl();
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0), // Reduced padding by half
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(
                      minHeight: 200,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: _imagePath != null
                        ? _imagePath!.startsWith('http')
                        ? Image.network(
                      _imagePath!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
                      ),
                    )
                        : Image.file(
                      File(_imagePath!),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
                      ),
                    )
                        : const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('Add Image', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Name field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Tags
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tags',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tagController,
                        decoration: const InputDecoration(
                          hintText: 'Add a tag',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _addTag(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addTag,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tags.map((tag) {
                    return Chip(
                      label: Text(tag),
                      onDeleted: () => _removeTag(tag),
                      backgroundColor: Colors.grey[300],
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Notes
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Source
            TextField(
              controller: _sourceController,
              decoration: const InputDecoration(
                labelText: 'Source',
                border: OutlineInputBorder(),
                hintText: 'e.g., Website, Magazine, Designer',
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveItem,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.grey[200],
                ),
                child: _isLoading
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black54,
                  ),
                )
                    : const Text('SAVE INSPIRATION'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

