import 'package:shared_preferences/shared_preferences.dart';

/// Cihazda saklanan kişisel rekorlar.
class Records {
  static const _prefix = 'rekor_';

  static Future<int> best(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_prefix$key') ?? 0;
  }

  /// Skor rekoru geçtiyse kaydeder ve true döner.
  static Future<bool> submit(String key, int score) async {
    final prefs = await SharedPreferences.getInstance();
    final old = prefs.getInt('$_prefix$key') ?? 0;
    if (score <= old) return false;
    await prefs.setInt('$_prefix$key', score);
    return true;
  }
}
