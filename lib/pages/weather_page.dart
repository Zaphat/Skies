import 'package:flutter/material.dart';

import 'package:responsive_sizer/responsive_sizer.dart';

import 'package:skies/services/weather_service.dart';

import 'package:skies/themes/weather_theme.dart';

import 'package:logging/logging.dart';

import 'package:skies/utils/utils.dart';

import 'package:intl/intl.dart';

import 'dart:async';

import 'package:diacritic/diacritic.dart';

import 'package:auto_size_text/auto_size_text.dart';

class WeatherPage extends StatefulWidget {
  static LinearGradient _currentWeatherTheme = WeatherTheme.loadingGradient;

  static Map<String, dynamic> weatherData = {};

  static int _closestHourIndex = 0;

  static String? _currentMainIcon;

  static final Logger _logger = Logger('WeatherPage');

  static late WeatherService weatherService;

  static late WeatherTheme weatherTheme;

  static Timer? _themeTimer;

  static Timer? _weatherTimer;

  static late DateTime _currentDateTime;

  static List<String>? _timestampDescriptions;

  static List<String>? _hourlyIcons;

  WeatherPage({super.key}) {
    weatherService = WeatherService();

    weatherTheme = WeatherTheme();

    _currentDateTime = DateTime.now();
  }

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  late Future<void> _initializationFuture;
  _fetchWeatherData() async {
    try {
      final newData = await WeatherPage.weatherService.getWeatherData();
      setState(() {
        WeatherPage.weatherData = newData;
        WeatherPage._timestampDescriptions = WeatherPage.weatherService
            .getTimeStampDescription(newData['hourly']['time']);
        WeatherPage._hourlyIcons = WeatherPage.weatherTheme.getHourlyIcons(
          WeatherPage.weatherData['hourly'],
          WeatherPage._timestampDescriptions,
        );
      });
    } on Exception catch (e) {
      WeatherPage._logger.severe('Failed to fetch weather data: $e');
    }
  }

  Future<void> _handleRefresh() async {
    await _fetchWeatherData();
    await _updateHourIndex();
    await _updateThemeAndIcon();
    return Future.delayed(const Duration(seconds: 0));
  }

  _updateHourIndex() async {
    final now = DateTime.now();
    final hourlyData = WeatherPage.weatherData['hourly'];
    if (hourlyData != null && hourlyData['time'] != null) {
      if (now.isAfter(DateTime.parse(hourlyData['time'].last))) {
        WeatherPage._closestHourIndex = hourlyData['time'].length - 1;

        return;
      }
      for (int i = 0; i < hourlyData['time'].length; i++) {
        final time = DateTime.parse(hourlyData['time'][i]);
        if (now.isBefore(time)) {
          WeatherPage._closestHourIndex = i > 0 ? i - 1 : i;
          return;
        }
      }
    }
  }

  _updateThemeAndIcon() async {
    final mainIcon = WeatherPage.weatherTheme.getCurrentMainIcon(
      {
        'sunset': WeatherPage.weatherService.aboutToSunset(),
        'sunrise': WeatherPage.weatherService.aboutToSunrise(),
      },
      WeatherPage._closestHourIndex,
      WeatherPage.weatherData['hourly'],
      WeatherPage._timestampDescriptions,
    );
    final newWeatherTheme = WeatherPage.weatherTheme.getAdaptiveTheme(
      WeatherPage.weatherService.isNight(),
      WeatherPage.weatherService.isSnowingSoon(),
      WeatherPage.weatherService.isRainingSoon(),
      WeatherPage.weatherData['hourly']['weather_code']
          [WeatherPage._closestHourIndex],
    );
    setState(() {
      WeatherPage._currentMainIcon = mainIcon;
      WeatherPage._currentWeatherTheme = newWeatherTheme;
    });
  }

  _startWeatherTimer() async {
    final now = DateTime.now();
    final nextMidnight =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final timeUntilMidnight = nextMidnight.difference(now);
    WeatherPage._weatherTimer?.cancel();
    WeatherPage._weatherTimer = Timer(timeUntilMidnight, () {
      _fetchWeatherData();
      _startWeatherTimer(); // Schedule the next update
    });
  }

  _startThemeTimer() async {
    WeatherPage._themeTimer?.cancel();

    const nextUpdate = Duration(seconds: 1200); // 20 minutes
    WeatherPage._themeTimer = Timer(nextUpdate, () {
      _updateHourIndex();
      _updateThemeAndIcon();
      _startThemeTimer();
    });
  }

  _initiateData() async {
    await _fetchWeatherData();
    await _updateHourIndex();
    await _updateThemeAndIcon();
    await _startWeatherTimer();
    await _startThemeTimer();
  }

  Widget _buildWeatherData() {
    String translateAndFormat(dynamic value, String unit) {
      if (value == null) return 'N/A';

      return '${value.toString()}$unit';
    }
    final hourlyData = WeatherPage.weatherData['hourly'];
    final temperature =
        hourlyData?['temperature_2m']?[WeatherPage._closestHourIndex];

    final weatherCode =
        hourlyData?['weather_code']?[WeatherPage._closestHourIndex];
    return SizedBox(
      height: 100.h,
      child: RefreshIndicator(
        onRefresh: _handleRefresh,
        strokeWidth: 3.5,
        color: Colors.white,
        backgroundColor: Colors.transparent,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              AutoSizeText(
                removeDiacritics(
                    WeatherPage.weatherData['city'].toString().toUpperCase()),
                style: TextStyle(
                  fontSize: 2.5.sh,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
              AutoSizeText(
                WeatherPage.weatherData['country'].toString().toUpperCase(),
                style: TextStyle(
                  fontSize: 2.sh,
                  color: Colors.white,
                ),
                maxLines: 1,
              ),
              SizedBox(height: 1.h),
              AutoSizeText(
                DateFormat('EEEE')
                    .format(WeatherPage._currentDateTime)
                    .toUpperCase(),
                style: TextStyle(
                  fontSize: 8.sw,
                  color: Colors.white,
                  fontWeight: FontWeight.w200,
                ),
                maxLines: 1,
              ),
              AutoSizeText(
                DateFormat('MMMM d')
                    .format(WeatherPage._currentDateTime)
                    .toUpperCase(),
                style: TextStyle(
                    fontSize: 10.sw,
                    color: Colors.white,
                    fontWeight: FontWeight.w600),
                maxLines: 1,
              ),
              SizedBox(height: 2.h),
              AutoSizeText(
                translateAndFormat(temperature, '°C'),
                style: TextStyle(
                  fontSize: 36.sp,
                  color: Colors.white.withOpacity(0.75),
                ),
                maxLines: 1,
              ),
              Image.asset(
                gaplessPlayback: true,
                WeatherPage._currentMainIcon!,
                fit: BoxFit.scaleDown,
                width: 50.sp,
                height: 50.sp,
              ),
              AutoSizeText(
                WeatherPage.weatherService
                    .getWeatherDescription(weatherCode)
                    .toUpperCase(),
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
              ),
              SizedBox(height: 1.h),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  childAspectRatio:
                      0.85, // Adjust this value to fit your design
                ),
                itemCount: WeatherPage._hourlyIcons?.length,
                itemBuilder: (context, index) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        WeatherPage._hourlyIcons![index],
                        width: 40, // Adjust the width as needed
                        height: 40, // Adjust the height as needed
                        fit: BoxFit.contain,
                      ),
                      AutoSizeText(
                        DateFormat.j().format(
                          DateTime.parse(hourlyData['time'][index]),
                        ),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    WeatherPage._currentDateTime = DateTime.now();

    super.initState();

    setupLogging();

    _initializationFuture = _initiateData();
  }

  @override
  void dispose() {
    WeatherPage._weatherTimer?.cancel();

    WeatherPage._themeTimer?.cancel();

    super.dispose();
  }

  @override
  void didUpdateWidget(WeatherPage oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Scaffold(
            extendBodyBehindAppBar: true,
            backgroundColor: Colors.transparent,
            body: SafeArea(
              minimum: EdgeInsets.zero,
              child: Container(
                decoration: BoxDecoration(
                  gradient: WeatherPage._currentWeatherTheme,
                ),
                child: _buildWeatherData(),
              ),
            ),
          );
        } else {
          return Scaffold(
            extendBodyBehindAppBar: true,
            backgroundColor: Colors.transparent,
            body: SafeArea(
              minimum: EdgeInsets.zero,
              child: Container(
                decoration: BoxDecoration(
                  gradient: WeatherPage._currentWeatherTheme,
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }
}
