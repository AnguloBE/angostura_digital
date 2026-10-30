import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Ajustes de Firestore para mejor rendimiento en redes lentas (4G).
Future<void> configureFirestore() async {
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  try {
    await FirebaseFirestore.instance.enableNetwork();
    debugPrint('Firestore: red gRPC habilitada.');
  } catch (e) {
    debugPrint('Firestore enableNetwork: $e');
  }
}
