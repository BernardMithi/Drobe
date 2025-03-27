import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:drobe/Wardrobe/wardrobe.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'Outfits/outfits.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:drobe/models/item.dart';
import 'package:drobe/services/outfitStorage.dart';
import 'package:drobe/models/outfit.dart';
import 'package:drobe/services/hiveServiceManager.dart';
import 'package:drobe/settings/settings.dart';
import 'package:drobe/settings/profile.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'weather_service.dart';


final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive and register adapters
  await Hive.initFlutter();
  Hive.registerAdapter(ItemAdapter());
  Hive.registerAdapter(OutfitAdapter());

  // Initialize Hive services and open boxes
  await HiveManager().init();
  await Hive.openBox<Outfit>('outfits');
  await OutfitStorageService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Drobe App',
      theme: ThemeData(
        primarySwatch: Colors.grey,
        fontFamily: 'Avenir',
      ),
      home: const Homepage(),
      navigatorObservers: [routeObserver],
    );
  }
}

// Homepage with RouteAware for refreshing on return
class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> with RouteAware {
  int currentIndex = 0;
  List<Outfit> todayOutfits = [];
  bool isLoading = true;
  final WeatherService weatherService = WeatherService();
  String greeting = "HI";

  @override
  void initState() {
    super.initState();
    _loadTodaysOutfits();
    _updateGreeting();
  }

  void _updateGreeting() {
    setState(() {
      greeting = weatherService.getGreeting();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Refresh when returning to this page.
    _loadTodaysOutfits();
    _updateGreeting();
    super.didPopNext();
  }

  Future<void> _loadTodaysOutfits() async {
    try {
      final allOutfits = await OutfitStorageService.getAllOutfits();
      final today = DateTime.now();
      final normalizedToday = DateTime(today.year, today.month, today.day);

      setState(() {
        todayOutfits = allOutfits.where((outfit) {
          final outfitDate = DateTime(
            outfit.date.year,
            outfit.date.month,
            outfit.date.day,
          );
          return outfitDate.isAtSameMomentAs(normalizedToday);
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading outfits: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DraggableMenuScreen(),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfilePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Add the profile button to the app bar instead
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(
                Icons.account_circle,
                size: 42,
                color: Colors.white,
              ),
              onPressed: _navigateToProfile,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Greeting Header with darker overlay
          Container(
            width: double.infinity,
            height: 160,
            padding: const EdgeInsets.only(top: 50),
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const NetworkImage(
                  'https://images.unsplash.com/photo-1524275539700-cf51138f679b?w=800&auto=format&fit=crop&q=60&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1yZWxhdGVkfDF8fHxlbnwwfHx8fHw%3D',
                ),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.1),
                  BlendMode.darken,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting BERNARD,',
                    style: const TextStyle(
                      fontFamily: 'Avenir',
                      fontSize: 24,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    weatherService.getSubGreeting(),
                    style: const TextStyle(
                      fontFamily: 'Avenir',
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main content
          Column(
            children: [
              const SizedBox(height: 160),
              const ImprovedWeatherWidget(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15.0,
                  vertical: 2.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "TODAY'S OUTFITS",
                      style: TextStyle(
                        fontFamily: 'Avenir',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (todayOutfits.isNotEmpty)
                      Text(
                        '${currentIndex + 1} / ${todayOutfits.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : todayOutfits.isEmpty
                    ? _buildNoOutfitsWidget()
                    : HorizontalOutfitList(
                  outfits: todayOutfits,
                  onPageChanged: (index) {
                    setState(() {
                      currentIndex = index;
                    });
                  },
                ),
              ),
            ],
          ),

          // Bottom Arrow Button to open menu
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: ArrowIcon(
                icon: Icons.keyboard_arrow_up,
                onTap: () => _showMenu(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoOutfitsWidget() {
    final double cardWidth = MediaQuery.of(context).size.width - 20;

    return Padding(
      padding: const EdgeInsets.only(left: 2.0, right: 2.0, bottom: 60.0),
      child: SizedBox(
        width: cardWidth,
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          elevation: 2,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 1),
                // Styled "No outfits" text
                Text(
                  'NO OUTFITS FOR TODAY',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                // Subtle description text
                Text(
                  'Create your first outfit for today',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 30),
                // Styled button with gray background
                Container(
                  child: Material(
                    clipBehavior: Clip.antiAlias,
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => OutfitsPage()),
                        );
                      },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              size: 50,
                              Icons.add_circle_outline,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Improved Weather Widget
class ImprovedWeatherWidget extends StatefulWidget {
  const ImprovedWeatherWidget({super.key});

  @override
  State<ImprovedWeatherWidget> createState() => _ImprovedWeatherWidgetState();
}

class _ImprovedWeatherWidgetState extends State<ImprovedWeatherWidget> {
  String temperature = "Loading...";
  String weatherDescription = "Fetching weather...";
  String location = "Fetching...";
  IconData weatherIcon = Icons.cloud_queue;
  final WeatherService weatherService = WeatherService();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeatherData();
  }

  Future<void> _loadWeatherData() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Get location
      final position = await weatherService.getLocation();

      // Fetch weather data
      final weatherData = await weatherService.fetchWeather(
          position.latitude,
          position.longitude
      );

      if (weatherData['success'] == true) {
        setState(() {
          temperature = weatherData['temperature'];
          weatherDescription = weatherData['description'];
          location = weatherData['location'];

          // Make sure we're getting a valid condition code
          final int conditionCode = weatherData['conditionCode'];

          // Get the appropriate icon
          weatherIcon = weatherService.getWeatherIcon(conditionCode);
          isLoading = false;
        });
      } else {
        setState(() {
          weatherDescription = weatherData['message'];
          weatherIcon = Icons.error_outline;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        weatherDescription = "Error: $e";
        weatherIcon = Icons.error_outline;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String date = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Weather Info
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(weatherIcon, size: 48, color: Colors.deepOrange),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          temperature,
                          style: const TextStyle(
                            fontFamily: 'Avenir',
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          weatherDescription,
                          style: const TextStyle(
                            fontFamily: 'Avenir',
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Date and Location
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    date,
                    style: const TextStyle(
                      fontFamily: 'Avenir',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  Text(
                    location,
                    style: const TextStyle(
                      fontFamily: 'Avenir',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Draggable Menu Screen
class DraggableMenuScreen extends StatelessWidget {
  const DraggableMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.77,
      minChildSize: 0.3,
      maxChildSize: 0.77,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 10),
                child: ArrowIcon(
                  icon: Icons.keyboard_arrow_down,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              // Expanded ListView
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    MenuTile(
                      icon: Icons.checkroom,
                      label: "OUTFITS",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => OutfitsPage()),
                        );
                      },
                    ),
                    MenuTile(
                      icon: Icons.inventory,
                      label: "MY WARDROBE",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => WardrobePage()),
                        );
                      },
                    ),
                    MenuTile(
                      icon: Icons.grid_view,
                      label: "LOOKBOOK",
                    ),
                    MenuTile(
                      icon: Icons.local_laundry_service,
                      label: "LAUNDRY",
                    ),
                    MenuTile(
                      icon: Icons.info_outline,
                      label: "FABRIC TIPS",
                    ),
                    MenuTile(
                      icon: Icons.account_circle,
                      label: "ACCOUNT",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ProfilePage()),
                        );
                      },
                    ),
                    MenuTile(
                      icon: Icons.settings,
                      label: "SETTINGS",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SettingsPage()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// MenuTile Widget
class MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const MenuTile({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 2),
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: Colors.grey[800]),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Avenir',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ArrowIcon Widget
class ArrowIcon extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;

  const ArrowIcon({
    super.key,
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 40,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 30,
          color: Colors.grey[800],
        ),
      ),
    );
  }
}

// Horizontal Outfit List
class HorizontalOutfitList extends StatelessWidget {
  final List<Outfit> outfits;
  final ValueChanged<int> onPageChanged;

  const HorizontalOutfitList({
    super.key,
    required this.outfits,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final double cardWidth = MediaQuery.of(context).size.width - 32;

    return Padding(
      padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 60.0),
      child: PageView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: outfits.length,
        onPageChanged: onPageChanged,
        itemBuilder: (context, index) {
          final outfit = outfits[index];

          // Get a main image from the outfit
          String? mainImageUrl = outfit.clothes['SHIRT'] ??
              outfit.clothes.values.firstWhere(
                    (url) => url != null && url.isNotEmpty,
                orElse: () => null,
              );

          return SizedBox(
            width: cardWidth,
            child: OutfitCard(
              imageUrl: mainImageUrl ?? '/placeholder.svg',
              description: outfit.name,
              outfit: outfit,
            ),
          );
        },
      ),
    );
  }
}

// Individual Outfit Card
class OutfitCard extends StatelessWidget {
  final String imageUrl;
  final String description;
  final Outfit outfit;

  const OutfitCard({
    super.key,
    required this.imageUrl,
    required this.description,
    required this.outfit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OutfitsPage(),
                  ),
                );
              },
              child: _buildClothingGrid(),
            ),
          ),

          // Accessories section
          if (_hasAccessories())
            Container(
              height: 120, // Increased height to accommodate the wheel
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
              child: Center(
                child: _buildAccessoriesRow(),
              ),
            ),
        ],
      ),
    );
  }

  bool _hasAccessories() {
    return outfit.accessories.any((accessory) => accessory != null && accessory.isNotEmpty);
  }

  Widget _buildClothingGrid() {
    final List<MapEntry<String, String?>> validClothes = outfit.clothes.entries
        .where((entry) => entry.value != null && entry.value!.isNotEmpty)
        .toList();

    if (validClothes.isEmpty) {
      return _buildPlaceholderImage();
    }

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      physics: const NeverScrollableScrollPhysics(), // Make grid non-scrollable
      shrinkWrap: true, // Ensure grid takes only the space it needs
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
      children: validClothes.map((entry) {
        return _buildClothingItem(entry.key, entry.value!);
      }).toList(),
    );
  }

  Widget _buildAccessoriesRow() {
    final List<String> validAccessories = outfit.accessories
        .where((accessory) => accessory != null && accessory.isNotEmpty)
        .cast<String>() // Cast to non-nullable String after filtering out nulls
        .toList();

    if (validAccessories.isEmpty) {
      return const Center(
        child: Text(
          'No accessories',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      );
    }

    // Calculate the middle index to start from
    final int initialIndex = validAccessories.length ~/ 2;

    return Column(
      children: [
        // Accessories scroll view
        Expanded(
          child: RotatedBox(
            quarterTurns: 3, // Rotate to make the wheel vertical
            child: ListWheelScrollView.useDelegate(
              itemExtent: 80,
              diameterRatio: 1.8,
              offAxisFraction: -0.5, // Offset to the left
              squeeze: 0.8,
              physics: const FixedExtentScrollPhysics(),
              controller: FixedExtentScrollController(initialItem: initialIndex),
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: validAccessories.length,
                builder: (context, index) {
                  return RotatedBox(
                    quarterTurns: 1, // Rotate items back to normal
                    child: Container(
                      width: 70,
                      height: 70,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: _buildImageWidget(validAccessories[index], 'Accessory'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // Scroll indicator
        Container(
          height: 15,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_left, size: 14, color: Colors.grey[400]),
              Text(
                'SCROLL FOR MORE',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
              Icon(Icons.arrow_right, size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClothingItem(String category, String imagePath) {
    return Container(
      margin: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildImageWidget(imagePath, category),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessoryItem(String imagePath) {
    return Container(
      width: 70,
      height: 70,
      margin: const EdgeInsets.only(right: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: _buildImageWidget(imagePath, 'Accessory'),
      ),
    );
  }

  Widget _buildImageWidget(String imagePath, String type) {
    return FutureBuilder<String>(
      future: getAbsoluteImagePath(imagePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        } else if (snapshot.hasError || !snapshot.hasData) {
          return _buildItemPlaceholder(type);
        } else {
          final absolutePath = snapshot.data!;
          final file = File(absolutePath);

          if (file.existsSync()) {
            return Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildItemPlaceholder(type);
              },
            );
          } else {
            return _buildItemPlaceholder(type);
          }
        }
      },
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(
          Icons.checkroom,
          size: 48,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildItemPlaceholder(String type) {
    IconData icon;
    Color iconColor;

    // Choose appropriate icon and color based on item type
    if (type.toLowerCase().contains('shirt') ||
        type.toLowerCase().contains('top') ||
        type.toLowerCase().contains('tee')) {
      icon = Icons.dry_cleaning;
      iconColor = Colors.blue[300]!;
    } else if (type.toLowerCase().contains('pant') ||
        type.toLowerCase().contains('trouser') ||
        type.toLowerCase().contains('short') ||
        type.toLowerCase().contains('bottom')) {
      icon = Icons.layers;
      iconColor = Colors.brown[300]!;
    } else if (type.toLowerCase().contains('shoe') ||
        type.toLowerCase().contains('sneaker') ||
        type.toLowerCase().contains('boot')) {
      icon = Icons.snowshoeing;
      iconColor = Colors.black54;
    } else if (type.toLowerCase().contains('accessory')) {
      icon = Icons.watch;
      iconColor = Colors.amber[700]!;
    } else if (type.toLowerCase().contains('layer') ||
        type.toLowerCase().contains('jacket') ||
        type.toLowerCase().contains('coat')) {
      icon = Icons.layers_outlined;
      iconColor = Colors.green[700]!;
    } else {
      icon = Icons.checkroom;
      iconColor = Colors.grey[600]!;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 36,
              color: iconColor,
            ),
            const SizedBox(height: 4),
            Text(
              type,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to convert stored relative paths to absolute paths.
Future<String> getAbsoluteImagePath(String storedPath) async {
  final directory = await getApplicationDocumentsDirectory();
  if (storedPath.contains('/Documents/')) {
    const docsKeyword = '/Documents/';
    final index = storedPath.indexOf(docsKeyword);
    final relativePath = storedPath.substring(index + docsKeyword.length);
    return path.join(directory.path, relativePath);
  } else {
    return path.join(directory.path, storedPath);
  }
}

