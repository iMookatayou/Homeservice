class WeatherNow {
  final double temperature;
  final double windSpeed;
  final int weatherCode;
  final DateTime time;

  const WeatherNow({
    required this.temperature,
    required this.windSpeed,
    required this.weatherCode,
    required this.time,
  });

  String get conditionLabel {
    final w = weatherCode;
    if ([0].contains(w)) return 'Clear Sky';
    if ([1, 2, 3].contains(w)) return 'Partly Cloudy';
    if ([45, 48].contains(w)) return 'Fog';
    if ([51, 53, 55, 56, 57].contains(w)) return 'Drizzle';
    if ([61, 63, 65, 66, 67, 80, 81, 82].contains(w)) return 'Rain';
    if ([71, 73, 75, 77, 85, 86].contains(w)) return 'Snow';
    if ([95, 96, 99].contains(w)) return 'Thunderstorm';
    return 'Unknown';
  }
}
