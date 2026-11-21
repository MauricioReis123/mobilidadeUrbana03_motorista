import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

/// Serviço Firebase Realtime OMNI com inicialização resiliente em APK/Emulador
class OmniFirebaseService extends ChangeNotifier {
  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _initialized = true;
    } catch (e) {
      // Caso google-services.json não esteja configurado no build local, mantém app funcional via REST/Local
      debugPrint('[OMNI Firebase] Modo resiliente local ativo: $e');
      _initialized = false;
    }
    notifyListeners();
  }
}
