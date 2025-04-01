import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:drobe/models/item.dart';
import 'package:drobe/services/hiveServiceManager.dart';
import 'package:drobe/auth/authService.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:drobe/services/removeBackground.dart';
import 'package:http/http.dart' as http;
import 'dart:math' show min;

class AddItemPage extends StatefulWidget {
  final String category;

  const AddItemPage({Key? key, required this.category}) : super(key: key);

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  File? _selectedImage;
  String? _imageUrl;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  List<int> _selectedColors = [];
  bool _isSaving = false;
  final HiveManager _hiveManager = HiveManager();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final authService = AuthService();
      await authService.ensureInitialized();
      final userData = await authService.getCurrentUser();
      setState(() {
        _currentUserId = userData['id'];
      });

      if (_currentUserId == null || _currentUserId!.isEmpty) {
        debugPrint('Warning: No current user ID available in AddItemPage');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to add items'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return SafeArea(
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
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Choose from Gallery'),
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
                  _showEnterUrlDialog();
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Removing background..."))
        );
      }

      // Create a File from the picked image path
      final originalFile = File(pickedFile.path);

      try {
        // Remove background from the image
        final processedFile = await removeBackground(originalFile);

        // If background removal was successful, use the processed file
        // Otherwise fall back to the original file
        final fileToUse = processedFile ?? originalFile;

        if (mounted) {
          setState(() {
            _selectedImage = fileToUse;
            _imageUrl = null;
          });

          // Show appropriate message based on background removal success
          final successMessage = processedFile != null
              ? "Background removed successfully"
              : "Image added (background removal failed)";

          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(successMessage))
          );
        }
      } catch (e) {
        debugPrint("Error removing background: $e");
        if (mounted) {
          // If there was an error, still use the original image
          setState(() {
            _selectedImage = originalFile;
            _imageUrl = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Background removal failed. Using original image."))
          );
        }
      }
    }
  }

  Future<void> _showEnterUrlDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Enter Image URL"),
          content: TextField(
            controller: _imageUrlController,
            decoration: const InputDecoration(hintText: "https://example.com/image.jpg"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final url = _imageUrlController.text.trim();
                Navigator.pop(context);
                await _processImageFromUrl(url);
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _processImageFromUrl(String url) async {
    if (!mounted) return;

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Downloading image..."))
    );

    try {
      // Download the image
      final response = await http.get(Uri.parse(url));

      if (!mounted) return;

      if (response.statusCode == 200) {
        // First save to a temporary file
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/temp_download.png');
        await tempFile.writeAsBytes(response.bodyBytes);

        // Show background removal in progress
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Removing background..."))
          );
        }

        // Remove background from the image
        final processedFile = await removeBackground(tempFile);

        // If background removal failed, use the original image
        final fileToSave = processedFile ?? tempFile;

        // Ensure the wardrobe_images directory exists
        final appDir = await getApplicationDocumentsDirectory();
        final wardrobeDir = Directory('${appDir.path}/wardrobe_images');
        if (!await wardrobeDir.exists()) {
          await wardrobeDir.create(recursive: true);
        }

        // Generate a unique filename with timestamp
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'img_$timestamp.png';
        final savedFile = File('${wardrobeDir.path}/$fileName');

        // Copy the processed file to the final location
        await fileToSave.copy(savedFile.path);

        // Update state only if still mounted
        if (!mounted) return;

        setState(() {
          _selectedImage = savedFile;
          _imageUrl = 'wardrobe_images/$fileName'; // Store the relative path
        });

        // Show success message with appropriate text based on background removal success
        if (mounted) {
          final successMessage = processedFile != null
              ? "Image downloaded and background removed successfully"
              : "Image downloaded successfully (background removal failed)";

          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(successMessage))
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Failed to download image: HTTP ${response.statusCode}"))
          );
        }
      }
    } catch (e) {
      debugPrint("Error processing URL image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error processing image: ${e.toString().substring(0, min(50, e.toString().length))}..."))
        );
      }
    }
  }

  Future<void> _extractColorsFromImage(File imageFile) async {
    try {
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        FileImage(imageFile),
        size: const Size(200, 200),
        maximumColorCount: 3, // Limit to 3 main colors
      );

      setState(() {
        _selectedColors = paletteGenerator.paletteColors
            .take(3)
            .map((color) => color.color.value)
            .toList();
      });
    } catch (e) {
      debugPrint("Error extracting colors: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to extract colors: ${e.toString()}"))
        );
      }
    }
  }

  Future<void> _openColorPicker() async {
    if (_selectedColors.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can only select up to 5 colors.")),
      );
      return;
    }

    Color selectedColor = Colors.black;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Pick a Color"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ColorPicker(
                pickerColor: selectedColor,
                enableAlpha: false,
                showLabel: false,
                onColorChanged: (color) {
                  selectedColor = color;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (!_selectedColors.contains(selectedColor.value)) {
                  setState(() {
                    _selectedColors.add(selectedColor.value);
                    if (_selectedColors.length > 5) {
                      _selectedColors = _selectedColors.take(5).toList();
                    }
                  });
                }
                Navigator.pop(context);
              },
              child: const Text("Select"),
            ),
          ],
        );
      },
    );
  }

  Future<String> saveImagePermanently(File imageFile) async {
    // Get application documents directory
    final appDir = await getApplicationDocumentsDirectory();

    // Create a dedicated folder for images
    final imagesDir = Directory('${appDir.path}/wardrobe_images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    // Generate unique filename
    final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.${imageFile.path.split('.').last}';

    // Full destination path
    final destPath = '${imagesDir.path}/$fileName';

    // Copy file to permanent location
    await imageFile.copy(destPath);

    // Return only the RELATIVE path (important!)
    return 'wardrobe_images/$fileName';
  }

  Future<void> _saveItem() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be logged in to add items")),
      );
      return;
    }

    // Check if required fields are filled
    if (_selectedImage == null && (_imageUrl == null || _imageUrl!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add an image for your item")),
      );
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a name for your item")),
      );
      return;
    }

    // Optional: Check if colors are selected
    if (_selectedColors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one color for your item")),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String imageUrl = '';

      if (_selectedImage != null) {
        // Convert File to String path (store as relative path)
        imageUrl = await saveImagePermanently(_selectedImage!);
      } else if (_imageUrl != null) {
        if (_imageUrl!.startsWith('http')) {
          imageUrl = _imageUrl!;
        } else {
          imageUrl = _imageUrl!; // Already a relative path
        }
      }

      // Create the new item with the current user ID
      final newItem = Item(
        id: 'item_${DateTime.now().millisecondsSinceEpoch}',
        imageUrl: imageUrl,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        colors: _selectedColors,
        category: widget.category,
        userId: _currentUserId, // Set the user ID explicitly
      );

      // Get the box and add the item
      final box = await _hiveManager.getBox('itemsBox');
      await box.add(newItem);

      debugPrint('Item added successfully: ID=${newItem.id}, Name=${newItem.name}, UserID=${newItem.userId}, Category=${newItem.category}');

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Item added successfully")),
        );

        // Return true to indicate success to the calling screen
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error saving item: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving item: ${e.toString()}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ADD NEW ITEM"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Image Picker (Tap to Choose)
              GestureDetector(
                onTap: _showImageSourceOptions,
                child: Container(
                  height: 400,
                  width: 400,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Image.file(
                      // If the file path starts with "file://", remove it.
                      File(_selectedImage!.path.startsWith("file://")
                          ? _selectedImage!.path.replaceFirst(RegExp(r'^file://'), '')
                          : _selectedImage!.path),
                      fit: BoxFit.cover,
                    ),
                  )
                      : _imageUrl != null
                      ? (_imageUrl!.startsWith("http")
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Image.network(_imageUrl!, fit: BoxFit.cover),
                  )
                      : FutureBuilder<String>(
                    future: getApplicationDocumentsDirectory().then(
                            (dir) => '${dir.path}/$_imageUrl'),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }
                      if (snapshot.hasData && snapshot.data != null) {
                        final file = File(snapshot.data!);
                        if (file.existsSync()) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: Image.file(file, fit: BoxFit.cover),
                          );
                        }
                      }
                      return const Icon(Icons.image_not_supported, size: 100, color: Colors.grey);
                    },
                  ))
                      : const Icon(Icons.image, size: 100, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 20),
              // Name Input Field
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "NAME",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // Description Input Field
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: "DESCRIPTION",
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                maxLength: 100,
              ),
              const SizedBox(height: 5),
              // Color Picker Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _openColorPicker,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text("SELECT COLOURS"),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _selectedImage != null ? () => _extractColorsFromImage(_selectedImage!) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text("GENERATE COLOURS"),
                  ),
                ],
              ),
              // Display Selected Colors
              if (_selectedColors.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _selectedColors.map((colorInt) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColors.remove(colorInt);
                        });
                      },
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Color(colorInt),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black12, width: 1),
                        ),
                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 20),
              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black54,
                    ),
                  )
                      : const Text("SAVE ITEM", style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

