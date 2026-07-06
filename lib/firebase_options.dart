// File cấu hình Firebase.
// Sau khi tạo project trên Firebase Console, chạy lệnh sau để ghi đè file này:
//   flutterfire configure
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions chưa hỗ trợ $defaultTargetPlatform.',
        );
    }
  }

  // TODO: Thay bằng cấu hình thật qua `flutterfire configure`

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDJ0RsptB7F6tP693-ItfrM7dUD5JIXE0Q',
    appId: '1:790076437485:web:8b226e79cc299a1b44ede4',
    messagingSenderId: '790076437485',
    projectId: 'datn-cuan',
    authDomain: 'datn-cuan.firebaseapp.com',
    storageBucket: 'datn-cuan.firebasestorage.app',
    measurementId: 'G-41LHE0SBPV',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCT-nCt_HXY5uv_bLCshFGpUL1_anpeBwM',
    appId: '1:790076437485:android:fcf4a0c1bc330f2c44ede4',
    messagingSenderId: '790076437485',
    projectId: 'datn-cuan',
    storageBucket: 'datn-cuan.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBASHA03xFUEgzXDqAwZa0tlXa7rZvY1Cc',
    appId: '1:790076437485:ios:50750ff4afee24dc44ede4',
    messagingSenderId: '790076437485',
    projectId: 'datn-cuan',
    storageBucket: 'datn-cuan.firebasestorage.app',
    iosBundleId: 'com.evcharging.evChargingStation',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'ev-charging-station',
    storageBucket: 'ev-charging-station.firebasestorage.app',
    iosBundleId: 'com.evcharging.evChargingStation',
  );
}
