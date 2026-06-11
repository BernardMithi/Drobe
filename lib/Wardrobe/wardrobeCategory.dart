import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:drobe/auth/authService.dart';
import 'package:drobe/models/item.dart';
import 'package:drobe/services/hiveServiceManager.dart';
import 'package:drobe/services/itemStorage.dart';
import 'package:drobe/theme/drobe_bottom_action.dart';
import 'package:drobe/theme/drobe_icon.dart';
import 'package:drobe/utils/category_utils.dart';
import 'package:path_provider/path_provider.dart';

import 'addItem.dart';
import 'editItem.dart';
import 'wardrobeProductDetails.dart';
import 'wardrobeTheme.dart';

class WardrobeCategoryPage extends StatefulWidget {
  final String category;

  const WardrobeCategoryPage({super.key, required this.category});

  @override
  State<WardrobeCategoryPage> createState() => _WardrobeCategoryPageState();
}

class _WardrobeCategoryPageState extends State<WardrobeCategoryPage> {
  final HiveManager _hiveManager = HiveManager();
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  bool _isLoading = true;
  List<Item> _items = [];
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUserItems();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
    });
  }

  Future<void> _loadUserItems() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final authService = AuthService();
      await authService.ensureInitialized();
      final userData = await authService.getCurrentUser();
      _currentUserId = userData['id'];

      if (_currentUserId == null || _currentUserId!.isEmpty) {
        debugPrint('Warning: No current user ID available in wardrobeCategory');
        if (mounted) {
          setState(() {
            _items = [];
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to view your items'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final box = await _hiveManager.getBox('itemsBox');
      final List<Item> allItems = [];

      for (var item in box.values) {
        if (item is Item) {
          if (item.userId == _currentUserId &&
              categoriesMatch(widget.category, item.category)) {
            allItems.add(item);
          }
        }
      }

      debugPrint(
        'Loaded ${allItems.length} items for user $_currentUserId in category ${widget.category}',
      );

      if (mounted) {
        setState(() {
          _items = allItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user items: $e');
      if (mounted) {
        setState(() {
          _items = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading items: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Item> get filteredItems {
    if (_isLoading || _items.isEmpty) {
      return [];
    }

    try {
      if (_searchText.isEmpty) {
        return _items;
      }

      return _items
          .where(
            (item) =>
                item.name.toLowerCase().contains(_searchText.toLowerCase()) ||
                item.description
                    .toLowerCase()
                    .contains(_searchText.toLowerCase()),
          )
          .toList();
    } catch (e) {
      debugPrint('Error filtering items: $e');
      return [];
    }
  }

  Future<void> _selectItem(Item selectedItem) async {
    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsPage(item: selectedItem),
      ),
    );

    if (result == EditItemResult.deleted) {
      await _loadUserItems();
      return;
    }

    if (result == null) {
      await _loadUserItems();
      return;
    }

    if (result is! Item) {
      return;
    }

    setState(() {
      final index = _items.indexWhere((item) => item.id == result.id);
      if (index >= 0) {
        _items[index] = result;
      }
    });
  }

  Future<String> _getImageAbsolutePath(String imagePath) async {
    if (imagePath.startsWith('http')) {
      return imagePath;
    }

    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$imagePath';
  }

  Widget _buildImage(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildImageFallback();
        },
      );
    }

    return FutureBuilder<String>(
      future: _getImageAbsolutePath(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: WardrobeTheme.surfaceAlt,
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: WardrobeTheme.accent,
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _buildImageFallback();
        }

        final file = File(snapshot.data!);
        if (!file.existsSync()) {
          debugPrint('Image file does not exist: ${snapshot.data}');
          return _buildImageFallback();
        }

        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Error loading image file: $error');
            return _buildImageFallback();
          },
        );
      },
    );
  }

  Widget _buildImageFallback() {
    return Container(
      color: WardrobeTheme.surfaceAlt,
      alignment: Alignment.center,
      child: const Icon(
        CupertinoIcons.square_stack_3d_up,
        size: 34,
        color: WardrobeTheme.mutedInk,
      ),
    );
  }

  Future<void> _navigateToEditItem(Item item) async {
    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (context) => EditItemPage(item: item),
      ),
    );

    if (result == EditItemResult.deleted || result == null) {
      await _loadUserItems();
      return;
    }

    if (result is Item) {
      await ItemStorageService.updateItem(result);
      await _loadUserItems();
    }
  }

  Future<void> _deleteItem(Item item) async {
    final bool? shouldDelete = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete item?'),
        content: Text(
          'Remove ${item.name} from your wardrobe? This can\'t be undone.',
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

    final deleted = await ItemStorageService.deleteItem(item.id);

    if (!deleted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find this item to delete.')),
      );
      return;
    }

    await _loadUserItems();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.name} deleted from your wardrobe.')),
    );
  }

  String _categorySubtitle() {
    switch (widget.category) {
      case 'LAYERS':
        return 'Outerwear, knits and pieces that define the silhouette.';
      case 'SHIRTS':
        return 'Daily staples, elevated basics and sharper top layers.';
      case 'BOTTOMS':
        return 'Tailored cuts, denim rotations and easy everyday foundations.';
      case 'SHOES':
        return 'Footwear that anchors the outfit and changes the mood.';
      case 'ACCESSORIES':
        return 'Details that finish the look and add personality.';
      default:
        return 'Curate the pieces you wear most and refine your rotation.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = filteredItems;

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
              'YOUR ${widget.category}',
              style: WardrobeTheme.appBarTitle,
            ),
            const SizedBox(height: 2),
            Text(
              _isLoading
                  ? 'CURATING PIECES'
                  : '${results.length} LOOK${results.length == 1 ? '' : 'S'} IN VIEW',
              style: WardrobeTheme.eyebrow,
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButtonLocation: const DrobeBottomFabLocation.end(),
      floatingActionButton: SizedBox(
        width: 58,
        height: 58,
        child: FloatingActionButton(
          onPressed: () async {
            final newItem = await Navigator.push<Item>(
              context,
              MaterialPageRoute(
                builder: (context) => AddItemPage(category: widget.category),
              ),
            );

            if (newItem != null) {
              await _loadUserItems();
            }
          },
          backgroundColor: WardrobeTheme.ink.withOpacity(0.75),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const CircleBorder(),
          child: const Icon(CupertinoIcons.add, size: 22),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    decoration: BoxDecoration(
                      color: WardrobeTheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: WardrobeTheme.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: WardrobeTheme.surfaceAlt,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            widget.category,
                            style: const TextStyle(
                              fontFamily: 'BarlowCondensed',
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 1.7,
                              color: WardrobeTheme.accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _categorySubtitle(),
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: WardrobeTheme.mutedInk,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _searchController,
                          textAlignVertical: TextAlignVertical.center,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1,
                            color: WardrobeTheme.ink,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: WardrobeTheme.pageBackground,
                            isCollapsed: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: WardrobeTheme.line,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: WardrobeTheme.line,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: WardrobeTheme.line,
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(left: 14, right: 10),
                              child: Icon(
                                CupertinoIcons.search,
                                color: WardrobeTheme.mutedInk,
                                size: 18,
                              ),
                            ),
                            suffixIcon: _searchText.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                    },
                                    icon: const Icon(
                                      CupertinoIcons.xmark_circle_fill,
                                      color: WardrobeTheme.mutedInk,
                                      size: 18,
                                    ),
                                  ),
                            hintText:
                                'Search within ${widget.category.toLowerCase()}',
                            hintStyle: const TextStyle(
                              color: WardrobeTheme.mutedInk,
                              fontSize: 14,
                              height: 1,
                            ),
                            contentPadding: const EdgeInsets.only(
                              top: 20,
                              bottom: 20,
                              right: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 1,
                        color: WardrobeTheme.accent,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isLoading
                            ? 'LOADING WARDROBE'
                            : '${results.length} ITEM${results.length == 1 ? '' : 'S'}',
                        style: const TextStyle(
                          fontFamily: 'BarlowCondensed',
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 1.8,
                          color: WardrobeTheme.mutedInk,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: WardrobeTheme.accent,
                        strokeWidth: 2.4,
                      ),
                    )
                  : results.isEmpty
                      ? _buildEmptyState()
                      : GridView.builder(
                          padding: EdgeInsets.fromLTRB(
                            22,
                            0,
                            22,
                            DrobeBottomAction.safeAreaContentInset(),
                          ),
                          physics: const BouncingScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final item = results[index];
                            return _buildItemCard(item);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasSearch = _searchText.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        12,
        22,
        DrobeBottomAction.safeAreaContentInset(),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        decoration: BoxDecoration(
          color: WardrobeTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: WardrobeTheme.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: WardrobeTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(22),
              ),
              alignment: Alignment.center,
              child: const Icon(
                CupertinoIcons.square_stack_3d_up,
                size: 30,
                color: WardrobeTheme.ink,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hasSearch
                  ? 'No pieces match your search'
                  : 'No items in this rotation yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'BarlowCondensed',
                fontSize: 28,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.4,
                color: WardrobeTheme.ink,
                height: 0.95,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              hasSearch
                  ? 'Try a different name or description to surface the right look.'
                  : 'Start curating this category by adding your first piece and building a stronger daily wardrobe.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: WardrobeTheme.mutedInk,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(Item item) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _selectItem(item),
        child: Ink(
          decoration: BoxDecoration(
            color: WardrobeTheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: WardrobeTheme.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(21),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: _buildImage(item.imageUrl),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                child: Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'BarlowCondensed',
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0.2,
                    color: WardrobeTheme.ink,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
