import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:drobe/models/item.dart';
import 'package:drobe/services/itemStorage.dart';
import 'package:drobe/theme/drobe_bottom_action.dart';
import 'package:drobe/theme/drobe_icon.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'editItem.dart';
import 'wardrobeTheme.dart';

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
              color: WardrobeTheme.ink,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 12,
            height: 2,
            decoration: BoxDecoration(
              color: WardrobeTheme.ink,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class ProductDetailsPage extends StatefulWidget {
  final Item item;

  const ProductDetailsPage({super.key, required this.item});

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  late Box itemsBox;
  late Item item;
  late List<int> _selectedColors;
  String? _fullImagePath;

  @override
  void initState() {
    super.initState();
    itemsBox = Hive.box('itemsBox');
    item = widget.item;
    _selectedColors = item.colors ?? [];
    _getFullImagePath();
  }

  Future<void> _getFullImagePath() async {
    if (item.imageUrl.isNotEmpty && !item.imageUrl.startsWith('http')) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final fullPath = '${directory.path}/${item.imageUrl}';
        final file = File(fullPath);

        if (file.existsSync()) {
          setState(() {
            _fullImagePath = fullPath;
          });
        }
      } catch (e) {
        debugPrint('Error getting full path: $e');
      }
    }
  }

  void _moveToLaundry() {
    setState(() {
      item.moveToLaundry();
      _saveItemChanges();
    });
  }

  void _markAsClean() {
    setState(() {
      item.markAsClean();
      _saveItemChanges();
    });
  }

  void _saveItemChanges() {
    try {
      final itemIndex =
          itemsBox.values.toList().indexWhere((i) => i.id == item.id);
      if (itemIndex != -1) {
        itemsBox.putAt(itemIndex, item);
        debugPrint('Item updated in Hive: ${item.id}');
      }
    } catch (e) {
      debugPrint('Error saving item changes: $e');
    }
  }

  Future<void> _openEditPage() async {
    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (context) => EditItemPage(item: item),
      ),
    );

    if (result == EditItemResult.deleted) {
      if (!mounted) return;
      Navigator.pop(context, EditItemResult.deleted);
      return;
    }

    if (result is! Item) {
      return;
    }

    final updatedItem = await ItemStorageService.updateItem(result);

    if (!mounted) return;

    setState(() {
      item = updatedItem;
      _selectedColors = item.colors ?? [];
      _fullImagePath = null;
    });

    await _getFullImagePath();
  }

  bool get _isAccessory => item.category.toLowerCase() == 'accessories';

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
        title: const SizedBox.shrink(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: PopupMenuButton<String>(
              tooltip: 'Options',
              color: WardrobeTheme.pageBackground,
              surfaceTintColor: WardrobeTheme.pageBackground,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: WardrobeTheme.line),
              ),
              position: PopupMenuPosition.under,
              onSelected: (value) {
                if (value == 'edit') {
                  _openEditPage();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Text('Edit'),
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
      bottomNavigationBar: _isAccessory
          ? null
          : SafeArea(
              bottom: false,
              child: Padding(
                padding: DrobeBottomAction.floatingBarPadding(context),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.local_laundry_service_outlined,
                        label: 'IN LAUNDRY',
                        isActive: item.inLaundry,
                        activeColor: WardrobeTheme.warning,
                        onPressed: _moveToLaundry,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.checkroom_outlined,
                        label: 'MARK CLEAN',
                        isActive: !item.inLaundry,
                        activeColor: WardrobeTheme.success,
                        onPressed: _markAsClean,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 4, 14, _isAccessory ? 14 : 12),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildImageCard(),
                const SizedBox(height: 10),
                _buildEditorialSummary(),
                const SizedBox(height: 10),
                _buildColorPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageCard() {
    return Expanded(
      flex: 7,
      child: Container(
        decoration: BoxDecoration(
          color: WardrobeTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: WardrobeTheme.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: AspectRatio(
            aspectRatio: 1.16,
            child: _buildItemImage(),
          ),
        ),
      ),
    );
  }

  Widget _buildItemImage() {
    if (item.imageUrl.isEmpty) {
      return _buildImageFallback();
    }

    if (item.imageUrl.startsWith('http')) {
      return Image.network(
        item.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildImageFallback(),
      );
    }

    if (_fullImagePath != null) {
      return Image.file(
        File(_fullImagePath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildImageFallback(),
      );
    }

    return Container(
      color: WardrobeTheme.surfaceAlt,
      child: const Center(
        child: CircularProgressIndicator(
          color: WardrobeTheme.accent,
          strokeWidth: 2.2,
        ),
      ),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      color: WardrobeTheme.surfaceAlt,
      alignment: Alignment.center,
      child: const Icon(
        CupertinoIcons.square_stack_3d_up,
        size: 48,
        color: WardrobeTheme.mutedInk,
      ),
    );
  }

  Widget _buildEditorialSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: WardrobeTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WardrobeTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: WardrobeTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'CURATED PIECE',
              style: TextStyle(
                fontFamily: 'BarlowCondensed',
                fontSize: 10,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.5,
                color: WardrobeTheme.accent,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.name,
            style: const TextStyle(
              fontFamily: 'BarlowCondensed',
              fontSize: 28,
              fontWeight: FontWeight.w300,
              height: 0.95,
              letterSpacing: 0.2,
              color: WardrobeTheme.ink,
            ),
          ),
          if (item.description.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.description,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: WardrobeTheme.mutedInk,
              ),
            ),
          ],
          if (!_isAccessory) ...[
            const SizedBox(height: 12),
            _buildStatusPill(),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: WardrobeTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WardrobeTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 1,
                color: WardrobeTheme.accent,
              ),
              const SizedBox(width: 8),
              const Text(
                'DETAILS',
                style: TextStyle(
                  fontFamily: 'BarlowCondensed',
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.5,
                  color: WardrobeTheme.mutedInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildMetaRow('Category', item.category),
          const SizedBox(height: 8),
          _buildMetaRow(
            'Wear status',
            _isAccessory
                ? 'Accessory item'
                : item.inLaundry
                    ? 'Currently in laundry'
                    : 'Ready to wear',
          ),
          const SizedBox(height: 8),
          _buildMetaRow(
            'Palette count',
            '${_selectedColors.length} shade${_selectedColors.length == 1 ? '' : 's'} saved',
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'BarlowCondensed',
              fontSize: 11,
              fontWeight: FontWeight.w400,
              letterSpacing: 1.3,
              color: WardrobeTheme.mutedInk,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              height: 1.3,
              color: WardrobeTheme.ink,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: WardrobeTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WardrobeTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 1,
                color: WardrobeTheme.accent,
              ),
              const SizedBox(width: 8),
              const Text(
                'COLOUR PALETTE',
                style: TextStyle(
                  fontFamily: 'BarlowCondensed',
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.5,
                  color: WardrobeTheme.mutedInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildColorSwatches(),
        ],
      ),
    );
  }

  Widget _buildStatusPill() {
    final bool inLaundry = item.inLaundry;
    final Color pillColor =
        inLaundry ? WardrobeTheme.warning : WardrobeTheme.success;
    final Color pillTint =
        inLaundry ? const Color(0xFFF1E4D7) : const Color(0xFFE2E9DD);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: pillTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            inLaundry
                ? Icons.local_laundry_service_outlined
                : Icons.checkroom_outlined,
            size: 16,
            color: pillColor,
          ),
          const SizedBox(width: 8),
          Text(
            inLaundry ? 'Currently in laundry' : 'Ready to wear',
            style: TextStyle(
              fontFamily: 'BarlowCondensed',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.8,
              color: pillColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSwatches() {
    if (_selectedColors.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: WardrobeTheme.pageBackground,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text(
          'No colour notes saved for this piece yet.',
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: WardrobeTheme.mutedInk,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _selectedColors.map((colorValue) {
        final color = Color(colorValue);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.85),
                  width: 3,
                ),
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
              _colorHex(colorValue),
              style: const TextStyle(
                fontSize: 11,
                color: WardrobeTheme.mutedInk,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  String _colorHex(int colorValue) {
    final rgb = colorValue & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onPressed,
  }) {
    final Color background = isActive ? activeColor : WardrobeTheme.surface;
    final Color foreground = isActive ? Colors.white : WardrobeTheme.ink;
    final Color borderColor = isActive ? activeColor : WardrobeTheme.line;

    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: background,
          foregroundColor: foreground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: borderColor),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontFamily: 'BarlowCondensed',
            fontSize: 15,
            fontWeight: FontWeight.w400,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}
