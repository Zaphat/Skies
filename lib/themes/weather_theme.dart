import 'dart:math';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:skies/utils/utils.dart';

class WeatherTheme with WeatherConditions {
  static const LinearGradient loadingGradient = LinearGradient(
    colors: [Colors.blue, Colors.lightBlueAccent],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static Map<String, LinearGradient> themeDay = {
    'sunny': const LinearGradient(
        colors: [
          Color(0xff3F28CF),
          Color(0xff5A6AC0),
          Color(0xff4CBAE9),
          Color(0xffE89153)
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 1 / 3, 2 / 3, 1.0],
        tileMode: TileMode.clamp,
        transform: GradientRotation(-pi)),
    'winter': const LinearGradient(
        colors: [Color(0xff5F8CB3), Color(0xffC1CDD9)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.6609997749328613, 0.930999755859375],
        transform: GradientRotation(-pi)),
    'cloud': const LinearGradient(
        colors: [Color(0xff6F6A6A), Color(0xffB1B0B0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.3409997522830963, 0.7909997701644897],
        transform: GradientRotation(-pi)),
    'rain': const LinearGradient(
        colors: [Color(0xff215479), Color(0xff0F307D)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.44599974155426025, 0.7959997653961182],
        transform: GradientRotation(-pi)),
  };
  static Map<String, LinearGradient> themeNight = {
    'winter': const LinearGradient(
        colors: [Color(0xff1E2C3C), Color(0xff0D1321)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.6609997749328613, 0.930999755859375],
        transform: GradientRotation(-pi)),
    'cloud': const LinearGradient(
        colors: [Color(0xff251B49), Color(0xff2C3E50)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.2509997487068176, 0.8009997606277466],
        transform: GradientRotation(-pi)),
    'star': const LinearGradient(
        colors: [Color(0xff130A20), Color(0xff191970)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.3359997570514679, 1.0],
        transform: GradientRotation(-pi)),
    'rain': const LinearGradient(
        colors: [Color(0xff191970), Color(0xff4B5D67)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.26099976897239685, 0.9909997582435608],
        transform: GradientRotation(-pi)),
  };
  static Map<String, Map<Set<int>, String>> themeMapping = {
    'day': {
      WeatherConditions.clear: 'sunny',
      WeatherConditions.snow: 'winter',
      WeatherConditions.rainShowers: 'rain',
      WeatherConditions.thunderstorm: 'rain',
    },
    'night': {
      WeatherConditions.snow: 'winter',
      WeatherConditions.rainShowers: 'rain',
      WeatherConditions.thunderstorm: 'rain',
    },
  };
  static late Map<dynamic, dynamic> _mainIconMap;
  static late Map<dynamic, dynamic> _subIconMap;
  WeatherTheme() {
    _initialize();
  }
  static _initialize() async {
    await _loadIconMap();
  }

  static _loadIconMap() async {
    String data = await rootBundle
        .loadString('$CONFIG_BASE/${CONFIG_PATH['weather_icons']}');
    final yamlMap = loadYaml(data);
    final iconMap = yamlMap['weather_icons'] as YamlMap;
    _mainIconMap = _parseIconMap(iconMap['main_icon']);
    _subIconMap = _parseIconMap(iconMap['sub_icon']);
  }

  static Map<dynamic, dynamic> _parseIconMap(iconMap) {
    Map<dynamic, dynamic> result = {};

    final day = iconMap['day'] as YamlMap;
    final night = iconMap['night'] as YamlMap;
    final winter = iconMap['winter'] as YamlMap;

    result['day'] = {};
    for (var entry in day.entries) {
      final key = entry.key is String ? entry.key : Set<int>.from(entry.key);
      final value = List<String>.from(entry.value);
      result['day'][key] = value;
    }

    result['night'] = {};
    for (var entry in night.entries) {
      final key = entry.key is String ? entry.key : Set<int>.from(entry.key);
      final value = List<String>.from(entry.value);
      result['night'][key] = value;
    }

    result['winter'] = {};
    for (var entry in winter.entries) {
      final key = entry.key is String ? entry.key : Set<int>.from(entry.key);
      final value = List<String>.from(entry.value);
      result['winter'][key] = value;
    }

    return result;
  }

  _getThemeKey(
      bool isNight, int weatherCode, bool isSnowing, bool isRainingSoon) {
    String timeOfDay = isNight ? 'night' : 'day';

    if (isSnowing) {
      return 'winter';
    }

    if (isRainingSoon) {
      return 'rain';
    }

    for (var entry in themeMapping[timeOfDay]!.entries) {
      if (entry.key.contains(weatherCode)) {
        return entry.value;
      }
    }

    return 'cloud'; // Default theme
  }

  // PUBLIC API
  LinearGradient getAdaptiveTheme(
      bool isNight, bool isSnowing, bool isRainingSoon, int weatherCode) {
    String themeKey =
        _getThemeKey(isNight, weatherCode, isSnowing, isRainingSoon);
    return isNight ? themeNight[themeKey]! : themeDay[themeKey]!;
  }

  String getCurrentMainIcon(
      specialTime, currentIndex, weatherHourlyData, timestampDescriptions) {
    final currentWeatherCode = weatherHourlyData['weather_code'][currentIndex];
    final currentTemperature =
        weatherHourlyData['temperature_2m'][currentIndex];
    final currentWindSpeed = weatherHourlyData['wind_speed_10m'][currentIndex];
    final currentTimeOfDay = _mainIconMap[timestampDescriptions[currentIndex]];

    // winter
    if (WeatherConditions.snow.contains(currentWeatherCode)) {
      final winterIconList = _mainIconMap['winter'][currentWeatherCode];
      return winterIconList[Random().nextInt(winterIconList.length)];
    }
    // sunrise - sunset
    if (specialTime['sunrise']) {
      final sunriseIconList = _mainIconMap['day']['sunrise'];
      return sunriseIconList[Random().nextInt(sunriseIconList.length)];
    }
    if (specialTime['sunset']) {
      final sunsetIconList = _mainIconMap['day']['sunset'];
      return sunsetIconList[Random().nextInt(sunsetIconList.length)];
    }
    // [clear] if temperature > 30 is hot, else if wind_speed_10m > 5.8 is windy
    if (WeatherConditions.clear.contains(currentWeatherCode)) {
      if (currentTemperature > 30) {
        final hotIconList = currentTimeOfDay['hot'];
        return hotIconList[Random().nextInt(hotIconList.length)];
      } else if (currentWindSpeed > 5.8) {
        final windyIconList = currentTimeOfDay['windy'];
        return windyIconList[Random().nextInt(windyIconList.length)];
      }
    }
    // match weather code with icon list
    for (var key in currentTimeOfDay.keys) {
      if (key is Set && key.contains(currentWeatherCode)) {
        final iconList = currentTimeOfDay[key];
        return iconList[Random().nextInt(iconList.length)];
      }
    }
    throw Exception('Icon not found');
  }

  List<String> getHourlyIcons(weatherHourlyData, timestampDescriptions) {
    List<String> icons = [];
    final weatherCodes = weatherHourlyData['weather_code'];
    for (int i = 0; i < weatherCodes.length; i++) {
      final weatherCode = weatherCodes[i];
      final desc = timestampDescriptions[i];
      final currentTimeOfDay = _subIconMap[desc];
      if (WeatherConditions.snow.contains(weatherCode)) {
        final winterIconList = _subIconMap['winter'][weatherCode];
        icons.add(winterIconList[Random().nextInt(winterIconList.length)]);
        continue;
      }
      for (var key in currentTimeOfDay.keys) {
        if (key is Set && key.contains(weatherCode)) {
          final iconList = currentTimeOfDay[key];
          icons.add(iconList[Random().nextInt(iconList.length)]);
          break;
        }
      }
    }
    return icons;
  }
}
