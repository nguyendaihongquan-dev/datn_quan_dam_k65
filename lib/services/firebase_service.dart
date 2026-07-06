import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:ev_charging_station/firebase_options.dart';

/// Khởi tạo Firebase an toàn — app vẫn chạy nếu chưa cấu hình project thật.
class FirebaseService {
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _initialized = true;
      debugPrint('Firebase initialized');
    } catch (e, st) {
      debugPrint('Firebase init thất bại (chạy flutterfire configure): $e');
      debugPrint('$st');
    }
  }
}
