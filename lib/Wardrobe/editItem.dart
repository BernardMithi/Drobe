import 'dart:io';
import 'dart:math' show min;

import 'package:drobe/models/item.dart';
import 'package:drobe/services/itemStorage.dart';
import 'package:drobe/services/removeBackground.dart';
import 'package:drobe/theme/drobe_bottom_action.dart';
import 'package:drobe/utils/category_utils.dart';
import 'package:drobe/utils/image_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'wardrobeTheme.dart';

enum EditItemResult { deleted }

class EditItemPage extends StatefulWidget {
  final Item item;

  const EditItemPage({super.key, required this.item});

  @override
  State<EditItemPage> createState() => _EditItemPageState();
}

class _EditItemPageState extends State<EditItemPage> {
  File? _selectedImage;
  String? _imageUrl;
  String? _localImagePath;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  final TextEditingController _imageUrlController = TextEditingController();
  late List<int> _selectedColors;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _descriptionController =
        TextEditingController(text: widget.item.description);
    _selectedColors = List<int>.from(widget.item.colors ?? []);

    if (widget.item.imageUrl.startsWith('http')) {
      _imageUrl = widget.item.imageUrl;
      _imageUrlController.text = widget.item.imageUrl;
    } else if (widget.item.imageUrl.isNotEmpty) {
      _resolveLocalImagePath(widget.item.imageUrl);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _resolveLocalImagePath(String imagePath) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fullPath = '${directory.path}/$imagePath';
      if (File(fullPath).existsSync()) {
        setState(() {
          _localImagePath = fullPath;
        });
      }
    } catch (e) {
      debugPrint('Error resolving local image: $e');
    }
  }

  Future<void> _deleteItem() async {
    final bool? shouldDelete = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete item?'),
        content: Text(
          'Remove ${widget.item.name} from your wardrobe? This can\'t be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final deleted = await ItemStorageService.deleteItem(widget.item.id);

    if (!mounted) return;

    if (!deleted) {
      setState(() {
        _isSaving = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find this item to delete.')),
      );
      return;
    }

    Navigator.pop(context, EditItemResult.deleted);
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: WardrobeTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: WardrobeTheme.line,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'UPDATE IMAGE',
                  style: TextStyle(
                    fontFamily: 'BarlowCondensed',
                    fontSize: 22,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0.8,
                    color: WardrobeTheme.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Swap the current image with a cleaner source.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: WardrobeTheme.mutedInk,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSheetOption(
                  icon: CupertinoIcons.camera,
                  title: 'Take photo',
                  subtitle: 'Capture a new image now',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 10),
                _buildSheetOption(
                  icon: CupertinoIcons.photo,
                  title: 'Choose from gallery',
                  subtitle: 'Select an existing image',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 10),
                _buildSheetOption(
                  icon: CupertinoIcons.link,
                  title: 'Enter image URL',
                  subtitle: 'Paste a product or campaign link',
                  onTap: () {
                    Navigator.pop(context);
                    _showEnterUrlDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: WardrobeTheme.pageBackground,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: WardrobeTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: WardrobeTheme.ink, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'BarlowCondensed',
                        fontSize: 20,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.4,
                        color: WardrobeTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                        color: WardrobeTheme.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.arrow_up_right,
                size: 16,
                color: WardrobeTheme.mutedInk,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile == null) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removing background...')),
      );
    }

    final originalFile = File(pickedFile.path);

    try {
      final processedFile = await removeBackground(originalFile);
      final fileToUse = processedFile ?? originalFile;

      if (!mounted) return;
      setState(() {
        _selectedImage = fileToUse;
        _imageUrl = null;
        _localImagePath = null;
      });

      final successMessage = processedFile != null
          ? 'Background removed successfully'
          : 'Image added (background removal failed)';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );

      _extractColorsFromImage(fileToUse);
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing image: $e')),
        );
      }
    }
  }

  void _showEnterUrlDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WardrobeTheme.surface,
        surfaceTintColor: WardrobeTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: WardrobeTheme.line),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: const Text(
          'Paste image URL',
          style: TextStyle(
            fontFamily: 'BarlowCondensed',
            fontSize: 24,
            fontWeight: FontWeight.w300,
            color: WardrobeTheme.ink,
          ),
        ),
        content: TextField(
          controller: _imageUrlController,
          decoration: InputDecoration(
            hintText: 'https://',
            hintStyle: const TextStyle(color: WardrobeTheme.mutedInk),
            filled: true,
            fillColor: WardrobeTheme.pageBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: WardrobeTheme.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: WardrobeTheme.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: WardrobeTheme.accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: WardrobeTheme.mutedInk),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: WardrobeTheme.ink,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final url = _imageUrlController.text.trim();
              if (url.isNotEmpty) {
                _processImageUrl(url);
              }
              Navigator.pop(context);
            },
            child: const Text('Use image'),
          ),
        ],
      ),
    );
  }

  Future<void> _processImageUrl(String url) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removing background...')),
      );
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          response.bodyBytes.isEmpty) {
        throw Exception('Could not download image');
      }

      final tempDir = await getTemporaryDirectory();
      final uriPath = Uri.parse(url).path;
      final extension =
          path.extension(uriPath).isNotEmpty ? path.extension(uriPath) : '.jpg';
      final tempFile = File(
        path.join(
          tempDir.path,
          'url_image_${DateTime.now().millisecondsSinceEpoch}$extension',
        ),
      );
      await tempFile.writeAsBytes(response.bodyBytes);

      final processedFile = await removeBackground(tempFile);
      final fileToUse = processedFile ?? tempFile;

      if (!mounted) return;
      setState(() {
        _selectedImage = fileToUse;
        _imageUrl = null;
        _localImagePath = null;
      });

      final successMessage = processedFile != null
          ? 'Background removed successfully'
          : 'Image added (background removal failed)';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );

      _extractColorsFromImage(fileToUse);
    } catch (e) {
      debugPrint('Error processing image URL: $e');
      if (!mounted) return;
      setState(() {
        _imageUrl = url;
        _selectedImage = null;
        _localImagePath = null;
      });
      _extractColorsFromNetworkImage(url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Using image URL without background removal')),
      );
    }
  }

  Future<void> _extractColorsFromImage(File imageFile) async {
    try {
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        FileImage(imageFile),
        maximumColorCount: 6,
      );

      setState(() {
        _selectedColors = paletteGenerator.colors
            .map((color) => color.value)
            .take(min(5, paletteGenerator.colors.length))
            .toList();
      });
    } catch (e) {
      debugPrint('Error extracting colors: $e');
    }
  }

  Future<void> _extractColorsFromNetworkImage(String imageUrl) async {
    try {
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
        maximumColorCount: 6,
      );

      setState(() {
        _selectedColors = paletteGenerator.colors
            .map((color) => color.value)
            .take(min(5, paletteGenerator.colors.length))
            .toList();
      });
    } catch (e) {
      debugPrint('Error extracting network colors: $e');
    }
  }

  Future<String?> _saveImageLocally(File imageFile) async {
    try {
      return await saveImagePermanently(imageFile);
    } catch (e) {
      debugPrint('Error saving image locally: $e');
      return null;
    }
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for this item')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String finalImageUrl = widget.item.imageUrl;

      if (_selectedImage != null) {
        final localPath = await _saveImageLocally(_selectedImage!);
        if (localPath != null) {
          finalImageUrl = localPath;
        }
      } else if ((_imageUrl ?? '').isNotEmpty) {
        finalImageUrl = _imageUrl!;
      }

      final updatedItem = Item(
        id: widget.item.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: finalImageUrl,
        category: wardrobeCategoryKey(widget.item.category),
        colors: _selectedColors,
        wearCount: widget.item.wearCount,
        inLaundry: widget.item.inLaundry,
        userId: widget.item.userId,
      );

      if (!mounted) return;
      Navigator.pop(context, updatedItem);
    } catch (e) {
      debugPrint('Error saving changes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving changes: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _openColorPicker() {
    Color tempColor = Colors.brown;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WardrobeTheme.surface,
        surfaceTintColor: WardrobeTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: WardrobeTheme.line),
        ),
        title: const Text(
          'Add colour',
          style: TextStyle(
            fontFamily: 'BarlowCondensed',
            fontSize: 24,
            fontWeight: FontWeight.w300,
            color: WardrobeTheme.ink,
          ),
        ),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: tempColor,
            onColorChanged: (color) {
              tempColor = color;
            },
            pickerAreaHeightPercent: 0.7,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: WardrobeTheme.mutedInk),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: WardrobeTheme.ink,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _selectedColors.add(tempColor.value);
              });
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _removeCurrentImage() {
    setState(() {
      _selectedImage = null;
      _imageUrl = null;
      _localImagePath = null;
      _imageUrlController.clear();
      _selectedColors = [];
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
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.item.category.toUpperCase(),
              style: WardrobeTheme.eyebrow,
            ),
            const SizedBox(height: 2),
            const Text(
              'EDIT PIECE',
              style: TextStyle(
                fontFamily: 'BarlowCondensed',
                fontSize: 22,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.8,
                color: WardrobeTheme.ink,
                height: 1,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              onPressed: _isSaving ? null : _deleteItem,
              style: IconButton.styleFrom(
                backgroundColor: WardrobeTheme.surface,
                foregroundColor: WardrobeTheme.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: const BorderSide(color: WardrobeTheme.line),
              ),
              icon: const Icon(CupertinoIcons.trash),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isSaving ? null : _saveChanges,
              child: Text(
                _isSaving ? 'Saving...' : 'Save',
                style: const TextStyle(
                  fontFamily: 'BarlowCondensed',
                  fontSize: 18,
                  letterSpacing: 0.8,
                  color: WardrobeTheme.ink,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        bottom: false,
        child: Padding(
          padding: DrobeBottomAction.floatingBarPadding(context),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: WardrobeTheme.ink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: _isSaving ? null : _saveChanges,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'SAVE CHANGES',
                      style: TextStyle(
                        fontFamily: 'BarlowCondensed',
                        fontSize: 17,
                        letterSpacing: 1.0,
                      ),
                    ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: WardrobeTheme.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIntroPanel(),
            const SizedBox(height: 18),
            _buildImagePanel(),
            const SizedBox(height: 18),
            _buildDetailsPanel(),
            const SizedBox(height: 18),
            _buildColourPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: WardrobeTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WardrobeTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: WardrobeTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'CURATION NOTE',
              style: TextStyle(
                fontFamily: 'BarlowCondensed',
                fontSize: 11,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.8,
                color: WardrobeTheme.accent,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Refine the image, wording and palette so this piece sits better within your wardrobe edit.',
            style: WardrobeTheme.body,
          ),
        ],
      ),
    );
  }

  Widget _buildImagePanel() {
    return _buildSectionShell(
      title: 'IMAGE',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _showImageSourceOptions,
            child: Container(
              height: 280,
              width: double.infinity,
              decoration: BoxDecoration(
                color: WardrobeTheme.pageBackground,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: WardrobeTheme.line),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(21),
                child: _buildImagePreview(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showImageSourceOptions,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: WardrobeTheme.ink,
                    side: const BorderSide(color: WardrobeTheme.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(CupertinoIcons.photo_on_rectangle),
                  label: const Text('Change image'),
                ),
              ),
              if (_selectedImage != null ||
                  _imageUrl != null ||
                  _localImagePath != null) ...[
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _removeCurrentImage,
                  style: IconButton.styleFrom(
                    backgroundColor: WardrobeTheme.surfaceAlt,
                    foregroundColor: WardrobeTheme.ink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(CupertinoIcons.trash),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_selectedImage != null) {
      return Image.file(_selectedImage!, fit: BoxFit.cover);
    }

    if ((_imageUrl ?? '').isNotEmpty) {
      return Image.network(
        _imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPreviewFallback(),
      );
    }

    if ((_localImagePath ?? '').isNotEmpty) {
      return Image.file(
        File(_localImagePath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPreviewFallback(),
      );
    }

    return _buildPreviewFallback();
  }

  Widget _buildPreviewFallback() {
    return Container(
      color: WardrobeTheme.pageBackground,
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.photo,
            size: 38,
            color: WardrobeTheme.mutedInk,
          ),
          SizedBox(height: 12),
          Text(
            'Update the image to refresh this piece.',
            style: TextStyle(
              fontSize: 14,
              color: WardrobeTheme.mutedInk,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsPanel() {
    return _buildSectionShell(
      title: 'DETAILS',
      child: Column(
        children: [
          _buildField(
            controller: _nameController,
            label: 'Name',
            hint: 'Vintage wool overshirt',
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _descriptionController,
            label: 'Description',
            hint: 'Relaxed fit, textured fabrication, neutral tone.',
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildColourPanel() {
    return _buildSectionShell(
      title: 'COLOUR PALETTE',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ..._selectedColors.asMap().entries.map(
                    (entry) => GestureDetector(
                      onLongPress: () {
                        setState(() {
                          _selectedColors.removeAt(entry.key);
                        });
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Color(entry.value),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _hex(entry.value),
                            style: const TextStyle(
                              fontSize: 11,
                              color: WardrobeTheme.mutedInk,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              GestureDetector(
                onTap: _openColorPicker,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: WardrobeTheme.pageBackground,
                    shape: BoxShape.circle,
                    border: Border.all(color: WardrobeTheme.line),
                  ),
                  child: const Icon(
                    CupertinoIcons.add,
                    color: WardrobeTheme.ink,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Tap + to add a colour manually. Long-press a swatch to remove it.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: WardrobeTheme.mutedInk,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionShell({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: WardrobeTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WardrobeTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 1,
                color: WardrobeTheme.accent,
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: WardrobeTheme.sectionLabel,
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'BarlowCondensed',
            fontSize: 12,
            fontWeight: FontWeight.w400,
            letterSpacing: 1.6,
            color: WardrobeTheme.mutedInk,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(
            fontSize: 14.5,
            color: WardrobeTheme.ink,
            height: 1.45,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: WardrobeTheme.mutedInk),
            filled: true,
            fillColor: WardrobeTheme.pageBackground,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: WardrobeTheme.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: WardrobeTheme.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: WardrobeTheme.accent),
            ),
          ),
        ),
      ],
    );
  }

  String _hex(int colorValue) {
    final rgb = colorValue & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}
