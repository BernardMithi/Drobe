import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'createOutfit.dart';
import 'itemSelection.dart';
import 'createPalette.dart';
import 'package:drobe/models/item.dart'; // ensure Item is imported

class OutfitsPage extends StatefulWidget {
  const OutfitsPage({Key? key}) : super(key: key);

  @override
  State<OutfitsPage> createState() => _OutfitsPageState();
}

class _OutfitsPageState extends State<OutfitsPage> {
  DateTime selectedDate = DateTime.now();
  final PageController _outfitController = PageController();
  int _currentOutfitIndex = 0;
  bool _isEditing = false;

  // Outfits stored by normalized date.
  // Each outfit is stored as a Map containing:
  //   'name': String, 'clothes': Map<String, String?>, 'accessories': List<String?>
  final Map<DateTime, List<Map<String, dynamic>>> outfitsPerDay = {};

  @override
  void dispose() {
    _outfitController.dispose();
    super.dispose();
  }

  // Normalize date (remove time)
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // Format date for display
  String _getFormattedDate(DateTime date) {
    return DateFormat('EEEE, d MMMM y').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final normalizedDate = _normalizeDate(selectedDate);
    final outfitsForSelectedDate = outfitsPerDay[normalizedDate] ?? [];
    final int outfitCount = outfitsForSelectedDate.length;

    return Scaffold(
      appBar: AppBar(
        // Show outfit name if available; otherwise, static title.
        title: Text(
               'OUTFITS',
          style: const TextStyle(fontFamily: 'Avenir', fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, size: 40),
            onPressed: () {},
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Toggle edit mode.
              FloatingActionButton(
                heroTag: 'editBtn',
                backgroundColor: Colors.grey,
                onPressed: () {
                  setState(() {
                    _isEditing = !_isEditing;
                  });
                },
                child: Icon(
                  _isEditing ? Icons.cancel : Icons.edit,
                  color: Colors.black,
                ),
              ),
              // Add new outfit.
              FloatingActionButton(
                heroTag: 'addBtn',
                backgroundColor: Colors.grey,
                onPressed: () async {
                  final newOutfit = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreatePalettePage(selectedDate: selectedDate),
                    ),
                  );

                  if (newOutfit != null) {
                    setState(() {
                      DateTime outfitDate = _normalizeDate(selectedDate); // Ensure outfit is assigned to the correct date

                      if (!outfitsPerDay.containsKey(outfitDate)) {
                        outfitsPerDay[outfitDate] = [];
                      }

                      outfitsPerDay[outfitDate]!.add({
                        'name': newOutfit.name,
                        'clothes': newOutfit.clothes,
                        'accessories': newOutfit.accessories,
                      });
                    });
                  }
                },
                child: const Icon(Icons.add, color: Colors.black),
              ),            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 132),
        child: Column(
          children: [
            // Date selector row.
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      setState(() {
                        selectedDate = _normalizeDate(selectedDate.subtract(const Duration(days: 1)));
                        _currentOutfitIndex = 0;
                      });
                    },
                  ),
                  GestureDetector(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          selectedDate = _normalizeDate(pickedDate);
                          _currentOutfitIndex = 0;
                        });
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        _getFormattedDate(selectedDate),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      setState(() {
                        selectedDate = _normalizeDate(selectedDate.add(const Duration(days: 1)));
                        _currentOutfitIndex = 0;
                      });
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: const EdgeInsets.all(12),
                child: outfitCount > 0
                    ? Column(
                  children: [
                    // Header displaying the outfit's name and index.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          outfitsForSelectedDate[_currentOutfitIndex]['name'] as String? ?? 'Unnamed Outfit',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_currentOutfitIndex + 1}/$outfitCount',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    // PageView for clothing items.
                    Expanded(
                      flex: 3,
                      child: PageView.builder(
                        controller: _outfitController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentOutfitIndex = index;
                          });
                        },
                        itemCount: outfitCount,
                        itemBuilder: (context, outfitIndex) {
                          final clothes = outfitsForSelectedDate[outfitIndex]['clothes'] as Map<String, dynamic>;
                          // Cast to Map<String, String?> to avoid type issues.
                          final clothesMap = Map<String, String?>.from(clothes);
                          return GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1,
                            children: clothesMap.entries.map((entry) {
                              // Wrap each tile in a RepaintBoundary with a stable key.
                              return RepaintBoundary(
                                key: ValueKey('clothing_${entry.key}_$outfitIndex'),
                                child: _buildClothingItem(entry.key, entry.value, outfitIndex),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("ACCESSORIES", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                    // Horizontal list for accessories.
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: (outfitsForSelectedDate[_currentOutfitIndex]['accessories'] as List).length,
                        itemBuilder: (context, accessoryIndex) {
                          final accessory = (outfitsForSelectedDate[_currentOutfitIndex]['accessories'] as List)[accessoryIndex];
                          return RepaintBoundary(
                            key: ValueKey('accessory_${accessoryIndex}_$_currentOutfitIndex'),
                            child: _buildAccessoryItem(accessory, _currentOutfitIndex, accessoryIndex),
                          );
                        },
                      ),
                    ),
                  ],
                )
                    : const Center(
                  child: Text(
                    'No outfits for this day.\nTap + to add some',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build a clothing item tile.
  Widget _buildClothingItem(String category, String? imageUrl, int outfitIndex) {
    return GestureDetector(
      onTap: _isEditing ? () => _editItem(category, outfitIndex) : null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          image: (imageUrl != null && imageUrl.isNotEmpty)
              ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
              : null,
        ),
      ),
    );
  }

  // Build an accessory tile.
  Widget _buildAccessoryItem(String? imageUrl, int outfitIndex, int accessoryIndex) {
    return GestureDetector(
      onTap: _isEditing ? () => _editAccessoryItem(outfitIndex, accessoryIndex) : null,
      child: Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: Colors.grey),
          image: (imageUrl != null && imageUrl.isNotEmpty)
              ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
              : null,
        ),
      ),
    );
  }

  // Launch ItemSelectionPage to edit a clothing item.
  void _editItem(String category, int outfitIndex) {
    Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ItemSelectionPage(
          slot: category,
          fromCreateOutfit: true,
        ),
      ),
    ).then((result) {
      if (result != null) {
        setState(() {
          final normalizedDate = _normalizeDate(selectedDate);
          final outfit = outfitsPerDay[normalizedDate]![outfitIndex];
          Map<String, String?> clothesMap = Map<String, String?>.from(outfit['clothes'] as Map);
          clothesMap[category] = result['item'].imageUrl as String?;
          outfit['clothes'] = clothesMap;
        });
      }
    });
  }

  // Launch ItemSelectionPage to edit an accessory.
  void _editAccessoryItem(int outfitIndex, int accessoryIndex) {
    Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ItemSelectionPage(fromCreateOutfit: true),
      ),
    ).then((result) {
      if (result != null) {
        final newUrl = result['item'].imageUrl as String?;
        setState(() {
          final normalizedDate = _normalizeDate(selectedDate);
          final outfit = outfitsPerDay[normalizedDate]![outfitIndex];
          List<String?> accessories = List<String?>.from(outfit['accessories'] as List);
          if (accessoryIndex < accessories.length) {
            accessories[accessoryIndex] = newUrl;
          } else {
            accessories.add(newUrl);
          }
          outfit['accessories'] = accessories;
        });
      }
    });
  }
}

class ColorTile {
  Color color;
  ColorTile({required this.color});
}

class Outfit {
  final String name;
  final DateTime date;
  final Map<String, String?> clothes;
  final List<String?> accessories;

  Outfit({
    required this.name,
    required this.date,
    required this.clothes,
    required this.accessories,
  });
}