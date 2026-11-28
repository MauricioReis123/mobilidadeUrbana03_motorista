import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/omni_integration_contracts.dart';

/// Contrato Canônico OMNI Roteamento Híbrido (omni_get_router_nonce + omni_global_router)
/// + Fallback Offline + ViaCEP + Geocodificação Reversa + Firebase RTDB REST
class OmniBackendService extends ChangeNotifier {
  static const String defaultBaseUrl = OmniRouterConfig.baseUrl;
  static const String nonceAction = OmniRouterConfig.nonceAction;
  static const String ajaxAction = OmniRouterConfig.routerAction;
  static const String defaultBackendFile = OmniRouterConfig.backendFile;
  static const String defaultClassName = OmniRouterConfig.className;
  static const String firebaseRtdbUrl = OmniRtdbConfig.baseUrl;
  static const String ownerEmailStorageKey = 'omni_app_owner_email_v1';
  static const String primaryOwnerEmail = 'yahnzinho1@gmail.com';
  static const Set<String> allowedOwnerEmails = {
    primaryOwnerEmail,
  };

  String _configuredDomain = OmniRouterConfig.defaultDomain;
  String _ajaxUrl = OmniRouterConfig.baseUrl;
  bool _hasCustomDomainCached = false;
  bool _domainLoaded = false;
  String? _jwtToken;
  String? _cachedNonce;
  String _ownerEmail = '';
  final List<Map<String, dynamic>> _offlineQueue = [];

  int get offlineQueueCount => _offlineQueue.length;
  String? get cachedNonce => _cachedNonce;
  String get configuredDomain => _configuredDomain;
  String get resolvedAjaxUrl => _ajaxUrl;
  String get baseUrl => _ajaxUrl;
  bool get hasCustomDomainCached => _hasCustomDomainCached;
  String get ownerEmail => _ownerEmail.trim();

  static bool isAllowedOwnerEmail(String? email) {
    final normalized = (email ?? '').trim().toLowerCase();
    return normalized.isNotEmpty && allowedOwnerEmails.contains(normalized);
  }

  void setAuthToken(String token) {
    _jwtToken = token;
    notifyListeners();
  }

  Future<void> setOwnerEmail(String email) async {
    _ownerEmail = email.trim().toLowerCase();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_ownerEmail.isEmpty) {
        await prefs.remove(ownerEmailStorageKey);
      } else {
        await prefs.setString(ownerEmailStorageKey, _ownerEmail);
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> clearOwnerEmail() async {
    await setOwnerEmail('');
  }

  void clearCachedNonce() {
    _cachedNonce = null;
  }

  /// Carrega o domínio/servidor salvo em cache (SharedPreferences) para Android / iOS
  Future<void> loadConfiguredDomain() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(OmniRouterConfig.domainStorageKey);
      if (saved != null && saved.trim().isNotEmpty) {
        _configuredDomain = OmniRouterConfig.normalizeBackendDomain(saved);
        _ajaxUrl = OmniRouterConfig.resolveAjaxEndpointFromDomain(_configuredDomain);
        _hasCustomDomainCached = true;
      } else {
        _configuredDomain = OmniRouterConfig.defaultDomain;
        _ajaxUrl = OmniRouterConfig.baseUrl;
        _hasCustomDomainCached = false;
      }
      if (_ownerEmail.trim().isEmpty) {
        final savedOwnerEmail = prefs.getString(ownerEmailStorageKey);
        if (savedOwnerEmail != null && savedOwnerEmail.trim().isNotEmpty) {
          _ownerEmail = savedOwnerEmail.trim().toLowerCase();
        }
      }
    } catch (_) {
      _configuredDomain = OmniRouterConfig.defaultDomain;
      _ajaxUrl = OmniRouterConfig.baseUrl;
      _hasCustomDomainCached = false;
    }
    _domainLoaded = true;
    notifyListeners();
  }

  /// Salva o domínio/IP flexível digitado pelo usuário no cache local (SharedPreferences)
  Future<Map<String, String>> saveConfiguredDomain(String rawDomain) async {
    if (rawDomain.trim().isNotEmpty &&
        !OmniRouterConfig.isValidBackendDomainInput(rawDomain)) {
      throw FormatException(
          'Formato de domínio ou IP inválido. Exemplos: http://192.168.12.9/servshop ou https://meusite.com.br');
    }

    final normalized = OmniRouterConfig.normalizeBackendDomain(rawDomain);
    final resolved = OmniRouterConfig.resolveAjaxEndpointFromDomain(normalized);

    _configuredDomain = normalized;
    _ajaxUrl = resolved;
    _hasCustomDomainCached = true;
    _domainLoaded = true;
    _cachedNonce = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(OmniRouterConfig.domainStorageKey, normalized);
    } catch (_) {}

    notifyListeners();
    return {'domain': normalized, 'ajaxUrl': resolved};
  }

  /// Restaura o domínio padrão e limpa a chave personalizada do cache
  Future<Map<String, String>> resetConfiguredDomain() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(OmniRouterConfig.domainStorageKey);
    } catch (_) {}

    _configuredDomain = OmniRouterConfig.defaultDomain;
    _ajaxUrl = OmniRouterConfig.baseUrl;
    _hasCustomDomainCached = false;
    _domainLoaded = true;
    _cachedNonce = null;
    notifyListeners();
    return {'domain': _configuredDomain, 'ajaxUrl': _ajaxUrl};
  }

  /// Testa a conexão ao vivo obtendo um novo nonce do servidor configurado
  Future<Map<String, dynamic>> testRouterConnection() async {
    final sw = Stopwatch()..start();
    final nonce = await fetchRouterNonce(forceRefresh: true);
    sw.stop();
    final ms = sw.elapsedMilliseconds;

    if (nonce != null && nonce.isNotEmpty) {
      final preview = nonce.length > 6 ? nonce.substring(0, 6) : nonce;
      return {
        'ok': true,
        'domain': _configuredDomain,
        'ajaxUrl': _ajaxUrl,
        'nonce': nonce,
        'latencyMs': ms,
        'message': 'Conexão confirmada! Nonce recebido ($preview...) em ${ms}ms.',
      };
    }

    return {
      'ok': false,
      'domain': _configuredDomain,
      'ajaxUrl': _ajaxUrl,
      'latencyMs': ms,
      'message':
          'Domínio salvo em cache ($_configuredDomain). Sem resposta ativa de $_ajaxUrl no momento (operando em fallback local + Firebase RTDB).',
    };
  }

  /// Normaliza qualquer nome de método para snake_case compatível com sanitize_key() do WordPress
  String _normalizeMethodName(String rawMethod) {
    return rawMethod.trim().replaceAll('.', '_').replaceAll('-', '_').toLowerCase();
  }

  /// Etapa 1: Solicita e faz cache do nonce de segurança em omni_get_router_nonce
  Future<String?> fetchRouterNonce({bool forceRefresh = false}) async {
    if (!_domainLoaded) {
      await loadConfiguredDomain();
    }
    if (!forceRefresh && _cachedNonce != null && _cachedNonce!.isNotEmpty) {
      return _cachedNonce;
    }

    try {
      final uri = Uri.parse('$_ajaxUrl?action=$nonceAction');
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              if (_jwtToken != null) 'Authorization': 'Bearer $_jwtToken',
              if (_ownerEmail.trim().isNotEmpty)
                'X-Omni-Owner-Email': _ownerEmail.trim(),
              'X-App-Client': 'OMNI_DRIVER_FLUTTER_V2',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          final data = decoded['data'];
          if (data is Map<String, dynamic> && data['nonce'] != null) {
            _cachedNonce = data['nonce'].toString();
            return _cachedNonce;
          }
        }
      }
    } catch (_) {
      // Silencioso: cairá no fallback gracioso caso o servidor configurado esteja inacessível
    }

    return null;
  }

  /// Etapa 2: Executa método PHP dinâmico via omni_global_router (POST form-urlencoded)
  Future<Map<String, dynamic>> executar({
    required String targetMethod,
    Map<String, dynamic>? arguments,
    String backendFile = defaultBackendFile,
    String className = defaultClassName,
  }) async {
    final safeMethod = _normalizeMethodName(targetMethod);
    final args = arguments ?? const <String, dynamic>{};
    final idemp =
        'idemp_${DateTime.now().millisecondsSinceEpoch}_${args.hashCode}';

    try {
      final finalArgs = Map<String, dynamic>.from(args);
      final effectiveOwnerEmail =
          (finalArgs['owner_email']?.toString().trim().isNotEmpty == true)
              ? finalArgs['owner_email'].toString().trim().toLowerCase()
              : (finalArgs['email']?.toString().trim().isNotEmpty == true)
                  ? finalArgs['email'].toString().trim().toLowerCase()
                  : _ownerEmail.trim().toLowerCase();
      if (effectiveOwnerEmail.isNotEmpty) {
        finalArgs['owner_email'] = effectiveOwnerEmail;
        finalArgs['email'] ??= effectiveOwnerEmail;
      }

      String? nonce = await fetchRouterNonce();
      if (nonce != null && nonce.isNotEmpty) {
        final payloadJson = jsonEncode({
          'backend_file': backendFile,
          'class_name': className,
          'target_method': safeMethod,
          'args': finalArgs,
        });

        http.Response response = await _postRouterRequest(
          nonce: nonce,
          payloadJson: payloadJson,
          idemp: idemp,
          ownerEmail: effectiveOwnerEmail,
        );

        // Se o nonce expirou (HTTP 403), renova uma única vez e reenvia
        if (response.statusCode == 403) {
          nonce = await fetchRouterNonce(forceRefresh: true);
          if (nonce != null && nonce.isNotEmpty) {
            response = await _postRouterRequest(
              nonce: nonce,
              payloadJson: payloadJson,
              idemp: idemp,
              ownerEmail: effectiveOwnerEmail,
            );
          }
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
          return {
            'success': true,
            'data': decoded,
            'timestamp': DateTime.now().toIso8601String(),
          };
        }
      }
    } catch (_) {
      // Fallback gracioso local + RTDB espelhado (idêntico ao backendService.ts)
    }

    return _processLocalStateProtocol(safeMethod, args, idemp);
  }

  Future<http.Response> _postRouterRequest({
    required String nonce,
    required String payloadJson,
    required String idemp,
    String ownerEmail = '',
  }) {
    final uri = Uri.parse(_ajaxUrl);
    return http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'Accept': 'application/json',
            if (_jwtToken != null) 'Authorization': 'Bearer $_jwtToken',
            if (ownerEmail.isNotEmpty) 'X-Omni-Owner-Email': ownerEmail,
            'X-Idempotency-Key': idemp,
            'X-App-Client': 'OMNI_DRIVER_FLUTTER_V2',
          },
          body: {
            'action': ajaxAction,
            'nonce': nonce,
            'payload': payloadJson,
          },
        )
        .timeout(const Duration(seconds: 8));
  }

  String _cleanRtdbPath(String path) =>
      path.startsWith('/') ? path.substring(1) : path;

  Future<bool> syncToFirebaseRtdb(String path, Object? payload) async {
    try {
      final clean = _cleanRtdbPath(path);
      final uri = Uri.parse('$firebaseRtdbUrl/$clean.json');
      final resp = await http
          .put(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<bool> patchFirebaseRtdb(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      final clean = _cleanRtdbPath(path);
      final uri = Uri.parse('$firebaseRtdbUrl/$clean.json');
      final resp = await http
          .patch(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<String?> pushToFirebaseRtdb(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      final clean = _cleanRtdbPath(path);
      final uri = Uri.parse('$firebaseRtdbUrl/$clean.json');
      final resp = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic> && decoded['name'] != null) {
          return decoded['name'].toString();
        }
      }
    } catch (_) {}
    return null;
  }

  Future<dynamic> readFromFirebaseRtdb(String path) async {
    try {
      final clean = _cleanRtdbPath(path);
      final uri = Uri.parse('$firebaseRtdbUrl/$clean.json');
      final resp = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200 &&
          resp.body.trim().isNotEmpty &&
          resp.body.trim() != 'null') {
        return jsonDecode(resp.body);
      }
    } catch (_) {
      // Silencioso para não interromper operação em fallback offline
    }
    return null;
  }

  Future<bool> deleteFromFirebaseRtdb(String path) async {
    try {
      final clean = _cleanRtdbPath(path);
      final uri = Uri.parse('$firebaseRtdbUrl/$clean.json');
      final resp = await http.delete(uri).timeout(const Duration(seconds: 4));
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> lookupViaCep(String rawCep) async {
    final clean = rawCep.replaceAll(RegExp(r'\D'), '');
    if (clean.length != 8) return null;
    try {
      final uri = Uri.parse('https://viacep.com.br/ws/$clean/json/');
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        if (json['erro'] == true) return null;
        return json;
      }
    } catch (_) {}
    return null;
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

  String _normalizeAsciiUpper(String raw) {
    const src = 'ÁÀÃÂÄÉÈÊËÍÌÎÏÓÒÕÔÖÚÙÛÜÇÑáàãâäéèêëíìîïóòõôöúùûüçñ';
    const dst = 'AAAAAEEEEIIIIOOOOOUUUUCNAAAAAEEEEIIIIOOOOOUUUUCN';
    final buf = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      final ch = raw[i];
      final idx = src.indexOf(ch);
      buf.write(idx >= 0 ? dst[idx] : ch.toUpperCase());
    }
    return buf.toString().trim();
  }

  String _resolveBrazilianUf(String rawState, {String isoCode = ''}) {
    final iso = isoCode.replaceFirst(RegExp(r'^BR-'), '').trim().toUpperCase();
    if (iso.length == 2) return iso;
    final norm = _normalizeAsciiUpper(rawState);
    if (norm.length == 2) return norm;
    return _stateNameToUf[norm] ?? '';
  }

  static double _haversineMeters(
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

  /// Geocodificação reversa gratuita de alta precisão
  /// (Nominatim layer=address + OSM Overpass rua/número mais próximo + Photon ordenado + BigDataCloud + ViaCEP)
  Future<Map<String, String>?> reverseGeocode(double lat, double lon) async {
    String cep = '';
    String street = '';
    String number = '';
    String neighborhood = '';
    String city = '';
    String state = '';

    String overpassStreet = '';
    String overpassNumber = '';
    double overpassBestNumDist = double.infinity;
    String overpassHighway = '';
    double overpassBestWayDist = double.infinity;

    // 0) OSM Overpass (gratuito): busca número predial exato (<=35m) e nome da via (<=25m)
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
          final dist = _haversineMeters(lat, lon, elLat, elLon);

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

    // 1) OpenStreetMap Nominatim (zoom=18 + layer=address para evitar POI/parque mascarando a rua real)
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon&zoom=18&layer=address&addressdetails=1&accept-language=pt-BR',
      );
      final resp = await http.get(
        uri,
        headers: const {
          'User-Agent': 'OMNI-Mobilidade-Motorista-Flutter/2.0 (contact@omnimobilidade.app)',
          'Accept': 'application/json',
          'Accept-Language': 'pt-BR,pt;q=0.9',
        },
      ).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        final addr = (decoded['address'] as Map?)?.cast<String, dynamic>() ?? const {};

        final rawPostcode = (addr['postcode'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
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

    // 2) Complemento: Photon ordenado pela menor distância real Haversine ao GPS
    if (street.isEmpty || number.isEmpty || city.isEmpty || cep.isEmpty) {
      try {
        final uri = Uri.parse(
          'https://photon.komoot.io/reverse?lat=$lat&lon=$lon&limit=6&lang=pt',
        );
        final resp = await http.get(
          uri,
          headers: const {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) {
          final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
          final features = (decoded['features'] as List<dynamic>?)
                  ?.whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList() ??
              <Map<String, dynamic>>[];

          features.sort((a, b) {
            final coordsA = ((a['geometry'] as Map?)?['coordinates'] as List?) ?? const [];
            final coordsB = ((b['geometry'] as Map?)?['coordinates'] as List?) ?? const [];
            final distA = coordsA.length >= 2
                ? _haversineMeters(
                    lat,
                    lon,
                    (coordsA[1] as num).toDouble(),
                    (coordsA[0] as num).toDouble(),
                  )
                : 9999.0;
            final distB = coordsB.length >= 2
                ? _haversineMeters(
                    lat,
                    lon,
                    (coordsB[1] as num).toDouble(),
                    (coordsB[0] as num).toDouble(),
                  )
                : 9999.0;
            final hasNumA = ((a['properties'] as Map?)?['housenumber'] ?? '').toString().isNotEmpty;
            final hasNumB = ((b['properties'] as Map?)?['housenumber'] ?? '').toString().isNotEmpty;
            final scoreA = distA - (hasNumA ? 6.0 : 0.0);
            final scoreB = distB - (hasNumB ? 6.0 : 0.0);
            return scoreA.compareTo(scoreB);
          });

          for (final feat in features) {
            final props =
                (feat['properties'] as Map?)?.cast<String, dynamic>() ?? const {};
            final pStreet = (props['street'] ?? '').toString().trim();
            final pNum = (props['housenumber'] ?? '').toString().trim();
            if (street.isEmpty && pStreet.isNotEmpty) {
              street = pStreet;
            }
            if (number.isEmpty && pNum.isNotEmpty) {
              number = pNum;
            }
            if (neighborhood.isEmpty) {
              neighborhood =
                  (props['district'] ?? props['locality'] ?? props['suburb'] ?? '')
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
              final pc = props['postcode'].toString().replaceAll(RegExp(r'\D'), '');
              if (pc.length == 8) {
                cep = '${pc.substring(0, 5)}-${pc.substring(5)}';
              }
            }
          }
        }
      } catch (_) {}
    }

    // Arbitragem com dados prediais do OSM Overpass quando mais próximos (<= 22m)
    if (overpassNumber.isNotEmpty && overpassBestNumDist <= 22.0) {
      number = overpassNumber;
      if (overpassStreet.isNotEmpty) {
        street = overpassStreet;
      }
    } else if (number.isEmpty && overpassNumber.isNotEmpty) {
      number = overpassNumber;
    }
    if (street.isEmpty && overpassHighway.isNotEmpty) {
      street = overpassHighway;
    } else if (overpassHighway.isNotEmpty && overpassBestWayDist <= 14.0 && number.isEmpty) {
      street = overpassHighway;
    }

    // 3) Fallback 3: BigDataCloud Client Reverse Geocode (cidade/bairro/UF)
    if (city.isEmpty || state.isEmpty || neighborhood.isEmpty) {
      try {
        final uri = Uri.parse(
          'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lon&localityLanguage=pt',
        );
        final resp = await http.get(
          uri,
          headers: const {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) {
          final bdc = jsonDecode(resp.body) as Map<String, dynamic>;
          if (city.isEmpty) {
            city = (bdc['city'] ?? bdc['locality'] ?? '').toString().trim();
          }
          if (neighborhood.isEmpty && bdc['locality'] != null) {
            final locName = bdc['locality'].toString().trim();
            if (locName.toLowerCase() != city.toLowerCase()) {
              neighborhood = locName;
            }
          }
          if (state.isEmpty) {
            state = _resolveBrazilianUf(
              (bdc['principalSubdivision'] ?? '').toString(),
              isoCode: (bdc['principalSubdivisionCode'] ?? '').toString(),
            );
          }
          if (cep.isEmpty && bdc['postcode'] != null) {
            final pc = bdc['postcode'].toString().replaceAll(RegExp(r'\D'), '');
            if (pc.length == 8) {
              cep = '${pc.substring(0, 5)}-${pc.substring(5)}';
            }
          }
        }
      } catch (_) {}
    }

    // 4) Enriquecimento ViaCEP pelo CEP (8 dígitos) ou busca por Logradouro/Cidade/UF
    final cleanCep = cep.replaceAll(RegExp(r'\D'), '');
    if (cleanCep.length == 8) {
      final via = await lookupViaCep(cleanCep);
      if (via != null) {
        if (street.isEmpty && via['logradouro'] != null) {
          street = via['logradouro'].toString().trim();
        }
        if (neighborhood.isEmpty && via['bairro'] != null) {
          neighborhood = via['bairro'].toString().trim();
        }
        if (city.isEmpty && via['localidade'] != null) {
          city = via['localidade'].toString().trim();
        }
        if (via['uf'] != null && via['uf'].toString().trim().length == 2) {
          state = via['uf'].toString().trim().toUpperCase();
        }
        if (via['cep'] != null) {
          cep = via['cep'].toString().trim();
        }
      }
    } else if (state.length == 2 && city.length >= 3 && street.length >= 3) {
      try {
        final searchUri = Uri.parse(
          'https://viacep.com.br/ws/${Uri.encodeComponent(state)}/${Uri.encodeComponent(city)}/${Uri.encodeComponent(street)}/json/',
        );
        final resp = await http.get(searchUri).timeout(const Duration(seconds: 4));
        if (resp.statusCode == 200) {
          final decoded = jsonDecode(resp.body);
          if (decoded is List && decoded.isNotEmpty) {
            final first = decoded.first as Map<String, dynamic>;
            if (cep.isEmpty && first['cep'] != null) {
              cep = first['cep'].toString().trim();
            }
            if (neighborhood.isEmpty && first['bairro'] != null) {
              neighborhood = first['bairro'].toString().trim();
            }
          }
        }
      } catch (_) {}
    }

    if (cep.isEmpty && street.isEmpty && neighborhood.isEmpty && city.isEmpty) {
      return null;
    }

    return {
      'cep': cep,
      'street': street,
      'number': number,
      'neighborhood': neighborhood,
      'city': city,
      'state': state,
    };
  }

  Future<Map<String, dynamic>> _processLocalStateProtocol(
    String method,
    Map<String, dynamic> args,
    String idemp,
  ) async {
    final now = DateTime.now().toIso8601String();
    final prefs = await SharedPreferences.getInstance();

    switch (method) {
      case OmniBackendMethods.availabilityToggle:
        final isOnline = args['is_online'] == true;
        final driverId = (args['driver_id'] ?? '').toString();
        final loc = args['location'] as Map<String, dynamic>?;
        await patchFirebaseRtdb(OmniRtdbPaths.driverOnline(driverId), {
          OmniRtdbFields.driverId: driverId,
          OmniRtdbFields.isOnline: isOnline,
          OmniRtdbFields.lat: loc?['latitude'],
          OmniRtdbFields.lng: loc?['longitude'],
          OmniRtdbFields.updatedAt: DateTime.now().millisecondsSinceEpoch,
        });
        return {
          'success': true,
          'data': {
            'is_online': isOnline,
            'status_text': isOnline ? 'ONLINE' : 'OFFLINE',
          },
          'timestamp': now,
        };

      case OmniBackendMethods.tripAccept:
        final tripMap = args['trip'] as Map<String, dynamic>? ?? const {};
        final tripId = tripMap['trip_id']?.toString() ?? (args['trip_id']?.toString() ?? '');
        final driverId = args['driver_id']?.toString() ?? '';
        final lockKey = 'trip_taken_$tripId';
        final existing = prefs.getString(lockKey);
        if (existing != null && existing != driverId) {
          return {
            'success': false,
            'code': 'TRIP_ALREADY_ASSIGNED',
            'error': 'Esta corrida acabou de ser aceita por outro motorista mais próximo.',
            'timestamp': now,
          };
        }
        await prefs.setString(lockKey, driverId);
        await patchFirebaseRtdb(OmniRtdbPaths.tripRoot(tripId), {
          OmniRtdbFields.status: OmniTripStatus.accepted,
          OmniRtdbFields.driverId: driverId,
          'accepted_at': now,
        });
        if (driverId.isNotEmpty && tripId.isNotEmpty) {
          await deleteFromFirebaseRtdb(
              '${OmniRtdbPaths.dispatchQueue}/$driverId/$tripId');
        }
        return {
          'success': true,
          'data': {'trip_id': tripId, 'status': OmniTripStatus.accepted, 'accepted_at': now},
          'timestamp': now,
        };

      case OmniBackendMethods.tripDecline:
        final tripId = (args['trip_id'] ?? '').toString();
        final driverId = (args['driver_id'] ?? '').toString();
        if (driverId.isNotEmpty && tripId.isNotEmpty) {
          await deleteFromFirebaseRtdb(
              '${OmniRtdbPaths.dispatchQueue}/$driverId/$tripId');
        }
        return {
          'success': true,
          'data': {'trip_id': tripId, 'driver_id': driverId, 'status': 'DECLINED'},
          'timestamp': now,
        };

      case OmniBackendMethods.tripArrived:
        final tripId = (args['trip_id'] ?? '').toString();
        if (tripId.isNotEmpty) {
          await patchFirebaseRtdb(OmniRtdbPaths.tripRoot(tripId), {
            OmniRtdbFields.status: OmniTripStatus.driverArrived,
            'arrived_at': now,
          });
        }
        return {
          'success': true,
          'data': {'trip_id': tripId, 'status': OmniTripStatus.driverArrived, 'arrived_at': now},
          'timestamp': now,
        };

      case OmniBackendMethods.tripValidateOtp:
        final inputOtp = (args['input_otp'] ?? '').toString().trim();
        final expectedOtp = (args['expected_otp'] ?? '').toString().trim();
        final tripId = (args['trip_id'] ?? '').toString();
        final attemptsKey = 'otp_attempts_$tripId';
        final attempts = (prefs.getInt(attemptsKey) ?? 0) + 1;
        await prefs.setInt(attemptsKey, attempts);

        if (attempts > 3) {
          return {
            'success': false,
            'code': 'OTP_MAX_ATTEMPTS_EXCEEDED',
            'error': 'Limite de 3 tentativas excedido. Favor solicitar novo código.',
            'timestamp': now,
          };
        }

        if (inputOtp.isNotEmpty && inputOtp == expectedOtp) {
          await prefs.remove(attemptsKey);
          await syncToFirebaseRtdb(
              OmniRtdbPaths.tripStatus(tripId), OmniTripStatus.boardingConfirmed);
          return {
            'success': true,
            'data': {'valid': true, 'status': OmniTripStatus.boardingConfirmed},
            'timestamp': now,
          };
        }

        return {
          'success': false,
          'code': 'OTP_INVALID',
          'error': 'Código PIN incorreto. Tentativa $attempts de 3.',
          'timestamp': now,
        };

      case OmniBackendMethods.tripStart:
        final tripId = (args['trip_id'] ?? '').toString();
        if (tripId.isNotEmpty) {
          await patchFirebaseRtdb(OmniRtdbPaths.tripRoot(tripId), {
            OmniRtdbFields.status: OmniTripStatus.tripInProgress,
            'started_at': now,
          });
        }
        return {
          'success': true,
          'data': {'trip_id': tripId, 'status': OmniTripStatus.tripInProgress, 'started_at': now},
          'timestamp': now,
        };

      case OmniBackendMethods.tripFinish:
        final tripId = (args['trip_id'] ?? '').toString();
        final finalFare = (args['final_fare'] as num?)?.toDouble() ??
            (args['final_amount_brl'] as num?)?.toDouble() ??
            0.0;
        if (tripId.isNotEmpty) {
          await patchFirebaseRtdb(OmniRtdbPaths.tripRoot(tripId), {
            OmniRtdbFields.status: OmniTripStatus.completed,
            'final_fare': finalFare,
            'finished_at': now,
          });
        }
        return {
          'success': true,
          'data': {
            'trip_id': tripId,
            'status': OmniTripStatus.completed,
            'final_fare': finalFare,
            'finished_at': now,
          },
          'timestamp': now,
        };

      case OmniBackendMethods.tripCancel:
        final tripId = (args['trip_id'] ?? '').toString();
        final reason = (args['reason'] ?? 'CANCELLED_BY_DRIVER').toString();
        if (tripId.isNotEmpty) {
          await patchFirebaseRtdb(OmniRtdbPaths.tripRoot(tripId), {
            OmniRtdbFields.status: OmniTripStatus.cancelledByDriver,
            'cancel_reason': reason,
          });
        }
        return {
          'success': true,
          'data': {'trip_id': tripId, 'status': OmniTripStatus.cancelledByDriver, 'reason': reason},
          'timestamp': now,
        };

      case OmniBackendMethods.tripLocationUpdate:
        final driverId = (args['driver_id'] ?? '').toString();
        final tripId = (args['trip_id'] ?? '').toString();
        final lat = (args['lat'] as num?)?.toDouble() ?? (args['latitude'] as num?)?.toDouble();
        final lng = (args['lng'] as num?)?.toDouble() ?? (args['longitude'] as num?)?.toDouble();
        final bearing = (args['bearing'] as num?)?.toDouble() ?? 0.0;
        final speedKmh = (args['speed_kmh'] as num?)?.toDouble() ?? 0.0;
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (driverId.isNotEmpty && lat != null && lng != null) {
          await patchFirebaseRtdb(OmniRtdbPaths.driverOnline(driverId), {
            OmniRtdbFields.lat: lat,
            OmniRtdbFields.lng: lng,
            OmniRtdbFields.updatedAt: nowMs,
          });
        }
        if (tripId.isNotEmpty && lat != null && lng != null) {
          await syncToFirebaseRtdb(OmniRtdbPaths.tripDriverLocation(tripId), {
            OmniRtdbFields.lat: lat,
            OmniRtdbFields.lng: lng,
            OmniRtdbFields.bearing: bearing,
            OmniRtdbFields.speedKmh: speedKmh,
            OmniRtdbFields.updatedAt: nowMs,
          });
        }
        return {
          'success': true,
          'data': {'driver_id': driverId, 'trip_id': tripId, 'updated_at': nowMs},
          'timestamp': now,
        };

      case OmniBackendMethods.tripChatSend:
        final tripId = (args['trip_id'] ?? '').toString();
        final driverId = (args['driver_id'] ?? '').toString();
        final senderId = (args['sender_id'] ?? driverId).toString();
        final senderRole = (args['sender_role'] ?? 'driver').toString().toLowerCase();
        final text = (args['text'] ?? '').toString().trim();
        final createdAtMs = (args['created_at'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch;
        if (tripId.isEmpty || text.isEmpty) {
          return {
            'success': false,
            'code': 'CHAT_INVALID_PARAMS',
            'error': 'trip_id e text são obrigatórios.',
            'timestamp': now,
          };
        }
        final chatPayload = <String, dynamic>{
          OmniRtdbFields.senderRole: senderRole,
          OmniRtdbFields.senderId: senderId,
          OmniRtdbFields.text: text,
          OmniRtdbFields.createdAt: createdAtMs,
          OmniRtdbFields.isRead: false,
        };
        final providedId = (args['message_id'] ?? '').toString();
        String? pushKey;
        if (providedId.isNotEmpty) {
          await syncToFirebaseRtdb(
              '${OmniRtdbPaths.tripChat(tripId)}/$providedId', chatPayload);
          pushKey = providedId;
        } else {
          pushKey = await pushToFirebaseRtdb(
              OmniRtdbPaths.tripChat(tripId), chatPayload);
        }
        final finalId = pushKey ?? 'msg_$createdAtMs';
        return {
          'success': true,
          'data': {
            'message_id': finalId,
            'trip_id': tripId,
            'sender_role': senderRole,
            'sender_id': senderId,
            'text': text,
            'created_at': createdAtMs,
            'is_read': false,
            'rtdb_synced': pushKey != null,
          },
          'timestamp': now,
        };

      case OmniBackendMethods.tripChatHistory:
        final tripId = (args['trip_id'] ?? '').toString();
        final rawChat = tripId.isNotEmpty
            ? await readFromFirebaseRtdb(OmniRtdbPaths.tripChat(tripId))
            : null;
        final List<Map<String, dynamic>> msgs = [];
        if (rawChat is Map) {
          rawChat.forEach((key, val) {
            if (val is Map && (val['text'] ?? '').toString().trim().isNotEmpty) {
              msgs.add({
                'message_id': key.toString(),
                'trip_id': tripId,
                'sender_role': (val['sender_role'] ?? 'passenger').toString().toLowerCase(),
                'sender_id': (val['sender_id'] ?? '').toString(),
                'text': val['text'].toString(),
                'created_at': (val['created_at'] as num?)?.toInt() ?? 0,
                'is_read': val['is_read'] == true,
              });
            }
          });
          msgs.sort((a, b) => ((a['created_at'] as int?) ?? 0)
              .compareTo((b['created_at'] as int?) ?? 0));
        }
        return {
          'success': true,
          'data': {'trip_id': tripId, 'messages': msgs},
          'timestamp': now,
        };

      case OmniBackendMethods.tripSosTrigger:
        final tripId = (args['trip_id'] ?? '').toString();
        final driverId = (args['driver_id'] ?? '').toString();
        final active = args['active'] != false;
        final incidentNote = (args['incident_note'] ?? '').toString();
        final triggeredBy = (args['triggered_by'] ?? 'DRIVER').toString();
        final payload = {
          'active': active,
          OmniRtdbFields.triggeredBy: triggeredBy,
          OmniRtdbFields.driverId: driverId,
          OmniRtdbFields.incidentNote: incidentNote,
          OmniRtdbFields.lat: args['lat'] ?? args['latitude'],
          OmniRtdbFields.lng: args['lng'] ?? args['longitude'],
          'timestamp': now,
        };
        if (tripId.isNotEmpty) {
          await syncToFirebaseRtdb(OmniRtdbPaths.tripSos(tripId), payload);
        }
        return {
          'success': true,
          'data': {'trip_id': tripId, 'active': active, 'protocol_id': 'SOS-$idemp'},
          'timestamp': now,
        };

      case OmniBackendMethods.privateTripsSubmitBid:
        final offerId = (args['offer_id'] ?? '').toString();
        final driverId = (args['driver_id'] ?? '').toString();
        final bidAmount = (args['bid_amount'] as num?)?.toDouble() ?? 0.0;
        final message = (args['message'] ?? '').toString();
        if (offerId.isEmpty || bidAmount <= 0) {
          return {
            'success': false,
            'code': 'BID_INVALID_PARAMS',
            'error': 'Oferta e valor do lance são obrigatórios.',
            'timestamp': now,
          };
        }
        final bidId = 'bid_${DateTime.now().millisecondsSinceEpoch}';
        await syncToFirebaseRtdb(OmniRtdbPaths.privateBidItem(offerId, bidId), {
          'bid_id': bidId,
          OmniRtdbFields.driverId: driverId,
          'bid_amount': bidAmount,
          'message': message,
          'created_at': now,
        });
        return {
          'success': true,
          'data': {
            'bid_id': bidId,
            'offer_id': offerId,
            'bid_amount': bidAmount,
            'status': 'SUBMITTED',
          },
          'timestamp': now,
        };

      case OmniBackendMethods.walletRequestPixPayout:
        final driverId = (args['driver_id'] ?? 'drv_default').toString();
        final amount = (args['amount'] as num?)?.toDouble() ?? 0.0;
        final pixKey = (args['pix_key'] ?? '').toString();
        final pixKeyType = (args['pix_key_type'] ?? 'CPF').toString();
        if (pixKey.isEmpty || amount <= 0) {
          return {
            'success': false,
            'code': 'PIX_INVALID_PARAMS',
            'error': 'Valor inválido ou chave Pix não informada.',
            'timestamp': now,
          };
        }
        final txId = 'tx_mp_pix_${DateTime.now().millisecondsSinceEpoch}';
        await syncToFirebaseRtdb(OmniRtdbPaths.payoutItem(driverId, txId), {
          'transaction_id': txId,
          'amount': amount,
          'pix_key': pixKey,
          'pix_key_type': pixKeyType,
          'status': 'COMPLETED',
          'processed_at': now,
        });
        return {
          'success': true,
          'data': {
            'transaction_id': txId,
            'status': 'COMPLETED',
            'amount': amount,
            'pix_key': pixKey,
            'pix_key_type': pixKeyType,
          },
          'timestamp': now,
        };

      case OmniBackendMethods.syncState:
        final driverId = (args['driver_id'] ?? 'drv_default').toString();
        final dispatchQueue = driverId.isNotEmpty
            ? await readFromFirebaseRtdb(OmniRtdbPaths.dispatchQueueDriver(driverId))
            : null;
        final privateOffers =
            await readFromFirebaseRtdb(OmniRtdbPaths.privateOffers);
        final rtdbPayouts = driverId.isNotEmpty
            ? await readFromFirebaseRtdb(OmniRtdbPaths.payoutsDriver(driverId))
            : null;
        return {
          'success': true,
          'data': {
            'driver_id': driverId,
            'sql_connected': false,
            'dispatch_queue': dispatchQueue,
            'private_offers': privateOffers,
            'rtdb_payouts': rtdbPayouts,
            'synced_at': now,
          },
          'timestamp': now,
        };

      case OmniBackendMethods.verifyAppOwner:
        final candidateEmail =
            (args['email'] ?? args['owner_email'] ?? _ownerEmail)
                .toString()
                .trim()
                .toLowerCase();
        final matched = isAllowedOwnerEmail(candidateEmail);
        return {
          'success': true,
          'data': {
            'is_owner': matched,
            'owner_test_allowed': matched,
            'role': matched ? 'app_owner' : 'driver',
            'owner_email': candidateEmail,
            'matched_by': matched ? 'email_local_fallback' : 'none',
            'local_fallback': true,
          },
          'timestamp': now,
        };

      case OmniBackendMethods.ownerSimulateHired:
        final candidateEmail =
            (args['email'] ?? args['owner_email'] ?? _ownerEmail)
                .toString()
                .trim()
                .toLowerCase();
        if (!isAllowedOwnerEmail(candidateEmail)) {
          return {
            'success': false,
            'code': 'OWNER_ONLY_FORBIDDEN',
            'error':
                'Acesso restrito: apenas o e-mail do dono ($primaryOwnerEmail) pode ativar o cenário de teste.',
            'timestamp': now,
          };
        }
        final driverId = (args['driver_id'] ?? '').toString();
        final enabled = args['enabled'] != false;
        final loc = args['location'] as Map<String, dynamic>?;
        await syncToFirebaseRtdb(OmniRtdbPaths.driverOnline(driverId), {
          OmniRtdbFields.driverId: driverId,
          OmniRtdbFields.isOnline: enabled,
          'test_mode': enabled,
          'simulated_hired': enabled,
          'onboarding_score': enabled ? 100 : 0,
          OmniRtdbFields.lat: loc?['latitude'],
          OmniRtdbFields.lng: loc?['longitude'],
          OmniRtdbFields.updatedAt: DateTime.now().millisecondsSinceEpoch,
        });
        return {
          'success': true,
          'data': {
            'driver_id': driverId,
            'simulated_hired': enabled,
            'is_online': enabled,
            'local_fallback': true,
          },
          'timestamp': now,
        };

      case OmniBackendMethods.registerFcmToken:
        final driverId = (args['driver_id'] ?? '').toString();
        if (driverId.isNotEmpty) {
          await syncToFirebaseRtdb(
            OmniRtdbPaths.motoristaDispositivo(driverId),
            {
              'driver_id': driverId,
              'fcm_token': (args['fcm_token'] ?? '').toString(),
              'platform': (args['platform'] ?? 'android').toString(),
              'cidade_atual': (args['cidade_atual'] ?? '').toString(),
              'topics': args['topics'] ?? const ['perfil_motorista'],
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            },
          );
        }
        return {
          'success': true,
          'data': {'driver_id': driverId, 'registered': true, 'local_fallback': true},
          'timestamp': now,
        };

      case OmniBackendMethods.campaignList:
        final rawCampaigns =
            await readFromFirebaseRtdb(OmniRtdbPaths.campanhasMotorista);
        final List<Map<String, dynamic>> campaigns = [];
        if (rawCampaigns is Map) {
          rawCampaigns.forEach((key, val) {
            if (val is Map) {
              final map = Map<String, dynamic>.from(val);
              map['campaign_id'] = map['campaign_id'] ?? key.toString();
              campaigns.add(map);
            }
          });
        }
        return {
          'success': true,
          'data': {'campaigns': campaigns, 'local_fallback': true},
          'timestamp': now,
        };

      case OmniBackendMethods.campaignSave:
        final saveEmail = (args['email'] ?? args['owner_email'] ?? _ownerEmail)
            .toString()
            .trim()
            .toLowerCase();
        if (!isAllowedOwnerEmail(saveEmail)) {
          return {
            'success': false,
            'code': 'OWNER_ONLY_FORBIDDEN',
            'error': 'Apenas o dono do aplicativo ($primaryOwnerEmail) pode salvar campanhas.',
            'timestamp': now,
          };
        }
        final campaignId = (args['campaign_id'] ?? args['id'] ?? 'cmp_${DateTime.now().millisecondsSinceEpoch}').toString();
        final dispatchNow = args['dispatch_now'] == true || args['disparar_agora'] == true;
        final rawImg = (args['imagem_url'] ?? '').toString().trim();
        final safeImg = (rawImg.startsWith('https://') || rawImg.startsWith('http://')) ? rawImg : '';
        final record = {
          'campaign_id': campaignId,
          'titulo': (args['titulo'] ?? '').toString().trim(),
          'mensagem': (args['mensagem'] ?? '').toString().trim(),
          'imagem_url': safeImg,
          'tipo_incentivo': (args['tipo_incentivo'] ?? 'bonus_corridas').toString(),
          'valor_ou_percentual_bonus': (args['valor_ou_percentual_bonus'] ?? '').toString(),
          'cidade_alvo': (args['cidade_alvo'] ?? 'TODAS').toString(),
          'data_hora_disparo': (args['data_hora_disparo'] ?? now).toString(),
          'data_hora_expiracao': (args['data_hora_expiracao'] ?? '').toString(),
          'status': dispatchNow ? 'enviada' : 'agendada',
          'created_by_email': saveEmail,
          'sent_at': dispatchNow ? now : '',
          'created_at': now,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        };
        await syncToFirebaseRtdb('${OmniRtdbPaths.campanhasMotorista}/$campaignId', record);
        return {
          'success': true,
          'data': {'campaign': record, 'local_fallback': true},
          'timestamp': now,
        };

      case OmniBackendMethods.campaignDispatchNow:
        final dispEmail = (args['email'] ?? args['owner_email'] ?? _ownerEmail)
            .toString()
            .trim()
            .toLowerCase();
        if (!isAllowedOwnerEmail(dispEmail)) {
          return {
            'success': false,
            'code': 'OWNER_ONLY_FORBIDDEN',
            'error': 'Apenas o dono do aplicativo ($primaryOwnerEmail) pode disparar campanhas.',
            'timestamp': now,
          };
        }
        final dispCid = (args['campaign_id'] ?? args['id'] ?? '').toString();
        if (dispCid.isEmpty) {
          return {'success': false, 'error': 'campaign_id obrigatório.', 'timestamp': now};
        }
        await patchFirebaseRtdb('${OmniRtdbPaths.campanhasMotorista}/$dispCid', {
          'status': 'enviada',
          'sent_at': now,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });
        return {
          'success': true,
          'data': {'campaign_id': dispCid, 'status': 'enviada', 'local_fallback': true},
          'timestamp': now,
        };

      case OmniBackendMethods.campaignCancel:
        final cancelEmail = (args['email'] ?? args['owner_email'] ?? _ownerEmail)
            .toString()
            .trim()
            .toLowerCase();
        if (!isAllowedOwnerEmail(cancelEmail)) {
          return {
            'success': false,
            'code': 'OWNER_ONLY_FORBIDDEN',
            'error': 'Apenas o dono do aplicativo ($primaryOwnerEmail) pode cancelar campanhas.',
            'timestamp': now,
          };
        }
        final cancelCid = (args['campaign_id'] ?? args['id'] ?? '').toString();
        if (cancelCid.isEmpty) {
          return {'success': false, 'error': 'campaign_id obrigatório.', 'timestamp': now};
        }
        await patchFirebaseRtdb('${OmniRtdbPaths.campanhasMotorista}/$cancelCid', {
          'status': 'cancelada',
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });
        return {
          'success': true,
          'data': {'campaign_id': cancelCid, 'status': 'cancelada', 'local_fallback': true},
          'timestamp': now,
        };

      case OmniBackendMethods.campaignDuplicate:
        final dupEmail = (args['email'] ?? args['owner_email'] ?? _ownerEmail)
            .toString()
            .trim()
            .toLowerCase();
        if (!isAllowedOwnerEmail(dupEmail)) {
          return {
            'success': false,
            'code': 'OWNER_ONLY_FORBIDDEN',
            'error': 'Apenas o dono do aplicativo ($primaryOwnerEmail) pode duplicar campanhas.',
            'timestamp': now,
          };
        }
        final sourceCid = (args['campaign_id'] ?? args['id'] ?? '').toString();
        final srcRaw = sourceCid.isNotEmpty
            ? await readFromFirebaseRtdb('${OmniRtdbPaths.campanhasMotorista}/$sourceCid')
            : null;
        if (srcRaw is! Map) {
          return {'success': false, 'error': 'Campanha origem não encontrada.', 'timestamp': now};
        }
        final newCid = 'cmp_${DateTime.now().millisecondsSinceEpoch}';
        final copy = Map<String, dynamic>.from(srcRaw);
        copy['campaign_id'] = newCid;
        copy['titulo'] = '${copy['titulo'] ?? 'Campanha'} (Cópia)';
        copy['status'] = 'agendada';
        copy['sent_at'] = '';
        copy['created_at'] = now;
        copy['updated_at'] = DateTime.now().millisecondsSinceEpoch;
        await syncToFirebaseRtdb('${OmniRtdbPaths.campanhasMotorista}/$newCid', copy);
        return {
          'success': true,
          'data': {'campaign': copy, 'local_fallback': true},
          'timestamp': now,
        };

      case OmniBackendMethods.promoRuleSave:
        final ruleId = (args['rule_id'] ?? args['id'] ?? '').toString().trim();
        if (ruleId.isNotEmpty) {
          await syncToFirebaseRtdb(
            OmniRtdbPaths.promocaoAgendada(ruleId),
            {
              'id': ruleId,
              'title': (args['title'] ?? '').toString(),
              'message': (args['message'] ?? '').toString(),
              'bonus_highlight': (args['bonus_highlight'] ?? '').toString(),
              'promo_style': (args['promo_style'] ?? 'bonus_corridas').toString(),
              'target_city': (args['target_city'] ?? 'TODAS').toString(),
              'interval_seconds': (args['interval_seconds'] as num?)?.round() ?? 300,
              'enabled': args['enabled'] == true,
              'last_triggered_at_ms': (args['last_triggered_at_ms'] as num?)?.round() ?? 0,
              'trigger_count': (args['trigger_count'] as num?)?.round() ?? 0,
              'created_at': (args['created_at'] ?? now).toString(),
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            },
          );
        }
        return {
          'success': true,
          'data': {
            'rule_id': ruleId,
            'saved_rtdb': ruleId.isNotEmpty,
            'fcm_configured': false,
            'local_fallback': true,
            'message': 'Salvo no Firebase RTDB (servidor PHP inacessível no momento; alarmes locais do Android ativos).',
          },
          'timestamp': now,
        };

      case OmniBackendMethods.promoRuleDelete:
        final delRuleId = (args['rule_id'] ?? args['id'] ?? '').toString().trim();
        if (delRuleId.isNotEmpty) {
          await deleteFromFirebaseRtdb(OmniRtdbPaths.promocaoAgendada(delRuleId));
        }
        return {
          'success': true,
          'data': {'rule_id': delRuleId, 'deleted': true, 'local_fallback': true},
          'timestamp': now,
        };

      case OmniBackendMethods.promoRuleList:
        final rawRules =
            await readFromFirebaseRtdb(OmniRtdbConfig.nodePromocoesAgendadas);
        final List<Map<String, dynamic>> rulesList = [];
        if (rawRules is Map) {
          rawRules.forEach((k, v) {
            if (v is Map) {
              final map = Map<String, dynamic>.from(v);
              map['id'] = map['id'] ?? k.toString();
              rulesList.add(map);
            }
          });
        }
        return {
          'success': true,
          'data': {'rules': rulesList, 'local_fallback': true},
          'timestamp': now,
        };

      case OmniBackendMethods.sendPushNotification:
      case OmniBackendMethods.campaignProcessCron:
      case OmniBackendMethods.dispatchTripPush:
        return {
          'success': false,
          'code': 'PHP_SERVER_UNREACHABLE',
          'error':
              'Servidor PHP ($_ajaxUrl) inacessível para disparo FCM HTTP v1. Verifique o IP/Domínio na aba Servidor/IP.',
          'data': {'local_fallback': true, 'fcm_configured': false},
          'timestamp': now,
        };

      default:
        return {
          'success': true,
          'data': {'executed': true, 'method': method, 'idemp': idemp, 'local_fallback': true},
          'timestamp': now,
        };
    }
  }
}
