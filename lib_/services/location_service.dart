import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as native_geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/omni_models.dart';

class _KalmanAxisFilter {
  double? _estimate;
  double _errorCovariance = 1.0;
  static const double _q = 0.00001; // Ruído de processo
  static const double _r = 0.00005; // Ruído de medição

  double filter(double measurement, double accuracyMeters) {
    final dynamicR = _r * (accuracyMeters / 5.0).clamp(0.4, 4.0);
    if (_estimate == null) {
      _estimate = measurement;
      return measurement;
    }
    _errorCovariance += _q;
    final gain = _errorCovariance / (_errorCovariance + dynamicR);
    _estimate = _estimate! + gain * (measurement - _estimate!);
    _errorCovariance = (1.0 - gain) * _errorCovariance;
    return _estimate!;
  }

  void reset() {
    _estimate = null;
    _errorCovariance = 1.0;
  }
}

class _CachedGeocodeEntry {
  final ReverseGeocodedAddress address;
  final DateTime cachedAt;
  const _CachedGeocodeEntry(this.address, this.cachedAt);
}

/// Serviço de GPS de Alta Precisão, Geocodificação Reversa em Cascata 100% Gratuita
/// e Snap-to-Road via OSRM Público (custo zero — zero APIs pagas do Google).
class OmniLocationService extends ChangeNotifier {
  static const double maxAcceptableAccuracyMeters = 15.0;
  static const Duration _reverseGeocodeDebounce = Duration(milliseconds: 800);
  static const double _minDisplacementForRegeocodeMeters = 10.0;
  static const Duration _cacheTtl = Duration(minutes: 5);

  OmniCoordinate _currentLocation = const OmniCoordinate(
    latitude: 0.0,
    longitude: 0.0,
  );
  OmniCoordinate? _snappedLocation;
  double _heading = 0.0;
  double _speedMps = 0.0;
  double _lastAccuracyMeters = 0.0;
  bool _hasRealFix = false;
  bool _isApproximateLocationWarning = false;
  GpsFixQuality _fixQuality = GpsFixQuality.searching;
  String? _statusMessage;

  final _KalmanAxisFilter _latKalman = _KalmanAxisFilter();
  final _KalmanAxisFilter _lngKalman = _KalmanAxisFilter();
  final List<Position> _stabilizationBuffer = [];
  final Map<String, _CachedGeocodeEntry> _geocodeCache = {};

  DateTime? _lastReverseGeocodeAt;
  OmniCoordinate? _lastReverseGeocodePoint;
  ReverseGeocodedAddress? _lastReverseGeocodedAddress;
  DateTime? _lastOsrmSnapAt;
  StreamSubscription<Position>? _sub;

  OmniCoordinate get currentLocation => _snappedLocation ?? _currentLocation;
  OmniCoordinate get rawLocation => _currentLocation;
  double get heading => _heading;
  double get speedMps => _speedMps;
  double get speedKmh => _speedMps * 3.6;
  double get lastAccuracyMeters => _lastAccuracyMeters;
  bool get hasRealFix => _hasRealFix;
  bool get isApproximateLocationWarning => _isApproximateLocationWarning;
  GpsFixQuality get fixQuality => _fixQuality;
  String? get statusMessage => _statusMessage;
  ReverseGeocodedAddress? get lastReverseGeocodedAddress =>
      _lastReverseGeocodedAddress;

  /// Configurações nativas de máxima precisão (Fused Location Android / Automotive Apple)
  LocationSettings _buildHighPrecisionSettings({
    int distanceFilter = 4,
    Duration interval = const Duration(seconds: 2),
  }) {
    if (kIsWeb) {
      return LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilter,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilter,
        forceLocationManager: false, // Usa Google Play Services Fused Location Provider (nativo gratuito)
        intervalDuration: interval,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: distanceFilter,
        pauseLocationUpdatesAutomatically: false,
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: distanceFilter,
    );
  }

  /// Verifica se o usuário concedeu Localização Exata (Android 12+ / iOS 14+) ou apenas Aproximada
  Future<void> checkLocationAccuracyStatus() async {
    try {
      final status = await Geolocator.getLocationAccuracy();
      final approx = status == LocationAccuracyStatus.reduced;
      if (_isApproximateLocationWarning != approx) {
        _isApproximateLocationWarning = approx;
        if (approx) {
          _fixQuality = GpsFixQuality.approximate;
          _statusMessage =
              'Localização Aproximada ativa. Ative a Localização Exata nas configurações do aparelho para precisão de rua e número.';
        }
        notifyListeners();
      }
    } catch (_) {
      // Plataformas onde getLocationAccuracy não está disponível
    }
  }

  /// Garante permissões e captura leitura GPS estabilizada (SEM getLastKnownPosition!)
  Future<OmniCoordinate?> fetchHighPrecisionLocation({
    bool snapToRoad = false,
    bool forceFresh = false,
  }) async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _fixQuality = GpsFixQuality.unavailable;
        _statusMessage = 'GPS do dispositivo desativado.';
        notifyListeners();
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _fixQuality = GpsFixQuality.unavailable;
        _statusMessage = 'Permissão de localização negada.';
        notifyListeners();
        return null;
      }

      await checkLocationAccuracyStatus();

      if (forceFresh) {
        _latKalman.reset();
        _lngKalman.reset();
        _snappedLocation = null;
      }

      _fixQuality = GpsFixQuality.searching;
      notifyListeners();

      final collected = <Position>[];
      Position? bestFallback;
      final nowUtc = DateTime.now().toUtc();

      final completer = Completer<Position?>();
      StreamSubscription<Position>? tempSub;

      tempSub = Geolocator.getPositionStream(
        locationSettings: _buildHighPrecisionSettings(
          distanceFilter: 0,
          interval: const Duration(milliseconds: 900),
        ),
      ).listen(
        (pos) {
          if (pos.isMocked) return;
          final ageSeconds = nowUtc.difference(pos.timestamp.toUtc()).inSeconds.abs();
          if (ageSeconds > 12 && collected.isNotEmpty) return;

          if (bestFallback == null || pos.accuracy < bestFallback!.accuracy) {
            bestFallback = pos;
          }
          if (pos.accuracy <= maxAcceptableAccuracyMeters) {
            collected.add(pos);
            final highAccCount = collected.where((p) => p.accuracy <= 10.0).length;
            final ultraAccCount = collected.where((p) => p.accuracy <= 6.0).length;
            if ((ultraAccCount >= 2 || highAccCount >= 3 || collected.length >= 4) &&
                !completer.isCompleted) {
              completer.complete(pos);
            }
          }
        },
        onError: (_) {
          if (!completer.isCompleted) {
            completer.complete(bestFallback);
          }
        },
      );

      Position? resolved;
      try {
        resolved = await completer.future.timeout(
          const Duration(seconds: 6),
          onTimeout: () => collected.isNotEmpty ? collected.last : bestFallback,
        );
      } finally {
        await tempSub.cancel();
      }

      if (resolved == null) {
        try {
          final single = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.bestForNavigation,
            timeLimit: const Duration(seconds: 6),
          );
          if (!single.isMocked) {
            resolved = single;
          }
        } catch (_) {}
      }

      if (resolved == null) {
        _fixQuality = GpsFixQuality.unavailable;
        notifyListeners();
        return null;
      }

      // Centroide ponderado pelo inverso da variância (1 / accuracy²) descartando outliers > 25m
      OmniCoordinate? coord;
      if (collected.length >= 2) {
        final sorted = [...collected]..sort((a, b) => a.accuracy.compareTo(b.accuracy));
        final anchor = sorted.first;
        double sumW = 0.0;
        double sumLat = 0.0;
        double sumLon = 0.0;
        double minAcc = anchor.accuracy;
        for (final s in sorted) {
          final dist = Geolocator.distanceBetween(
            anchor.latitude,
            anchor.longitude,
            s.latitude,
            s.longitude,
          );
          if (dist > 25.0) continue;
          final effAcc = s.accuracy.clamp(2.0, 50.0);
          final w = 1.0 / (effAcc * effAcc);
          sumW += w;
          sumLat += s.latitude * w;
          sumLon += s.longitude * w;
          if (s.accuracy < minAcc) minAcc = s.accuracy;
        }
        if (sumW > 0) {
          final avgPos = Position(
            latitude: sumLat / sumW,
            longitude: sumLon / sumW,
            timestamp: resolved.timestamp,
            accuracy: minAcc,
            altitude: resolved.altitude,
            altitudeAccuracy: resolved.altitudeAccuracy,
            heading: resolved.heading,
            headingAccuracy: resolved.headingAccuracy,
            speed: resolved.speed,
            speedAccuracy: resolved.speedAccuracy,
          );
          coord = _applyPositionFix(avgPos, bypassKalman: forceFresh);
        }
      }
      coord ??= _applyPositionFix(resolved, bypassKalman: forceFresh);

      if (snapToRoad && coord != null) {
        await snapCurrentLocationToRoadOsrm();
      }
      return currentLocation;
    } catch (e) {
      debugPrint('[OMNI GPS] Falha ao capturar posição de alta precisão: $e');
      return null;
    }
  }

  /// Mantido como alias compatível para chamadas existentes
  Future<OmniCoordinate?> fetchFreshLocation() =>
      fetchHighPrecisionLocation(snapToRoad: false, forceFresh: true);

  OmniCoordinate? _applyPositionFix(Position pos, {bool bypassKalman = false}) {
    final acc = pos.accuracy.isFinite ? pos.accuracy : 99.0;
    _lastAccuracyMeters = acc;
    _speedMps = pos.speed.isFinite && pos.speed > 0 ? pos.speed : 0.0;

    // Rejeita saltos grosseiros (>15m) se já possuímos um fix preciso recente
    if (!bypassKalman &&
        _hasRealFix &&
        acc > maxAcceptableAccuracyMeters &&
        _fixQuality == GpsFixQuality.precise) {
      return null;
    }

    _stabilizationBuffer.add(pos);
    if (_stabilizationBuffer.length > 3) {
      _stabilizationBuffer.removeAt(0);
    }

    final filteredLat =
        bypassKalman ? pos.latitude : _latKalman.filter(pos.latitude, acc);
    final filteredLng =
        bypassKalman ? pos.longitude : _lngKalman.filter(pos.longitude, acc);

    final approxOnly = _isApproximateLocationWarning || acc > 25.0;
    _fixQuality = approxOnly ? GpsFixQuality.approximate : GpsFixQuality.precise;
    _statusMessage = approxOnly
        ? 'Precisão reduzida (${acc.toStringAsFixed(0)}m). Prefira áreas abertas e Localização Exata.'
        : 'GPS de alta precisão ativo (${acc.toStringAsFixed(0)}m)';

    _currentLocation = OmniCoordinate(
      latitude: filteredLat,
      longitude: filteredLng,
      accuracyMeters: acc,
      isApproximateOnly: approxOnly,
    );

    if (pos.heading.isFinite && pos.heading > 0 && _speedMps > 0.8) {
      _heading = pos.heading;
    }
    _hasRealFix = true;
    notifyListeners();
    return _currentLocation;
  }

  Future<void> startTracking() async {
    try {
      await fetchHighPrecisionLocation();

      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      _sub?.cancel();
      _sub = Geolocator.getPositionStream(
        locationSettings: _buildHighPrecisionSettings(
          distanceFilter: 4,
          interval: const Duration(seconds: 2),
        ),
      ).listen((p) {
        final updated = _applyPositionFix(p);
        if (updated != null && (_speedMps >= 1.2 || p.accuracy <= 15.0)) {
          unawaited(snapCurrentLocationToRoadOsrm());
        }
      });
    } catch (e) {
      debugPrint('[OMNI GPS] Stream contínuo indisponível no momento: $e');
    }
  }

  Future<OmniCoordinate?> recenterHighPrecision() async {
    _latKalman.reset();
    _lngKalman.reset();
    _snappedLocation = null;
    return fetchHighPrecisionLocation(snapToRoad: true);
  }

  /// Snap-to-Road 100% Gratuito via OSRM Público com alinhamento de heading e interpolação suave
  Future<OmniCoordinate?> snapCurrentLocationToRoadOsrm() async {
    final now = DateTime.now();
    if (_lastOsrmSnapAt != null &&
        now.difference(_lastOsrmSnapAt!) < const Duration(milliseconds: 1400)) {
      return _snappedLocation;
    }
    _lastOsrmSnapAt = now;

    final raw = _currentLocation;
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/nearest/v1/driving/${raw.longitude},${raw.latitude}?number=3',
      );
      final resp = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 3));

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic> &&
            decoded['code'] == 'Ok' &&
            decoded['waypoints'] is List) {
          final waypoints = decoded['waypoints'] as List;
          if (waypoints.isEmpty) return null;

          // Seleciona o waypoint mais próximo respeitando limite de 25m para evitar pular para via paralela
          Map<String, dynamic>? chosen;
          double bestScore = double.infinity;

          for (final wp in waypoints.whereType<Map>()) {
            final wpMap = Map<String, dynamic>.from(wp);
            final dist = (wpMap['distance'] as num?)?.toDouble() ?? 999.0;
            if (dist > 25.0) continue;

            final locArr = wpMap['location'];
            if (locArr is! List || locArr.length < 2) continue;
            final wpLon = (locArr[0] as num).toDouble();
            final wpLat = (locArr[1] as num).toDouble();

            double score = dist;
            if (_speedMps > 1.5 && _snappedLocation != null) {
              final candBearing = calculateBearing(
                _snappedLocation!,
                OmniCoordinate(latitude: wpLat, longitude: wpLon),
              );
              final angleDiff =
                  ((candBearing - _heading).abs() % 360.0);
              final shortestAngle = angleDiff > 180 ? 360 - angleDiff : angleDiff;
              score += shortestAngle * 0.15;
            }
            if (score < bestScore) {
              bestScore = score;
              chosen = wpMap;
            }
          }

          if (chosen != null) {
            final locArr = chosen['location'] as List;
            final targetLon = (locArr[0] as num).toDouble();
            final targetLat = (locArr[1] as num).toDouble();

            // Interpolação suave (lerp) entre posição anterior e ponto encaixado na via
            final prev = _snappedLocation ?? raw;
            final lerpLat = prev.latitude + (targetLat - prev.latitude) * 0.65;
            final lerpLon = prev.longitude + (targetLon - prev.longitude) * 0.65;

            _snappedLocation = OmniCoordinate(
              latitude: lerpLat,
              longitude: lerpLon,
              accuracyMeters: raw.accuracyMeters,
              isApproximateOnly: raw.isApproximateOnly,
            );
            notifyListeners();
            return _snappedLocation;
          }
        }
      }
    } catch (_) {
      // Silencioso: mantém coordenada GPS filtrada pelo Kalman
    }
    return null;
  }

  static double _haversineDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  /// Geocodificação Reversa em Cascata 100% Gratuita de Alta Precisão:
  /// OSM Overpass (número predial + via mais próxima) + Nominatim (zoom=18&layer=address)
  /// + Geocoder Nativo do Android/iOS + Photon ordenado + BigDataCloud + ViaCEP.
  Future<ReverseGeocodedAddress?> reverseGeocodeFree(
    double lat,
    double lon, {
    bool immediate = false,
  }) async {
    // 5 casas decimais (~1,1m) para não misturar ruas paralelas
    final cacheKey = '${lat.toStringAsFixed(5)},${lon.toStringAsFixed(5)}';
    if (!immediate) {
      final cached = _geocodeCache[cacheKey];
      if (cached != null &&
          DateTime.now().difference(cached.cachedAt) < _cacheTtl) {
        _lastReverseGeocodedAddress = cached.address;
        return cached.address;
      }

      final now = DateTime.now();
      if (_lastReverseGeocodePoint != null) {
        final dist = Geolocator.distanceBetween(
          _lastReverseGeocodePoint!.latitude,
          _lastReverseGeocodePoint!.longitude,
          lat,
          lon,
        );
        if (dist < _minDisplacementForRegeocodeMeters &&
            _lastReverseGeocodedAddress != null) {
          return _lastReverseGeocodedAddress;
        }
      }
      if (_lastReverseGeocodeAt != null &&
          now.difference(_lastReverseGeocodeAt!) < _reverseGeocodeDebounce &&
          _lastReverseGeocodedAddress != null) {
        return _lastReverseGeocodedAddress;
      }
    }

    _lastReverseGeocodeAt = DateTime.now();
    _lastReverseGeocodePoint = OmniCoordinate(latitude: lat, longitude: lon);

    String cep = '';
    String street = '';
    String number = '';
    String neighborhood = '';
    String city = '';
    String state = '';
    String source = 'nominatim_address';

    String overpassStreet = '';
    String overpassNumber = '';
    double overpassBestNumDist = double.infinity;
    String overpassHighway = '';
    double overpassBestWayDist = double.infinity;

    // 0. OSM Overpass gratuito: mede distância exata ao número predial e à via mais próxima
    try {
      final q =
          '[out:json][timeout:4];(node["addr:housenumber"](around:35,$lat,$lon);way["addr:housenumber"](around:35,$lat,$lon);way["highway"]["name"](around:25,$lat,$lon););out center;';
      final resp = await http
          .post(
            Uri.parse('https://overpass-api.de/api/interpreter'),
            headers: const {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/json',
            },
            body: {'data': q},
          )
          .timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        final elements = decoded['elements'] as List<dynamic>? ?? const [];
        for (final rawEl in elements) {
          if (rawEl is! Map) continue;
          final el = Map<String, dynamic>.from(rawEl);
          final tags = (el['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
          final elLat = (el['lat'] as num?)?.toDouble() ??
              ((el['center'] as Map?)?['lat'] as num?)?.toDouble();
          final elLon = (el['lon'] as num?)?.toDouble() ??
              ((el['center'] as Map?)?['lon'] as num?)?.toDouble();
          if (elLat == null || elLon == null) continue;
          final dist = _haversineDistanceMeters(lat, lon, elLat, elLon);

          final hn = (tags['addr:housenumber'] ?? '').toString().trim();
          final addrSt = (tags['addr:street'] ?? '').toString().trim();
          if (hn.isNotEmpty && dist < overpassBestNumDist) {
            overpassBestNumDist = dist;
            overpassNumber = hn;
            if (addrSt.isNotEmpty) {
              overpassStreet = addrSt;
            }
          }

          final hwName = (tags['name'] ?? '').toString().trim();
          if (tags['highway'] != null &&
              hwName.isNotEmpty &&
              dist < overpassBestWayDist) {
            overpassBestWayDist = dist;
            overpassHighway = hwName;
          }
        }
      }
    } catch (_) {}

    // 1. Primário Gratuito: OpenStreetMap Nominatim (zoom=18 + layer=address)
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon&zoom=18&layer=address&addressdetails=1&accept-language=pt-BR',
      );
      final resp = await http.get(
        uri,
        headers: const {
          'User-Agent':
              'OMNI-Mobilidade-Motorista-Flutter/2.0 (contato@omnimobilidade.app)',
          'Accept': 'application/json',
          'Accept-Language': 'pt-BR,pt;q=0.9',
        },
      ).timeout(const Duration(seconds: 6));

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        final addr =
            (decoded['address'] as Map?)?.cast<String, dynamic>() ?? const {};

        final rawPostcode =
            (addr['postcode'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
        if (rawPostcode.length == 8) {
          cep = '${rawPostcode.substring(0, 5)}-${rawPostcode.substring(5)}';
        } else if (rawPostcode.isNotEmpty) {
          cep = rawPostcode;
        }

        street = (addr['road'] ??
                addr['pedestrian'] ??
                addr['street'] ??
                addr['residential'] ??
                addr['footway'] ??
                addr['path'] ??
                addr['highway'] ??
                addr['service'] ??
                '')
            .toString()
            .trim();
        number = (addr['house_number'] ?? '').toString().trim();
        neighborhood = (addr['suburb'] ??
                addr['neighbourhood'] ??
                addr['quarter'] ??
                addr['city_district'] ??
                addr['borough'] ??
                addr['district'] ??
                addr['hamlet'] ??
                '')
            .toString()
            .trim();
        city = (addr['city'] ??
                addr['town'] ??
                addr['municipality'] ??
                addr['village'] ??
                addr['county'] ??
                '')
            .toString()
            .trim();
        state = _resolveBrazilianUf(
          (addr['state'] ?? '').toString(),
          isoCode: (addr['ISO3166-2-lvl4'] ?? '').toString(),
        );
      }
    } catch (_) {}

    // 2. Geocoder Nativo Gratuito do Android/iOS (Fused Geocoder do aparelho, ótimo para rua + número)
    try {
      final placemarks =
          await native_geocoding.placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final pm = placemarks.first;
        final nativeStreet = (pm.thoroughfare ?? '').trim();
        final nativeNumber = (pm.subThoroughfare ?? '').trim();

        // Se o Geocoder nativo trouxe rua E número exato e o Nominatim não trouxe número, prioriza o par completo nativo
        if (nativeStreet.isNotEmpty &&
            nativeNumber.isNotEmpty &&
            (number.isEmpty || street.isEmpty)) {
          street = nativeStreet;
          number = nativeNumber;
          source = 'native_os_geocoder';
        } else {
          if (street.isEmpty && nativeStreet.isNotEmpty) {
            street = nativeStreet;
            source = 'native_os_geocoder';
          }
          if (number.isEmpty && nativeNumber.isNotEmpty) {
            number = nativeNumber;
            if (source == 'nominatim_address') source = 'nominatim+os_number';
          }
        }

        if (neighborhood.isEmpty && (pm.subLocality ?? '').trim().isNotEmpty) {
          neighborhood = pm.subLocality!.trim();
        }
        if (city.isEmpty) {
          final c = (pm.subAdministrativeArea ?? '').trim().isNotEmpty
              ? pm.subAdministrativeArea!.trim()
              : (pm.locality ?? '').trim();
          if (c.isNotEmpty) city = c;
        }
        if (state.isEmpty && (pm.administrativeArea ?? '').trim().isNotEmpty) {
          state = _resolveBrazilianUf(pm.administrativeArea!);
        }
        if (cep.isEmpty && (pm.postalCode ?? '').trim().isNotEmpty) {
          final pc = pm.postalCode!.replaceAll(RegExp(r'\D'), '');
          if (pc.length == 8) {
            cep = '${pc.substring(0, 5)}-${pc.substring(5)}';
          }
        }
      }
    } catch (_) {}

    // 3. Complemento gratuito Photon ordenado pela menor distância real ao GPS
    if (street.isEmpty || number.isEmpty || city.isEmpty || cep.isEmpty) {
      try {
        final uri = Uri.parse(
          'https://photon.komoot.io/reverse?lat=$lat&lon=$lon&limit=6&lang=pt',
        );
        final resp = await http
            .get(uri, headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) {
          final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
          final features = (decoded['features'] as List<dynamic>?)
                  ?.whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList() ??
              <Map<String, dynamic>>[];

          features.sort((a, b) {
            final coordsA =
                ((a['geometry'] as Map?)?['coordinates'] as List?) ?? const [];
            final coordsB =
                ((b['geometry'] as Map?)?['coordinates'] as List?) ?? const [];
            final distA = coordsA.length >= 2
                ? _haversineDistanceMeters(
                    lat,
                    lon,
                    (coordsA[1] as num).toDouble(),
                    (coordsA[0] as num).toDouble(),
                  )
                : 9999.0;
            final distB = coordsB.length >= 2
                ? _haversineDistanceMeters(
                    lat,
                    lon,
                    (coordsB[1] as num).toDouble(),
                    (coordsB[0] as num).toDouble(),
                  )
                : 9999.0;
            final hasNumA =
                ((a['properties'] as Map?)?['housenumber'] ?? '')
                    .toString()
                    .isNotEmpty;
            final hasNumB =
                ((b['properties'] as Map?)?['housenumber'] ?? '')
                    .toString()
                    .isNotEmpty;
            final scoreA = distA - (hasNumA ? 6.0 : 0.0);
            final scoreB = distB - (hasNumB ? 6.0 : 0.0);
            return scoreA.compareTo(scoreB);
          });

          for (final feat in features) {
            final props =
                (feat['properties'] as Map?)?.cast<String, dynamic>() ??
                    const {};
            final pStreet = (props['street'] ?? '').toString().trim();
            final pNum = (props['housenumber'] ?? '').toString().trim();
            if (street.isEmpty && pStreet.isNotEmpty) {
              street = pStreet;
            }
            if (number.isEmpty && pNum.isNotEmpty) {
              number = pNum;
            }
            if (neighborhood.isEmpty) {
              neighborhood = (props['district'] ??
                      props['locality'] ??
                      props['suburb'] ??
                      '')
                  .toString()
                  .trim();
            }
            if (city.isEmpty) {
              city = (props['city'] ?? props['town'] ?? props['county'] ?? '')
                  .toString()
                  .trim();
            }
            if (state.isEmpty) {
              state = _resolveBrazilianUf((props['state'] ?? '').toString());
            }
            if (cep.isEmpty && props['postcode'] != null) {
              final pc =
                  props['postcode'].toString().replaceAll(RegExp(r'\D'), '');
              if (pc.length == 8) {
                cep = '${pc.substring(0, 5)}-${pc.substring(5)}';
              }
            }
          }
        }
      } catch (_) {}
    }

    // 4. Arbitragem final com Overpass (números/vias <= 22m do ponto GPS exato)
    if (overpassNumber.isNotEmpty && overpassBestNumDist <= 22.0) {
      number = overpassNumber;
      if (overpassStreet.isNotEmpty) {
        street = overpassStreet;
        source = 'overpass_building';
      }
    } else if (number.isEmpty && overpassNumber.isNotEmpty) {
      number = overpassNumber;
    }
    if (street.isEmpty && overpassHighway.isNotEmpty) {
      street = overpassHighway;
      source = 'overpass_highway';
    } else if (overpassHighway.isNotEmpty &&
        overpassBestWayDist <= 14.0 &&
        number.isEmpty) {
      street = overpassHighway;
      source = 'overpass_highway';
    }

    if (street.isEmpty && city.isEmpty && cep.isEmpty) {
      return null;
    }

    final result = ReverseGeocodedAddress(
      cep: cep,
      street: street,
      number: number,
      neighborhood: neighborhood,
      city: city,
      state: state,
      source: source,
      accuracyMeters: _lastAccuracyMeters > 0 ? _lastAccuracyMeters : null,
    );

    _geocodeCache[cacheKey] = _CachedGeocodeEntry(result, DateTime.now());
    _lastReverseGeocodedAddress = result;
    notifyListeners();
    return result;
  }

  /// Rota gratuita entre 2 pontos usando OSRM público (fallback para polilinha suave se offline)
  static Future<List<OmniCoordinate>> fetchFreeOsrmRoutePolyline(
    OmniCoordinate start,
    OmniCoordinate end,
  ) async {
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
      );
      final resp = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic> &&
            decoded['routes'] is List &&
            (decoded['routes'] as List).isNotEmpty) {
          final firstRoute = (decoded['routes'] as List).first as Map;
          final geom = firstRoute['geometry'] as Map?;
          final coords = geom?['coordinates'] as List?;
          if (coords != null && coords.isNotEmpty) {
            return coords
                .whereType<List>()
                .where((c) => c.length >= 2)
                .map((c) => OmniCoordinate(
                      latitude: (c[1] as num).toDouble(),
                      longitude: (c[0] as num).toDouble(),
                    ))
                .toList();
          }
        }
      }
    } catch (_) {}
    return generateRoutePolyline(start, end);
  }

  void setManualAdjustedPosition(OmniCoordinate next, {double? nextHeading}) {
    _currentLocation = next;
    _snappedLocation = null;
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

  static const Map<String, String> _stateNameToUf = {
    'ACRE': 'AC',
    'ALAGOAS': 'AL',
    'AMAPA': 'AP',
    'AMAZONAS': 'AM',
    'BAHIA': 'BA',
    'CEARA': 'CE',
    'DISTRITO FEDERAL': 'DF',
    'ESPIRITO SANTO': 'ES',
    'GOIAS': 'GO',
    'MARANHAO': 'MA',
    'MATO GROSSO': 'MT',
    'MATO GROSSO DO SUL': 'MS',
    'MINAS GERAIS': 'MG',
    'PARA': 'PA',
    'PARAIBA': 'PB',
    'PARANA': 'PR',
    'PERNAMBUCO': 'PE',
    'PIAUI': 'PI',
    'RIO DE JANEIRO': 'RJ',
    'RIO GRANDE DO NORTE': 'RN',
    'RIO GRANDE DO SUL': 'RS',
    'RONDONIA': 'RO',
    'RORAIMA': 'RR',
    'SANTA CATARINA': 'SC',
    'SAO PAULO': 'SP',
    'SERGIPE': 'SE',
    'TOCANTINS': 'TO',
  };

  String _resolveBrazilianUf(String rawState, {String isoCode = ''}) {
    final iso = isoCode.replaceFirst(RegExp(r'^BR-'), '').trim().toUpperCase();
    if (iso.length == 2) return iso;
    const src = 'ÁÀÃÂÄÉÈÊËÍÌÎÏÓÒÕÔÖÚÙÛÜÇÑáàãâäéèêëíìîïóòõôöúùûüçñ';
    const dst = 'AAAAAEEEEIIIIOOOOOUUUUCNAAAAAEEEEIIIIOOOOOUUUUCN';
    final buf = StringBuffer();
    for (int i = 0; i < rawState.length; i++) {
      final ch = rawState[i];
      final idx = src.indexOf(ch);
      buf.write(idx >= 0 ? dst[idx] : ch.toUpperCase());
    }
    final norm = buf.toString().trim();
    if (norm.length == 2) return norm;
    return _stateNameToUf[norm] ?? '';
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
