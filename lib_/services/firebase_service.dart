import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../config/omni_integration_contracts.dart';

/// Serviço Firebase Realtime OMNI com inicialização resiliente em APK/Emulador
class OmniFirebaseService extends ChangeNotifier {
  bool _initialized = false;
  FirebaseDatabase? _database;

  bool get isInitialized => _initialized;
  FirebaseDatabase? get database => _database;

  Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _database = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: OmniRtdbConfig.baseUrl,
      );
      _initialized = true;
    } catch (e) {
      // Caso google-services.json não esteja configurado no build local, mantém app funcional via REST/Local
      debugPrint('[OMNI Firebase] Modo resiliente REST ativo: $e');
      _database = null;
      _initialized = false;
    }
    notifyListeners();
  }

  DatabaseReference? ref(String path) {
    if (!_initialized || _database == null) return null;
    try {
      final clean = path.startsWith('/') ? path.substring(1) : path;
      return _database!.ref(clean);
    } catch (_) {
      return null;
    }
  }

  Stream<DatabaseEvent>? valueStream(String path) {
    final reference = ref(path);
    if (reference == null) return null;
    try {
      return reference.onValue;
    } catch (_) {
      return null;
    }
  }

  Stream<DatabaseEvent>? childAddedStream(String path) {
    final reference = ref(path);
    if (reference == null) return null;
    try {
      return reference.onChildAdded;
    } catch (_) {
      return null;
    }
  }
}
