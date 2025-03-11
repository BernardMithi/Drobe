import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class WeatherService {
  final String apiKey = "463022c9dca3ba42334800d4428170fb"; // Your API Key

  /// Get the user's location and fetch weather data
  Future<Map<String, String>> getWeather() async {
    try {
      final response = await http.get(Uri.parse('https://api.weatherapi.com/v1/current.json?key=YOUR_API_KEY&q=London'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'temperature': "${data['current']['temp_c']}°C",
          'description': data['current']['condition']['text']
        };
      } else {
        return {'temperature': '--', 'description': 'Unavailable'};
      }
    } catch (e) {
      return {'temperature': '--', 'description': 'Error fetching weather'};
    }
  }

  /// Get user's current location
  Future<Position> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("GPS is disabled.");
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permission denied.");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Permission denied permanently.");
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
    );
  }

  /// Fetch weather data from OpenWeather API and format it
  Future<String> _fetchWeather(double lat, double lon) async {
    final String url =
        "https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric";

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final temperature = "${data['main']['temp'].toStringAsFixed(0)}°C";
      final condition = _capitalize(data['weather'][0]['description']);
      return "$temperature $condition"; // Example: "22°C Sunny"
    } else {
      throw Exception("Could not fetch weather.");
    }
  }

  /// Capitalize first letter of condition
  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}