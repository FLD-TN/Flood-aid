import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBwPzhXlVaSC7YQ6MiBMbk308Iju8pdtNw',
    appId: '1:121208807643:web:e2cf6ca64bf3e746302cfe',
    messagingSenderId: '121208807643',
    projectId: 'floodaid-9802a',
    authDomain: 'floodaid-9802a.firebaseapp.com',
    storageBucket: 'floodaid-9802a.firebasestorage.app',
    measurementId: 'G-S4WFP7E0WH',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDYQbEefS9Oo1mt9ba0uszwiI_Ls8eUEPg',
    appId: '1:121208807643:android:3f60d82c1c6e8077302cfe',
    messagingSenderId: '121208807643',
    projectId: 'floodaid-9802a',
    storageBucket: 'floodaid-9802a.firebasestorage.app',
  );

  // TODO: Add iOS FirebaseOptions when you register an iOS app
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'TODO',
    appId: 'TODO',
    messagingSenderId: '121208807643',
    projectId: 'floodaid-9802a',
    storageBucket: 'floodaid-9802a.firebasestorage.app',
    iosBundleId: 'com.floodaid.mobile',
  );
}
