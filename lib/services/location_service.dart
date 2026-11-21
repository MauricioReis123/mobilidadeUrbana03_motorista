import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/omni_models.dart';

/// Serviço de GPS e Telemetria de Rota OMNI (Geolocator + Fallback Av. Paulista)
class OmniLocationService extends ChangeNotifier {
  OmniCoordinate _currentLocation = const OmniCoordinate(
    latitude: -23.5614,
    longitude: -46.6559,
  );
  double _heading = 35.0;
  StreamSubscription<Position>? _sub;

  OmniCoordinate get currentLocation => _currentLocation;
  double get heading => _heading;

  Future<void> startTracking() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentLocation = OmniCoordinate(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
      if (pos.heading > 0) _heading = pos.heading;
      notifyListeners();

      _sub?.cancel();
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 8,
        ),
      ).listen((p) {
        _currentLocation = OmniCoordinate(
          latitude: p.latitude,
          longitude: p.longitude,
        );
        if (p.heading > 0) _heading = p.heading;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('[OMNI GPS] Fallback Av. Paulista ativo: $e');
    }
  }

  void updateSimulatedPosition(OmniCoordinate next, {double? nextHeading}) {
    _currentLocation = next;
    if (nextHeading != null) _heading = nextHeading;
    notifyListeners();
  }

  static double calculateBearing(OmniCoordinate a, OmniCoordinate b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final brng = math.atan2(y, x) * 180 / math.pi;
    return (brng + 360) % 360;
  }

  static List<OmniCoordinate> generateRoutePolyline(
    OmniCoordinate start,
    OmniCoordinate end, {
    int segments = 14,
  }) {
    final pts = <OmniCoordinate>[];
    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final curve = math.sin(t * math.pi) * 0.0014;
      pts.add(
        OmniCoordinate(
          latitude: start.latitude + (end.latitude - start.latitude) * t + curve,
          longitude:
              start.longitude + (end.longitude - start.longitude) * t - curve * 0.6,
        ),
      );
    }
    return pts;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
