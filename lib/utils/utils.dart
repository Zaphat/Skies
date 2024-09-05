import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

const CONFIG_BASE = 'assets/config';
const CONFIG_PATH = {
  'weather_service': 'weather_service.yaml',
  'weather_codes': 'weather_codes.yaml',
  'weather_icons': 'weather_icons.yaml'
};

Future<void> setupLogging() async {
  final appDocumentDir = await getApplicationDocumentsDirectory();
  final logFile = File('${appDocumentDir.path}/skies_log.txt');

  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    final logMessage =
        '${record.time}: ${record.level.name}: ${record.message}';
    logFile.writeAsStringSync('$logMessage\n', mode: FileMode.append);
  });
}

mixin WeatherConditions {
  static const clear = {0, 1};
  static const cloudy = {2, 3};
  static const foggy = {45, 48};
  static const snow = {71, 73, 75, 77, 85, 86};
  static const rainShowers = {
    51,
    53,
    55,
    56,
    57,
    61,
    63,
    65,
    66,
    67,
    80,
    81,
    82
  };
  static const thunderstorm = {95, 96, 99};
}
