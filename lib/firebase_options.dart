// Firebase configuration for Helpi.
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
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCzSDFsv4Q5GEC3Ls20mGPOL_3CBFa0I6M',
    appId: '1:400034948021:web:cf3d55ff8b9d5543226ffc',
    messagingSenderId: '400034948021',
    projectId: 'helpi-95e83',
    authDomain: 'helpi-95e83.firebaseapp.com',
    storageBucket: 'helpi-95e83.firebasestorage.app',
    measurementId: 'G-K5392Y8B59',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyARi8zhu71K4MwbuTGaweEXhRDgRf_Diz0',
    appId: '1:400034948021:android:6030e0bf78e306fb226ffc',
    messagingSenderId: '400034948021',
    projectId: 'helpi-95e83',
    storageBucket: 'helpi-95e83.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCTuIQwRftXvCjAKgQghGgIfYs5SY2JoJA',
    appId: '1:400034948021:ios:86726f6fdf31a657226ffc',
    messagingSenderId: '400034948021',
    projectId: 'helpi-95e83',
    storageBucket: 'helpi-95e83.firebasestorage.app',
    androidClientId: '400034948021-0ahid050kd2np17l55lvtvrm0gk4q6ds.apps.googleusercontent.com',
    iosClientId: '400034948021-6hdr4nu77ubc0g0osreofd6fmel8goaf.apps.googleusercontent.com',
    iosBundleId: 'com.example.aplicacionHelpi',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCTuIQwRftXvCjAKgQghGgIfYs5SY2JoJA',
    appId: '1:400034948021:ios:86726f6fdf31a657226ffc',
    messagingSenderId: '400034948021',
    projectId: 'helpi-95e83',
    storageBucket: 'helpi-95e83.firebasestorage.app',
    androidClientId: '400034948021-0ahid050kd2np17l55lvtvrm0gk4q6ds.apps.googleusercontent.com',
    iosClientId: '400034948021-6hdr4nu77ubc0g0osreofd6fmel8goaf.apps.googleusercontent.com',
    iosBundleId: 'com.example.aplicacionHelpi',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCzSDFsv4Q5GEC3Ls20mGPOL_3CBFa0I6M',
    appId: '1:400034948021:web:cf3d55ff8b9d5543226ffc',
    messagingSenderId: '400034948021',
    projectId: 'helpi-95e83',
    authDomain: 'helpi-95e83.firebaseapp.com',
    storageBucket: 'helpi-95e83.firebasestorage.app',
    measurementId: 'G-K5392Y8B59',
  );
}
