import 'dart:convert';
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

  String _configuredDomain = OmniRouterConfig.defaultDomain;
  String _ajaxUrl = OmniRouterConfig.baseUrl;
  bool _hasCustomDomainCached = false;
  bool _domainLoaded = false;
  String? _jwtToken;
  String? _cachedNonce;
  final List<Map<String, dynamic>> _offlineQueue = [];

  int get offlineQueueCount => _offlineQueue.length;
  String? get cachedNonce => _cachedNonce;
  String get configuredDomain => _configuredDomain;
  String get resolvedAjaxUrl => _ajaxUrl;
  String get baseUrl => _ajaxUrl;
  bool get hasCustomDomainCached => _hasCustomDomainCached;

  void setAuthToken(String token) {
    _jwtToken = token;
    notifyListeners();
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
      String? nonce = await fetchRouterNonce();
      if (nonce != null && nonce.isNotEmpty) {
        final payloadJson = jsonEncode({
          'backend_file': backendFile,
          'class_name': className,
          'target_method': safeMethod,
          'args': args,
        });

        http.Response response = await _postRouterRequest(
          nonce: nonce,
          payloadJson: payloadJson,
          idemp: idemp,
        );

        // Se o nonce expirou (HTTP 403), renova uma única vez e reenvia
        if (response.statusCode == 403) {
          nonce = await fetchRouterNonce(forceRefresh: true);
          if (nonce != null && nonce.isNotEmpty) {
            response = await _postRouterRequest(
              nonce: nonce,
              payloadJson: payloadJson,
              idemp: idemp,
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
  }) {
    final uri = Uri.parse(_ajaxUrl);
    return http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'Accept': 'application/json',
            if (_jwtToken != null) 'Authorization': 'Bearer $_jwtToken',
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

  Future<void> syncToFirebaseRtdb(String path, Object? payload) async {
    try {
      final uri = Uri.parse('$firebaseRtdbUrl/$path.json');
      await http
          .put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // Silencioso para não travar operação offline
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

  /// Geocodificação reversa via OpenStreetMap Nominatim + ViaCEP para pré-preenchimento editável do endereço pelo GPS
  Future<Map<String, String>?> reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon&addressdetails=1&accept-language=pt-BR',
      );
      final resp = await http.get(
        uri,
        headers: const {
          'User-Agent': 'OMNI-Mobilidade-Motorista-Flutter/2.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 7));
      if (resp.statusCode != 200) return null;
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final addr = (decoded['address'] as Map?)?.cast<String, dynamic>() ?? const {};

      final rawPostcode = (addr['postcode'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
      String cep = rawPostcode.length == 8
          ? '${rawPostcode.substring(0, 5)}-${rawPostcode.substring(5)}'
          : rawPostcode;
      String street = (addr['road'] ?? addr['pedestrian'] ?? addr['street'] ?? addr['residential'] ?? '').toString();
      final String number = (addr['house_number'] ?? '').toString();
      String neighborhood =
          (addr['suburb'] ?? addr['neighbourhood'] ?? addr['quarter'] ?? addr['city_district'] ?? '').toString();
      String city = (addr['city'] ?? addr['town'] ?? addr['municipality'] ?? addr['village'] ?? '').toString();
      final isoState = (addr['ISO3166-2-lvl4'] ?? '').toString().replaceFirst('BR-', '').toUpperCase();
      String state = isoState.length == 2 ? isoState : 'SP';

      if (rawPostcode.length == 8) {
        final via = await lookupViaCep(rawPostcode);
        if (via != null) {
          if (street.isEmpty && via['logradouro'] != null) street = via['logradouro'].toString();
          if (neighborhood.isEmpty && via['bairro'] != null) neighborhood = via['bairro'].toString();
          if (city.isEmpty && via['localidade'] != null) city = via['localidade'].toString();
          if (via['uf'] != null) state = via['uf'].toString().toUpperCase();
          if (via['cep'] != null) cep = via['cep'].toString();
        }
      }

      return {
        'cep': cep,
        'street': street,
        'number': number,
        'neighborhood': neighborhood,
        'city': city,
        'state': state,
      };
    } catch (_) {
      return null;
    }
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
        await syncToFirebaseRtdb(OmniRtdbPaths.driverOnline(driverId), {
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
        await syncToFirebaseRtdb(OmniRtdbPaths.tripStatus(tripId), OmniTripStatus.accepted);
        await syncToFirebaseRtdb(OmniRtdbPaths.tripDriverId(tripId), driverId);
        return {
          'success': true,
          'data': {'trip_id': tripId, 'status': OmniTripStatus.accepted, 'accepted_at': now},
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

        if (inputOtp == expectedOtp) {
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

      case OmniBackendMethods.walletRequestPixPayout:
        final amount = (args['amount'] as num?)?.toDouble() ?? 0.0;
        final pixKey = (args['pix_key'] ?? '').toString();
        if (pixKey.isEmpty || amount <= 0) {
          return {
            'success': false,
            'code': 'PIX_INVALID_PARAMS',
            'error': 'Valor inválido ou chave Pix não informada.',
            'timestamp': now,
          };
        }
        return {
          'success': true,
          'data': {
            'transaction_id': 'tx_mp_pix_${DateTime.now().millisecondsSinceEpoch}',
            'status': 'COMPLETED',
            'amount': amount,
            'pix_key': pixKey,
          },
          'timestamp': now,
        };

      default:
        return {
          'success': true,
          'data': {'executed': true, 'method': method, 'idemp': idemp},
          'timestamp': now,
        };
    }
  }
}
