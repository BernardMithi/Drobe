import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

class WeatherWidget extends StatefulWidget {
  const WeatherWidget({super.key});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  String temperature = "Loading...";
  String weatherDescription = "Fetching weather...";
  String location = "Fetching...";
  IconData weatherIcon = Icons.cloud_queue; // ✅ Default weather icon
  final String apiKey = "463022c9dca3ba42334800d4428170fb";

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
        final conditionCode = data['weather'][0]['id']; // ✅ Get weather condition code

        setState(() {
          temperature = "${data['main']['temp']}°C";
          weatherDescription = data['weather'][0]['description'].toString().toUpperCase();
          location = "${data['name']}, ${data['sys']['country']}";
          weatherIcon = _getWeatherIcon(conditionCode); // ✅ Assign the correct icon
        });
      } else {
        setState(() {
          weatherDescription = "Could not fetch weather";
          weatherIcon = Icons.error; // ❌ Fallback icon for errors
        });
      }
    } catch (e) {
      setState(() {
        weatherDescription = "Error fetching weather";
        weatherIcon = Icons.error_outline; // ❌ Fallback icon for API failure
      });
    }
  }

  /// **✅ Assign Weather Icon Based on Condition Code**
  IconData _getWeatherIcon(int conditionCode) {
    if (conditionCode >= 200 && conditionCode < 300) {
      return Icons.flash_on; // ⛈️ Thunderstorm
    } else if (conditionCode >= 300 && conditionCode < 400) {
      return Icons.grain; // 🌧️ Drizzle
    } else if (conditionCode >= 500 && conditionCode < 600) {
      return Icons.umbrella; // ☔ Rain (This is what should show!)
    } else if (conditionCode >= 600 && conditionCode < 700) {
      return Icons.ac_unit; // ❄️ Snow
    } else if (conditionCode >= 700 && conditionCode < 800) {
      return Icons.blur_on; // 🌫️ Fog/Mist
    } else if (conditionCode == 800) {
      return Icons.wb_sunny; // ☀️ Clear sky
    } else if (conditionCode > 800 && conditionCode <= 804) {
      return Icons.cloud; // ☁️ Cloudy
    } else {
      return Icons.help_outline; // ❓ Unknown condition
    }
  }

  @override
  Widget build(BuildContext context) {
    String date = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
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