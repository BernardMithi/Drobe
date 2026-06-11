import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drobe/services/hiveServiceManager.dart';
import 'package:drobe/services/outfitStorage.dart';
import 'package:drobe/auth/authService.dart';
import 'package:drobe/routes.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:drobe/Wardrobe/wardrobe.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:drobe/Outfits/outfits.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:drobe/models/item.dart';
import 'package:drobe/models/outfit.dart';
import 'package:drobe/settings/profile.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:drobe/Lookbook/lookbook.dart';
import 'package:drobe/Laundry/laundry.dart';
import 'package:drobe/auth/authWrapper.dart';
import 'package:drobe/weather_service.dart';
import 'package:drobe/Fabrics/fabricTips.dart';
import 'package:drobe/theme/app_theme.dart';
import 'package:drobe/theme/drobe_icon.dart';
import 'package:drobe/theme/drobe_bottom_action.dart';
import 'package:drobe/settings/profileAvatar.dart';
import 'package:drobe/services/notificationService.dart'; // Add this import for notifications
import 'package:drobe/services/itemStorage.dart';
import 'package:drobe/services/lookbookStorage.dart';
import 'package:drobe/utils/category_utils.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

// App that shows while we're initializing
class LoadingApp extends StatelessWidget {
  final String message;

  const LoadingApp({Key? key, this.message = 'Initializing app...'})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(message, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

// Initialize the app properly - we'll initialize AuthService here as well
Future<void> initializeApp() async {
  try {
    // Set preferred orientations
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Initialize HiveManager (which handles adapter registration)
    await HiveManager().init().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('HiveManager initialization timed out, continuing anyway');
        return; // Return void as expected
      },
    );

    // Initialize OutfitStorageService
    await OutfitStorageService.init().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint(
            'OutfitStorageService initialization timed out, continuing anyway');
        return; // Return void as expected
      },
    );

    // Initialize AuthService (now using Hive)
    await AuthService().initialize().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('AuthService initialization timed out, continuing anyway');
        return true; // Return bool as expected
      },
    );

    // Initialize NotificationService
    await NotificationService().init().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint(
            'NotificationService initialization timed out, continuing anyway');
        return true; // Return bool as expected
      },
    );

    // Create a demo user if needed
    await AuthService().createDemoUserIfNeeded().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('Demo user creation timed out, continuing anyway');
        return; // Return void as expected
      },
    );

    debugPrint('App initialized successfully');
  } catch (e) {
    debugPrint('Error initializing app: $e');
    // Do not clear persistent data automatically. Startup failures should not
    // wipe accounts, wardrobe items, outfits, or lookbook entries.
    try {
      await HiveManager().init();
      await OutfitStorageService.init();
      await AuthService().initialize();

      // Try to initialize notification service again
      try {
        await NotificationService().init();
      } catch (notificationError) {
        debugPrint(
            'Failed to initialize notifications after recovery: $notificationError');
        // Continue without notifications if they fail
      }
    } catch (recoveryError) {
      debugPrint('Recovery failed: $recoveryError');
      // Continue anyway
    }
  }
}

// Modify the main function to ensure proper initialization sequence
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services in the correct order
  try {
    // First initialize AuthService
    final authService = AuthService();
    await authService.initialize();
    debugPrint('AuthService initialized in main()');

    // Then initialize HiveManager
    await HiveManager().init();
    debugPrint('HiveManager initialized in main()');

    // Then initialize storage services
    await ItemStorageService.init();
    await OutfitStorageService.init();
    await LookbookStorageService.init();
    debugPrint('All storage services initialized in main()');
  } catch (e) {
    debugPrint('Error initializing services in main(): $e');
  }

  // This ensures Flutter is initialized before we do anything else
  //WidgetsFlutterBinding.ensureInitialized();

  // Show a loading screen while we handle initialization
  runApp(const LoadingApp(message: 'Starting app...'));

  try {
    // Initialize HiveManager first with a timeout
    bool hiveInitialized = false;
    try {
      await HiveManager().init().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('HiveManager initialization timed out, continuing anyway');
          hiveInitialized = true;
        },
      );
      hiveInitialized = true;
    } catch (e) {
      debugPrint('HiveManager initialization error: $e');
      hiveInitialized = true; // Continue anyway
    }

    // Initialize OutfitStorageService
    bool outfitStorageInitialized = false;
    try {
      await OutfitStorageService.init().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint(
              'OutfitStorageService initialization timed out, continuing anyway');
          outfitStorageInitialized = true;
        },
      );
      outfitStorageInitialized = true;
    } catch (e) {
      debugPrint('OutfitStorageService initialization error: $e');
      outfitStorageInitialized = true; // Continue anyway
    }

    // Initialize AuthService and wait for it to complete
    bool authInitialized = false;
    try {
      final authService = AuthService();
      authInitialized = await authService.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('AuthService initialization timed out, continuing anyway');
          return true; // Fixed: Always return a boolean value
        },
      );
    } catch (e) {
      debugPrint('AuthService initialization error: $e');
      authInitialized = true; // Continue anyway
    }

    // Initialize NotificationService
    bool notificationInitialized = false;
    try {
      final notificationService = NotificationService();
      notificationInitialized = await notificationService.init().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint(
              'NotificationService initialization timed out, continuing anyway');
          return true; // Fixed: Always return a boolean value
        },
      );
    } catch (e) {
      debugPrint('NotificationService initialization error: $e');
      notificationInitialized = true; // Continue anyway
    }

    if (!notificationInitialized) {
      debugPrint('Warning: NotificationService initialization failed');
      // We'll continue anyway and let the UI handle this gracefully
    } else {
      debugPrint('NotificationService initialized successfully');
    }

    if (!authInitialized) {
      debugPrint('Warning: AuthService initialization failed');
      // We'll continue anyway and let the UI handle this gracefully
    } else {
      debugPrint('AuthService initialized successfully');
    }

    // Now run the actual app
    runApp(const MyApp());
  } catch (e) {
    // If there's an error during initialization, show an error screen
    debugPrint('Critical error during app initialization: $e');
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Error Starting App',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w300),
                ),
                const SizedBox(height: 8),
                Text('$e', style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    // Show loading screen
                    runApp(const LoadingApp(message: 'Clearing data...'));

                    try {
                      // Clear all data and try again
                      await HiveManager().clearAllData().timeout(
                        const Duration(seconds: 5),
                        onTimeout: () {
                          debugPrint(
                              'Clearing data timed out, continuing anyway');
                        },
                      );

                      // Initialize again
                      await HiveManager().init();
                      await OutfitStorageService.init();
                      await AuthService().initialize();
                      await NotificationService().init();

                      // Run the app
                      runApp(const MyApp());
                    } catch (e) {
                      debugPrint('Error during recovery: $e');
                      // Run the app anyway
                      runApp(const MyApp());
                    }
                  },
                  child: const Text('Clear Data & Restart'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Drobe',
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: routes,
      onGenerateRoute: generateRoute,
      navigatorObservers: [routeObserver],
    );
  }
}

// New class to handle app startup and auth initialization
class AppStartupHandler extends StatefulWidget {
  const AppStartupHandler({Key? key}) : super(key: key);

  @override
  State<AppStartupHandler> createState() => _AppStartupHandlerState();
}

class _AppStartupHandlerState extends State<AppStartupHandler> {
  bool _isInitializing = true;
  bool _authInitialized = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      // Delay to ensure the app is fully rendered
      await Future.delayed(const Duration(milliseconds: 500));

      // Try to initialize AuthService
      final success = await AuthService().initialize();

      // Also initialize NotificationService
      await NotificationService().init();

      if (mounted) {
        setState(() {
          _authInitialized = success;
          _isInitializing = false;
        });
      }

      if (success) {
        // Create a demo user for testing if needed
        await AuthService().createDemoUserIfNeeded();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error initializing authentication: $e';
          _isInitializing = false;
          _authInitialized = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Initializing app...'),
            ],
          ),
        ),
      );
    }

    if (!_authInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 48, color: Colors.orange),
              const SizedBox(height: 20),
              const Text(
                'Authentication service unavailable',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w300),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _errorMessage.isEmpty
                      ? 'You can continue using the app without signing in.'
                      : _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const Homepage()),
                  );
                },
                child: const Text('Continue to App'),
              ),
              const SizedBox(height: 15),
              TextButton(
                onPressed: () async {
                  setState(() {
                    _isInitializing = true;
                  });
                  await _initializeAuth();
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    // Auth initialized successfully, proceed to auth wrapper
    return const AuthWrapper();
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
  String heroOutfitPrompt = "Dress for the day ahead";
  String heroTemperature = '--';
  String heroWeatherDescription = 'WEATHER';
  IconData heroWeatherIcon = Icons.cloud_queue;
  Map<String, String> _userData = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadTodaysOutfits();
    _updateGreeting();
    _loadHeroOutfitPrompt();
  }

  Future<void> _loadUserData() async {
    if (AuthService().isInitialized) {
      final userData = await AuthService().getCurrentUser();
      setState(() {
        _userData = userData;
      });
    }
  }

  void _updateGreeting() {
    setState(() {
      greeting = weatherService.getGreeting();
    });
  }

  Future<void> _loadHeroOutfitPrompt() async {
    try {
      final weather = await weatherService.getCurrentWeather();
      final temperature = (weather['temperature'] as num?)?.toDouble() ?? 20.0;
      final condition = weather['condition']?.toString().toLowerCase() ?? '';
      final description =
          weather['description']?.toString().toUpperCase() ?? 'WEATHER';

      if (!mounted) return;

      setState(() {
        heroOutfitPrompt = _buildOutfitPrompt(temperature, condition);
        heroTemperature = temperature.toStringAsFixed(1);
        heroWeatherDescription = _compactWeatherDescription(description);
        heroWeatherIcon = _weatherIconForCondition(condition);
      });
    } catch (e) {
      debugPrint('Error loading hero outfit prompt: $e');
      if (!mounted) return;

      setState(() {
        heroOutfitPrompt = _fallbackOutfitPrompt();
        heroTemperature = '--';
        heroWeatherDescription = 'WEATHER';
        heroWeatherIcon = Icons.cloud_queue;
      });
    }
  }

  IconData _weatherIconForCondition(String condition) {
    if (condition.contains('thunder')) {
      return Icons.flash_on;
    }
    if (condition.contains('rain') || condition.contains('drizzle')) {
      return Icons.umbrella;
    }
    if (condition.contains('snow')) {
      return Icons.ac_unit;
    }
    if (condition.contains('mist') ||
        condition.contains('fog') ||
        condition.contains('haze')) {
      return Icons.blur_on;
    }
    if (condition.contains('clear')) {
      return Icons.wb_sunny;
    }
    if (condition.contains('cloud')) {
      return Icons.cloud;
    }
    return Icons.cloud_queue;
  }

  String _compactWeatherDescription(String description) {
    final normalized = description.trim().toUpperCase();

    if (normalized.contains('OVERCAST')) return 'OVERCAST';
    if (normalized.contains('CLOUD')) return 'CLOUDY';
    if (normalized.contains('RAIN')) return 'RAIN';
    if (normalized.contains('DRIZZLE')) return 'DRIZZLE';
    if (normalized.contains('SNOW')) return 'SNOW';
    if (normalized.contains('CLEAR')) return 'CLEAR';
    if (normalized.contains('MIST') || normalized.contains('FOG'))
      return 'MIST';
    return normalized;
  }

  String _buildOutfitPrompt(double temperature, String condition) {
    if (condition.contains('rain') || condition.contains('drizzle')) {
      return "Rain's around. Add a waterproof layer";
    }
    if (condition.contains('snow')) {
      return "It's cold out. Bundle up in warm layers";
    }
    if (temperature >= 24) {
      return "It's warm outside. Dress light";
    }
    if (temperature >= 18) {
      return "Mild weather. Keep the outfit breathable";
    }
    if (temperature >= 12) {
      return "Cool outside. Add a light layer";
    }
    return "It's chilly out. Go for warm layers";
  }

  String _fallbackOutfitPrompt() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return "Plan a clean fit for the day ahead";
    } else if (hour < 17) {
      return "Keep it comfortable and easy to move in";
    } else {
      return "Wind down in relaxed layers";
    }
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
    _loadUserData();
    _loadTodaysOutfits();
    _updateGreeting();
    _loadHeroOutfitPrompt();
    super.didPopNext();
  }

  @override
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

      debugPrint('Loaded ${todayOutfits.length} outfits for today');
    } catch (e) {
      debugPrint('Error loading outfits: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfilePage()),
    ).then((_) {
      // Refresh user data when returning from profile page
      _loadUserData();
      setState(() {});
    });
  }

  double _heroHeight(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    return min(max(screenHeight * 0.30, 232), 262);
  }

  Widget _buildHeroHeader(BuildContext context) {
    final String firstName = _userData['name']?.split(' ').first ?? 'there';
    final String date =
        DateFormat('EEEE, MMM d').format(DateTime.now()).toUpperCase();
    final double topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      height: _heroHeight(context),
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(
            'https://images.unsplash.com/photo-1524275539700-cf51138f679b?w=1200&auto=format&fit=crop&q=70',
          ),
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.16),
                  Colors.black.withValues(alpha: 0.44),
                  Colors.black.withValues(alpha: 0.70),
                ],
                stops: const [0.0, 0.48, 1.0],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18, topPadding + 46, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, ${firstName.toUpperCase()}',
                  style: const TextStyle(
                    fontFamily: 'BarlowCondensed',
                    fontSize: 32,
                    height: 1.02,
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 6),
                Text(
                  heroOutfitPrompt,
                  style: TextStyle(
                    fontFamily: 'BarlowCondensed',
                    fontSize: 16,
                    height: 1.25,
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      height: 38,
                      constraints: const BoxConstraints(minWidth: 104),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.42),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.42)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        date,
                        style: const TextStyle(
                          fontFamily: 'BarlowCondensed',
                          fontSize: 13,
                          height: 1,
                          fontWeight: FontWeight.w300,
                          color: Colors.white,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildHeroWeatherPill(),
                  ],
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroWeatherPill() {
    return Container(
      height: 38,
      constraints: const BoxConstraints(minWidth: 104, maxWidth: 136),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(heroWeatherIcon, size: 15, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            '$heroTemperature°C',
            style: const TextStyle(
              fontFamily: 'BarlowCondensed',
              fontSize: 13,
              height: 1,
              fontWeight: FontWeight.w300,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 5),
          if (heroWeatherDescription.length <= 6)
            Flexible(
              child: Text(
                heroWeatherDescription,
                style: TextStyle(
                  fontFamily: 'BarlowCondensed',
                  fontSize: 13,
                  height: 1,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double heroHeight = _heroHeight(context);

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Profile picture in the app bar
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: _navigateToProfile,
              child: ProfileAvatar(
                key: ValueKey(
                    'header_avatar_${DateTime.now().millisecondsSinceEpoch}'),
                size: 42,
                userId: _userData['id'] ?? '',
                name: _userData['name'] ?? 'User',
                email: _userData['email'] ?? '',
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildHeroHeader(context),

          // Main content
          Column(
            children: [
              SizedBox(height: heroHeight),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22.0,
                  vertical: 18.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "TODAY'S OUTFITS",
                      style: TextStyle(
                        fontFamily: 'BarlowCondensed',
                        fontSize: 22,
                        fontWeight: FontWeight.w300,
                        color: Color(0xFF252525),
                      ),
                    ),
                    if (todayOutfits.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE6DED6)),
                        ),
                        child: Text(
                          '${currentIndex + 1} / ${todayOutfits.length}',
                          style: const TextStyle(
                            fontFamily: 'BarlowCondensed',
                            fontSize: 17,
                            fontWeight: FontWeight.w300,
                            color: Color(0xFF6A625B),
                          ),
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

          Positioned(
            left: 18,
            right: 18,
            bottom: DrobeBottomAction.drawerBottomOffset(context),
            child: BottomAppDrawer(
              onOutfitsTap: () => _openDrawerDestination(const OutfitsPage()),
              onWardrobeTap: () => _openDrawerDestination(const WardrobePage()),
              onLookbookTap: () => _openDrawerDestination(const LookbookPage()),
              onLaundryTap: () => _openDrawerDestination(const LaundryPage()),
              onFabricTipsTap: () =>
                  _openDrawerDestination(const FabricTipsPage()),
            ),
          ),
        ],
      ),
    );
  }

  void _openDrawerDestination(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    ).then((_) {
      _loadUserData();
      _loadTodaysOutfits();
      _loadHeroOutfitPrompt();
    });
  }

  Widget _buildNoOutfitsWidget() {
    final double cardWidth = MediaQuery.of(context).size.width - 20;

    return Padding(
      padding: const EdgeInsets.only(left: 2.0, right: 2.0, bottom: 96.0),
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
                    fontWeight: FontWeight.w300,
                    color: Colors.grey[700],
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                // Subtle description text
                Text(
                  'Create your first outfit for today',
                  style: TextStyle(
                    fontFamily: 'BarlowCondensed',
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    color: Colors.grey[600],
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
                          MaterialPageRoute(
                              builder: (context) => const OutfitsPage()),
                        );
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
          position.latitude, position.longitude);

      if (weatherData['success'] == true) {
        setState(() {
          final tempValue = weatherData['temperature'];
          temperature = tempValue is num
              ? tempValue.toStringAsFixed(1)
              : tempValue.toString();
          weatherDescription = weatherData['description'];
          location = weatherData['location'];

          // Make sure we're getting a valid condition code
          final int conditionCode = weatherData['conditionCode'];

          weatherIcon = weatherService.getWeatherIcon(conditionCode);
          isLoading = false;
        });
      } else {
        setState(() {
          temperature = '--';
          weatherDescription = 'WEATHER UNAVAILABLE';
          location = 'Unavailable';
          weatherIcon = Icons.error_outline;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        temperature = '--';
        weatherDescription = 'WEATHER UNAVAILABLE';
        location = 'Unavailable';
        weatherIcon = Icons.error_outline;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 142),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE8E3DD)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1E8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(weatherIcon,
                              size: 34, color: const Color(0xFFFF5722)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'OUTFIT WEATHER',
                                style: TextStyle(
                                  fontFamily: 'BarlowCondensed',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w300,
                                  color: Color(0xFF8A8179),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    temperature,
                                    style: const TextStyle(
                                      fontFamily: 'BarlowCondensed',
                                      fontSize: 34,
                                      height: 0.95,
                                      fontWeight: FontWeight.w300,
                                      color: Color(0xFF242424),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Text(
                                      '°C',
                                      style: TextStyle(
                                        fontFamily: 'BarlowCondensed',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w300,
                                        color: Color(0xFF55504C),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 132),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F4F3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              weatherDescription,
                              style: const TextStyle(
                                fontFamily: 'BarlowCondensed',
                                fontSize: 13,
                                fontWeight: FontWeight.w300,
                                color: Color(0xFF5E6865),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _WeatherMeta(
                      icon: Icons.place_outlined,
                      label: location,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _WeatherMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _WeatherMeta({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF8A8179)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'BarlowCondensed',
              fontSize: 15,
              fontWeight: FontWeight.w300,
              color: Color(0xFF4B4743),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class BottomAppDrawer extends StatelessWidget {
  final VoidCallback onOutfitsTap;
  final VoidCallback onWardrobeTap;
  final VoidCallback onLookbookTap;
  final VoidCallback onLaundryTap;
  final VoidCallback onFabricTipsTap;

  const BottomAppDrawer({
    super.key,
    required this.onOutfitsTap,
    required this.onWardrobeTap,
    required this.onLookbookTap,
    required this.onLaundryTap,
    required this.onFabricTipsTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6F2),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0xFFE6E0D8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _BottomDrawerButton(
              iconName: DrobeIconName.wardrobe,
              fallbackIcon: CupertinoIcons.archivebox,
              label: 'Wardrobe',
              onTap: onWardrobeTap,
            ),
            _BottomDrawerButton(
              iconName: DrobeIconName.laundry,
              fallbackIcon: CupertinoIcons.drop,
              label: 'Laundry',
              onTap: onLaundryTap,
            ),
            _BottomDrawerButton(
              iconName: DrobeIconName.outfit,
              fallbackIcon: CupertinoIcons.square_stack,
              label: 'Outfits',
              isActive: true,
              onTap: onOutfitsTap,
            ),
            _BottomDrawerButton(
              iconName: DrobeIconName.lookbook,
              fallbackIcon: CupertinoIcons.square_grid_2x2,
              label: 'Lookbook',
              isPrimary: true,
              onTap: onLookbookTap,
            ),
            _BottomDrawerButton(
              iconName: DrobeIconName.fabricTips,
              fallbackIcon: CupertinoIcons.book,
              label: 'Fabric',
              onTap: onFabricTipsTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomDrawerButton extends StatelessWidget {
  final DrobeIconName? iconName;
  final IconData fallbackIcon;
  final String label;
  final bool isActive;
  final bool isPrimary;
  final VoidCallback onTap;

  const _BottomDrawerButton({
    this.iconName,
    required this.fallbackIcon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color foreground = const Color(0xFF242424);
    final Color background = isPrimary
        ? const Color(0xFFF0ECE6)
        : isActive
            ? Colors.white
            : const Color(0xFFF3EFEA);
    final Color borderColor = isPrimary
        ? const Color(0xFFE0D9D1)
        : isActive
            ? const Color(0xFFE0D8D0)
            : const Color(0xFFE7E0D8);

    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: isPrimary ? 54 : 48,
          height: isPrimary ? 54 : 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 1),
            boxShadow: isActive || isPrimary
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: iconName == null
              ? Icon(
                  fallbackIcon,
                  size: isPrimary ? 23 : 21,
                  color: foreground,
                )
              : DrobeIcon(
                  name: iconName!,
                  fallback: fallbackIcon,
                  size: isPrimary ? 23 : 21,
                  color: foreground,
                ),
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
      padding: const EdgeInsets.only(left: 18.0, right: 18.0, bottom: 104.0),
      child: PageView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: outfits.length,
        onPageChanged: onPageChanged,
        itemBuilder: (context, index) {
          final outfit = outfits[index];

          // Get a main image from the outfit
          String? mainImageUrl = getOutfitClothingBySlot(
                outfit.clothes,
                'SHIRT',
              ) ??
              outfit.clothes.values.firstWhere(
                (url) => url != null && url.isNotEmpty,
                orElse: () => null,
              );

          return SizedBox(
            width: cardWidth,
            child: OutfitCard(
              key: ValueKey('outfit-card-${outfit.id}'),
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
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const OutfitsPage(),
          ),
        );
      },
      child: _buildFloatingClothes(),
    );
  }

  Widget _buildFloatingClothes() {
    final normalizedClothes = normalizeOutfitClothes(outfit.clothes);
    final List<MapEntry<String, String?>> validClothes = normalizedClothes
        .entries
        .where((entry) => entry.value != null && entry.value!.isNotEmpty)
        .toList();
    final List<String> validAccessories = outfit.accessories
        .where((accessory) => accessory != null && accessory.isNotEmpty)
        .cast<String>()
        .toList();

    if (validClothes.isEmpty && validAccessories.isEmpty) {
      return _buildPlaceholderImage();
    }

    final List<_FloatingOutfitPiece> pieces = [
      ...validClothes.map(
        (entry) => _FloatingOutfitPiece(
          category: entry.key,
          imagePath: entry.value!,
          isAccessory: false,
        ),
      ),
      ...validAccessories.map(
        (imagePath) => _FloatingOutfitPiece(
          category: 'Accessory',
          imagePath: imagePath,
          isAccessory: true,
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (int index = 0; index < pieces.length; index++)
              _buildFloatingPiece(
                  pieces[index], index, canvasSize, pieces.length),
          ],
        );
      },
    );
  }

  Widget _buildFloatingPiece(
    _FloatingOutfitPiece piece,
    int index,
    Size canvasSize,
    int totalPieces,
  ) {
    final String category = piece.category.toLowerCase();
    final bool isLayer = !piece.isAccessory && category.contains('layer');
    final bool isShirt = !piece.isAccessory && category.contains('shirt');
    final bool isShoes = !piece.isAccessory &&
        (category.contains('shoe') || category.contains('trainer'));
    final bool isBottom = !piece.isAccessory &&
        (category.contains('bottom') ||
            category.contains('trouser') ||
            category.contains('pant') ||
            category.contains('short'));

    final int accessoryCount = outfit.accessories
        .where((accessory) => accessory != null && accessory.isNotEmpty)
        .length;
    final int clothingCount = totalPieces - accessoryCount;

    final clothingSlots = <_FloatingSlot>[
      const _FloatingSlot(x: 0.02, y: 0.01, w: 0.44, h: 0.32),
      const _FloatingSlot(x: 0.54, y: 0.01, w: 0.44, h: 0.32),
      const _FloatingSlot(x: 0.02, y: 0.42, w: 0.44, h: 0.32),
      const _FloatingSlot(x: 0.54, y: 0.42, w: 0.44, h: 0.32),
    ];
    const double accW = 0.21;
    const double accH = 0.21;
    const double accGap = 0.045;
    final double totalAccWidth =
        accessoryCount * accW + (accessoryCount - 1).clamp(0, 99) * accGap;
    final double accStartX = (1.0 - totalAccWidth) / 2.0;
    final accessorySlots = List.generate(
      accessoryCount.clamp(1, 6),
      (i) => _FloatingSlot(
        x: accStartX + i * (accW + accGap),
        y: 0.78,
        w: accW,
        h: accH,
      ),
    );

    final _FloatingSlot baseSlot = piece.isAccessory
        ? accessorySlots[(index - clothingCount) % accessorySlots.length]
        : clothingSlots[index % clothingSlots.length];

    final double adjustedY = baseSlot.y;

    final double width = canvasSize.width * baseSlot.w;
    final double height = canvasSize.height * baseSlot.h;
    final double scale = piece.isAccessory ? 1.0 : 1.5125;

    return Positioned(
      left: canvasSize.width * baseSlot.x,
      top: canvasSize.height * adjustedY,
      width: width,
      height: height,
      child: Transform.rotate(
        angle: piece.isAccessory
            ? (index.isOdd ? -0.004 : 0.004)
            : (index.isOdd ? -0.01 : 0.01),
        child: Transform.scale(
          scale: scale,
          child: _buildImageWidget(piece.imagePath, piece.category),
        ),
      ),
    );
  }

  Widget _buildImageWidget(String imagePath, String type) {
    if (imagePath.startsWith('http')) {
      final provider = NetworkImage(imagePath) as ImageProvider;
      return _withShapeShadow(
        Image(
          image: provider,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              _buildItemPlaceholder(type),
        ),
        provider,
      );
    }

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
            final provider = FileImage(file) as ImageProvider;
            return _withShapeShadow(
              Image(
                image: provider,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    _buildItemPlaceholder(type),
              ),
              provider,
            );
          } else {
            return _buildItemPlaceholder(type);
          }
        }
      },
    );
  }

  Widget _withShapeShadow(Widget image, ImageProvider provider) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Transform.translate(
          offset: const Offset(0, 4),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.22),
                BlendMode.srcIn,
              ),
              child: Image(image: provider, fit: BoxFit.contain),
            ),
          ),
        ),
        image,
      ],
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
                fontSize: 12,
                fontWeight: FontWeight.w300,
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

class _OutfitStagePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x14FFFFFF),
          Color(0x00FFFFFF),
        ],
      ).createShader(Offset.zero & size);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.15, -0.2),
        radius: 0.95,
        colors: [
          const Color(0x22FFFFFF),
          const Color(0x00FFFFFF),
        ],
      ).createShader(Offset.zero & size);

    final floorPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0x00CDBCA8),
          const Color(0x33D8CABB),
        ],
        stops: const [0.58, 1.0],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, basePaint);
    canvas.drawRect(Offset.zero & size, glowPaint);

    final floorRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height * 0.68, size.width, size.height * 0.32),
      const Radius.circular(28),
    );
    canvas.drawRRect(floorRect, floorPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FloatingOutfitPiece {
  final String category;
  final String imagePath;
  final bool isAccessory;

  const _FloatingOutfitPiece({
    required this.category,
    required this.imagePath,
    required this.isAccessory,
  });
}

class _FloatingSlot {
  final double x;
  final double y;
  final double w;
  final double h;

  const _FloatingSlot({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });
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

// Helper method to create a demo user if needed
extension AuthServiceExtension on AuthService {
  Future<void> createDemoUserIfNeeded() async {
    if (!isInitialized) {
      await initialize();
    }

    // Only create a demo user in specific development scenarios
    // For example, check for a debug flag or environment variable
    bool shouldCreateDemoUser = false;

    // For debugging purposes only - set to true to enable demo user creation
    // In production, this should always be false
    // Uncomment this line to enable demo user creation during development
    // shouldCreateDemoUser = true;

    if (!isLoggedIn && shouldCreateDemoUser) {
      try {
        final userId = await createUserDirectly(
            'Demo User', 'demo@example.com', 'password123');
        debugPrint('Created demo user with ID: $userId');
      } catch (e) {
        debugPrint('Failed to create demo user: $e');
      }
    }
  }

  // A method that creates a user directly without requiring a BuildContext
  Future<String> createUserDirectly(
      String name, String email, String password) async {
    // Implement direct user creation logic here
    // This will depend on your actual AuthService implementation
    // For example, you might directly add the user to your storage

    // This is a placeholder implementation - replace with your actual logic
    final userId = DateTime.now().millisecondsSinceEpoch.toString();

    // You might need to set the user as logged in
    // setLoggedInUser(userId, name, email);

    return userId;
  }
}
