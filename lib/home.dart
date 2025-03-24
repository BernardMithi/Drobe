import 'dart:convert';
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


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(ItemAdapter());
  Hive.registerAdapter(OutfitAdapter());


  await Hive.openBox('itemsBox');
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
    );
  }
}

// Homepage
class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

IconData weatherIcon = Icons.cloud_queue; // ✅ Define weatherIcon in Homepage

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Stack(
      children: [
        Column(
          children: [
            const SizedBox(height: 200),
            Icon(weatherIcon, size: 60, color: Colors.blue), // ✅ Use updated icon
          ],
        ),
      ],
    ),
  );
}

class _HomepageState extends State<Homepage> {
  final List<Map<String, String>> outfits = [
    {
      'image':
      'https://i.pinimg.com/736x/0a/4d/47/0a4d4711c66e734444630bd8f0d192b1.jpg',
      'description': 'T-shirt with Shorts and Sneakers',
    },
    {
      'image':
      'https://i.pinimg.com/736x/6d/8c/a4/6d8ca407235fb57945617dcdb669a53b.jpg',
      'description': 'Formal Shirt with Trousers and Shoes',
    },
    {
      'image':
      'https://i.pinimg.com/736x/82/d3/3f/82d33fe9eed4c101d6a53d0fd16adc38.jpg',
      'description': 'Hoodie with Joggers and Running Shoes',
    },
  ];

  int currentIndex = 0;

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Enables full-screen dragging
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
      ),
      builder: (context) => const DraggableMenuScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Allows AppBar to overlap the body
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Greeting Header with darker overlay
          Container(
            width: double.infinity,
            height: 200,
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                // Place greeting text on the left & account icon on the right
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Greeting text
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'HI BERNARD,',
                        style: TextStyle(
                          fontFamily: 'Avenir',
                          fontSize: 24,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Let\'s get the day going',
                        style: TextStyle(
                          fontFamily: 'Avenir',
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),

                  // Account icon
                  Icon(
                    Icons.account_circle,
                    size: 42,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),

          // Main content
          Column(
            children: [
              const SizedBox(height: 200), // Space for the greeting header
              const WeatherWidget(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "TODAY'S OUTFITS",
                      style: TextStyle(
                        fontFamily: 'Avenir',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (outfits.isNotEmpty)
                      Text(
                        '${currentIndex + 1} / ${outfits.length}',
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
                child: HorizontalOutfitList(
                  outfits: outfits,
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
}

// Weather Widget
class WeatherWidget extends StatefulWidget {
  const WeatherWidget({super.key});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  String temperature = "Loading...";
  String weatherDescription = "Fetching weather...";
  String location = "Fetching...";
  String apiKey = "463022c9dca3ba42334800d4428170fb";


  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  /// **Get User's Current Location**
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => weatherDescription = "GPS is disabled.");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => weatherDescription = "Location permission denied.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => weatherDescription = "Permission denied forever.");
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    fetchWeather(position.latitude, position.longitude);
  }

  /// **Fetch Weather Data Based on Location**
  Future<void> fetchWeather(double lat, double lon) async {
    final String url =
        "https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          temperature = "${data['main']['temp']}°C";
          weatherDescription =
              data['weather'][0]['description'].toString().toUpperCase();
          location = "${data['name']}, ${data['sys']['country']}";
        });
      } else {
        setState(() => weatherDescription = "Could not fetch weather");
      }
    } catch (e) {
      setState(() => weatherDescription = "Error fetching weather");
    }
  }


  @override
  Widget build(BuildContext context) {
    String date = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Weather Info
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(weatherIcon, size: 48, color: Colors.orangeAccent),
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
      initialChildSize: 0.77, // Start high
      minChildSize: 0.3,     // Minimum height
      maxChildSize: 0.77,     // Full height
      builder: (context, scrollController) {
        return Container(
          decoration:  BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
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
                  children:  [
                    MenuTile(
                      icon: Icons.checkroom,
                      label: "OUTFITS",
                      onTap: () {
                        Navigator.pop(context); // Close the menu
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
                        Navigator.pop(context); // Close the menu
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
                    ),
                    MenuTile(
                      icon: Icons.settings,
                      label: "SETTINGS",
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

// MenuTile
class MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  MenuTile({
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
            Icon(
                icon,
                size: 28,
                color: Colors.grey[800]
            ),
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

// ArrowIcon
class ArrowIcon extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;

  const ArrowIcon({required this.onTap, required this.icon, super.key});

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
  final List<Map<String, String>> outfits;
  final ValueChanged<int> onPageChanged;

  const HorizontalOutfitList({
    required this.outfits,
    required this.onPageChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final double cardWidth = MediaQuery.of(context).size.width - 32;

    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 80.0),
      child: PageView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: outfits.length,
        onPageChanged: onPageChanged,
        itemBuilder: (context, index) {
          final outfit = outfits[index];
          return SizedBox(
            width: cardWidth,
            child: OutfitCard(
              imageUrl: outfit['image']!,
              description: outfit['description']!,
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

  const OutfitCard({
    required this.imageUrl,
    required this.description,
    super.key,
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
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              description,
              style: const TextStyle(
                fontFamily: 'Avenir',
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
