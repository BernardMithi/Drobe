import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'itemSelection.dart';

class CreateOutfitPage extends StatefulWidget {
  final List<Color> colorPalette;
  final List<Outfit> savedOutfits;
  final DateTime selectedDate; // Add selectedDate parameter

  const CreateOutfitPage({
    super.key,
    required this.colorPalette,
    required this.savedOutfits,
    required this.selectedDate, // Initialize selectedDate
  });

  @override
  State<CreateOutfitPage> createState() => _CreateOutfitPageState();
}

class _CreateOutfitPageState extends State<CreateOutfitPage> {
  late DateTime selectedDate; // ✅ Store date that can change
  late List<ColorTile> _paletteTiles;

  // Map holding the selected image URL for each clothing slot.
  Map<String, String?> chosenClothes = {
    'Layer': null,
    'Shirt': null,
    'Bottoms': null,
    'Shoes': null,
  };

  // List for accessories.
  List<String?> chosenAccessories = [];

  bool get canSave {
    return chosenClothes.values.any((url) => url != null && url.isNotEmpty);
  }

  @override
  void initState() {
    super.initState();
    _paletteTiles = widget.colorPalette.map((c) => ColorTile(color: c)).toList();
    selectedDate = widget.selectedDate; // Initialize with the selected date
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
      floatingActionButton: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Dummy outfit generator.
              FloatingActionButton(
                heroTag: 'generateBtn',
                backgroundColor: Colors.grey,
                onPressed: _generateOutfit,
                child: const Icon(Icons.auto_fix_high, color: Colors.black),
              ),
              // Save outfit button.
              FloatingActionButton(
                heroTag: 'saveBtn',
                backgroundColor: canSave ? Colors.grey : Colors.grey[400],
                onPressed: canSave ? _saveOutfit : null,
                child: const Icon(Icons.check, color: Colors.black),
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 132),
        child: Column(
          children: [
            // Date selector.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _goToPreviousDay,
                ),
                GestureDetector(
                  onTap: _selectDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      _getFormattedDate(selectedDate),
                      style: const TextStyle(
                        fontFamily: 'Avenir',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _goToNextDay,
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Palette display.
            SizedBox(
              height: 40,
              child: Row(
                children: _paletteTiles.map((tile) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 0),
                      decoration: BoxDecoration(
                        color: tile.color,
                        borderRadius: BorderRadius.circular(1),
                        border: Border.all(color: Colors.black12),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            // Outfit details: Clothes and Accessories.
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Grid for clothing items.
                    Expanded(
                      flex: 3,
                      child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildClothingItem('Layer', chosenClothes['Layer']),
                          _buildClothingItem('Shirt', chosenClothes['Shirt']),
                          _buildClothingItem('Bottoms', chosenClothes['Bottoms']),
                          _buildClothingItem('Shoes', chosenClothes['Shoes']),
                        ],
                      ),
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "ACCESSORIES",
                        style: TextStyle(
                          fontFamily: 'Avenir',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Horizontal list for accessories.
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: chosenAccessories.length + 1,
                        itemBuilder: (context, index) {
                          if (index == chosenAccessories.length) {
                            return GestureDetector(
                              onTap: () => _editAccessoryItem(index),
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
                            final accessoryUrl = chosenAccessories[index];
                            return _buildAccessoryItem(index, accessoryUrl);
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

  void _goToPreviousDay() {
    setState(() {
      selectedDate = selectedDate.subtract(const Duration(days: 1));
      if (selectedDate.isBefore(DateTime(2020))) {
        selectedDate = DateTime(2020);
      }
    });
  }

  void _goToNextDay() {
    setState(() {
      selectedDate = selectedDate.add(const Duration(days: 1));
      if (selectedDate.isAfter(DateTime(2030))) {
        selectedDate = DateTime(2030);
      }
    });
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  String _getFormattedDate(DateTime date) {
    return DateFormat('EEEE, d MMMM y').format(date);
  }

  // Dummy outfit generator.
  void _generateOutfit() {
    setState(() {
      chosenClothes['Layer'] =
      'https://www.kurin.com/wp-content/uploads/placeholder-square.jpg';
      chosenClothes['Shirt'] =
      'https://www.kurin.com/wp-content/uploads/placeholder-square.jpg';
      chosenClothes['Bottoms'] =
      'https://www.kurin.com/wp-content/uploads/placeholder-square.jpg';
      chosenClothes['Shoes'] =
      'https://www.kurin.com/wp-content/uploads/placeholder-square.jpg';
      chosenAccessories.clear();
      chosenAccessories.add(
          'https://www.kurin.com/wp-content/uploads/placeholder-square.jpg');
    });
  }

  // Saves the outfit and navigates back to OutfitsPage.
// Saves the outfit and navigates back to OutfitsPage.
  void _saveOutfit() {
    if (!canSave) return;

    final filteredClothes = Map<String, String>.from(chosenClothes)
      ..removeWhere((key, value) => value == null || value.isEmpty);

    final newOutfit = Outfit(
      date: selectedDate, // ✅ Use the updated selected date
      clothes: filteredClothes,
      accessories: List.from(chosenAccessories.where((a) => a != null && a.isNotEmpty)),
    );

    // ✅ Send the outfit back to OutfitsPage
    Navigator.pop(context, newOutfit);
  }

  // Handles editing a clothing item.
  Future<void> _editClothingItem(String category) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ItemSelectionPage(
          slot: category,
          fromCreateOutfit: true,
        ),
      ),
    );
    if (result != null) {
      final selectedItem = result['item'] as Item;
      final slotResult = result['slot'] as String?;
      setState(() {
        chosenClothes[slotResult ?? category] = selectedItem.imageUrl;
      });
    }
  }

  // Handles editing an accessory item.
  Future<void> _editAccessoryItem(int index) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ItemSelectionPage(
          fromCreateOutfit: true,
        ),
      ),
    );
    if (result != null) {
      final selectedItem = result['item'] as Item;
      setState(() {
        if (index < chosenAccessories.length) {
          chosenAccessories[index] = selectedItem.imageUrl;
        } else {
          chosenAccessories.add(selectedItem.imageUrl);
        }
      });
    }
  }

  Widget _buildClothingItem(String category, String? imageUrl) {
    return GestureDetector(
      onTap: () => _editClothingItem(category),
      onLongPress: () {
        setState(() {
          chosenClothes[category] = null;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
          image: (imageUrl != null && imageUrl.isNotEmpty)
              ? DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
          )
              : null,
        ),
        child: (imageUrl == null || imageUrl.isEmpty)
            ? Center(
          child: Text(
            category.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        )
            : null,
      ),
    );
  }

  Widget _buildAccessoryItem(int index, String? imageUrl) {
    return GestureDetector(
      onTap: () => _editAccessoryItem(index),
      onLongPress: () {
        setState(() {
          if (index < chosenAccessories.length) {
            chosenAccessories.removeAt(index);
          }
        });
      },
      child: Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: Colors.grey.shade300),
          image: (imageUrl != null && imageUrl.isNotEmpty)
              ? DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
          )
              : null,
        ),
        child: (imageUrl == null || imageUrl.isEmpty)
            ? const Icon(Icons.add, color: Colors.grey)
            : null,
      ),
    );
  }
}

class Outfit {
  final DateTime date;
  final Map<String, String?> clothes;
  final List<String?> accessories;

  Outfit({
    required this.date,
    required this.clothes,
    required this.accessories,
  });
}

class ColorTile {
  final Color color;
  ColorTile({required this.color});
}