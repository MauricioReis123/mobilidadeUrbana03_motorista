import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../config/omni_integration_contracts.dart';
import '../models/omni_models.dart';
import 'backend_service.dart';
import 'firebase_service.dart';

/// Canal Heads-Up principal de alta prioridade (Android 8+) para FCM e alertas locais
const String kOmniDriverHighChannelId = 'omni_motorista_high_channel';
const String kOmniDriverLegacyChannelId = 'omni_motorista_campanhas_high';
const String kOmniDriverCampaignChannelId = kOmniDriverHighChannelId;
const String kOmniDriverCampaignChannelName = 'OMNI Motorista Prioritário';
const String kOmniDriverCampaignChannelDesc =
    'Notificações prioritárias de corridas, chat, repasses Pix, campanhas e bônus no topo da tela.';

final FlutterLocalNotificationsPlugin _bgLocalNotifications =
    FlutterLocalNotificationsPlugin();
bool _bgLocalInitialized = false;

Future<void> _ensureHighPriorityChannelsOnPlugin(
  FlutterLocalNotificationsPlugin plugin,
) async {
  final androidPlugin = plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin == null) return;

  await androidPlugin.createNotificationChannel(
    const AndroidNotificationChannel(
      kOmniDriverHighChannelId,
      kOmniDriverCampaignChannelName,
      description: kOmniDriverCampaignChannelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    ),
  );
  // Canal legado mantido com Importance.max para retrocompatibilidade
  await androidPlugin.createNotificationChannel(
    const AndroidNotificationChannel(
      kOmniDriverLegacyChannelId,
      'Campanhas e Bônus OMNI',
      description: kOmniDriverCampaignChannelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    ),
  );
}

/// Handler Top-Level obrigatório do Firebase Messaging em background / app totalmente fechado
@pragma('vm:entry-point')
Future<void> omniFirebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {}

  // Se o payload vier como data-only (ou híbrido sem bloco notification), exibe Heads-Up local imediatamente
  if (message.notification == null && message.data.isNotEmpty) {
    try {
      if (!_bgLocalInitialized) {
        const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        const iosInit = DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );
        await _bgLocalNotifications.initialize(
          const InitializationSettings(android: androidInit, iOS: iosInit),
        );
        await _ensureHighPriorityChannelsOnPlugin(_bgLocalNotifications);
        _bgLocalInitialized = true;
      }

      final title = (message.data['title'] ??
              message.data['titulo'] ??
              'OMNI Motorista PRO')
          .toString();
      final body = (message.data['body'] ??
              message.data['mensagem'] ??
              'Nova notificação prioritária disponível.')
          .toString();
      final rawChannel = (message.data['channel_id'] ?? '').toString().trim();
      final channelId = rawChannel == kOmniDriverLegacyChannelId
          ? kOmniDriverLegacyChannelId
          : kOmniDriverHighChannelId;

      final androidDetails = AndroidNotificationDetails(
        channelId,
        kOmniDriverCampaignChannelName,
        channelDescription: kOmniDriverCampaignChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
        ticker: title,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
        ),
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      await _bgLocalNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: jsonEncode(message.data),
      );
    } catch (_) {}
  }
}

/// Motor de Notificações Push (FCM HTTP v1 + Local Heads-Up + AlarmManager Background + Tópicos + RTDB)
class DriverNotificationService extends ChangeNotifier {
  static const String _cityTopicStorageKey = 'omni_subscribed_city_topic_v1';
  static const String _promoRulesStorageKey = 'omni_owner_promo_rules_v1';
  static const String _scheduledOsIdsStorageKey =
      'omni_scheduled_os_notif_ids_v1';
  static const String _driverTopic = 'perfil_motorista';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  OmniBackendService? _backend;
  OmniFirebaseService? _firebaseService;

  bool _initialized = false;
  bool _timeZonesInitialized = false;
  bool _notificationsPermissionGranted = true;
  bool _exactAlarmPermissionGranted = true;
  int _pendingOsScheduledCount = 0;
  String? _fcmToken;
  String? _currentCityTopic;
  String _driverId = 'drv_default';
  String _driverEmail = '';
  String _driverCity = '';
  String? _lastRemoteFcmStatus;
  bool _lastRemoteFcmOk = false;
  List<DriverCampaign> _campaigns = const [];
  List<ScheduledPromoNotificationRule> _scheduledPromoRules = const [];
  final Set<String> _nativeScheduledRuleIds = <String>{};

  bool _resyncInFlight = false;
  bool _resyncRequestedAgain = false;

  StreamSubscription<DatabaseEvent>? _rtdbCampaignsSub;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;
  Timer? _rtdbPollTimer;
  Timer? _promoSchedulerTimer;

  void Function(Map<String, dynamic> data)? _onDeepLinkCallback;
  void Function(String title, String message, String severity)?
      _onForegroundBanner;

  bool get initialized => _initialized;
  bool get notificationsPermissionGranted => _notificationsPermissionGranted;
  bool get exactAlarmPermissionGranted => _exactAlarmPermissionGranted;
  int get pendingOsScheduledCount => _pendingOsScheduledCount;
  String? get fcmToken => _fcmToken;
  bool get hasFcmToken => _fcmToken != null && _fcmToken!.isNotEmpty;
  bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;
  String? get lastRemoteFcmStatus => _lastRemoteFcmStatus;
  bool get lastRemoteFcmOk => _lastRemoteFcmOk;
  String? get currentCityTopic => _currentCityTopic;
  List<DriverCampaign> get campaigns => _campaigns;
  List<ScheduledPromoNotificationRule> get scheduledPromoRules =>
      _scheduledPromoRules;

  List<String> get activeTopics => [
        _driverTopic,
        if (_currentCityTopic != null && _currentCityTopic!.isNotEmpty)
          _currentCityTopic!,
      ];

  /// Normaliza cidade operacional para slug de tópico FCM (`motorista_cidade_{slug}`)
  static String normalizeCityTopic(String rawCity) {
    var clean = rawCity.trim();
    if (clean.isEmpty ||
        clean.toUpperCase() == 'TODAS' ||
        clean.toUpperCase() == 'ALL') {
      return '';
    }
    clean = clean.replaceAll(RegExp(r'\s*[-\/]\s*[A-Za-z]{2}$'), '');
    const src = 'ÁÀÃÂÄáàãâäÉÈÊËéèêëÍÌÎÏíìîïÓÒÕÔÖóòõôöÚÙÛÜúùûüÇçÑñ';
    const dst = 'AAAAAaaaaaEEEEeeeeIIIIiiiiOOOOOoooooUUUUuuuuCcNn';
    final buf = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      final ch = clean[i];
      final idx = src.indexOf(ch);
      buf.write(idx >= 0 ? dst[idx] : ch);
    }
    final slug = buf
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return slug.isEmpty ? '' : 'motorista_cidade_$slug';
  }

  void _ensureTimeZonesReady() {
    if (_timeZonesInitialized) return;
    try {
      tz_data.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
      _timeZonesInitialized = true;
    } catch (e) {
      debugPrint('[OMNI Push] Erro ao inicializar timezone: $e');
    }
  }

  /// Inicializa canal Heads-Up local, permissões FCM/AlarmManager, token e listeners
  Future<void> initialize({
    required OmniBackendService backend,
    required OmniFirebaseService firebaseService,
    required String driverId,
    String? initialCity,
    String? driverEmail,
    void Function(Map<String, dynamic> data)? onDeepLink,
    void Function(String title, String message, String severity)?
        onForegroundBanner,
  }) async {
    _backend = backend;
    _firebaseService = firebaseService;
    _driverId = driverId.trim().isNotEmpty ? driverId.trim() : _driverId;
    if (initialCity != null) _driverCity = initialCity.trim();
    if (driverEmail != null) _driverEmail = driverEmail.trim();
    _onDeepLinkCallback = onDeepLink;
    _onForegroundBanner = onForegroundBanner;

    if (!_initialized) {
      _ensureTimeZonesReady();
      await _initLocalNotifications();
      await _loadScheduledPromoRules();
      await _syncMissedRuleCountersOnLoad();
      await _initFirebaseMessaging(
        driverId: _driverId,
        initialCity: _driverCity,
      );
      _startCampaignsRealtimeSync();
      _startPromoSchedulerLoop();
      _initialized = true;
      await resyncScheduledPromoAlarms();
      notifyListeners();
    } else {
      await syncDriverIdentityAndToken(
        driverId: _driverId,
        city: _driverCity,
        email: _driverEmail,
      );
    }
  }

  Future<void> _initLocalNotifications() async {
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      await _localNotifications.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
        onDidReceiveNotificationResponse: (details) {
          final payloadStr = details.payload;
          if (payloadStr != null && payloadStr.isNotEmpty) {
            try {
              final decoded = jsonDecode(payloadStr);
              if (decoded is Map<String, dynamic>) {
                _handleDeepLinkPayload(decoded);
              }
            } catch (_) {
              _handleDeepLinkPayload({'action': 'open_promotions'});
            }
          } else {
            _handleDeepLinkPayload({'action': 'open_promotions'});
          }
        },
      );

      await _ensureHighPriorityChannelsOnPlugin(_localNotifications);

      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        _notificationsPermissionGranted =
            granted ?? (await androidPlugin.areNotificationsEnabled()) ?? true;

        try {
          final canExact = await androidPlugin.canScheduleExactNotifications();
          _exactAlarmPermissionGranted = canExact ?? true;
        } catch (_) {
          _exactAlarmPermissionGranted = true;
        }
      }
    } catch (e) {
      debugPrint('[OMNI Push] Erro ao iniciar flutter_local_notifications: $e');
    }
  }

  Future<bool> requestNotificationsPermissionExplicit() async {
    try {
      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        final enabled = await androidPlugin.areNotificationsEnabled();
        _notificationsPermissionGranted = granted ?? enabled ?? false;
        try {
          final canExactBefore =
              await androidPlugin.canScheduleExactNotifications();
          if (canExactBefore == false) {
            await androidPlugin.requestExactAlarmsPermission();
          }
          _exactAlarmPermissionGranted =
              (await androidPlugin.canScheduleExactNotifications()) ?? true;
        } catch (_) {}
      }
      if (Firebase.apps.isNotEmpty) {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          _notificationsPermissionGranted = false;
        }
      }
    } catch (_) {}
    await resyncScheduledPromoAlarms();
    notifyListeners();
    return _notificationsPermissionGranted;
  }

  Future<bool> requestExactAlarmPermissionExplicit() async {
    try {
      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestExactAlarmsPermission();
        _exactAlarmPermissionGranted =
            (await androidPlugin.canScheduleExactNotifications()) ?? true;
      }
    } catch (_) {}
    await resyncScheduledPromoAlarms();
    notifyListeners();
    return _exactAlarmPermissionGranted;
  }

  Future<void> _initFirebaseMessaging({
    required String driverId,
    String? initialCity,
  }) async {
    try {
      if (Firebase.apps.isEmpty) {
        return;
      }
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      try {
        await messaging.subscribeToTopic(_driverTopic);
      } catch (_) {}

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        _fcmToken = token;
      }

      if (initialCity != null && initialCity.trim().isNotEmpty) {
        await syncDriverCityTopic(driverId: driverId, city: initialCity);
      } else if (_fcmToken != null) {
        await _persistDeviceRegistration(
          driverId: driverId,
          city: initialCity ?? '',
        );
      }

      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        unawaited(_persistDeviceRegistration(
          driverId: _driverId,
          city: _driverCity,
        ));
        notifyListeners();
      });

      _onMessageSub?.cancel();
      _onMessageSub = FirebaseMessaging.onMessage.listen((msg) {
        _handleForegroundMessage(msg);
      });

      _onOpenedSub?.cancel();
      _onOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        _handleDeepLinkPayload(msg.data);
      });

      final initialMsg = await messaging.getInitialMessage();
      if (initialMsg != null) {
        _handleDeepLinkPayload(initialMsg.data);
      }
    } catch (e) {
      debugPrint(
          '[OMNI Push] FCM indisponível neste build (modo local/RTDB ativo): $e');
    }
  }

  /// Atualiza identidade + token FCM do motorista no RTDB e Backend PHP
  Future<void> syncDriverIdentityAndToken({
    required String driverId,
    String? city,
    String? email,
  }) async {
    if (driverId.trim().isNotEmpty) {
      _driverId = driverId.trim();
    }
    if (email != null) {
      _driverEmail = email.trim();
    }
    if (city != null && city.trim().isNotEmpty) {
      _driverCity = city.trim();
      await syncDriverCityTopic(driverId: _driverId, city: _driverCity);
    } else {
      await _persistDeviceRegistration(driverId: _driverId, city: _driverCity);
    }
  }

  /// Atualiza tópico da cidade do motorista e remove tópico antigo para evitar alertas errados
  Future<void> syncDriverCityTopic({
    required String driverId,
    required String city,
  }) async {
    if (driverId.trim().isNotEmpty) {
      _driverId = driverId.trim();
    }
    _driverCity = city.trim();
    final nextTopic = normalizeCityTopic(city);
    try {
      final prefs = await SharedPreferences.getInstance();
      final prevTopic = prefs.getString(_cityTopicStorageKey) ?? '';

      if (Firebase.apps.isNotEmpty) {
        final messaging = FirebaseMessaging.instance;
        await messaging.subscribeToTopic(_driverTopic);

        if (prevTopic.isNotEmpty && prevTopic != nextTopic) {
          try {
            await messaging.unsubscribeFromTopic(prevTopic);
          } catch (_) {}
        }
        if (nextTopic.isNotEmpty && nextTopic != prevTopic) {
          try {
            await messaging.subscribeToTopic(nextTopic);
          } catch (_) {}
        }
      }

      _currentCityTopic = nextTopic.isEmpty ? null : nextTopic;
      if (nextTopic.isEmpty) {
        await prefs.remove(_cityTopicStorageKey);
      } else {
        await prefs.setString(_cityTopicStorageKey, nextTopic);
      }
    } catch (_) {}

    await _persistDeviceRegistration(driverId: _driverId, city: _driverCity);
    notifyListeners();
  }

  Future<void> _persistDeviceRegistration({
    required String driverId,
    required String city,
  }) async {
    if (_backend == null) return;
    if ((_fcmToken == null || _fcmToken!.isEmpty) && Firebase.apps.isNotEmpty) {
      try {
        _fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (_) {}
    }
    final token = _fcmToken;
    if (token == null || token.isEmpty) return;

    final platform =
        defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    final payload = {
      'driver_id': driverId,
      'email': _driverEmail,
      'fcm_token': token,
      'platform': platform,
      'cidade_atual': city,
      'topics': activeTopics,
      'channel_id': kOmniDriverHighChannelId,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    unawaited(
      _backend!.syncToFirebaseRtdb(
        OmniRtdbPaths.motoristaDispositivo(driverId),
        payload,
      ),
    );
    unawaited(
      _backend!.executar(
        targetMethod: OmniBackendMethods.registerFcmToken,
        arguments: payload,
      ),
    );
  }

  /// Dispara push real via Backend PHP (FCM HTTP v1) para um token individual, motorista ou tópico
  Future<Map<String, dynamic>> sendRemoteFcmPush({
    required String title,
    required String body,
    String? targetFcmToken,
    String? targetDriverId,
    String? topic,
    Map<String, dynamic> data = const {},
  }) async {
    if (_backend == null) {
      return {'success': false, 'error': 'Backend não inicializado.'};
    }
    final args = <String, dynamic>{
      'email': _driverEmail.isNotEmpty ? _driverEmail : _backend!.ownerEmail,
      'owner_email':
          _driverEmail.isNotEmpty ? _driverEmail : _backend!.ownerEmail,
      'title': title,
      'body': body,
      'channel_id': kOmniDriverHighChannelId,
      'data': {
        'action': 'open_promotions',
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        ...data,
      },
    };
    if (targetFcmToken != null && targetFcmToken.trim().isNotEmpty) {
      args['fcm_token'] = targetFcmToken.trim();
    } else if (targetDriverId != null && targetDriverId.trim().isNotEmpty) {
      args['target_driver_id'] = targetDriverId.trim();
    } else if (topic != null && topic.trim().isNotEmpty) {
      args['topic'] = topic.trim();
    } else if (_fcmToken != null && _fcmToken!.isNotEmpty) {
      args['fcm_token'] = _fcmToken!;
    } else {
      args['target_driver_id'] = _driverId;
    }

    final resp = await _backend!.executar(
      targetMethod: OmniBackendMethods.sendPushNotification,
      arguments: args,
    );
    if (resp['success'] == true) {
      _lastRemoteFcmOk = true;
      _lastRemoteFcmStatus =
          (resp['data']?['message'] ?? 'Push FCM HTTP v1 enviado com sucesso ✓')
              .toString();
    } else {
      _lastRemoteFcmOk = false;
      _lastRemoteFcmStatus =
          (resp['error'] ?? 'Falha ao enviar via FCM HTTP v1.')
              .toString();
    }
    notifyListeners();
    return resp;
  }

  Future<void> _handleForegroundMessage(RemoteMessage msg) async {
    final title = msg.notification?.title ??
        (msg.data['title'] ?? msg.data['titulo'] ?? 'OMNI Motorista')
            .toString();
    final body = msg.notification?.body ??
        (msg.data['body'] ??
                msg.data['mensagem'] ??
                'Confira os detalhes disponíveis agora.')
            .toString();
    final promoStyle =
        (msg.data['promo_style'] ?? msg.data['tipo_incentivo'] ?? 'bonus_corridas')
            .toString();
    final bonus =
        (msg.data['valor_ou_percentual_bonus'] ?? msg.data['bonus'] ?? '')
            .toString();

    await showHeadsUpLocalNotification(
      title: title,
      body: body,
      promoStyle: promoStyle,
      bonusHighlight: bonus,
      data: msg.data,
    );
    _onForegroundBanner?.call(title, body, 'info');
    unawaited(refreshCampaigns());
  }

  static Color _promoAccentColor(String promoStyle) {
    switch (promoStyle) {
      case 'alta_demanda':
        return const Color(0xFFF59E0B);
      case 'meta_relampago':
        return const Color(0xFF00FFCC);
      case 'clube_vip':
        return const Color(0xFFA855F7);
      case 'combustivel':
        return const Color(0xFF38BDF8);
      case 'aviso_frota':
        return const Color(0xFFF43F5E);
      case 'bonus_corridas':
      default:
        return const Color(0xFF10B981);
    }
  }

  static String _promoEmoji(String promoStyle) {
    switch (promoStyle) {
      case 'alta_demanda':
        return '🔥';
      case 'meta_relampago':
        return '⚡';
      case 'clube_vip':
        return '👑';
      case 'combustivel':
        return '⛽';
      case 'aviso_frota':
        return '📢';
      case 'bonus_corridas':
      default:
        return '🎁';
    }
  }

  ({String styledTitle, NotificationDetails details})
      _buildHeadsUpNotificationDetails({
    required String title,
    required String body,
    String promoStyle = 'bonus_corridas',
    String bonusHighlight = '',
    String channelId = kOmniDriverHighChannelId,
  }) {
    final emoji = _promoEmoji(promoStyle);
    final styledTitle = title.startsWith(emoji) ? title : '$emoji $title';
    final accent = _promoAccentColor(promoStyle);
    final cleanBonus = bonusHighlight.trim();
    final subText =
        cleanBonus.isNotEmpty ? 'OMNI • $cleanBonus' : 'OMNI Motorista PRO';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      kOmniDriverCampaignChannelName,
      channelDescription: kOmniDriverCampaignChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      ticker: styledTitle,
      playSound: true,
      enableVibration: true,
      color: accent,
      subText: subText,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: styledTitle,
        summaryText: cleanBonus.isNotEmpty
            ? 'OMNI Motorista • $cleanBonus'
            : 'OMNI Motorista • Toque para abrir',
      ),
    );
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      subtitle: cleanBonus.isNotEmpty ? cleanBonus : 'OMNI Motorista',
    );
    return (
      styledTitle: styledTitle,
      details: NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  /// Exibe notificação Heads-Up (Importance.max / Priority.high) no topo do dispositivo
  Future<void> showHeadsUpLocalNotification({
    required String title,
    required String body,
    String promoStyle = 'bonus_corridas',
    String bonusHighlight = '',
    Map<String, dynamic> data = const {},
  }) async {
    try {
      final rawChannel = (data['channel_id'] ?? '').toString().trim();
      final channelId = rawChannel == kOmniDriverLegacyChannelId
          ? kOmniDriverLegacyChannelId
          : kOmniDriverHighChannelId;
      final built = _buildHeadsUpNotificationDetails(
        title: title,
        body: body,
        promoStyle: promoStyle,
        bonusHighlight: bonusHighlight,
        channelId: channelId,
      );
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        built.styledTitle,
        body,
        built.details,
        payload:
            jsonEncode(data.isEmpty ? {'action': 'open_promotions'} : data),
      );
    } catch (_) {}
  }

  void _handleDeepLinkPayload(Map<String, dynamic> data) {
    _onDeepLinkCallback?.call(data);
  }

  void _startCampaignsRealtimeSync() {
    _rtdbCampaignsSub?.cancel();
    _rtdbPollTimer?.cancel();

    final stream =
        _firebaseService?.valueStream(OmniRtdbPaths.campanhasMotorista);
    if (stream != null) {
      _rtdbCampaignsSub = stream.listen((event) {
        final raw = event.snapshot.value;
        if (raw is Map) {
          _ingestRtdbCampaigns(raw);
        } else if (raw == null) {
          _campaigns = const [];
          notifyListeners();
        }
      });
    }

    unawaited(refreshCampaigns());
    _rtdbPollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => refreshCampaigns(),
    );
  }

  void _ingestRtdbCampaigns(Map raw) {
    final List<DriverCampaign> parsed = [];
    raw.forEach((key, val) {
      if (val is Map) {
        final map = Map<String, dynamic>.from(val);
        map['campaign_id'] = map['campaign_id'] ?? key.toString();
        parsed.add(DriverCampaign.fromJson(map));
      }
    });
    parsed.sort((a, b) => b.dataHoraDisparo.compareTo(a.dataHoraDisparo));
    _campaigns = parsed;
    notifyListeners();
  }

  Future<void> refreshCampaigns() async {
    if (_backend == null) return;
    try {
      final resp = await _backend!.executar(
        targetMethod: OmniBackendMethods.campaignList,
        arguments: const {},
      );
      final data = resp['data'];
      if (resp['success'] == true &&
          data is Map<String, dynamic> &&
          data['campaigns'] is List) {
        final List<DriverCampaign> list = [];
        for (final item in data['campaigns'] as List) {
          if (item is Map) {
            list.add(DriverCampaign.fromJson(Map<String, dynamic>.from(item)));
          }
        }
        if (list.isNotEmpty) {
          list.sort((a, b) => b.dataHoraDisparo.compareTo(a.dataHoraDisparo));
          _campaigns = list;
          notifyListeners();
          return;
        }
      }

      final rawRtdb =
          await _backend!.readFromFirebaseRtdb(OmniRtdbPaths.campanhasMotorista);
      if (rawRtdb is Map) {
        _ingestRtdbCampaigns(rawRtdb);
      }
    } catch (_) {}
  }

  List<DriverCampaign> activeCampaignsForCity(String? driverCity) {
    final driverSlug =
        driverCity != null ? normalizeCityTopic(driverCity) : '';
    return _campaigns.where((c) {
      if (!c.isActiveForDriver) return false;
      final campSlug = normalizeCityTopic(c.cidadeAlvo);
      if (campSlug.isEmpty || driverSlug.isEmpty) return true;
      return campSlug == driverSlug;
    }).toList();
  }

  Future<void> _loadScheduledPromoRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_promoRulesStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _scheduledPromoRules = list
            .whereType<Map<String, dynamic>>()
            .map(ScheduledPromoNotificationRule.fromJson)
            .toList();
      }
    } catch (_) {}
  }

  Future<void> _persistScheduledPromoRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _promoRulesStorageKey,
        jsonEncode(_scheduledPromoRules.map((r) => r.toJson()).toList()),
      );
    } catch (_) {}
  }

  /// Atualiza os contadores e último disparo quando o app volta a abrir após disparos feitos pelo Android/iOS fechado
  Future<void> _syncMissedRuleCountersOnLoad() async {
    if (_scheduledPromoRules.isEmpty) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    bool changed = false;
    final updated = <ScheduledPromoNotificationRule>[];

    for (final rule in _scheduledPromoRules) {
      if (!rule.enabled ||
          rule.intervalSeconds <= 0 ||
          rule.lastTriggeredAtMs <= 0) {
        updated.add(rule);
        continue;
      }
      final intervalMs = rule.intervalSeconds * 1000;
      if (nowMs - rule.lastTriggeredAtMs >= intervalMs) {
        final steps = (nowMs - rule.lastTriggeredAtMs) ~/ intervalMs;
        updated.add(rule.copyWith(
          lastTriggeredAtMs: rule.lastTriggeredAtMs + (steps * intervalMs),
          triggerCount: rule.triggerCount + steps,
        ));
        changed = true;
      } else {
        updated.add(rule);
      }
    }

    if (changed) {
      _scheduledPromoRules = updated;
      await _persistScheduledPromoRules();
    }
  }

  /// Reagenda todos os próximos disparos nativos diretamente no AlarmManager (Android) / UNUserNotificationCenter (iOS)
  Future<void> resyncScheduledPromoAlarms() async {
    if (_resyncInFlight) {
      _resyncRequestedAgain = true;
      return;
    }
    _resyncInFlight = true;
    try {
      await _doResyncScheduledPromoAlarms();
    } finally {
      _resyncInFlight = false;
      if (_resyncRequestedAgain) {
        _resyncRequestedAgain = false;
        unawaited(resyncScheduledPromoAlarms());
      }
    }
  }

  Future<void> _doResyncScheduledPromoAlarms() async {
    _ensureTimeZonesReady();
    final prefs = await SharedPreferences.getInstance();
    final prevIdsRaw = prefs.getStringList(_scheduledOsIdsStorageKey) ?? const [];

    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      for (final s in prevIdsRaw) {
        final id = int.tryParse(s);
        if (id != null) {
          try {
            await _localNotifications.cancel(id);
          } catch (_) {}
        }
      }
      _nativeScheduledRuleIds.clear();
      await prefs.setStringList(_scheduledOsIdsStorageKey, const []);
      _pendingOsScheduledCount = 0;
      notifyListeners();
      return;
    }

    final activeRules = _scheduledPromoRules
        .where((r) => r.enabled && r.intervalSeconds > 0)
        .toList();
    if (activeRules.isEmpty) {
      for (final s in prevIdsRaw) {
        final id = int.tryParse(s);
        if (id != null) {
          try {
            await _localNotifications.cancel(id);
          } catch (_) {}
        }
      }
      _nativeScheduledRuleIds.clear();
      await prefs.setStringList(_scheduledOsIdsStorageKey, const []);
      _pendingOsScheduledCount = 0;
      notifyListeners();
      return;
    }

    bool useExact = true;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final androidPlugin =
            _localNotifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          final canExact = await androidPlugin.canScheduleExactNotifications();
          useExact = canExact ?? true;
          _exactAlarmPermissionGranted = useExact;
        }
      } catch (_) {}
    }

    final int maxTotalSlots =
        defaultTargetPlatform == TargetPlatform.iOS ? 45 : 150;
    final int slotsPerRule =
        (maxTotalSlots ~/ activeRules.length).clamp(1, 60);

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final List<String> newOsIds = <String>[];
    final Set<int> newIdSet = <int>{};
    final Set<String> nextNativeRuleIds = <String>{};

    for (int ruleIdx = 0; ruleIdx < activeRules.length; ruleIdx++) {
      final rule = activeRules[ruleIdx];
      final intervalMs = rule.intervalSeconds * 1000;
      final anchorMs =
          rule.lastTriggeredAtMs > 0 ? rule.lastTriggeredAtMs : nowMs;
      int firstFireMs = anchorMs + intervalMs;
      if (firstFireMs <= nowMs + 1500) {
        final stepsAhead =
            ((nowMs + 1500 - anchorMs) ~/ intervalMs) + 1;
        firstFireMs = anchorMs + (stepsAhead * intervalMs);
      }

      final fullTitle = rule.bonusHighlight.trim().isNotEmpty
          ? '${rule.title} • ${rule.bonusHighlight.trim()}'
          : rule.title;
      final built = _buildHeadsUpNotificationDetails(
        title: fullTitle,
        body: rule.message,
        promoStyle: rule.promoStyle,
        bonusHighlight: rule.bonusHighlight,
        channelId: kOmniDriverHighChannelId,
      );
      final payloadJson = jsonEncode({
        'action': 'open_promotions',
        'rule_id': rule.id,
        'promo_style': rule.promoStyle,
        'target_city': rule.targetCity,
      });

      bool ruleNativeOk = false;
      for (int slot = 0; slot < slotsPerRule; slot++) {
        final fireAtMs = firstFireMs + (slot * intervalMs);
        final notifId = 200000 + (ruleIdx * 500) + slot;
        final scheduledTz =
            tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, fireAtMs);

        try {
          await _localNotifications.zonedSchedule(
            notifId,
            built.styledTitle,
            rule.message,
            scheduledTz,
            built.details,
            androidScheduleMode: useExact
                ? AndroidScheduleMode.alarmClock
                : AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: payloadJson,
          );
          newOsIds.add(notifId.toString());
          newIdSet.add(notifId);
          ruleNativeOk = true;
        } catch (e) {
          final err = e.toString().toLowerCase();
          if (useExact &&
              (err.contains('exact_alarms_not_permitted') ||
                  err.contains('exact') ||
                  err.contains('alarm'))) {
            try {
              await _localNotifications.zonedSchedule(
                notifId,
                built.styledTitle,
                rule.message,
                scheduledTz,
                built.details,
                androidScheduleMode:
                    AndroidScheduleMode.exactAllowWhileIdle,
                uiLocalNotificationDateInterpretation:
                    UILocalNotificationDateInterpretation.absoluteTime,
                payload: payloadJson,
              );
              newOsIds.add(notifId.toString());
              newIdSet.add(notifId);
              ruleNativeOk = true;
            } catch (_) {
              useExact = false;
              _exactAlarmPermissionGranted = false;
              try {
                await _localNotifications.zonedSchedule(
                  notifId,
                  built.styledTitle,
                  rule.message,
                  scheduledTz,
                  built.details,
                  androidScheduleMode:
                      AndroidScheduleMode.inexactAllowWhileIdle,
                  uiLocalNotificationDateInterpretation:
                      UILocalNotificationDateInterpretation.absoluteTime,
                  payload: payloadJson,
                );
                newOsIds.add(notifId.toString());
                newIdSet.add(notifId);
                ruleNativeOk = true;
              } catch (_) {}
            }
          }
        }
      }

      if (ruleNativeOk) {
        nextNativeRuleIds.add(rule.id);
      }
    }

    // Cancela apenas IDs antigos que não foram sobrescritos (substituição atômica)
    for (final s in prevIdsRaw) {
      final id = int.tryParse(s);
      if (id != null && !newIdSet.contains(id)) {
        try {
          await _localNotifications.cancel(id);
        } catch (_) {}
      }
    }

    _nativeScheduledRuleIds
      ..clear()
      ..addAll(nextNativeRuleIds);
    await prefs.setStringList(_scheduledOsIdsStorageKey, newOsIds);
    _pendingOsScheduledCount = newOsIds.length;
    notifyListeners();
  }

  void _startPromoSchedulerLoop() {
    _promoSchedulerTimer?.cancel();
    _promoSchedulerTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_evaluateDuePromoRules()),
    );
  }

  Future<void> _evaluateDuePromoRules() async {
    if (_scheduledPromoRules.isEmpty) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    bool changed = false;
    bool needsQueueTopUp = false;
    final updated = <ScheduledPromoNotificationRule>[];

    for (final rule in _scheduledPromoRules) {
      if (!rule.enabled || rule.intervalSeconds <= 0) {
        updated.add(rule);
        continue;
      }
      final intervalMs = rule.intervalSeconds * 1000;
      if (rule.lastTriggeredAtMs == 0 ||
          nowMs - rule.lastTriggeredAtMs >= intervalMs) {
        final int steps = rule.lastTriggeredAtMs == 0
            ? 1
            : ((nowMs - rule.lastTriggeredAtMs) ~/ intervalMs);
        final int nextAnchorMs = rule.lastTriggeredAtMs == 0
            ? nowMs
            : rule.lastTriggeredAtMs + (steps * intervalMs);

        final bool handledByNativeAlarm =
            _nativeScheduledRuleIds.contains(rule.id);
        await _fireRuleNotification(
          rule,
          showOsNotification: !handledByNativeAlarm,
        );
        if (handledByNativeAlarm) {
          needsQueueTopUp = true;
        }
        updated.add(rule.copyWith(
          lastTriggeredAtMs: nextAnchorMs,
          triggerCount: rule.triggerCount + steps,
        ));
        changed = true;
      } else {
        updated.add(rule);
      }
    }

    if (changed) {
      _scheduledPromoRules = updated;
      await _persistScheduledPromoRules();
      for (final r in updated) {
        if (r.enabled) {
          unawaited(_syncPromoRuleToServer(r, triggerImmediately: false));
        }
      }
      if (needsQueueTopUp) {
        unawaited(resyncScheduledPromoAlarms());
      }
      notifyListeners();
    }
  }

  Future<void> _fireRuleNotification(
    ScheduledPromoNotificationRule rule, {
    bool showOsNotification = true,
  }) async {
    final fullTitle = rule.bonusHighlight.trim().isNotEmpty
        ? '${rule.title} • ${rule.bonusHighlight.trim()}'
        : rule.title;
    if (showOsNotification) {
      await showHeadsUpLocalNotification(
        title: fullTitle,
        body: rule.message,
        promoStyle: rule.promoStyle,
        bonusHighlight: rule.bonusHighlight,
        data: {
          'action': 'open_promotions',
          'rule_id': rule.id,
          'promo_style': rule.promoStyle,
          'target_city': rule.targetCity,
        },
      );
    }
    _onForegroundBanner?.call(
      '${rule.iconEmoji} $fullTitle',
      rule.message,
      'success',
    );
  }

  int? secondsUntilNextFire(ScheduledPromoNotificationRule rule) {
    if (!rule.enabled || rule.intervalSeconds <= 0) return null;
    if (rule.lastTriggeredAtMs == 0) return 0;
    final elapsedSec =
        ((DateTime.now().millisecondsSinceEpoch - rule.lastTriggeredAtMs) /
                1000)
            .floor();
    final remaining = rule.intervalSeconds - (elapsedSec % rule.intervalSeconds);
    return elapsedSec >= rule.intervalSeconds ? 0 : remaining;
  }

  Future<void> _syncPromoRuleToServer(
    ScheduledPromoNotificationRule rule, {
    bool triggerImmediately = false,
  }) async {
    if (_backend == null) return;
    final effectiveEmail =
        _driverEmail.isNotEmpty ? _driverEmail : _backend!.ownerEmail;

    unawaited(
      _backend!.syncToFirebaseRtdb(
        OmniRtdbPaths.promocaoAgendada(rule.id),
        rule.toJson(),
      ),
    );

    try {
      final resp = await _backend!.executar(
        targetMethod: OmniBackendMethods.promoRuleSave,
        arguments: {
          'email': effectiveEmail,
          'owner_email': effectiveEmail,
          'rule_id': rule.id,
          'title': rule.title,
          'message': rule.message,
          'bonus_highlight': rule.bonusHighlight,
          'promo_style': rule.promoStyle,
          'target_city': rule.targetCity,
          'interval_seconds': rule.intervalSeconds,
          'enabled': rule.enabled,
          'last_triggered_at_ms': rule.lastTriggeredAtMs,
          'trigger_count': rule.triggerCount,
          'created_at': rule.createdAt,
          'trigger_immediately': triggerImmediately,
          'driver_id': _driverId,
          if (_fcmToken != null && _fcmToken!.isNotEmpty)
            'fcm_token': _fcmToken!,
        },
      );

      final data = resp['data'];
      final bool isLocalFallback =
          data is Map<String, dynamic> && data['local_fallback'] == true;
      if (resp['success'] == true && !isLocalFallback) {
        final bool fcmConfigured =
            data is Map<String, dynamic> && data['fcm_configured'] == true;
        final fcmRes = data is Map<String, dynamic> ? data['fcm_result'] : null;
        if (fcmRes is Map && fcmRes['sent'] == true) {
          _lastRemoteFcmOk = true;
          _lastRemoteFcmStatus =
              'Regra sincronizada no servidor + push FCM HTTP v1 confirmado ✓';
        } else if (fcmConfigured) {
          _lastRemoteFcmOk = true;
          _lastRemoteFcmStatus =
              'Regra sincronizada no PHP + RTDB com FCM HTTP v1 pronto ✓';
        } else {
          _lastRemoteFcmOk = false;
          _lastRemoteFcmStatus =
              'Regra salva no servidor PHP/RTDB; configure firebase-service-account.json no servidor para FCM HTTP v1 remoto.';
        }
      } else {
        _lastRemoteFcmOk = false;
        _lastRemoteFcmStatus =
            'Salvo em Firebase RTDB + AlarmManager nativo (servidor PHP offline no momento).';
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<Map<String, dynamic>> triggerServerCronTick() async {
    if (_backend == null) {
      return {'success': false, 'error': 'Backend não inicializado.'};
    }
    final effectiveEmail =
        _driverEmail.isNotEmpty ? _driverEmail : _backend!.ownerEmail;
    final resp = await _backend!.executar(
      targetMethod: OmniBackendMethods.campaignProcessCron,
      arguments: {
        'email': effectiveEmail,
        'owner_email': effectiveEmail,
      },
    );
    if (resp['success'] == true) {
      final data = resp['data'];
      final promoCount =
          data is Map<String, dynamic> ? (data['promo_rules_count'] ?? 0) : 0;
      final campCount =
          data is Map<String, dynamic> ? (data['processed_count'] ?? 0) : 0;
      final warning =
          data is Map<String, dynamic> ? (data['warning'] ?? '').toString().trim() : '';
      final tokensCount =
          data is Map<String, dynamic> ? (data['registered_tokens_count'] ?? 0) : 0;
      if (warning.isNotEmpty) {
        _lastRemoteFcmOk = false;
        _lastRemoteFcmStatus = warning;
      } else {
        _lastRemoteFcmOk = true;
        _lastRemoteFcmStatus =
            'Cron FCM OK ($promoCount promoções / $campCount campanhas • $tokensCount dispositivos).';
      }
    } else {
      _lastRemoteFcmOk = false;
      _lastRemoteFcmStatus =
          (resp['error'] ?? 'Falha ao acionar cron FCM no servidor PHP.')
              .toString();
    }
    notifyListeners();
    return resp;
  }

  Future<void> addOrUpdateScheduledPromoRule(
    ScheduledPromoNotificationRule rule, {
    bool triggerImmediately = true,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final normalized = rule.copyWith(
      createdAt: rule.createdAt.isEmpty
          ? DateTime.now().toIso8601String()
          : rule.createdAt,
      lastTriggeredAtMs: triggerImmediately ? nowMs : rule.lastTriggeredAtMs,
      triggerCount:
          triggerImmediately ? rule.triggerCount + 1 : rule.triggerCount,
    );

    final idx = _scheduledPromoRules.indexWhere((r) => r.id == normalized.id);
    if (idx >= 0) {
      final copy = [..._scheduledPromoRules];
      copy[idx] = normalized;
      _scheduledPromoRules = copy;
    } else {
      _scheduledPromoRules = [normalized, ..._scheduledPromoRules];
    }

    if (triggerImmediately && normalized.enabled) {
      await _fireRuleNotification(normalized, showOsNotification: true);
    }

    await _persistScheduledPromoRules();
    await resyncScheduledPromoAlarms();
    await _syncPromoRuleToServer(normalized, triggerImmediately: false);
    notifyListeners();
  }

  Future<void> toggleScheduledPromoRule(String ruleId, bool enabled) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    ScheduledPromoNotificationRule? updatedRule;
    _scheduledPromoRules = _scheduledPromoRules.map((r) {
      if (r.id != ruleId) return r;
      updatedRule = r.copyWith(
        enabled: enabled,
        lastTriggeredAtMs: enabled ? nowMs : r.lastTriggeredAtMs,
      );
      return updatedRule!;
    }).toList();
    await _persistScheduledPromoRules();
    await resyncScheduledPromoAlarms();
    if (updatedRule != null) {
      unawaited(_syncPromoRuleToServer(updatedRule!, triggerImmediately: false));
    }
    notifyListeners();
  }

  Future<void> triggerPromoRuleNow(ScheduledPromoNotificationRule rule) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _fireRuleNotification(rule, showOsNotification: true);
    ScheduledPromoNotificationRule? updatedRule;
    _scheduledPromoRules = _scheduledPromoRules.map((r) {
      if (r.id != rule.id) return r;
      updatedRule = r.copyWith(
        lastTriggeredAtMs: nowMs,
        triggerCount: r.triggerCount + 1,
      );
      return updatedRule!;
    }).toList();
    await _persistScheduledPromoRules();
    await resyncScheduledPromoAlarms();
    if (updatedRule != null) {
      unawaited(_syncPromoRuleToServer(updatedRule!, triggerImmediately: false));
    }
    notifyListeners();
  }

  Future<void> deleteScheduledPromoRule(String ruleId) async {
    _scheduledPromoRules =
        _scheduledPromoRules.where((r) => r.id != ruleId).toList();
    await _persistScheduledPromoRules();
    await resyncScheduledPromoAlarms();
    if (_backend != null) {
      final effectiveEmail =
          _driverEmail.isNotEmpty ? _driverEmail : _backend!.ownerEmail;
      unawaited(
        _backend!.deleteFromFirebaseRtdb(OmniRtdbPaths.promocaoAgendada(ruleId)),
      );
      unawaited(
        _backend!.executar(
          targetMethod: OmniBackendMethods.promoRuleDelete,
          arguments: {
            'email': effectiveEmail,
            'owner_email': effectiveEmail,
            'rule_id': ruleId,
          },
        ),
      );
    }
    notifyListeners();
  }

  Future<void> clearAllDeliveredNotifications() async {
    try {
      await _localNotifications.cancelAll();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_scheduledOsIdsStorageKey, const []);
      _nativeScheduledRuleIds.clear();
      _pendingOsScheduledCount = 0;
      await resyncScheduledPromoAlarms();
    } catch (_) {}
  }

  @override
  void dispose() {
    _rtdbCampaignsSub?.cancel();
    _tokenRefreshSub?.cancel();
    _onMessageSub?.cancel();
    _onOpenedSub?.cancel();
    _rtdbPollTimer?.cancel();
    _promoSchedulerTimer?.cancel();
    super.dispose();
  }
}
