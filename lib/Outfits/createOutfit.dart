import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'itemSelection.dart';

class CreateOutfitPage extends StatefulWidget {
  final List<Color> colorPalette;
  final List<Outfit> savedOutfits;
  final DateTime selectedDate;

  const CreateOutfitPage({
    super.key,
    required this.colorPalette,
    required this.savedOutfits,
    required this.selectedDate,
  });

  @override
  State<CreateOutfitPage> createState() => _CreateOutfitPageState();
}

class _CreateOutfitPageState extends State<CreateOutfitPage> {
  late DateTime selectedDate;
  final TextEditingController _outfitNameController = TextEditingController();

  // Store color tiles from the chosen palette
  late List<ColorTile> _paletteTiles;

  // Map holding the selected image URL for each clothing slot
  Map<String, String?> chosenClothes = {
    'Layer': null,
    'Shirt': null,
    'Bottoms': null,
    'Shoes': null,
  };

  // List for accessories
  List<String?> chosenAccessories = [];

  // Determine if the "Save" FAB is enabled
  bool get canSave {
    final hasName = _outfitNameController.text.trim().isNotEmpty;
    final hasAtLeastOneClothing =
    chosenClothes.values.any((url) => (url != null && url.isNotEmpty));
    return hasName && hasAtLeastOneClothing;
  }

  @override
  void initState() {
    super.initState();
    selectedDate = widget.selectedDate;
    _paletteTiles = widget.colorPalette.map((c) => ColorTile(color: c)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CREATE AN OUTFIT'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, size: 40),
            onPressed: () {},
          ),
        ],
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFABs(),

      body: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 132),
        child: Column(
          children: [
            // ** Outfit Name Field **
            TextField(
              controller: _outfitNameController,
              decoration: const InputDecoration(
                labelText: 'Outfit Name',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                // Rebuild so "Save" FAB can enable/disable
                setState(() {});
              },
            ),
            const SizedBox(height: 6),



            const SizedBox(height: 10),

            // ** Palette Display **
            SizedBox(
              height: 40,
              child: Row(
                children: _paletteTiles.map((tile) {
                  return Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: tile.color,
                        border: Border.all(color: Colors.black12),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // **Outfit Section: Clothes + Accessories**
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    // Clothing Grid (4 items)
                    Expanded(
                      flex: 3,
                      child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1,
                        physics: const NeverScrollableScrollPhysics(),
                        children: chosenClothes.entries.map((entry) {
                          final category = entry.key;
                          final imageUrl = entry.value;
                          return _buildClothingTile(category, imageUrl);
                        }).toList(),
                      ),
                    ),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "ACCESSORIES",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Horizontal Accessories row
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: chosenAccessories.length + 1,
                        itemBuilder: (context, index) {
                          // "Add Accessory" slot
                          if (index == chosenAccessories.length) {
                            return GestureDetector(
                              onTap: () => _onEditAccessory(index),
                              child: Container(
                                width: 80,
                                height: 80,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: const Icon(Icons.add, color: Colors.grey),
                              ),
                            );
                          } else {
                            // Display existing accessory
                            final accessoryUrl = chosenAccessories[index];
                            return _buildAccessoryTile(index, accessoryUrl);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// FAB row with "Generate" & "Save"
  Widget _buildFABs() {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Generate outfit
            FloatingActionButton(
              heroTag: 'generateBtn',
              backgroundColor: Colors.grey,
              onPressed: _autoGenerateOutfit,
              child: const Icon(Icons.auto_fix_high, color: Colors.black),
            ),
            // Save outfit
            FloatingActionButton(
              heroTag: 'saveBtn',
              backgroundColor: canSave ? Colors.grey : Colors.grey[400],
              onPressed: canSave ? _onSaveOutfit : null,
              child: const Icon(Icons.check, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  /// Convert DateTime -> String
  String _formatDate(DateTime date) {
    return DateFormat('EEEE, d MMMM y').format(date);
  }

  /// Decrement the selected date by 1 day
  void _previousDay() {
    setState(() {
      selectedDate = selectedDate.subtract(const Duration(days: 1));
      // Optional guard
      if (selectedDate.isBefore(DateTime(2020))) {
        selectedDate = DateTime(2020);
      }
    });
  }

  /// Increment the selected date by 1 day
  void _nextDay() {
    setState(() {
      selectedDate = selectedDate.add(const Duration(days: 1));
      // Optional guard
      if (selectedDate.isAfter(DateTime(2030))) {
        selectedDate = DateTime(2030);
      }
    });
  }

  /// Show the date picker
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  void _autoGenerateOutfit() {
    setState(() {
      chosenClothes['Layer'] = 'https://www.nomadfoods.com/wp-content/uploads/2018/08/placeholder-1-e1533569576673.png';
      chosenClothes['Shirt'] = 'https://www.nomadfoods.com/wp-content/uploads/2018/08/placeholder-1-e1533569576673.png';
      chosenClothes['Bottoms'] = 'https://www.nomadfoods.com/wp-content/uploads/2018/08/placeholder-1-e1533569576673.png';
      chosenClothes['Shoes'] = 'https://www.nomadfoods.com/wp-content/uploads/2018/08/placeholder-1-e1533569576673.png';

      chosenAccessories
        ..clear()
        ..add('https://www.nomadfoods.com/wp-content/uploads/2018/08/placeholder-1-e1533569576673.png');
    });
  }

  /// Actually build each tile in the clothing grid
  Widget _buildClothingTile(String category, String? imageUrl) {
    final isEmpty = (imageUrl == null || imageUrl.isEmpty);

    return GestureDetector(
      onTap: () => _onEditClothing(category),
      onLongPress: () => setState(() => chosenClothes[category] = null),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
          image: !isEmpty
              ? DecorationImage(
            image: NetworkImage(imageUrl!),
            fit: BoxFit.cover,
          )
              : null,
        ),
        child: isEmpty
            ? Center(
          child: Text(
            category.toUpperCase(),
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        )
            : null,
      ),
    );
  }

  /// Build each accessory tile
  Widget _buildAccessoryTile(int index, String? imageUrl) {
    final isEmpty = (imageUrl == null || imageUrl.isEmpty);

    return GestureDetector(
      onTap: () => _onEditAccessory(index),
      onLongPress: () {
        // Remove the accessory
        setState(() {
          chosenAccessories.removeAt(index);
        });
      },
      child: Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(2),
          image: !isEmpty
              ? DecorationImage(
            image: NetworkImage(imageUrl!),
            fit: BoxFit.cover,
          )
              : null,
        ),
        child: isEmpty
            ? const Icon(Icons.add, color: Colors.grey)
            : null,
      ),
    );
  }

  /// Saves the outfit and returns to OutfitsPage
  void _onSaveOutfit() {
    if (!canSave) return;

    final outfit = Outfit(
      name: _outfitNameController.text.trim(),
      date: selectedDate,
      clothes: Map.from(chosenClothes),
      accessories: List.from(chosenAccessories),
    );

    Navigator.pop(context, outfit);
  }

  /// Edit a particular clothing category
  Future<void> _onEditClothing(String category) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ItemSelectionPage(
          slot: category,
          fromCreateOutfit: true,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        chosenClothes[category] = result['item'].imageUrl as String?;
      });
    }
  }

  /// Edit or add an accessory
  Future<void> _onEditAccessory(int index) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ItemSelectionPage(fromCreateOutfit: true),
      ),
    );

    if (result != null && mounted) {
      final newUrl = result['item'].imageUrl as String?;
      setState(() {
        if (index < chosenAccessories.length) {
          chosenAccessories[index] = newUrl;
        } else {
          chosenAccessories.add(newUrl);
        }
      });
    }
  }
}

/// Represents the chosen color swatch in the palette
class ColorTile {
  final Color color;
  ColorTile({required this.color});
}

/// Represents an Outfit object with a name
class Outfit {
  final String name;             // New: outfit name
  final DateTime date;           // The selected day
  final Map<String, String?> clothes;     // 4 clothing slots
  final List<String?> accessories;        // Accessory list

  Outfit({
    required this.name,
    required this.date,
    required this.clothes,
    required this.accessories,
  });
}