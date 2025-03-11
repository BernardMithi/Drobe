import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:drobe/Outfits/createOutfit.dart';
import 'outfits.dart';

class CreatePalettePage extends StatefulWidget {
  final DateTime selectedDate;

  const CreatePalettePage({super.key, required this.selectedDate});


  @override
  State<CreatePalettePage> createState() => _CreatePalettePageState();
}

class _CreatePalettePageState extends State<CreatePalettePage> {
  late DateTime selectedDate;
  int _paletteSize = 3;


  @override
  void initState() {
    super.initState();
    selectedDate = widget.selectedDate; // ✅ Assign selectedDate
  }
  // Initial palette
  final List<ColorTile> _palette = [
    ColorTile(color: Colors.grey.shade200),
    ColorTile(color: Colors.teal.shade100),
    ColorTile(color: Colors.teal.shade200),
    ColorTile(color: Colors.teal.shade300),
  ];

  @override
  Widget build(BuildContext context) {
    // The first _paletteSize tiles
    final activePalette = _palette.take(_paletteSize).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('CREATE AN OUTFIT'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, size: 30),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// **Title Section**
            const Padding(
              padding: EdgeInsets.all(25),
              child: Text(
                "LETS CHOOSE A COLOUR PALETTE",
                style: TextStyle(
                  fontFamily: 'Avenir',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),

            /// **Palette Size Selection**
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 25),
              child: Text(
                "COLOUR PALETTE SIZE",
                style: TextStyle(fontFamily: 'Avenir', fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (index) {
                  final size = index + 1;
                  final isSelected = (size == _paletteSize);

                  return GestureDetector(
                    onTap: () {
                      setState(() => _paletteSize = size);
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: isSelected
                            ? const Border(
                          bottom: BorderSide(
                            color: Colors.black,
                            width: 4,
                          ),
                        )
                            : null,
                      ),
                      child: Text(
                        size.toString(),
                        style: TextStyle(
                          fontFamily: 'Avenir',
                          fontSize: 16,
                          fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),

            /// **Draggable Color Tiles**
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ReorderableListView(
                  scrollDirection: Axis.horizontal,
                  buildDefaultDragHandles: false,
                  children: List.generate(
                    _paletteSize,
                        (i) => _buildColorTileWidget(i, key: ValueKey(i)),
                  ),
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final ColorTile tile = _palette.removeAt(oldIndex);
                      _palette.insert(newIndex, tile);
                    });
                  },
                ),
              ),
            ),

            /// **Bottom Buttons**
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  /// **Generate Palette Button**
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 16),
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onPressed: _generatePalette,
                    child: const Text("GENERATE",
                      style: TextStyle(
                        fontFamily: 'Avenir',   // Apply Avenir font here
                        fontSize: 14,           // Optional: Adjust size if needed
                      ),
                    ),
                  ),

                  /// **Confirm Button** — Now pushes to the next page
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey,
                    child: IconButton(
                      icon: const Icon(Icons.check, size: 28, color: Colors.black),
                      onPressed: () {
                        // Convert the active color tiles to a List<Color>
                        final chosenColors = activePalette.map((t) => t.color).toList();

                        // Push to your CreateOutfitPage, passing the palette
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreateOutfitPage(
                              colorPalette: chosenColors,
                              savedOutfits: [],
                              selectedDate: DateTime.now(), // Pass the selected date
                            ),
                          ),
                        ).then((newOutfit) {
                          if (newOutfit != null) {
                            Navigator.pop(context, newOutfit); // ✅ Send the outfit back to OutfitsPage
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// **Build Each Color Tile**
  Widget _buildColorTileWidget(int i, {Key? key}) {
    final tile = _palette[i];

    return ReorderableDragStartListener(
      key: key!,
      index: i,
      child: Container(
        width: (MediaQuery.of(context).size.width - 48) / _paletteSize,
        height: 320,
        decoration: BoxDecoration(
          color: tile.color,
          borderRadius: BorderRadius.circular(1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            /// **Edit Button (Top)**
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.black),
              onPressed: () => _editColor(i),
            ),

            /// **Drag Handle (Below Edit Button)**
            const Icon(Icons.drag_indicator, color: Colors.black, size: 28),

            /// **Lock/Unlock Button**
            IconButton(
              icon: Icon(
                tile.isLocked ? Icons.lock : Icons.lock_open,
                color: Colors.black,
              ),
              onPressed: () {
                setState(() {
                  tile.isLocked = !tile.isLocked;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  /// **Edit Color Method**
  Future<void> _editColor(int i) async {
    TextEditingController colorController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: Colors.grey[200], // Light grey background
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// **Dialog Title**
              const Text(
                "Enter HEX Color",
                style: TextStyle(
                  fontFamily: 'Avenir',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              /// **HEX Input Field**
              TextField(
                controller: colorController,
                style: const TextStyle(fontFamily: 'Avenir', color: Colors.black),
                decoration: InputDecoration(
                  hintText: "e.g., #A1A1A1",
                  hintStyle: TextStyle(fontFamily: 'Avenir', color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.grey[300],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(2),
                    borderSide: BorderSide(color: Colors.grey[500]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              /// **Dialog Buttons**
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  /// **Cancel Button**
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black87,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),

                  /// **Confirm Button**
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[900],
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final chosenColors = _palette.take(_paletteSize).map((tile) => tile.color).toList();

                      // Navigate to CreateOutfitPage and wait for the returned outfit
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateOutfitPage(
                            colorPalette: chosenColors,
                            savedOutfits: [],
                            selectedDate: selectedDate, // ✅ Ensure selectedDate is passed
                          ),
                        ),
                      ).then((newOutfit) {
                        if (newOutfit != null) {
                          Navigator.pop(context, newOutfit); // ✅ Send new outfit back to OutfitsPage
                        }
                      });
                    },
                    child: const Text("OK"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// **Generate New Color Palette**
  Future<void> _generatePalette() async {
    setState(() {
      for (int i = 0; i < _paletteSize; i++) {
        if (!_palette[i].isLocked) {
          _palette[i].color = _randomLocalColor(); // Generates a new random color every click
        }
      }
    });
  }

  /// **Fetch Random Color from API**
  Future<Color> _fetchRandomColorFromAPI() async {
    final url = Uri.parse("https://www.colr.org/json/color/random");
    try {
      final resp = await http.get(url);
      final data = jsonDecode(resp.body);
      final hexStr = (data["colors"][0]["hex"] as String);
      return Color(int.parse("0xFF$hexStr"));
    } catch (e) {
      return _randomLocalColor();
    }
  }

  /// Fallback random color if the API fails
  Color _randomLocalColor() {
    return Color.fromARGB(
      255,
      Random().nextInt(256),
      Random().nextInt(256),
      Random().nextInt(256),
    );
  }
}

/// **ColorTile Class**
class ColorTile {
  Color color;
  bool isLocked = false;

  ColorTile({required this.color});
}