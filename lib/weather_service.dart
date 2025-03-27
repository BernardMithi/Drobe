import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

class WeatherService {
  final String apiKey = "463022c9dca3ba42334800d4428170fb";

  /// Get user's current location
  Future<Position> getLocation() async {
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
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Fetch weather data from OpenWeather API
  Future<Map<String, dynamic>> fetchWeather(double lat, double lon) async {
    final String url =
        "https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Debug print to check the weather data
        print("Weather data: ${data['weather'][0]}");

        return {
          'temperature': "${data['main']['temp'].round()}°C",
          'description': data['weather'][0]['description'].toString().toUpperCase(),
          'location': "${data['name']}, ${data['sys']['country']}",
          'conditionCode': data['weather'][0]['id'],
          'success': true
        };
      } else {
        return {
          'success': false,
          'message': "Could not fetch weather. Status: ${response.statusCode}"
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': "Error fetching weather: $e"
      };
    }
  }

  /// Get appropriate weather icon based on condition code
  IconData getWeatherIcon(int conditionCode) {
    print("Getting icon for condition code: $conditionCode"); // Debug print

    if (conditionCode >= 200 && conditionCode < 300) {
      return Icons.flash_on; // Thunderstorm
    } else if (conditionCode >= 300 && conditionCode < 400) {
      return Icons.grain; // Drizzle
    } else if (conditionCode >= 500 && conditionCode < 600) {
      return Icons.umbrella; // Rain
    } else if (conditionCode >= 600 && conditionCode < 700) {
      return Icons.ac_unit; // Snow
    } else if (conditionCode >= 700 && conditionCode < 800) {
      return Icons.blur_on; // Fog/Mist
    } else if (conditionCode == 800) {
      return Icons.wb_sunny; // Clear sky
    } else if (conditionCode > 800 && conditionCode <= 804) {
      return Icons.cloud; // Cloudy
    } else {
      return Icons.help_outline; // Unknown condition
    }
  }

  /// Get greeting based on time of day
  String getGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return "MORNING";
    } else if (hour < 17) {
      return "AFTERNOON";
    } else {
      return "EVENING";
    }
  }

  /// Get sub-greeting message based on time of day
  String getSubGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return "Let's get the day going";
    } else if (hour < 17) {
      return "Hope you're having a productive day";
    } else {
      return "Time to wind down and relax";
    }
  }
}

