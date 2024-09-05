import 'dart:convert';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:yaml/yaml.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:skies/utils/utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class WeatherService with WeatherConditions {
  static const int _currentDayIndex = 0;
  static late Map<int, String> _weatherCodes;
  static late String _weatherServiceURL;
  static late Map<String, dynamic> _queryDetails;
  static Map<String, dynamic> _deviceLocation = {};
  static Map<String, dynamic> _weatherData = {};
  static Map<String, dynamic> _publicWeatherData = {};
  static final Logger _logger = Logger('WeatherService');

  WeatherService() {
    setupLogging();
    _initialize();
  }

  static _initialize() async {
    await _loadQueryDetails();
    await _loadWeatherCodes();
  }

  static _loadQueryDetails() async {
    String pathToConfig = '$CONFIG_BASE/${CONFIG_PATH['weather_service']}';
    final yamlString = await rootBundle.loadString(pathToConfig);
    final yamlMap = loadYaml(yamlString);
    final weatherApiYaml = yamlMap['weather_api'] as YamlMap;
    _weatherServiceURL = weatherApiYaml['base_url'];
    _queryDetails =
        _parseQueryDetails(weatherApiYaml['query_details'] as YamlList);
  }

  static _parseQueryDetails(YamlList queryDetailsList) {
    Map<String, dynamic> result = {};
    for (var item in queryDetailsList) {
      if (item is YamlMap) {
        result.addAll(item.map((key, value) {
          if (value is YamlList) {
            return MapEntry(key, value.join(','));
          }
          return MapEntry(key.toString(), value.toString());
        }));
      }
    }
    return result;
  }

  static _getApiUrl(dynamic latitude, dynamic longitude) {
    String queryString =
        _queryDetails.entries.map((e) => "${e.key}=${e.value}").join('&');
    return "${_weatherServiceURL}latitude=$latitude&longitude=$longitude&$queryString";
  }

  static _loadWeatherCodes() async {
    String pathToConfig = '$CONFIG_BASE/${CONFIG_PATH['weather_codes']}';
    final yamlString = await rootBundle.loadString(pathToConfig);
    final yamlMap = loadYaml(yamlString);
    final weatherCodesYaml = yamlMap['weather_codes'] as YamlMap;
    _weatherCodes = weatherCodesYaml.map(
        (key, value) => MapEntry(int.parse(key.toString()), value.toString()));
  }

  static _getCurrentLocation() async {
    //  First try to use GPS
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          throw Exception('Location permission denied');
        }
      }
      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark place = placemarks[0];
      return {
        'city': place.locality ?? 'Unknown',
        'country': place.country ?? 'Unknown',
        'latitude': position.latitude.toString(),
        'longitude': position.longitude.toString()
      };
    } catch (e) {
      _logger.warning('Failed to get location: $e');
    }
    // If location is not granted, try to get location from IP
    try {
      final response = await http.get(Uri.parse("http://ip-api.com/json/"));
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        return {
          'city': parsed['city'],
          'country': parsed['country'],
          'latitude': parsed['lat'].toString(),
          'longitude': parsed['lon'].toString()
        };
      }
    } catch (e) {
      _logger.warning('IP-based location failed: $e');
    }
    _logger.severe('Failed to get location both ways');
    return Future.error('Error: Failed to get location both ways');
  }

  static _saveWeatherDataToFile(Map<String, dynamic> data) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/weather_data.json');
    await file.writeAsString(json.encode({
      'data': data,
    }));
  }

  static _readWeatherDataFromFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/weather_data.json');
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        return json.decode(jsonString);
      }
    } catch (e) {
      _logger.warning('Error reading weather data file: $e');
    }
    return null;
  }

  static _getWeatherData() async {
    _deviceLocation = await _getCurrentLocation();
    // Check if data is cached and up-to-date
    final cachedData = await _readWeatherDataFromFile();
    if (cachedData != null) {
      final data = cachedData['data'];
      final lastUpdate = data['last_updated'];
      final locationCity = data['city'];
      final locationCountry = data['country'];
      final today = DateFormat.yMd().format(DateTime.now());
      if (today == lastUpdate &&
          locationCity == _deviceLocation['city'] &&
          locationCountry == _deviceLocation['country']) {
        return data;
      }
    }
    // else fetch new data and save it
    final String latitude = _deviceLocation['latitude'];
    final String longitude = _deviceLocation['longitude'];
    final String url = _getApiUrl(latitude, longitude);
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final parsed = jsonDecode(response.body);
      parsed['last_updated'] = DateFormat.yMd().format(DateTime.now());
      _publicWeatherData = {...parsed, ..._deviceLocation};
      await _saveWeatherDataToFile(_publicWeatherData);
      return parsed;
    }
    return Future.error('Error: Failed to get weather data');
  }

  static _updateWeatherData() async {
    _weatherData = await _getWeatherData();
    _publicWeatherData = {..._weatherData, ..._deviceLocation};
  }

  // PUBLIC API
  Future<Map<String, dynamic>> getWeatherData() async {
    // if data is empty, fetch it
    if (_publicWeatherData.isEmpty) {
      await _updateWeatherData();
    } else {
      // if data is outdated, update it
      final today = DateFormat.yMd().format(DateTime.now());
      final lastUpdate = _publicWeatherData['last_updated'];
      if (today != lastUpdate) {
        await _updateWeatherData();
      }
    }
    return _publicWeatherData;
  }

  String getWeatherDescription(int code) {
    if (code == -1) {
      return '';
    }
    return _weatherCodes[code] ?? '';
  }

  List<String> getTimeStampDescription(List timeStamps) {
    List<String> result = [];
    final sunriseTime = DateTime.parse(_weatherData['daily']['sunrise'][0]);
    final sunsetTime = DateTime.parse(_weatherData['daily']['sunset'][0]);
    for (int i = 0; i < timeStamps.length; i++) {
      final time = DateTime.parse(timeStamps[i]);
      if ((time.isAtSameMomentAs(sunriseTime) || time.isBefore(sunriseTime)) ||
          (time.isAtSameMomentAs(sunsetTime) || time.isAfter(sunsetTime))) {
        result.add('night');
      } else {
        result.add('day');
      }
    }
    return result;
  }

  bool aboutToSunrise() {
    final sunrise = _weatherData['daily']['sunrise'][_currentDayIndex];
    final sunriseTime = DateTime.parse(sunrise);
    final now = DateTime.now();
    final timeUntilSunrise = sunriseTime.difference(now);
    return timeUntilSunrise.inMinutes < 30 && timeUntilSunrise.inMinutes > 0;
  }

  bool aboutToSunset() {
    final sunset = _weatherData['daily']['sunset'][_currentDayIndex];
    final sunsetTime = DateTime.parse(sunset);
    final now = DateTime.now();
    final timeUntilSunset = sunsetTime.difference(now);
    return timeUntilSunset.inMinutes < 30 && timeUntilSunset.inMinutes > 0;
  }

  bool isNight() {
    final sunrise = _weatherData['daily']['sunrise'][_currentDayIndex];
    final sunset = _weatherData['daily']['sunset'][_currentDayIndex];
    final now = DateTime.now();
    return now.isAfter(DateTime.parse(sunset)) ||
        now.isBefore(DateTime.parse(sunrise));
  }

  bool isSnowingSoon() {
    if (_weatherData.isEmpty) {
      return false;
    }
    final hourlyData = _weatherData['hourly'];
    final now = DateTime.now();
    final threeHoursLater = now.add(const Duration(hours: 3));
    // check if it's snowing in the next 3 hours, weather codes for snowing [71, 73, 75, 77, 85, 86]
    for (int i = 0; i < hourlyData['time'].length; i++) {
      final time = DateTime.parse(hourlyData['time'][i]);
      if (time.isAfter(now) && time.isBefore(threeHoursLater)) {
        final weatherCode = hourlyData['weather_code'][i];
        if (WeatherConditions.snow.contains(weatherCode)) {
          return true;
        }
      }
    }
    return false;
  }

  bool isRainingSoon() {
    if (_weatherData.isEmpty) {
      return false;
    }
    final hourlyData = _weatherData['hourly'];
    final now = DateTime.now();
    final threeHoursLater = now.add(const Duration(hours: 3));
    // check if it's raining in the next 3 hours
    for (int i = 0; i < hourlyData['time'].length; i++) {
      final time = DateTime.parse(hourlyData['time'][i]);
      if (time.isAfter(now) && time.isBefore(threeHoursLater)) {
        final weatherCode = hourlyData['weather_code'][i];
        if (WeatherConditions.rainShowers.contains(weatherCode)) {
          return true;
        }
      }
    }
    return false;
  }
}
