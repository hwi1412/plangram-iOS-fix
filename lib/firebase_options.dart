// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBb-zr4kgXrWz3Y_LwMriDOBErvVsyShmQ',
    appId: '1:148847618419:web:18560e3713e7bf89027d06',
    messagingSenderId: '148847618419',
    projectId: 'loginplangram',
    authDomain: 'loginplangram.firebaseapp.com',
    storageBucket: 'loginplangram.firebasestorage.app',
    measurementId: 'G-BKGGBD2J10',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBeYA_1H6dM8PvBkMfah9Tu98JOnHiBqXk',
    appId: '1:148847618419:android:ada9f1815e423acd027d06',
    messagingSenderId: '148847618419',
    projectId: 'loginplangram',
    storageBucket: 'loginplangram.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCLrGxAtZNbOChleoKLBY2iJBbAVVESQss',
    appId: '1:148847618419:ios:a809c76415200089027d06',
    messagingSenderId: '148847618419',
    projectId: 'loginplangram',
    storageBucket: 'loginplangram.firebasestorage.app',
    iosBundleId: 'com.hwi.plangram',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCLrGxAtZNbOChleoKLBY2iJBbAVVESQss',
    appId: '1:148847618419:ios:a809c76415200089027d06',
    messagingSenderId: '148847618419',
    projectId: 'loginplangram',
    storageBucket: 'loginplangram.firebasestorage.app',
    iosBundleId: 'com.hwi.plangram',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBb-zr4kgXrWz3Y_LwMriDOBErvVsyShmQ',
    appId: '1:148847618419:web:541e51ef6324354b027d06',
    messagingSenderId: '148847618419',
    projectId: 'loginplangram',
    authDomain: 'loginplangram.firebaseapp.com',
    storageBucket: 'loginplangram.firebasestorage.app',
    measurementId: 'G-WRYH5CWLQB',
  );
}
