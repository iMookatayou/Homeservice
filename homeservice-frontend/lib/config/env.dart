import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get apiBaseUrl {
    final raw = dotenv.env['API_BASE_URL']?.trim() ?? '';
    if (raw.isEmpty) {
      throw StateError('API_BASE_URL is missing in .env');
    }
    // ตัดท้ายนุ่ม ๆ แล้วบังคับมี /api เสมอ
    final noSlash = raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
    return noSlash; // เราจะกำหนดให้ .env ใส่ /api มาอยู่แล้ว
  }
}
