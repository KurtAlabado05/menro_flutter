import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseConfig {
  // 🔥 YOUR FIREBASE WEB CONFIG STYLE (from JSON)
  static const String apiKey = "AIzaSyDVathEKcTzGiKb0yFgaUo7tWknL1wdnOM";
  static const String projectId = "cenro-4b48e";
  static const String messagingSenderId = "110648660679";
  static const String appId = "1:110648660679:android:8e7cace34914767f9aa4e2";
  static const String storageBucket = "cenro-4b48e.firebasestorage.app";
}

/// Non-secret app configuration.
///
/// Used to ensure web/mobile can hit the correct identifySpecies backend.
class ApiRuntimeConfig {
  /// Cloudflare Worker endpoint for tree species identification.
  ///
  /// Must include the route `/identifySpecies` because the client posts to it.
  static const String identifySpeciesUrl =
      'https://cenro-functions-worker.kurtalabado0527.workers.dev/identifySpecies';
}



class FirebaseService {
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: FirebaseConfig.apiKey,
        appId: FirebaseConfig.appId,
        messagingSenderId: FirebaseConfig.messagingSenderId,
        projectId: FirebaseConfig.projectId,
        storageBucket: FirebaseConfig.storageBucket,
      ),
    );
  }

  // 🔥 Firebase instances
  static FirebaseAuth auth = FirebaseAuth.instance;
  static FirebaseFirestore firestore = FirebaseFirestore.instance;
}