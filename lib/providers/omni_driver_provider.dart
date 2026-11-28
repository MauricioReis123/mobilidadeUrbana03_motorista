import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/omni_integration_contracts.dart';
import '../models/omni_models.dart';
import '../services/backend_service.dart';
import '../services/behavioral_antifraud_engine.dart';
import '../services/driver_notification_service.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../services/sound_service.dart';
import '../services/vision_service.dart';
import '../utils/document_validators.dart';
import '../utils/driver_onboarding.dart';
import '../utils/vehicle_catalog.dart';

class DocumentUploadCrossResult {
  final String? faceMatchStatus; // 'MATCHED' | 'MISMATCH' | 'WAITING_FACE'
  final String? faceMatchMessage;
  final String? dataMatchStatus; // 'FIRST_DOC' | 'MATCHED' | 'MISMATCH'
  final String? dataMatchMessage;

  const DocumentUploadCrossResult({
    this.faceMatchStatus,
    this.faceMatchMessage,
    this.dataMatchStatus,
    this.dataMatchMessage,
  });
}

/// Estado Reativo Global OMNI Motorista — 1:1 com src/context/OmniDriverContext.tsx
class OmniDriverProvider extends ChangeNotifier {
  static const String _driverStorageKey = 'omni_driver_profile_v3';
  static const String _vehiclesStorageKey = 'omni_driver_vehicles_v3';
  static const String _documentsStorageKey = 'omni_driver_documents_v3';

  final OmniBackendService backend;
  final OmniLocationService locationService;
  final OmniFirebaseService? firebaseService;
  final DriverNotificationService? notificationService;

  late OmniDriver _driver;
  late List<OmniVehicle> _vehicles;
  late List<DriverDocument> _documents;
  late List<WalletTransaction> _transactions;
  late List<PrivateTripOffer> _privateOffers;
  late List<ChatMessage> _chatMessages;
  late List<SmartAlert> _alerts;

  OmniTrip? _incomingTrip;
  OmniTrip? _activeTrip;
  int _dispatchCountdown = 15;
  List<OmniCoordinate> _routePolyline = [];
  double _driverHeading = 0.0;

  // Navegação e UI
  MainTab _activeTab = MainTab.map;
  ProfileSubTab _profileSubTab = ProfileSubTab.personal;
  bool _mapDarkMode = true;
  bool _muted = false;
  bool _isSosActive = false;
  bool _biometricModalOpen = false;
  bool _stepperModalOpen = true;
  int? _stepperInitialStep;
  bool _safetyModalOpen = false;
  bool _chatOpen = false;
  int _unreadChatCount = 0;
  String? _documentCaptureDocId;
  bool _documentCaptureAutoCamera = true;
  int _recenterTick = 0;
  bool _isRunningFingerprintDocCheck = false;
  int _recentVehicleSwitches = 0;
  bool _ownerTestHiredMode = false;
  bool _ownerTestBusy = false;
  bool _isPollingDispatch = false;
  bool _isPollingChat = false;
  bool _isPollingTripStatus = false;
  bool _backendVerifiedOwner = false;
  String _ownerMatchedBy = 'none';

  Timer? _dispatchTimer;
  Timer? _dispatchPollTimer;
  Timer? _chatPollTimer;
  Timer? _tripStatusPollTimer;
  Timer? _locationStreamTimer;
  Timer? _privateOffersPollTimer;

  StreamSubscription<DatabaseEvent>? _dispatchRtdbSub;
  StreamSubscription<DatabaseEvent>? _chatRtdbSub;
  StreamSubscription<DatabaseEvent>? _tripStatusRtdbSub;
  StreamSubscription<DatabaseEvent>? _privateOffersRtdbSub;
  StreamSubscription<DatabaseEvent>? _payoutsRtdbSub;

  final Set<String> _knownChatMessageIds = {};
  final Set<String> _dismissedDispatchIds = {};

  OmniDriverProvider({
    required this.backend,
    required this.locationService,
    this.firebaseService,
    this.notificationService,
  }) {
    _initDefaults();
    notificationService?.addListener(_onNotificationServiceChanged);
    _loadPersistedState();
  }

  void _onNotificationServiceChanged() {
    notifyListeners();
  }

  String get backendDomain => backend.configuredDomain;
  String get backendAjaxUrl => backend.resolvedAjaxUrl;
  bool get hasCustomBackendDomain => backend.hasCustomDomainCached;

  Future<Map<String, String>> saveBackendDomain(String rawDomain) async {
    final res = await backend.saveConfiguredDomain(rawDomain);
    OmniSoundService.playSuccess();
    notifyListeners();
    unawaited(verifyAppOwnerWithBackend());
    return res;
  }

  Future<Map<String, String>> resetBackendDomain() async {
    final res = await backend.resetConfiguredDomain();
    OmniSoundService.playChatBeep();
    notifyListeners();
    return res;
  }

  Future<Map<String, dynamic>> testBackendDomain() async {
    final res = await backend.testRouterConnection();
    notifyListeners();
    return res;
  }

  void _initDefaults() {
    _driver = const OmniDriver(
      id: 'usr_drv_local',
      name: '',
      cpf: '',
      rg: '',
      rgIssuer: '',
      birthDate: '',
      email: '',
      phone: '',
      cnhNumber: '',
      cnhCategory: '',
      cnhExpiry: '',
      cnhIssueState: '',
      cnhEar: false,
      operationalCity: '',
      bio: '',
      address: DriverAddress(
        cep: '',
        street: '',
        number: '',
        complement: '',
        neighborhood: '',
        city: '',
        state: '',
      ),
      workPreferences: DriverWorkPreferences(
        acceptsPassengers: true,
        acceptsDeliveries: true,
        acceptsPrivateTrips: true,
        acceptsCash: true,
        acceptsPets: false,
        acceptsLargeLuggage: false,
        hasEar: false,
        maxRadiusKm: 15,
      ),
      complianceRites: ComplianceRites(
        acceptedTerms: false,
        acceptedPrivacyLgpd: false,
        acceptedZeroTolerance: false,
        completedSafetyBriefing: false,
        termsVersion: 'OMNI-BR-2025.2',
      ),
      rating: 5.0,
      acceptanceRate: 100.0,
      cancellationRate: 0.0,
      totalTrips: 0,
      clubTier: 'INICIAL',
      avatarUrl: '',
      faceMatchRg: FaceMatchEntry(status: 'PENDING'),
      faceMatchCnh: FaceMatchEntry(status: 'PENDING'),
      isOnline: false,
      isBiometricVerified: false,
      walletBalance: 0.0,
      todayEarnings: 0.0,
      todayTripsCount: 0,
      onlineHoursToday: 0.0,
      referralCode: 'OMNI-DRIVER',
      referralsCount: 0,
      referralEarnings: 0.0,
      behavioralRisk: BehavioralRiskState(
        accountStatus: 'PENDING_SUBMISSION',
        riskScore: 0,
        riskLevel: 'LOW',
        revalidationRequired: false,
        vehicleSwitchCountRecent: 0,
        incidentCount: 0,
        events: const [],
        deviceFingerprint: 'OMNI-DEV-PRIMARY',
      ),
    );

    _vehicles = const [];

    _documents = const [
      DriverDocument(
        id: 'doc_cpf',
        name: 'CPF — Cadastro de Pessoa Física',
        type: 'CPF',
        status: 'PENDING',
        updatedAt: 'Aguardando envio',
      ),
      DriverDocument(
        id: 'doc_rg',
        name: 'RG / CIN — Identidade com Foto',
        type: 'RG',
        status: 'PENDING',
        updatedAt: 'Aguardando envio',
      ),
      DriverDocument(
        id: 'doc_cnh',
        name: 'CNH Digital com Observação EAR',
        type: 'CNH_EAR',
        status: 'PENDING',
        updatedAt: 'Aguardando envio',
      ),
      DriverDocument(
        id: 'doc_crlv',
        name: 'CRLV-e Digital (Licenciamento Anual)',
        type: 'CRLV',
        status: 'PENDING',
        updatedAt: 'Aguardando envio',
      ),
      DriverDocument(
        id: 'doc_bg',
        name: 'Certidão Antecedentes Criminais (PF / TJ Estadual)',
        type: 'BACKGROUND_CHECK',
        status: 'PENDING',
        updatedAt: 'Aguardando envio',
      ),
      DriverDocument(
        id: 'doc_res',
        name: 'Comprovante de Residência (últimos 90 dias)',
        type: 'RESIDENCE_PROOF',
        status: 'PENDING',
        updatedAt: 'Pendente envio',
      ),
      DriverDocument(
        id: 'doc_photo',
        name: 'Foto de Perfil Padrão (Fundo Neutro)',
        type: 'PROFILE_PHOTO',
        status: 'PENDING',
        updatedAt: 'Aguardando envio',
      ),
    ];

    _transactions = const [];

    _privateOffers = const [];

    _chatMessages = const [];

    _alerts = const [];
  }

  /// Grava arquivo real capturado no diretório persistente de documentos do aplicativo
  Future<String> persistCapturedMedia(Uint8List bytes, String prefix) async {
    final dir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${dir.path}/omni_media');
    if (!mediaDir.existsSync()) {
      await mediaDir.create(recursive: true);
    }
    final file = File(
      '${mediaDir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dJson = prefs.getString(_driverStorageKey);
      if (dJson != null) {
        var loaded = OmniDriver.fromJson(jsonDecode(dJson) as Map<String, dynamic>);
        // Recarrega bytes do avatar/oval salvos no disco se o arquivo existir
        if (loaded.avatarFilePath != null &&
            File(loaded.avatarFilePath!).existsSync()) {
          final bytes = await File(loaded.avatarFilePath!).readAsBytes();
          loaded = loaded.copyWith(avatarBytes: bytes);
        }
        if (loaded.capturedOvalFacePath != null &&
            File(loaded.capturedOvalFacePath!).existsSync()) {
          final bytes = await File(loaded.capturedOvalFacePath!).readAsBytes();
          loaded = loaded.copyWith(capturedOvalFaceBytes: bytes);
        }
        _driver = loaded;
      }

      final vJson = prefs.getString(_vehiclesStorageKey);
      if (vJson != null) {
        final list = jsonDecode(vJson) as List<dynamic>;
        if (list.isNotEmpty) {
          const legacyRenavamFix = {
            '01284950122': '01284950120',
            '01394811209': '01394811206',
            '01450298111': '01450298114',
          };
          _vehicles = list
              .whereType<Map<String, dynamic>>()
              .map(OmniVehicle.fromJson)
              .map((v) => (v.renavam != null && legacyRenavamFix.containsKey(v.renavam))
                  ? v.copyWith(renavam: legacyRenavamFix[v.renavam])
                  : v)
              .toList();
        }
      }

      final docJson = prefs.getString(_documentsStorageKey);
      if (docJson != null) {
        final list = jsonDecode(docJson) as List<dynamic>;
        if (list.isNotEmpty) {
          final loadedDocs = <DriverDocument>[];
          for (final item in list.whereType<Map<String, dynamic>>()) {
            var doc = DriverDocument.fromJson(item);
            if (doc.filePath != null &&
                !doc.filePath!.toLowerCase().endsWith('.pdf') &&
                File(doc.filePath!).existsSync()) {
              try {
                final b = await File(doc.filePath!).readAsBytes();
                doc = doc.copyWith(fileBytes: b);
              } catch (_) {}
            }
            if (doc.faceFilePath != null &&
                doc.faceFilePath!.isNotEmpty &&
                File(doc.faceFilePath!).existsSync()) {
              try {
                final fb = await File(doc.faceFilePath!).readAsBytes();
                doc = doc.copyWith(faceFileBytes: fb);
              } catch (_) {}
            }
            loadedDocs.add(doc);
          }
          _documents = loadedDocs;
        }
      }

      final status = onboardingStatus;
      if (!status.isDriverFullyApproved && _driver.isOnline) {
        _driver = _driver.copyWith(isOnline: false);
      }
      notifyListeners();
      unawaited(verifyAppOwnerWithBackend());
      unawaited(_hydrateStateFromBackendAndRtdb());
      unawaited(_initializePushNotifications());
      _startPrivateOffersAndPayoutsListeners();
    } catch (e) {
      debugPrint('[OMNI Provider] Erro ao ler cache local: $e');
    }
  }

  Future<void> _initializePushNotifications() async {
    if (notificationService == null || firebaseService == null) return;
    await notificationService!.initialize(
      backend: backend,
      firebaseService: firebaseService!,
      driverId: _driver.id,
      initialCity: resolvedDriverCity,
      driverEmail: _driver.email,
      onDeepLink: handleNotificationDeepLink,
      onForegroundBanner: addAlert,
    );
  }

  Future<void> _persistAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_driverStorageKey, jsonEncode(_driver.toJson()));
      await prefs.setString(
        _vehiclesStorageKey,
        jsonEncode(_vehicles.map((v) => v.toJson()).toList()),
      );
      await prefs.setString(
        _documentsStorageKey,
        jsonEncode(_documents.map((d) => d.toJson()).toList()),
      );
    } catch (_) {}
  }

  // Getters
  OmniDriver get driver => _driver;
  List<OmniVehicle> get vehicles => _vehicles;
  OmniVehicle get activeVehicle {
    if (_vehicles.isEmpty) {
      return OmniVehicle(
        id: '',
        type: VehicleType.car,
        category: VehicleCategory.omniX,
        brand: 'Nenhum veículo',
        model: 'cadastrado',
        year: DateTime.now().year,
        plate: '---',
        color: '-',
        seats: 4,
        status: 'PENDING',
        isActive: false,
      );
    }
    return _vehicles.firstWhere(
      (v) => v.isActive,
      orElse: () => _vehicles.first,
    );
  }
  List<DriverDocument> get documents => _documents;
  List<WalletTransaction> get transactions => _transactions;
  List<PrivateTripOffer> get privateOffers => _privateOffers;
  List<ChatMessage> get chatMessages => _chatMessages;
  List<SmartAlert> get alerts => _alerts;

  OmniTrip? get incomingTrip => _incomingTrip;
  OmniTrip? get activeTrip => _activeTrip;
  int get dispatchCountdown => _dispatchCountdown;
  List<OmniCoordinate> get routePolyline => _routePolyline;
  double get driverHeading => _driverHeading;
  OmniCoordinate get driverLocation => locationService.currentLocation;

  MainTab get activeTab => _activeTab;
  ProfileSubTab get profileSubTab => _profileSubTab;
  bool get mapDarkMode => _mapDarkMode;
  bool get muted => _muted;
  bool get isSosActive => _isSosActive;
  bool get biometricModalOpen => _biometricModalOpen;
  bool get stepperModalOpen => _stepperModalOpen;
  int? get stepperInitialStep => _stepperInitialStep;
  bool get safetyModalOpen => _safetyModalOpen;
  bool get chatOpen => _chatOpen;
  int get unreadChatCount => _unreadChatCount;
  String? get documentCaptureDocId => _documentCaptureDocId;
  bool get documentCaptureAutoCamera => _documentCaptureAutoCamera;
  int get recenterTick => _recenterTick;
  bool get isRunningFingerprintDocCheck => _isRunningFingerprintDocCheck;
  bool get ownerTestHiredMode =>
      _ownerTestHiredMode && isDriverFullyApproved && _driver.isOnline;
  bool get ownerTestBusy => _ownerTestBusy;
  bool get backendVerifiedOwner => _backendVerifiedOwner;
  String get ownerMatchedBy => _ownerMatchedBy;

  bool get isAuthorizedAppOwner {
    final driverMail = (_driver.email ?? '').trim().toLowerCase();
    return OmniBackendService.isAllowedOwnerEmail(driverMail) ||
        OmniBackendService.isAllowedOwnerEmail(backend.ownerEmail);
  }

  String get resolvedDriverCity {
    final addrCity = (_driver.address?.city ?? '').trim();
    if (addrCity.isNotEmpty) return addrCity;
    return (_driver.operationalCity ?? '').trim();
  }

  List<DriverCampaign> get allCampaigns =>
      notificationService?.campaigns ?? const [];

  List<DriverCampaign> get activeDriverCampaigns =>
      notificationService?.activeCampaignsForCity(resolvedDriverCity) ??
      const [];

  List<ScheduledPromoNotificationRule> get scheduledPromoRules =>
      notificationService?.scheduledPromoRules ?? const [];

  Future<void> refreshCampaigns() async {
    await notificationService?.refreshCampaigns();
  }

  Future<void> syncCityNotifications() async {
    if (notificationService == null) return;
    await notificationService!.syncDriverIdentityAndToken(
      driverId: _driver.id,
      city: resolvedDriverCity,
      email: _driver.email,
    );
  }

  void handleNotificationDeepLink(Map<String, dynamic> data) {
    final eventType =
        (data['event_type'] ?? data['action'] ?? '').toString().trim().toLowerCase();
    if (eventType == 'new_trip_dispatch' || eventType == 'open_trip') {
      _activeTab = MainTab.map;
    } else if (eventType == 'chat_message' || eventType == 'open_chat') {
      _activeTab = MainTab.map;
      if (_activeTrip != null) {
        _chatOpen = true;
      }
    } else if (eventType == 'private_offer_new' ||
        eventType == 'private_offer_bid' ||
        eventType == 'open_private_trips') {
      _activeTab = MainTab.privateTrips;
    } else if (eventType == 'payout_update' || eventType == 'open_wallet') {
      _activeTab = MainTab.wallet;
    } else {
      _activeTab = MainTab.clube;
    }

    final title = (data['titulo'] ?? data['title'] ?? '').toString().trim();
    final msg = (data['mensagem'] ?? data['body'] ?? '').toString().trim();
    if (title.isNotEmpty || msg.isNotEmpty) {
      addAlert(
        title.isNotEmpty ? title : 'OMNI Motorista PRO',
        msg.isNotEmpty ? msg : 'Notificação recebida em tempo real.',
        'info',
      );
    }
    notifyListeners();
    unawaited(refreshCampaigns());
  }

  DriverOnboardingStatus get onboardingStatus => evaluateDriverOnboarding(
        driver: _driver,
        documents: _documents,
        vehicles: _vehicles,
      );
  int get onboardingScore => onboardingStatus.onboardingScore;
  bool get isDriverFullyApproved => onboardingStatus.isDriverFullyApproved;

  void addAlert(String title, String message, String severity) {
    final id = 'al_${DateTime.now().millisecondsSinceEpoch}';
    _alerts = [
      SmartAlert(
        id: id,
        title: title,
        message: message,
        severity: severity,
        visible: true,
      ),
      ..._alerts.take(2),
    ];
    notifyListeners();
    Future.delayed(const Duration(seconds: 6), () {
      _alerts = _alerts.where((a) => a.id != id).toList();
      notifyListeners();
    });
  }

  void dismissAlert(String id) {
    _alerts = _alerts.where((a) => a.id != id).toList();
    notifyListeners();
  }

  void setActiveTab(MainTab tab) {
    _activeTab = tab;
    notifyListeners();
  }

  void setProfileSubTab(ProfileSubTab subTab) {
    _profileSubTab = subTab;
    notifyListeners();
  }

  void toggleMapDarkMode() {
    _mapDarkMode = !_mapDarkMode;
    notifyListeners();
  }

  void toggleMute() {
    _muted = !_muted;
    OmniSoundService.muted = _muted;
    notifyListeners();
  }

  void triggerRecenter() {
    _recenterTick++;
    notifyListeners();
  }

  void setBiometricModalOpen(bool open) {
    _biometricModalOpen = open;
    notifyListeners();
  }

  void openStepperModal({int? initialStep}) {
    _stepperInitialStep = initialStep;
    _stepperModalOpen = true;
    notifyListeners();
  }

  void closeStepperModal() {
    _stepperModalOpen = false;
    _stepperInitialStep = null;
    notifyListeners();
  }

  void setSafetyModalOpen(bool open) {
    _safetyModalOpen = open;
    notifyListeners();
  }

  void setChatOpen(bool open) {
    _chatOpen = open;
    if (open) {
      unawaited(markChatMessagesRead());
    }
    notifyListeners();
  }

  void openDocumentCapture(String? docId, {bool autoOpenCamera = true}) {
    _documentCaptureDocId = docId;
    _documentCaptureAutoCamera = autoOpenCamera;
    notifyListeners();
  }

  /// Direciona o motorista exatamente para a etapa pendente (envio de docs/selfie sempre liberado!)
  void navigateToOnboardingAction(OnboardingTargetAction action) {
    switch (action) {
      case OnboardingTargetAction.openBioModal:
        _biometricModalOpen = true;
        break;
      case OnboardingTargetAction.openDocCpf:
        _activeTab = MainTab.profile;
        _profileSubTab = ProfileSubTab.documents;
        final doc = _documents.cast<DriverDocument?>().firstWhere(
              (d) => d?.type == 'CPF',
              orElse: () => null,
            );
        if (doc != null) _documentCaptureDocId = doc.id;
        break;
      case OnboardingTargetAction.openDocRg:
        _activeTab = MainTab.profile;
        _profileSubTab = ProfileSubTab.documents;
        final doc = _documents.cast<DriverDocument?>().firstWhere(
              (d) => d?.type == 'RG',
              orElse: () => null,
            );
        if (doc != null) _documentCaptureDocId = doc.id;
        break;
      case OnboardingTargetAction.openDocCnh:
        _activeTab = MainTab.profile;
        _profileSubTab = ProfileSubTab.documents;
        final doc = _documents.cast<DriverDocument?>().firstWhere(
              (d) => d?.type == 'CNH_EAR' || d?.type == 'CNH',
              orElse: () => null,
            );
        if (doc != null) _documentCaptureDocId = doc.id;
        break;
      case OnboardingTargetAction.openDocCrlv:
        _activeTab = MainTab.profile;
        _profileSubTab = ProfileSubTab.documents;
        final doc = _documents.cast<DriverDocument?>().firstWhere(
              (d) => d?.type == 'CRLV',
              orElse: () => null,
            );
        if (doc != null) _documentCaptureDocId = doc.id;
        break;
      case OnboardingTargetAction.openDocResidence:
        _activeTab = MainTab.profile;
        _profileSubTab = ProfileSubTab.documents;
        final doc = _documents.cast<DriverDocument?>().firstWhere(
              (d) => d?.type == 'RESIDENCE_PROOF',
              orElse: () => null,
            );
        if (doc != null) _documentCaptureDocId = doc.id;
        break;
      case OnboardingTargetAction.openPersonalForm:
        _activeTab = MainTab.profile;
        _profileSubTab = ProfileSubTab.personal;
        break;
      case OnboardingTargetAction.openVehiclesForm:
        _activeTab = MainTab.profile;
        _profileSubTab = ProfileSubTab.vehicles;
        break;
      case OnboardingTargetAction.openComplianceTerms:
        _activeTab = MainTab.profile;
        _profileSubTab = ProfileSubTab.terms;
        break;
    }
    notifyListeners();
  }

  /// Portão de Segurança (Gatekeeper): bloqueia apenas operação real (Online, Corridas, Lances)
  bool requireFullOnboardingGate(String blockedFeatureLabel) {
    final beh = _driver.behavioralRisk;
    if (beh != null &&
        (beh.revalidationRequired || beh.accountStatus == 'REVALIDATION_PENDING')) {
      addAlert(
        'Revalidação Biométrica Pendente',
        beh.revalidationReason ??
            'Capture uma nova selfie ao vivo no molde oval para continuar operando.',
        'warning',
      );
      _biometricModalOpen = true;
      notifyListeners();
      return false;
    }

    final status = onboardingStatus;
    if (status.isDriverFullyApproved) return true;
    final nextLabel =
        status.nextRecommendedStep?.label ?? 'etapas de validação restantes';
    addAlert(
      'Operação Bloqueada ($onboardingScore% Aprovado)',
      'Você não pode $blockedFeatureLabel antes de atingir 100% de aptidão. Próxima pendência: $nextLabel.',
      'warning',
    );
    if (status.nextRecommendedStep != null) {
      navigateToOnboardingAction(status.nextRecommendedStep!.action);
    }
    return false;
  }

  Future<void> toggleOnlineStatus() async {
    if (!_driver.isOnline) {
      if (!requireFullOnboardingGate('ficar ONLINE para corridas')) {
        return;
      }
      await OmniSoundService.playSuccess();
    }

    final nextOnline = !_driver.isOnline;
    await backend.executar(
      targetMethod: 'driver_availability_toggle',
      arguments: {
        'driver_id': _driver.id,
        'is_online': nextOnline,
        'location': locationService.currentLocation.toJson(),
      },
    );

    _driver = _driver.copyWith(isOnline: nextOnline);
    if (nextOnline) {
      _startDispatchPolling();
      _startLocationTelemetryHeartbeat();
    } else {
      _stopDispatchPolling();
      if (_activeTrip == null) {
        _stopLocationTelemetryHeartbeat();
      }
      _ownerTestHiredMode = false;
    }
    await _persistAll();
    addAlert(
      nextOnline ? 'Você está ONLINE!' : 'Modo Offline',
      nextOnline
          ? 'Radar OMNI buscando corridas e entregas na sua região.'
          : 'Você saiu da fila de chamadas.',
      nextOnline ? 'success' : 'info',
    );
    notifyListeners();
  }

  /// Consulta em tempo real a fila de chamadas reais enviadas pelo App Passageiro no Firebase RTDB.
  Future<bool> refreshPassengerDispatchQueueNow() async {
    if (!requireFullOnboardingGate('receber chamadas de passageiros ou entregas')) {
      return false;
    }
    if (_incomingTrip != null || _activeTrip != null) return true;

    try {
      final rawQueue = await backend.readFromFirebaseRtdb(
        OmniRtdbPaths.driverDispatchQueue(_driver.id),
      );
      if (rawQueue is Map && rawQueue.isNotEmpty) {
        _handleDispatchQueueSnapshot(rawQueue);
        if (_incomingTrip != null) return true;
      }

      addAlert(
        'Radar Firebase RTDB Ativo',
        'Aguardando solicitações reais do App Passageiro em /dispatch_queue/${_driver.id}.',
        'info',
      );
      notifyListeners();
      return false;
    } catch (_) {
      addAlert(
        'Erro ao consultar RTDB',
        'Verifique sua conexão para receber chamadas reais do Passageiro.',
        'warning',
      );
      return false;
    }
  }

  Future<void> acceptIncomingTrip() async {
    if (!requireFullOnboardingGate('aceitar solicitações de corrida')) return;
    final trip = _incomingTrip;
    if (trip == null) return;

    _dispatchTimer?.cancel();
    final resp = await backend.executar(
      targetMethod: OmniBackendMethods.tripAccept,
      arguments: {
        'driver_id': _driver.id,
        'trip_id': trip.tripId,
        'trip': {
          'trip_id': trip.tripId,
          'estimated_fare': trip.fareTotal,
          'otp_code': trip.otpPin,
          'trip_type': trip.type,
          'passenger_name': trip.passenger.name,
        },
      },
    );

    if (resp['success'] != true) {
      _dismissedDispatchIds.add(trip.tripId);
      _incomingTrip = null;
      addAlert(
        'Chamada Indisponível',
        resp['error']?.toString() ?? 'Esta corrida foi assumida por outro motorista.',
        'warning',
      );
      notifyListeners();
      return;
    }

    _activeTrip = trip.copyWith(status: TripStatus.driverEnRoute);
    _incomingTrip = null;
    final currentPos = locationService.currentLocation;
    _routePolyline = OmniLocationService.generateRoutePolyline(
      currentPos,
      trip.origin.coords,
    );
    unawaited(
      OmniLocationService.fetchFreeOsrmRoutePolyline(
        currentPos,
        trip.origin.coords,
      ).then((pts) {
        if (_activeTrip?.tripId == trip.tripId && pts.isNotEmpty) {
          _routePolyline = pts;
          notifyListeners();
        }
      }),
    );
    _knownChatMessageIds.clear();
    _chatMessages = [];
    _unreadChatCount = 0;

    await OmniSoundService.playSuccess();
    _startTripRealtimeListeners(trip.tripId);
    _startLocationTelemetryHeartbeat();
    unawaited(_loadChatHistoryFromBackend(trip.tripId));
    notifyListeners();
  }

  void declineIncomingTrip() {
    _dispatchTimer?.cancel();
    final trip = _incomingTrip;
    _incomingTrip = null;
    if (trip != null) {
      _dismissedDispatchIds.add(trip.tripId);
      unawaited(backend.executar(
        targetMethod: OmniBackendMethods.tripDecline,
        arguments: {
          'trip_id': trip.tripId,
          'driver_id': _driver.id,
          'reason': 'DECLINED_BY_DRIVER',
        },
      ));
    }
    notifyListeners();
  }

  void arriveAtPickup() {
    final trip = _activeTrip;
    if (trip == null) return;
    _activeTrip = trip.copyWith(status: TripStatus.driverArrived);
    final currentPos = locationService.currentLocation;
    _routePolyline = OmniLocationService.generateRoutePolyline(
      currentPos,
      trip.destination.coords,
    );
    unawaited(
      OmniLocationService.fetchFreeOsrmRoutePolyline(
        currentPos,
        trip.destination.coords,
      ).then((pts) {
        if (_activeTrip?.tripId == trip.tripId && pts.isNotEmpty) {
          _routePolyline = pts;
          notifyListeners();
        }
      }),
    );
    OmniSoundService.playAlert();
    addAlert(
      'Você chegou ao embarque!',
      'Solicite o código PIN de 4 dígitos ao passageiro para iniciar a viagem.',
      'info',
    );
    unawaited(backend.executar(
      targetMethod: OmniBackendMethods.tripArrived,
      arguments: {
        'trip_id': trip.tripId,
        'driver_id': _driver.id,
      },
    ));
    notifyListeners();
  }

  Future<bool> verifyOtpAndBoard(String pin) async {
    final trip = _activeTrip;
    if (trip == null) return false;
    final resp = await backend.executar(
      targetMethod: OmniBackendMethods.tripValidateOtp,
      arguments: {
        'trip_id': trip.tripId,
        'input_otp': pin,
        'expected_otp': trip.otpPin,
      },
    );
    if (resp['success'] == true) {
      _activeTrip = trip.copyWith(status: TripStatus.boardingConfirmed);
      await OmniSoundService.playSuccess();
      notifyListeners();
      return true;
    } else {
      addAlert(
          'PIN Incorreto', resp['error']?.toString() ?? 'Tente novamente.', 'danger');
      return false;
    }
  }

  void startTripToDestination() {
    final trip = _activeTrip;
    if (trip == null) return;
    _activeTrip = trip.copyWith(status: TripStatus.tripInProgress);
    final currentPos = locationService.currentLocation;
    _routePolyline = OmniLocationService.generateRoutePolyline(
      currentPos,
      trip.destination.coords,
    );
    unawaited(
      OmniLocationService.fetchFreeOsrmRoutePolyline(
        currentPos,
        trip.destination.coords,
      ).then((pts) {
        if (_activeTrip?.tripId == trip.tripId && pts.isNotEmpty) {
          _routePolyline = pts;
          notifyListeners();
        }
      }),
    );
    unawaited(backend.executar(
      targetMethod: OmniBackendMethods.tripStart,
      arguments: {
        'trip_id': trip.tripId,
        'driver_id': _driver.id,
      },
    ));
    notifyListeners();
  }

  Future<void> completeCurrentTrip(int passengerRating) async {
    final trip = _activeTrip;
    if (trip == null) return;

    await backend.executar(
      targetMethod: OmniBackendMethods.tripFinish,
      arguments: {
        'trip_id': trip.tripId,
        'driver_id': _driver.id,
        'final_fare': trip.fareTotal,
        'passenger_rating': passengerRating,
      },
    );

    _stopTripRealtimeListeners();
    if (!_driver.isOnline) {
      _stopLocationTelemetryHeartbeat();
    }

    _activeTrip = trip.copyWith(status: TripStatus.completed);
    final earned = trip.driverNetEarnings;

    _driver = _driver.copyWith(
      walletBalance: _driver.walletBalance + earned,
      todayEarnings: _driver.todayEarnings + earned,
      todayTripsCount: _driver.todayTripsCount + 1,
      totalTrips: _driver.totalTrips + 1,
    );

    _transactions = [
      WalletTransaction(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        title:
            '${trip.type == 'DELIVERY' ? 'Entrega' : 'Corrida'} #${trip.tripId} • ${trip.destination.shortName}',
        type: 'TRIP_EARNING',
        amount: earned,
        timestamp: 'Agora',
        status: 'COMPLETED',
      ),
      ..._transactions,
    ];
    await _persistAll();
    await OmniSoundService.playSuccess();
    notifyListeners();

    Future.delayed(const Duration(seconds: 2), () {
      if (_activeTrip?.status == TripStatus.completed) {
        _activeTrip = null;
        _routePolyline = [];
        notifyListeners();
      }
    });
  }

  Future<void> cancelActiveTrip(String reason) async {
    final trip = _activeTrip;
    if (trip == null) return;

    await backend.executar(
      targetMethod: OmniBackendMethods.tripCancel,
      arguments: {
        'trip_id': trip.tripId,
        'driver_id': _driver.id,
        'reason': reason,
      },
    );

    _stopTripRealtimeListeners();
    if (!_driver.isOnline) {
      _stopLocationTelemetryHeartbeat();
    }

    final nextRate = double.parse(
      (_driver.cancellationRate + 3.0).clamp(0.0, 100.0).toStringAsFixed(1),
    );
    _driver = _driver.copyWith(cancellationRate: nextRate);
    _activeTrip = null;
    _routePolyline = [];
    _chatMessages = [];
    _unreadChatCount = 0;

    if (nextRate > 12.0) {
      await triggerBehavioralEvent(
        'EXCESSIVE_CANCELLATION',
        customDescription:
            'Cancelamento de corrida ativa ($reason). Taxa atual: $nextRate%.',
      );
    } else {
      await _persistAll();
      addAlert('Corrida Cancelada', 'Motivo registrado: $reason', 'warning');
      notifyListeners();
    }
  }

  void finishRatingAndCloseTrip() {
    _stopTripRealtimeListeners();
    _activeTrip = null;
    _routePolyline = [];
    _chatMessages = [];
    _unreadChatCount = 0;
    notifyListeners();
  }

  Future<bool> requestPixWithdrawal({
    required double amount,
    required String pixKey,
    required String keyType,
  }) async {
    if (amount <= 0 || amount > _driver.walletBalance) {
      addAlert(
          'Saldo Insuficiente',
          'Informe um valor até R\$ ${_driver.walletBalance.toStringAsFixed(2)}.',
          'danger');
      return false;
    }
    final resp = await backend.executar(
      targetMethod: OmniBackendMethods.walletRequestPixPayout,
      arguments: {
        'driver_id': _driver.id,
        'amount': amount,
        'pix_key': pixKey,
        'pix_key_type': keyType,
      },
    );
    if (resp['success'] == true) {
      final data = resp['data'] as Map<String, dynamic>?;
      final txId = data?['transaction_id']?.toString() ??
          'tx_pix_${DateTime.now().millisecondsSinceEpoch}';
      _driver = _driver.copyWith(walletBalance: _driver.walletBalance - amount);
      _transactions = [
        WalletTransaction(
          id: txId,
          title: 'Saque Pix Imediato ($keyType)',
          type: 'PIX_WITHDRAWAL',
          amount: -amount,
          timestamp: 'Agora',
          status: 'COMPLETED',
        ),
        ..._transactions,
      ];
      await _persistAll();
      await OmniSoundService.playSuccess();
      addAlert('Saque Pix Enviado!',
          'R\$ ${amount.toStringAsFixed(2)} liquidado via Pix.', 'success');
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> submitPrivateBid(String offerId, double bidAmount) async {
    if (!requireFullOnboardingGate('enviar propostas de viagens particulares')) return;
    _privateOffers = _privateOffers
        .map((o) =>
            o.id == offerId ? o.copyWith(status: 'BID_SENT', driverBid: bidAmount) : o)
        .toList();
    notifyListeners();

    final resp = await backend.executar(
      targetMethod: OmniBackendMethods.privateTripsSubmitBid,
      arguments: {
        'offer_id': offerId,
        'driver_id': _driver.id,
        'bid_amount': bidAmount,
        'message': 'Motorista qualificado OMNI disponível com veículo aprovado.',
      },
    );

    if (resp['success'] == true) {
      await OmniSoundService.playSuccess();
      addAlert(
        'Proposta Enviada!',
        'Seu lance de R\$ ${bidAmount.toStringAsFixed(2)} foi registrado no SQL e RTDB.',
        'success',
      );
    } else {
      addAlert(
        'Falha ao Enviar Lance',
        resp['error']?.toString() ?? 'Tente novamente em instantes.',
        'warning',
      );
    }
    notifyListeners();
  }

  Future<void> toggleActiveVehicle(String vehicleId) async {
    final currentActive = activeVehicle;
    if (currentActive.id != vehicleId) {
      _recentVehicleSwitches++;
    }
    _vehicles = _vehicles
        .map((v) => v.copyWith(isActive: v.id == vehicleId))
        .toList();
    if (_recentVehicleSwitches >= 3) {
      await triggerBehavioralEvent(
        'FREQUENT_VEHICLE_SWITCH',
        customDescription:
            'Trocas frequentes de veículo ativo detectadas ($_recentVehicleSwitches alternâncias recentes).',
      );
      return;
    }
    await _persistAll();
    final activeVeh = activeVehicle;
    unawaited(backend.executar(
      targetMethod: OmniBackendMethods.vehicleUpsert,
      arguments: {
        'driver_id': _driver.id,
        'vehicle': activeVeh.toJson(),
      },
    ));
    notifyListeners();
  }

  Future<void> addVehicle(OmniVehicle vehicle) async {
    var created = vehicle;
    if ((created.photoUrl ?? '').isEmpty) {
      final fetched = await lookupRealVehiclePhotoOnline(
        created.brand,
        created.model,
        created.type,
      );
      if (fetched != null) {
        created = created.copyWith(photoUrl: fetched);
      }
    }
    final has5Photos =
        BehavioralAntifraudEngine.countVehiclePhotos(created.visualPhotos) >= 5;
    created = created.copyWith(
      inspection360Completed:
          (created.inspection360Completed == true) || has5Photos,
    );
    final crlvDoc = _documents.cast<DriverDocument?>().firstWhere(
          (d) => d?.type == 'CRLV',
          orElse: () => null,
        );
    created = created.copyWith(
      vehicleScreening:
          BehavioralAntifraudEngine.evaluateVehiclePackage(created, crlvDoc),
    );
    if (created.isActive) {
      _vehicles = _vehicles.map((v) => v.copyWith(isActive: false)).toList();
    }
    _vehicles = [created, ..._vehicles];
    await _persistAll();
    unawaited(backend.executar(
      targetMethod: OmniBackendMethods.vehicleUpsert,
      arguments: {
        'driver_id': _driver.id,
        'vehicle': created.toJson(),
      },
    ));
    addAlert('Veículo Adicionado',
        '${created.brand} ${created.model} cadastrado com sucesso.', 'success');
    notifyListeners();
  }

  Future<void> updateVehicle(OmniVehicle updated) async {
    final existing = _vehicles.cast<OmniVehicle?>().firstWhere(
          (v) => v?.id == updated.id,
          orElse: () => null,
        );
    final mergedPhotos = updated.visualPhotos ?? existing?.visualPhotos;
    final has5Photos =
        BehavioralAntifraudEngine.countVehiclePhotos(mergedPhotos) >= 5;
    var next = updated.copyWith(
      ownershipType:
          updated.ownershipType ?? existing?.ownershipType ?? 'PROPRIO',
      ownerName: updated.ownerName ?? existing?.ownerName,
      ownerDocument: updated.ownerDocument ?? existing?.ownerDocument,
      authorizationDocPath:
          updated.authorizationDocPath ?? existing?.authorizationDocPath,
      authorizationDocName:
          updated.authorizationDocName ?? existing?.authorizationDocName,
      authorizationDocBytes:
          updated.authorizationDocBytes ?? existing?.authorizationDocBytes,
      visualPhotos: mergedPhotos,
      inspection360Completed:
          (updated.inspection360Completed == true) || has5Photos,
    );
    if ((next.photoUrl ?? '').isEmpty) {
      final fetched = await lookupRealVehiclePhotoOnline(
        next.brand,
        next.model,
        next.type,
      );
      if (fetched != null) {
        next = next.copyWith(photoUrl: fetched);
      }
    }
    final crlvDoc = _documents.cast<DriverDocument?>().firstWhere(
          (d) => d?.type == 'CRLV',
          orElse: () => null,
        );
    next = next.copyWith(
      vehicleScreening:
          BehavioralAntifraudEngine.evaluateVehiclePackage(next, crlvDoc),
    );
    _vehicles = _vehicles.map((v) {
      if (v.id == next.id) return next;
      if (next.isActive) return v.copyWith(isActive: false);
      return v;
    }).toList();
    await _persistAll();
    unawaited(backend.executar(
      targetMethod: OmniBackendMethods.vehicleUpsert,
      arguments: {
        'driver_id': _driver.id,
        'vehicle': next.toJson(),
      },
    ));
    addAlert('Veículo Atualizado',
        '${next.brand} ${next.model} salvo com sucesso.', 'success');
    notifyListeners();
  }

  Future<void> deleteVehicle(String vehicleId) async {
    if (_vehicles.length <= 1) {
      addAlert('Ação Bloqueada',
          'É necessário manter ao menos 1 veículo cadastrado.', 'warning');
      return;
    }
    final remaining = _vehicles.where((v) => v.id != vehicleId).toList();
    if (!remaining.any((v) => v.isActive)) {
      remaining[0] = remaining[0].copyWith(isActive: true);
    }
    _vehicles = remaining;
    await _persistAll();
    notifyListeners();
  }

  Future<void> updateDriverProfile(
    OmniDriver updated, {
    bool silent = false,
  }) async {
    final sensitiveChanged = _driver.isBiometricVerified &&
        (updated.name.trim() != _driver.name.trim() ||
            updated.cpf.replaceAll(RegExp(r'\D'), '') !=
                _driver.cpf.replaceAll(RegExp(r'\D'), '') ||
            (updated.rg ?? '').trim() != (_driver.rg ?? '').trim() ||
            updated.phone.trim() != _driver.phone.trim());

    var resolved = updated;
    if (sensitiveChanged) {
      resolved = resolved.copyWith(
        behavioralRisk: BehavioralAntifraudEngine.recordEvent(
          _driver.behavioralRisk,
          'PROFILE_EDIT',
          rating: _driver.rating,
          cancellationRate: _driver.cancellationRate,
          onboardingApproved: isDriverFullyApproved,
        ),
        isOnline: false,
      );
    }
    final cleanEmail = (resolved.email ?? '').trim().toLowerCase();
    final emailOwnerMatched =
        OmniBackendService.isAllowedOwnerEmail(cleanEmail);
    if (emailOwnerMatched) {
      resolved = resolved.copyWith(
        isAppOwner: true,
        role: 'app_owner',
      );
      _backendVerifiedOwner = true;
      _ownerMatchedBy = 'email_only';
      unawaited(backend.setOwnerEmail(cleanEmail));
    } else if (cleanEmail.isNotEmpty) {
      resolved = resolved.copyWith(isAppOwner: false, role: 'driver');
      _backendVerifiedOwner = false;
      _ownerMatchedBy = 'none';
      if (OmniBackendService.isAllowedOwnerEmail(backend.ownerEmail)) {
        unawaited(backend.clearOwnerEmail());
      }
    }
    _driver = resolved;
    await _persistAll();
    if (!silent) {
      await OmniSoundService.playSuccess();
      addAlert(
        sensitiveChanged
            ? 'Perfil Atualizado • Revalidação Solicitada'
            : 'Perfil Atualizado',
        sensitiveChanged
            ? 'Dados salvos. Pela alteração cadastral sensível, capture uma nova selfie no oval antes de operar.'
            : 'Dados salvos e sincronizados com segurança.',
        sensitiveChanged ? 'warning' : 'success',
      );
    }
    notifyListeners();

    unawaited(backend.executar(
      targetMethod: 'driver_profile_update',
      arguments: {
        'driver_id': _driver.id,
        'name': _driver.name,
        'cpf': _driver.cpf,
        'rg': _driver.rg,
        'birth_date': _driver.birthDate,
        'email': _driver.email,
        'phone': _driver.phone,
        'cnh_number': _driver.cnhNumber,
        'cnh_category': _driver.cnhCategory,
        'cnh_expiry': _driver.cnhExpiry,
        'cnh_issue_state': _driver.cnhIssueState,
        'operational_city': _driver.operationalCity,
        'address': _driver.address?.toJson(),
        'bank_payout': _driver.bankPayout?.toJson(),
        'emergency_contact': _driver.emergencyContact?.toJson(),
        'work_preferences': _driver.workPreferences?.toJson(),
      },
    ));
    unawaited(syncCityNotifications());
    unawaited(verifyAppOwnerWithBackend());
  }

  Future<void> updateComplianceRites(ComplianceRites rites) async {
    final allSigned = rites.acceptedTerms &&
        rites.acceptedPrivacyLgpd &&
        rites.acceptedZeroTolerance &&
        rites.completedSafetyBriefing;
    final nextRites = rites.copyWith(
      signedAt: allSigned ? DateTime.now().toIso8601String() : rites.signedAt,
      termsVersion: 'OMNI-BR-2025.2',
      signatureHash: allSigned
          ? 'OMNI-TERM-${DateTime.now().millisecondsSinceEpoch % 100000}-SHA256'
          : rites.signatureHash,
    );
    _driver = _driver.copyWith(complianceRites: nextRites);
    await _persistAll();
    if (allSigned) {
      await OmniSoundService.playSuccess();
      unawaited(backend.executar(
        targetMethod: OmniBackendMethods.complianceSignRites,
        arguments: {
          'driver_id': _driver.id,
          'terms_version': nextRites.termsVersion,
          'signature_hash': nextRites.signatureHash,
          'signed_at': nextRites.signedAt,
        },
      ));
      addAlert('Conformidade 100% Assinada',
          'Termos, LGPD e Briefing de Segurança registrados.', 'success');
    }
    notifyListeners();
  }

  /// Salva a foto real do rosto capturada na moldura oval e executa match automático
  /// com qualquer RG/CNH já enviado (fluxo Oval-First — 1:1 com saveCapturedOvalFace)
  Future<void> saveCapturedOvalFace(
    Uint8List ovalBytes, {
    String? filePath,
  }) async {
    final savedPath = filePath ?? await persistCapturedMedia(ovalBytes, 'oval_selfie');
    final nowIso = DateTime.now().toIso8601String();

    bool hasUsableDocFace(DriverDocument d) {
      final hasFace = (d.faceFileBytes != null && d.faceFileBytes!.isNotEmpty) ||
          (d.faceFilePath != null && d.faceFilePath!.isNotEmpty);
      if (hasFace) return true;
      final isPdf = (d.fileName ?? d.filePath ?? '').toLowerCase().endsWith('.pdf');
      if (isPdf) return false;
      return (d.fileBytes != null && d.fileBytes!.isNotEmpty) ||
          (d.filePath != null && d.filePath!.isNotEmpty);
    }

    final rgDoc = _documents.cast<DriverDocument?>().firstWhere(
          (d) =>
              d != null &&
              d.type == 'RG' &&
              d.status == 'APPROVED' &&
              hasUsableDocFace(d),
          orElse: () => null,
        );
    final cnhDoc = _documents.cast<DriverDocument?>().firstWhere(
          (d) =>
              d != null &&
              d.type == 'CNH_EAR' &&
              d.status == 'APPROVED' &&
              hasUsableDocFace(d),
          orElse: () => null,
        );

    FaceMatchEntry nextRgMatch =
        const FaceMatchEntry(status: 'WAITING_DOC');
    FaceMatchEntry nextCnhMatch =
        const FaceMatchEntry(status: 'WAITING_DOC');

    if (rgDoc != null) {
      try {
        final cmp = await OmniVisionService.compareFaces(
          documentPath: rgDoc.faceFilePath ?? rgDoc.filePath,
          documentBytes: rgDoc.faceFileBytes ?? rgDoc.fileBytes,
          selfiePath: savedPath,
          selfieBytes: ovalBytes,
        );
        nextRgMatch = FaceMatchEntry(
          status: (cmp.approved && cmp.isSamePerson) ? 'MATCHED' : 'MISMATCH',
          score: cmp.confidenceScore,
          analysis: cmp.rejectionReason ?? cmp.facialFeaturesAnalysis,
          updatedAt: nowIso,
        );
      } catch (_) {
        nextRgMatch = const FaceMatchEntry(status: 'WAITING_DOC');
      }
    }

    if (cnhDoc != null) {
      try {
        final cmp = await OmniVisionService.compareFaces(
          documentPath: cnhDoc.faceFilePath ?? cnhDoc.filePath,
          documentBytes: cnhDoc.faceFileBytes ?? cnhDoc.fileBytes,
          selfiePath: savedPath,
          selfieBytes: ovalBytes,
        );
        nextCnhMatch = FaceMatchEntry(
          status: (cmp.approved && cmp.isSamePerson) ? 'MATCHED' : 'MISMATCH',
          score: cmp.confidenceScore,
          analysis: cmp.rejectionReason ?? cmp.facialFeaturesAnalysis,
          updatedAt: nowIso,
        );
      } catch (_) {
        nextCnhMatch = const FaceMatchEntry(status: 'WAITING_DOC');
      }
    }

    final anyMismatch = nextRgMatch.status == 'MISMATCH' ||
        nextCnhMatch.status == 'MISMATCH';

    final shouldClearReval = !anyMismatch &&
        (_driver.behavioralRisk?.revalidationRequired == true ||
            _driver.behavioralRisk?.accountStatus == 'REVALIDATION_PENDING');

    _driver = _driver.copyWith(
      avatarBytes: ovalBytes,
      avatarFilePath: savedPath,
      capturedOvalFaceBytes: ovalBytes,
      capturedOvalFacePath: savedPath,
      selfieVerifiedAt: nowIso,
      isBiometricVerified: !anyMismatch,
      faceMatchRg: nextRgMatch,
      faceMatchCnh: nextCnhMatch,
      behavioralRisk: shouldClearReval
          ? BehavioralAntifraudEngine.clearRevalidationAfterOvalSelfie(
              _driver.behavioralRisk,
              onboardingApproved: isDriverFullyApproved,
            )
          : _driver.behavioralRisk,
    );

    await _persistAll();
    if (anyMismatch) {
      addAlert(
        'Divergência Facial Detectada',
        'A selfie capturada no oval divergiu do retrato no seu RG ou CNH.',
        'danger',
      );
    } else {
      await OmniSoundService.playSuccess();
      addAlert(
        'Rosto Salvo no Oval!',
        'Seu retrato facial real já está ativo e pronto para cruzamento com RG e CNH.',
        'success',
      );
    }
    notifyListeners();
  }

  /// Finaliza a verificação biométrica comparando o rosto capturado no oval com RG/CNH
  /// e atualiza o avatar oficial do motorista com a foto real capturada
  Future<void> setBiometricVerified(
    bool status, {
    Uint8List? avatarBytes,
    String? avatarPath,
    Uint8List? documentBytes,
    String? documentPath,
    FaceComparisonAiResult? result,
    String? docType, // 'RG' | 'CNH_EAR'
  }) async {
    final nowIso = DateTime.now().toIso8601String();
    String? resolvedAvatarPath = avatarPath;
    if (avatarBytes != null && (resolvedAvatarPath == null || resolvedAvatarPath.isEmpty)) {
      resolvedAvatarPath = await persistCapturedMedia(avatarBytes, 'oval_selfie');
    }

    String? resolvedDocPath = documentPath;
    if (documentBytes != null && (resolvedDocPath == null || resolvedDocPath.isEmpty)) {
      resolvedDocPath = await persistCapturedMedia(documentBytes, 'bio_doc');
    }

    final matchEntry = result != null
        ? FaceMatchEntry(
            status: status ? 'MATCHED' : 'MISMATCH',
            score: result.confidenceScore,
            analysis: result.rejectionReason ?? result.facialFeaturesAnalysis,
            updatedAt: nowIso,
          )
        : null;

    var nextFaceRg = _driver.faceMatchRg ?? const FaceMatchEntry(status: 'PENDING');
    var nextFaceCnh = _driver.faceMatchCnh ?? const FaceMatchEntry(status: 'PENDING');

    if (matchEntry != null) {
      final isCnhDoc = docType == 'CNH_EAR' ||
          docType == 'CNH' ||
          (result?.documentTypeDetected.toUpperCase().contains('CNH') ?? false);
      if (isCnhDoc) {
        nextFaceCnh = matchEntry;
      } else {
        nextFaceRg = matchEntry;
      }
    }

    // Cruzamento automático com o outro documento caso já tenha sido enviado antes
    final selfieBytesForCross = avatarBytes ?? _driver.capturedOvalFaceBytes;
    final selfiePathForCross = resolvedAvatarPath ?? _driver.capturedOvalFacePath;

    if (status &&
        (selfieBytesForCross != null ||
            (selfiePathForCross != null && selfiePathForCross.isNotEmpty))) {
      bool docHasFaceImg(DriverDocument d) {
        if ((d.faceFileBytes != null && d.faceFileBytes!.isNotEmpty) ||
            (d.faceFilePath != null && d.faceFilePath!.isNotEmpty)) {
          return true;
        }
        final isPdf =
            (d.fileName ?? d.filePath ?? '').toLowerCase().endsWith('.pdf');
        if (isPdf) return false;
        return (d.fileBytes != null && d.fileBytes!.isNotEmpty) ||
            (d.filePath != null && d.filePath!.isNotEmpty);
      }

      if (nextFaceRg.status != 'MATCHED') {
        final rgDoc = _documents.cast<DriverDocument?>().firstWhere(
              (d) =>
                  d != null &&
                  d.type == 'RG' &&
                  d.status == 'APPROVED' &&
                  docHasFaceImg(d),
              orElse: () => null,
            );
        if (rgDoc != null) {
          try {
            final cmpRg = await OmniVisionService.compareFaces(
              documentPath: rgDoc.faceFilePath ?? rgDoc.filePath,
              documentBytes: rgDoc.faceFileBytes ?? rgDoc.fileBytes,
              selfiePath: selfiePathForCross,
              selfieBytes: selfieBytesForCross,
            );
            nextFaceRg = FaceMatchEntry(
              status: (cmpRg.approved && cmpRg.isSamePerson) ? 'MATCHED' : 'MISMATCH',
              score: cmpRg.confidenceScore,
              analysis: cmpRg.rejectionReason ?? cmpRg.facialFeaturesAnalysis,
              updatedAt: nowIso,
            );
          } catch (_) {}
        }
      }

      if (nextFaceCnh.status != 'MATCHED') {
        final cnhDoc = _documents.cast<DriverDocument?>().firstWhere(
              (d) =>
                  d != null &&
                  d.type == 'CNH_EAR' &&
                  d.status == 'APPROVED' &&
                  docHasFaceImg(d),
              orElse: () => null,
            );
        if (cnhDoc != null) {
          try {
            final cmpCnh = await OmniVisionService.compareFaces(
              documentPath: cnhDoc.faceFilePath ?? cnhDoc.filePath,
              documentBytes: cnhDoc.faceFileBytes ?? cnhDoc.fileBytes,
              selfiePath: selfiePathForCross,
              selfieBytes: selfieBytesForCross,
            );
            nextFaceCnh = FaceMatchEntry(
              status: (cmpCnh.approved && cmpCnh.isSamePerson) ? 'MATCHED' : 'MISMATCH',
              score: cmpCnh.confidenceScore,
              analysis: cmpCnh.rejectionReason ?? cmpCnh.facialFeaturesAnalysis,
              updatedAt: nowIso,
            );
          } catch (_) {}
        }
      }
    }

    final shouldClearReval = status &&
        (_driver.behavioralRisk?.revalidationRequired == true ||
            _driver.behavioralRisk?.accountStatus == 'REVALIDATION_PENDING');

    _driver = _driver.copyWith(
      isBiometricVerified: status,
      avatarBytes: (status && avatarBytes != null) ? avatarBytes : _driver.avatarBytes,
      avatarFilePath: (status && resolvedAvatarPath != null)
          ? resolvedAvatarPath
          : _driver.avatarFilePath,
      capturedOvalFaceBytes:
          avatarBytes ?? _driver.capturedOvalFaceBytes,
      capturedOvalFacePath:
          resolvedAvatarPath ?? _driver.capturedOvalFacePath,
      biometricDocumentBytes:
          documentBytes ?? _driver.biometricDocumentBytes,
      biometricDocumentPath:
          resolvedDocPath ?? _driver.biometricDocumentPath,
      selfieVerifiedAt: status ? nowIso : _driver.selfieVerifiedAt,
      biometricScore: result?.confidenceScore ?? _driver.biometricScore,
      biometricAnalysis:
          result?.facialFeaturesAnalysis ?? _driver.biometricAnalysis,
      faceMatchRg: nextFaceRg,
      faceMatchCnh: nextFaceCnh,
      behavioralRisk: shouldClearReval
          ? BehavioralAntifraudEngine.clearRevalidationAfterOvalSelfie(
              _driver.behavioralRisk,
              onboardingApproved: isDriverFullyApproved,
            )
          : _driver.behavioralRisk,
    );

    if (docType != null &&
        (resolvedDocPath != null || documentBytes != null) &&
        status) {
      final targetType = docType == 'CNH' ? 'CNH_EAR' : docType;
      _documents = _documents.map((d) {
        if (d.type == targetType && d.status != 'APPROVED') {
          return d.copyWith(
            status: 'APPROVED',
            updatedAt: 'Validado na biometria',
            filePath: resolvedDocPath ?? d.filePath,
            fileBytes: documentBytes ?? d.fileBytes,
          );
        }
        return d;
      }).toList();
    }

    await _persistAll();
    if (status) {
      await OmniSoundService.playSuccess();
      final scoreStr = result?.confidenceScore.toStringAsFixed(0) ?? '95';
      addAlert(
        'Biometria Facial Aprovada!',
        'Sua selfie real foi validada ($scoreStr% compatibilidade) e definida como avatar oficial.',
        'success',
      );
    }
    notifyListeners();
  }

  /// Avalia se os dados OCR extraídos (Nome, Nascimento, CPF, RG) batem com documentos anteriores já aprovados.
  DocumentAiAuditResult evaluateCrossDocumentDataMatch(
    String docType,
    DocumentAiAuditResult audit,
  ) {
    final ext = audit.extractedValidation;
    if (!audit.isAuthentic || ext == null) return audit;

    final baselines = _documents
        .where((d) {
          final b = d.aiAudit?.extractedValidation;
          return d.type != docType &&
              d.status == 'APPROVED' &&
              b != null &&
              ((b.fullName?.isNotEmpty == true) ||
                  (b.birthDateIso?.isNotEmpty == true) ||
                  (b.cpfDigits?.isNotEmpty == true) ||
                  (b.rgNumber?.isNotEmpty == true));
        })
        .map((d) {
          final b = d.aiAudit!.extractedValidation!;
          return DocumentIdentityBaseline(
            docType: d.type,
            docTitle: d.name,
            fullName: b.fullName,
            birthDateIso: b.birthDateIso,
            birthDateBr: b.birthDateBr,
            cpfDigits: b.cpfDigits?.replaceAll(RegExp(r'\D'), ''),
            rgNumber: b.rgNumber,
          );
        })
        .toList();

    final current = ExtractedOcrIdentity(
      fullName: ext.fullName,
      birthDateIso: ext.birthDateIso,
      birthDateBr: ext.birthDateBr,
      cpfDigits: ext.cpfDigits?.replaceAll(RegExp(r'\D'), ''),
      cpfFormatted: ext.cpfDigits,
      cpfMasked: ext.cpfMasked,
      rgRaw: ext.rgNumber,
      rgMasked: ext.rgMasked,
      rgIssuer: ext.rgIssuer,
      cnhRegistryDigits: ext.cnhRegistryDigits,
      cnhRegistryMasked: ext.cnhRegistryMasked,
      cnhCategory: ext.cnhCategory,
      cnhHasEar: ext.cnhHasEar,
      cnhExpiryIso: ext.cnhExpiryIso,
    );

    final matchRes = compareIdentityAgainstBaseline(current, baselines);
    final isMismatch = matchRes.status == 'MISMATCH';

    return DocumentAiAuditResult(
      isAuthentic: isMismatch ? false : audit.isAuthentic,
      matchesExpectedType: audit.matchesExpectedType,
      documentTypeDetected: audit.documentTypeDetected,
      integrityScore: audit.integrityScore,
      fraudRisk: isMismatch ? 'HIGH' : audit.fraudRisk,
      hasHolderPhoto: audit.hasHolderPhoto,
      detectedDetails: audit.detectedDetails,
      ocrTextExcerpt: audit.ocrTextExcerpt,
      rejectionReason: isMismatch ? matchRes.summary : audit.rejectionReason,
      resolutionTier: audit.resolutionTier,
      engineUsed: audit.engineUsed,
      extractedValidation: ext.copyWith(
        dataMatchStatus: matchRes.status,
        dataMatchSummary: matchRes.summary,
        matchedFields: matchRes.matchedFields,
      ),
    );
  }

  /// Upload & Auditoria de Documento Físico/Digital com Match Bidirecional + Auto-preenchimento do Cadastro
  Future<DocumentUploadCrossResult> uploadDriverDocument(
    String docId, {
    required DocumentAiAuditResult audit,
    Uint8List? fileBytes,
    String? filePath,
    String? fileName,
    Uint8List? faceBytes,
    String? facePath,
  }) async {
    final targetDoc = _documents.cast<DriverDocument?>().firstWhere(
          (d) => d?.id == docId || d?.type == docId,
          orElse: () => null,
        );
    final resolvedDocId = targetDoc?.id ?? docId;
    final docType = targetDoc?.type ?? docId;

    final enrichedAudit = evaluateCrossDocumentDataMatch(docType, audit);

    String? savedPath = filePath;
    if (fileBytes != null &&
        (savedPath == null || savedPath.isEmpty) &&
        !(fileName?.toLowerCase().endsWith('.pdf') ?? false)) {
      savedPath = await persistCapturedMedia(fileBytes, 'doc_$docType');
    }

    String? savedFacePath = facePath;
    if (faceBytes != null && (savedFacePath == null || savedFacePath.isEmpty)) {
      savedFacePath =
          await persistCapturedMedia(faceBytes, 'doc_${docType}_face');
    }

    final nowLabel = 'Hoje, ${TimeOfDayString.now()}';
    _documents = _documents.map((d) {
      if (d.id == resolvedDocId) {
        return d.copyWith(
          status: enrichedAudit.isAuthentic ? 'APPROVED' : 'REJECTED',
          updatedAt: nowLabel,
          fileName: fileName ?? d.fileName,
          filePath: savedPath ?? d.filePath,
          fileBytes: fileBytes ?? d.fileBytes,
          faceFilePath: savedFacePath ?? d.faceFilePath,
          faceFileBytes: faceBytes ?? d.faceFileBytes,
          aiAudit: enrichedAudit,
        );
      }
      return d;
    }).toList();

    // Auto-preenchimento automático estritamente validado do Cadastro Completo do Motorista com dados do OCR
    final ext = enrichedAudit.extractedValidation;
    if (enrichedAudit.isAuthentic && ext != null) {
      final cleanCpf = ext.cpfDigits?.replaceAll(RegExp(r'\D'), '') ?? '';
      final validCpf = cleanCpf.length == 11 && isValidBrazilianCpf(cleanCpf);
      final validName = isValidAutoFillName(ext.fullName);
      final validBirth = ext.birthDateIso != null &&
          RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(ext.birthDateIso!) &&
          (int.tryParse(ext.birthDateIso!.substring(0, 4)) ?? 0) >= 1920 &&
          DateTime.now().year -
                  (int.tryParse(ext.birthDateIso!.substring(0, 4)) ??
                      DateTime.now().year) >=
              18;
      final cleanRg = (ext.rgNumber ?? '')
          .replaceAll(RegExp(r'[^0-9X]', caseSensitive: false), '');
      final validRg = cleanRg.length >= 7 && cleanRg.length <= 11;
      final cleanCnh =
          (ext.cnhRegistryDigits ?? '').replaceAll(RegExp(r'\D'), '');
      final validCnh =
          cleanCnh.length == 11 && isValidBrazilianCnhNumber(cleanCnh);
      final validExpiry = ext.cnhExpiryIso != null &&
          RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(ext.cnhExpiryIso!) &&
          (int.tryParse(ext.cnhExpiryIso!.substring(0, 4)) ?? 0) >= 2015;

      _driver = _driver.copyWith(
        name: validName ? ext.fullName : _driver.name,
        birthDate: validBirth ? ext.birthDateIso : _driver.birthDate,
        cpf: validCpf ? formatCpfInput(cleanCpf) : _driver.cpf,
        rg: validRg ? ext.rgNumber : _driver.rg,
        rgIssuer: (ext.rgIssuer != null && ext.rgIssuer!.length >= 3)
            ? ext.rgIssuer
            : _driver.rgIssuer,
        cnhNumber: validCnh ? cleanCnh : _driver.cnhNumber,
        cnhCategory: ext.cnhCategory ?? _driver.cnhCategory,
        cnhExpiry: validExpiry ? ext.cnhExpiryIso : _driver.cnhExpiry,
        cnhEar: ext.cnhHasEar ?? _driver.cnhEar,
      );
    }

    // Se enviou Foto de Perfil aprovada pela IA, atualiza avatar imediatamente
    if (enrichedAudit.isAuthentic && docType == 'PROFILE_PHOTO') {
      _driver = _driver.copyWith(
        avatarBytes: fileBytes ?? _driver.avatarBytes,
        avatarFilePath: savedPath ?? _driver.avatarFilePath,
      );
    }

    // Match Facial Bidirecional se for RG ou CNH_EAR (prioriza Parte A 3x4)
    String? faceMatchStatus;
    String? faceMatchMessage;

    if (enrichedAudit.isAuthentic &&
        (docType == 'RG' || docType == 'CNH_EAR')) {
      final hasOval = (_driver.capturedOvalFaceBytes != null &&
              _driver.capturedOvalFaceBytes!.isNotEmpty) ||
          (_driver.capturedOvalFacePath != null &&
              _driver.capturedOvalFacePath!.isNotEmpty);
      final isPdf = (fileName ?? savedPath ?? '').toLowerCase().endsWith('.pdf');
      final docFacePath = savedFacePath ?? (isPdf ? null : savedPath);
      final docFaceBytes = faceBytes ?? (isPdf ? null : fileBytes);
      final hasFaceSource =
          (docFaceBytes != null && docFaceBytes.isNotEmpty) ||
              (docFacePath != null && docFacePath.isNotEmpty);

      if (!hasOval || !hasFaceSource) {
        const waitingEntry = FaceMatchEntry(status: 'WAITING_FACE');
        _driver = _driver.copyWith(
          faceMatchRg: docType == 'RG' ? waitingEntry : _driver.faceMatchRg,
          faceMatchCnh:
              docType == 'CNH_EAR' ? waitingEntry : _driver.faceMatchCnh,
        );
        faceMatchStatus = 'WAITING_FACE';
        faceMatchMessage = !hasFaceSource
            ? 'Documento PDF validado! Envie a Parte A (foto 3x4) ou faça o Match no Oval.'
            : 'Documento validado! Agora capture seu rosto no oval para confirmar o Match Facial.';
      } else {
        try {
          final cmp = await OmniVisionService.compareFaces(
            documentPath: docFacePath,
            documentBytes: docFaceBytes,
            selfiePath: _driver.capturedOvalFacePath,
            selfieBytes: _driver.capturedOvalFaceBytes,
          );
          final matched = cmp.approved && cmp.isSamePerson;
          final entry = FaceMatchEntry(
            status: matched ? 'MATCHED' : 'MISMATCH',
            score: cmp.confidenceScore,
            analysis: cmp.rejectionReason ?? cmp.facialFeaturesAnalysis,
            updatedAt: DateTime.now().toIso8601String(),
          );
          _driver = _driver.copyWith(
            faceMatchRg: docType == 'RG' ? entry : _driver.faceMatchRg,
            faceMatchCnh: docType == 'CNH_EAR' ? entry : _driver.faceMatchCnh,
            isBiometricVerified: matched ? true : _driver.isBiometricVerified,
          );
          faceMatchStatus = entry.status;
          faceMatchMessage = matched
              ? 'Match Facial confirmado com a foto do oval (${cmp.confidenceScore.toStringAsFixed(0)}%)!'
              : (cmp.rejectionReason ??
                  'O rosto neste documento divergiu da selfie capturada no oval.');
        } catch (_) {
          faceMatchStatus = 'WAITING_FACE';
          faceMatchMessage =
              'Documento aprovado! Revalide o oval se necessário.';
        }
      }
    }

    await _persistAll();
    if (enrichedAudit.isAuthentic && faceMatchStatus != 'MISMATCH') {
      await OmniSoundService.playSuccess();
    }
    notifyListeners();

    if (docType == 'BACKGROUND_CHECK') {
      final bgDoc = _documents.cast<DriverDocument?>().firstWhere(
            (d) => d?.type == 'BACKGROUND_CHECK',
            orElse: () => null,
          );
      final nextScreening = BehavioralAntifraudEngine.evaluateCriminalCertificate(
        _driver.criminalCertificate,
        bgDoc,
        driverName: _driver.name,
      );
      _driver = _driver.copyWith(criminalScreening: nextScreening);
      await _persistAll();
      notifyListeners();
    } else if (docType == 'CRLV') {
      final crlvDoc = _documents.cast<DriverDocument?>().firstWhere(
            (d) => d?.type == 'CRLV',
            orElse: () => null,
          );
      _vehicles = _vehicles
          .map((v) => v.copyWith(
                vehicleScreening:
                    BehavioralAntifraudEngine.evaluateVehiclePackage(v, crlvDoc),
              ))
          .toList();
      await _persistAll();
      notifyListeners();
    } else if (enrichedAudit.isAuthentic &&
        (docType == 'RG' || docType == 'CNH_EAR') &&
        _driver.isFingerprintVerified) {
      unawaited(runFingerprintDocComparison(
        overrideDocType: docType,
        overrideOcrExcerpt: enrichedAudit.ocrTextExcerpt,
        overrideFilePath: savedPath ?? filePath,
        overrideBytes: fileBytes,
        overrideIsPdf:
            (fileName ?? savedPath ?? '').toLowerCase().endsWith('.pdf'),
      ));
    }

    unawaited(backend.executar(
      targetMethod: OmniBackendMethods.documentsUpload,
      arguments: {
        'driver_id': _driver.id,
        'doc_type': docType,
        'status': enrichedAudit.isAuthentic ? 'APPROVED' : 'REJECTED',
        'ocr_score': enrichedAudit.integrityScore,
        'fraud_risk': enrichedAudit.fraudRisk,
      },
    ));

    return DocumentUploadCrossResult(
      faceMatchStatus: faceMatchStatus,
      faceMatchMessage: faceMatchMessage,
      dataMatchStatus: ext?.dataMatchStatus,
      dataMatchMessage: ext?.dataMatchSummary,
    );
  }

  Future<void> sendChatMessage(String text) async {
    final trimmed = text.trim();
    final trip = _activeTrip;
    if (trimmed.isEmpty || trip == null) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final tempId = 'local_$nowMs';
    final optimistic = ChatMessage(
      id: tempId,
      sender: 'DRIVER',
      text: trimmed,
      timestamp: _formatTimeFromMs(nowMs),
      senderId: _driver.id,
      createdAtMs: nowMs,
      isRead: true,
    );
    _knownChatMessageIds.add(tempId);
    _chatMessages = [..._chatMessages, optimistic];
    await OmniSoundService.playChatBeep();
    notifyListeners();

    final resp = await backend.executar(
      targetMethod: OmniBackendMethods.tripChatSend,
      arguments: {
        'trip_id': trip.tripId,
        'driver_id': _driver.id,
        'sender_id': _driver.id,
        'sender_role': 'driver',
        'text': trimmed,
        'created_at': nowMs,
      },
    );

    final data = resp['data'];
    if (resp['success'] == true &&
        data is Map<String, dynamic> &&
        data['message_id'] != null) {
      final serverId = data['message_id'].toString();
      _knownChatMessageIds.add(serverId);
      _chatMessages = _chatMessages
          .map((m) => m.id == tempId ? m.copyWith(id: serverId) : m)
          .toList();
      notifyListeners();
    }
  }

  Future<void> markChatMessagesRead() async {
    final trip = _activeTrip;
    if (trip == null) {
      _unreadChatCount = 0;
      return;
    }

    final unreadPassengerMsgs = _chatMessages
        .where((m) => m.sender == 'PASSENGER' && !m.isRead)
        .toList();
    if (unreadPassengerMsgs.isNotEmpty) {
      _chatMessages = _chatMessages
          .map((m) => m.sender == 'PASSENGER' ? m.copyWith(isRead: true) : m)
          .toList();
      _unreadChatCount = 0;
      notifyListeners();

      for (final msg in unreadPassengerMsgs) {
        if (!msg.id.startsWith('local_')) {
          unawaited(backend.patchFirebaseRtdb(
            '${OmniRtdbPaths.tripChat(trip.tripId)}/${msg.id}',
            {OmniRtdbFields.isRead: true},
          ));
        }
      }
      unawaited(backend.executar(
        targetMethod: OmniBackendMethods.tripChatHistory,
        arguments: {
          'trip_id': trip.tripId,
          'mark_read_for_role': 'driver',
        },
      ));
    } else if (_unreadChatCount != 0) {
      _unreadChatCount = 0;
      notifyListeners();
    }
  }

  Future<void> triggerEmergencySos({String? incidentNote}) async {
    _isSosActive = true;
    await OmniSoundService.playAlert();
    final loc = locationService.currentLocation;
    unawaited(backend.executar(
      targetMethod: OmniBackendMethods.tripSosTrigger,
      arguments: {
        'trip_id': _activeTrip?.tripId ?? '',
        'driver_id': _driver.id,
        'triggered_by': 'DRIVER',
        'incident_note': incidentNote ?? '',
        'active': true,
        'lat': loc.latitude,
        'lng': loc.longitude,
      },
    ));
    addAlert(
      'ALERTA SOS ATIVADO!',
      'Central de Segurança OMNI 24h recebeu sua telemetria GPS em tempo real.',
      'danger',
    );
    notifyListeners();
  }

  Future<void> resolveEmergencySos() async {
    _isSosActive = false;
    final loc = locationService.currentLocation;
    unawaited(backend.executar(
      targetMethod: OmniBackendMethods.tripSosTrigger,
      arguments: {
        'trip_id': _activeTrip?.tripId ?? '',
        'driver_id': _driver.id,
        'triggered_by': 'DRIVER',
        'active': false,
        'lat': loc.latitude,
        'lng': loc.longitude,
      },
    ));
    notifyListeners();
  }

  /// Executa o cruzamento biométrico da Impressão Digital do aparelho contra o polegar do RG/CNH
  Future<FingerprintDocComparison> runFingerprintDocComparison({
    String? method,
    String? hash,
    String? verifiedAt,
    String? overrideDocType,
    String? overrideOcrExcerpt,
    String? overrideFilePath,
    Uint8List? overrideBytes,
    bool overrideIsPdf = false,
  }) async {
    _isRunningFingerprintDocCheck = true;
    notifyListeners();
    try {
      DriverDocument? findApproved(String type) => _documents
          .cast<DriverDocument?>()
          .firstWhere(
            (d) => d?.type == type && d?.status == 'APPROVED',
            orElse: () => null,
          );

      final rgDoc = findApproved('RG');
      final cnhDoc = findApproved('CNH_EAR') ?? findApproved('CNH');
      final chosenType = overrideDocType ??
          (rgDoc != null ? 'RG' : (cnhDoc != null ? 'CNH_EAR' : null));
      final refDoc = chosenType == 'RG' ? rgDoc : cnhDoc;

      final resolvedPath = overrideFilePath ?? refDoc?.filePath;
      final resolvedBytes = overrideBytes ?? refDoc?.fileBytes;
      final resolvedIsPdf = overrideIsPdf ||
          ((resolvedPath ?? refDoc?.fileName ?? '')
              .toLowerCase()
              .endsWith('.pdf'));

      final result = await OmniVisionService.compareFingerprintWithDocument(
        driverName: _driver.name,
        cpf: _driver.cpf,
        rgNumber: _driver.rg,
        cnhNumber: _driver.cnhNumber,
        docType: chosenType,
        docOcrExcerpt: overrideOcrExcerpt ?? refDoc?.aiAudit?.ocrTextExcerpt,
        docFilePath: resolvedPath,
        docBytes: resolvedBytes,
        docIsPdf: resolvedIsPdf,
        fingerprintMethod: method ?? _driver.fingerprintMethod,
        fingerprintHash: hash ?? _driver.fingerprintHash,
        fingerprintVerifiedAt: verifiedAt ?? _driver.fingerprintVerifiedAt,
      );

      _driver = _driver.copyWith(fingerprintDocComparison: result);
      await _persistAll();

      if (result.status == 'MATCHED') {
        await OmniSoundService.playSuccess();
        addAlert(
          'Digital Vinculada ao ${result.docTypeUsed ?? 'RG/CNH'} (${result.score}%)',
          'Biometria do aparelho compatível e íntegra (${result.protocolCode}).',
          'success',
        );
      }

      await backend.executar(
        targetMethod: 'driver_biometrics_fingerprint_doc_cross',
        arguments: {
          'driver_id': _driver.id,
          'status': result.status,
          'doc_type': result.docTypeUsed,
          'score': result.score,
          'protocol': result.protocolCode,
        },
      );

      return result;
    } finally {
      _isRunningFingerprintDocCheck = false;
      notifyListeners();
    }
  }

  /// Registra a validação biométrica por Impressão Digital do dispositivo / Sensor OMNI
  Future<void> verifyFingerprintBiometrics({
    String method = 'DEVICE_BIOMETRIC_NATIVE',
    String? hash,
  }) async {
    final nowIso = DateTime.now().toIso8601String();
    final resolvedHash = hash ??
        'FP-OMNI-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}-SHA256';
    _driver = _driver.copyWith(
      isFingerprintVerified: true,
      fingerprintVerifiedAt: nowIso,
      fingerprintMethod: method,
      fingerprintHash: resolvedHash,
    );
    await _persistAll();
    await OmniSoundService.playSuccess();
    addAlert(
      'Impressão Digital Validada!',
      'Assinatura biométrica digital registrada ($resolvedHash).',
      'success',
    );
    notifyListeners();
    unawaited(backend.executar(
      targetMethod: OmniBackendMethods.biometricsFingerprint,
      arguments: {
        'driver_id': _driver.id,
        'method': method,
        'hash': resolvedHash,
        'verified_at': nowIso,
        'confidence': 98.5,
      },
    ));
    unawaited(runFingerprintDocComparison(
      method: method,
      hash: resolvedHash,
      verifiedAt: nowIso,
    ));
  }

  /// Registra e avalia os dados estruturados da Certidão de Antecedentes Criminais (sem consulta automática em API)
  Future<CriminalScreeningResult> submitCriminalCertificate(
    CriminalCertificateSubmission submission,
  ) async {
    final bgDoc = _documents.cast<DriverDocument?>().firstWhere(
          (d) => d?.type == 'BACKGROUND_CHECK',
          orElse: () => null,
        );
    final withTimestamp = submission.copyWith(
      submittedAt: DateTime.now().toIso8601String(),
    );
    final screening = BehavioralAntifraudEngine.evaluateCriminalCertificate(
      withTimestamp,
      bgDoc,
      driverName: _driver.name,
    );

    _driver = _driver.copyWith(
      criminalCertificate: withTimestamp,
      criminalScreening: screening,
    );
    await _persistAll();

    if (screening.status == 'APPROVED' || screening.status == 'IN_REVIEW') {
      await OmniSoundService.playSuccess();
      addAlert(
        'Certidão Registrada (${screening.score}%)',
        screening.summary,
        'success',
      );
    } else {
      OmniSoundService.playAlert();
      addAlert(
        'Triagem Documental Pendente',
        screening.rejectionReason ?? screening.summary,
        'warning',
      );
    }
    notifyListeners();

    unawaited(backend.executar(
      targetMethod: 'driver_compliance_background_check',
      arguments: {
        'driver_id': _driver.id,
        'status': screening.status,
        'risk_level': screening.riskLevel,
        'score': screening.score,
        'protocol': screening.protocolCode,
        'portal': withTimestamp.issuingPortal,
      },
    ));

    return screening;
  }

  /// Registra evento do Motor Antifraude Comportamental & Revalidação
  Future<BehavioralRiskState> triggerBehavioralEvent(
    String triggerType, {
    String? customDescription,
  }) async {
    final nextState = BehavioralAntifraudEngine.recordEvent(
      _driver.behavioralRisk,
      triggerType,
      rating: _driver.rating,
      cancellationRate: _driver.cancellationRate,
      onboardingApproved: isDriverFullyApproved,
      customDescription: customDescription,
    );
    _driver = _driver.copyWith(
      behavioralRisk: nextState,
      isOnline:
          (nextState.revalidationRequired || nextState.accountStatus == 'SUSPENDED')
              ? false
              : _driver.isOnline,
    );
    await _persistAll();
    if (nextState.revalidationRequired) {
      OmniSoundService.playAlert();
      addAlert(
        'Revalidação Facial Solicitada',
        nextState.revalidationReason ??
            'Capture uma nova selfie no molde oval para continuar operando.',
        'warning',
      );
    }
    notifyListeners();
    return nextState;
  }

  Future<void> clearBehavioralRevalidation() async {
    _driver = _driver.copyWith(
      behavioralRisk: BehavioralAntifraudEngine.clearRevalidationAfterOvalSelfie(
        _driver.behavioralRisk,
        onboardingApproved: onboardingScore == 100,
      ),
    );
    await _persistAll();
    await OmniSoundService.playSuccess();
    notifyListeners();
  }

  /// Libera todas as pendências exclusivamente quando o dono aciona o checkbox de motorista contratado para testes
  Future<void> unlockAllOnboardingForSimulation() async {
    final nowIso = DateTime.now().toIso8601String();
    final todayStr = nowIso.substring(0, 10);
    _documents = _documents
        .map((d) => d.copyWith(
              status: 'APPROVED',
              updatedAt: 'Liberado Teste Dono',
            ))
        .toList();

    final sourceVehicles = _vehicles.isNotEmpty
        ? _vehicles
        : [
            OmniVehicle(
              id: 'veh_owner_test',
              type: VehicleType.car,
              category: VehicleCategory.omniX,
              brand: 'Veículo Teste',
              model: 'OMNI Padrão',
              year: DateTime.now().year,
              plate: 'OMN1D23',
              color: 'Prata',
              seats: 4,
              renavam: '01348291041',
              crlvExpiry: todayStr,
              fuelType: 'FLEX',
              transmission: 'AUTOMATIC',
              doors: 4,
              hasAirConditioning: true,
              insuranceCompany: 'OMNI Teste',
              insurancePolicy: 'OWNER-TEST-APP',
              insuranceAppActive: true,
              inspection360Completed: true,
              status: 'APPROVED',
              isActive: true,
            ),
          ];

    _vehicles = sourceVehicles
        .map((v) => v.copyWith(
              status: 'APPROVED',
              insurancePolicy: v.insurancePolicy ?? 'OMNI-APP-2026',
              insuranceAppActive: true,
              inspection360Completed: true,
              inspection360Date: nowIso,
              ownershipType: v.ownershipType ?? 'PROPRIO',
              visualPhotos: const VehicleVisualPhotos(
                front: 'owner_test://vehicle_front',
                rear: 'owner_test://vehicle_rear',
                leftSide: 'owner_test://vehicle_left',
                rightSide: 'owner_test://vehicle_right',
                plate: 'owner_test://vehicle_plate',
              ),
              vehicleScreening: VehicleScreeningResult(
                status: 'APPROVED',
                score: 100,
                riskLevel: 'LOW',
                protocolCode: 'OMNI-OWNER-VEH',
                checkedAt: nowIso,
                crlvAttached: true,
                ownershipVerified: true,
                photosCount: 5,
                renavamValid: true,
                plateValid: true,
                chassiValid: true,
                summary:
                    'Veículo aprovado pelo modo de teste de comunicação do dono (${v.plate}).',
                findings: const [
                  'Liberação ativada exclusivamente pelo dono para testes Driver ↔ Passenger.',
                ],
              ),
            ))
        .toList();
    _driver = _driver.copyWith(
      isBiometricVerified: true,
      isFingerprintVerified: true,
      fingerprintVerifiedAt: nowIso,
      fingerprintMethod: 'OWNER_TEST_MODE',
      fingerprintHash: 'OMNI-OWNER-FP',
      fingerprintDocComparison: FingerprintDocComparison(
        status: 'MATCHED',
        score: 100,
        ridgeQuality: 'NITIDA',
        docTypeUsed: 'RG',
        protocolCode: 'OMNI-OWNER-FP',
        checkedAt: nowIso,
        summary: 'Validação biométrica liberada pelo dono para testes reais.',
        findings: const ['Modo de teste de comunicação do dono ativo.'],
        resolutionTier: 1,
        engineUsed: 'OMNI Owner Test',
      ),
      cnhEar: true,
      capturedOvalFacePath:
          _driver.capturedOvalFacePath ?? 'owner_test://oval_face_verified',
      selfieVerifiedAt: nowIso,
      faceMatchRg: const FaceMatchEntry(
        status: 'MATCHED',
        score: 100.0,
        analysis: 'Liberado pelo dono para testes de comunicação.',
      ),
      faceMatchCnh: const FaceMatchEntry(
        status: 'MATCHED',
        score: 100.0,
        analysis: 'Liberado pelo dono para testes de comunicação.',
      ),
      criminalCertificate: CriminalCertificateSubmission(
        issuingPortal: 'AMBOS',
        validationCode: 'OMNI-OWNER-TEST',
        issueDate: todayStr,
        ufJurisdiction: (_driver.address?.state ?? '').isNotEmpty
            ? _driver.address!.state
            : 'BR',
        selfDeclaredClean: true,
        submittedAt: nowIso,
      ),
      criminalScreening: CriminalScreeningResult(
        status: 'APPROVED',
        score: 100,
        riskLevel: 'LOW',
        protocolCode: 'OMNI-OWNER-TRG',
        checkedAt: nowIso,
        hasAttachment: true,
        hasValidCode: true,
        hasValidDate: true,
        hasDeclaration: true,
        summary: 'Triagem liberada pelo modo de teste do dono.',
        findings: const ['Liberado pelo dono para testes em tempo real.'],
      ),
      behavioralRisk: BehavioralAntifraudEngine.createDefaultState(
        initialStatus: 'APPROVED',
      ),
      complianceRites: const ComplianceRites(
        acceptedTerms: true,
        acceptedPrivacyLgpd: true,
        acceptedZeroTolerance: true,
        completedSafetyBriefing: true,
        termsVersion: 'OMNI-BR-2025.2',
        signatureHash: 'OMNI-OWNER-TEST',
      ),
    );
    await _persistAll();
    notifyListeners();
  }

  /// Reconhece o dono exclusivamente pelo e-mail autorizado
  Future<bool> authenticateOwnerByEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!OmniBackendService.isAllowedOwnerEmail(cleanEmail)) {
      _backendVerifiedOwner = false;
      _ownerMatchedBy = 'none';
      await backend.clearOwnerEmail();
      _driver = _driver.copyWith(role: 'driver', isAppOwner: false);
      await _persistAll();
      notifyListeners();
      return false;
    }
    await backend.setOwnerEmail(cleanEmail);
    _backendVerifiedOwner = true;
    _ownerMatchedBy = 'email_only';
    _driver = _driver.copyWith(
      email: cleanEmail,
      role: 'app_owner',
      isAppOwner: true,
    );
    await _persistAll();
    await verifyAppOwnerWithBackend(emailOverride: cleanEmail);
    notifyListeners();
    return true;
  }

  /// Consulta o backend PHP (`driver_verify_app_owner`) enviando o e-mail para confirmação do dono.
  Future<bool> verifyAppOwnerWithBackend({
    String? emailOverride,
  }) async {
    final effectiveEmail = (emailOverride ??
            ((_driver.email ?? '').trim().isNotEmpty
                ? _driver.email!
                : backend.ownerEmail))
        .trim()
        .toLowerCase();

    if (!OmniBackendService.isAllowedOwnerEmail(effectiveEmail)) {
      _backendVerifiedOwner = false;
      _ownerMatchedBy = 'none';
      _driver = _driver.copyWith(role: 'driver', isAppOwner: false);
      notifyListeners();
      return false;
    }

    try {
      final res = await backend.executar(
        targetMethod: OmniBackendMethods.verifyAppOwner,
        arguments: {
          'driver_id': _driver.id,
          'email': effectiveEmail,
          'owner_email': effectiveEmail,
        },
      );

      final data = res['data'];
      if (res['success'] == true && data is Map<String, dynamic>) {
        final confirmed = OmniBackendService.isAllowedOwnerEmail(effectiveEmail) &&
            (data['is_owner'] == true ||
                data['owner_test_allowed'] == true ||
                OmniBackendService.isAllowedOwnerEmail(
                  data['email']?.toString() ?? effectiveEmail,
                ));
        _backendVerifiedOwner = confirmed;
        _ownerMatchedBy = confirmed ? 'email_only' : 'none';

        _driver = _driver.copyWith(
          role: confirmed ? 'app_owner' : 'driver',
          isAppOwner: confirmed,
        );
        await _persistAll();
        notifyListeners();
        return confirmed;
      }
    } catch (_) {
      // Fallback offline mantendo reconhecimento estrito pelo e-mail autorizado
    }

    _backendVerifiedOwner = true;
    _ownerMatchedBy = 'email_only';
    _driver = _driver.copyWith(role: 'app_owner', isAppOwner: true);
    notifyListeners();
    return true;
  }

  /// Atualiza metadados da conta logada reconhecendo o dono apenas pelo e-mail autorizado
  Future<void> applyAuthenticatedUserOwnerContext({
    String? email,
    String? uid,
  }) async {
    final normalizedEmail = (email ?? '').trim().toLowerCase();
    final matchedOwner = OmniBackendService.isAllowedOwnerEmail(normalizedEmail);
    _driver = _driver.copyWith(
      email: email ?? _driver.email,
      authUid: uid ?? _driver.authUid,
      role: matchedOwner ? 'app_owner' : 'driver',
      isAppOwner: matchedOwner,
    );
    if (matchedOwner) {
      await backend.setOwnerEmail(normalizedEmail);
      _backendVerifiedOwner = true;
      _ownerMatchedBy = 'email_only';
    } else if (normalizedEmail.isNotEmpty) {
      await backend.clearOwnerEmail();
      _backendVerifiedOwner = false;
      _ownerMatchedBy = 'none';
    }
    await _persistAll();
    notifyListeners();
    unawaited(verifyAppOwnerWithBackend());
  }

  /// ---
  /// CALLBACK PRINCIPAL DO CHECKBOX DO DONO (TESTE CONTRATADO + APROVADO + ONLINE)
  /// Executa em segundo plano toda a liberação do motorista para testes reais
  /// de comunicação Motorista <-> Passageiro (onboardingScore = 100%, documentos,
  /// biometria, veículo aprovado, modo ONLINE ativo, persistência PHP e escuta RTDB).
  /// ---
  Future<void> setOwnerSimulatedHiredDriver(bool enabled) async {
    if (_ownerTestBusy) return;
    final ownerEmail = ((_driver.email ?? '').trim().isNotEmpty
            ? _driver.email!
            : backend.ownerEmail)
        .trim()
        .toLowerCase();

    if (!OmniBackendService.isAllowedOwnerEmail(ownerEmail)) {
      return;
    }

    _ownerTestBusy = true;
    notifyListeners();

    try {

      if (enabled) {
        await unlockAllOnboardingForSimulation();
        _stepperModalOpen = false;
        _ownerTestHiredMode = true;
        _driver = _driver.copyWith(isOnline: true);

        await backend.executar(
          targetMethod: OmniBackendMethods.ownerSimulateHired,
          arguments: {
            'driver_id': _driver.id,
            'auth_uid': _driver.authUid ?? _driver.id,
            'email': ownerEmail,
            'owner_email': ownerEmail,
            'enabled': true,
            'location': locationService.currentLocation.toJson(),
          },
        );

        await backend.executar(
          targetMethod: OmniBackendMethods.availabilityToggle,
          arguments: {
            'driver_id': _driver.id,
            'is_online': true,
            'test_mode': true,
            'simulated_hired': true,
            'owner_email': ownerEmail,
            'owner_uid': _driver.authUid ?? _driver.id,
            'location': locationService.currentLocation.toJson(),
          },
        );

        await _persistAll();
        _startDispatchPolling();
        _startLocationTelemetryHeartbeat();
        await OmniSoundService.playSuccess();
        addAlert(
          'Modo Teste do Dono Ativo (100% Online)',
          'Motorista marcado como contratado, aprovado e ONLINE para receber chamadas do Passageiro.',
          'success',
        );
      } else {
        _stopDispatchPolling();
        if (_activeTrip == null) {
          _stopLocationTelemetryHeartbeat();
        }
        _ownerTestHiredMode = false;
        _driver = _driver.copyWith(isOnline: false);

        await backend.executar(
          targetMethod: OmniBackendMethods.ownerSimulateHired,
          arguments: {
            'driver_id': _driver.id,
            'auth_uid': _driver.authUid ?? _driver.id,
            'email': ownerEmail,
            'owner_email': ownerEmail,
            'enabled': false,
            'location': locationService.currentLocation.toJson(),
          },
        );

        await backend.executar(
          targetMethod: OmniBackendMethods.availabilityToggle,
          arguments: {
            'driver_id': _driver.id,
            'is_online': false,
            'test_mode': false,
            'location': locationService.currentLocation.toJson(),
          },
        );

        await _persistAll();
        addAlert(
          'Modo Teste do Dono Desativado',
          'Motorista colocado em modo offline para testes.',
          'info',
        );
      }
    } finally {
      _ownerTestBusy = false;
      notifyListeners();
    }
  }

  /// Ajustes administrativos de nível Clube OMNI, raio operacional e cidade (somente dono)
  Future<bool> adminUpdateOperationalControls({
    String? clubTier,
    num? maxRadiusKm,
    String? operationalCity,
  }) async {
    if (!isAuthorizedAppOwner) return false;
    final currPrefs = _driver.workPreferences ??
        const DriverWorkPreferences(
          acceptsPassengers: true,
          acceptsDeliveries: true,
          acceptsPrivateTrips: true,
          acceptsCash: true,
          acceptsPets: false,
          acceptsLargeLuggage: false,
          hasEar: false,
          maxRadiusKm: 15.0,
        );
    final nextPrefs = maxRadiusKm != null
        ? currPrefs.copyWith(
            maxRadiusKm: maxRadiusKm.toDouble().clamp(3.0, 80.0),
          )
        : currPrefs;
    final nextCity = operationalCity != null
        ? operationalCity.trim()
        : _driver.operationalCity;
    _driver = _driver.copyWith(
      clubTier: clubTier ?? _driver.clubTier,
      workPreferences: nextPrefs,
      operationalCity: nextCity,
    );
    await _persistAll();
    await syncCityNotifications();
    notifyListeners();
    return true;
  }

  /// Lança bônus promocional administrativo na carteira do motorista (somente dono)
  Future<bool> adminGrantPromoWalletBonus({
    required double amount,
    String description = 'Bônus Promocional Administrativo (Dono)',
  }) async {
    if (!isAuthorizedAppOwner || amount <= 0) return false;
    final cleanDesc = description.trim().isEmpty
        ? 'Bônus Promocional Administrativo (Dono)'
        : description.trim();
    _driver = _driver.copyWith(
      walletBalance: _driver.walletBalance + amount,
      todayEarnings: _driver.todayEarnings + amount,
    );
    _transactions = [
      WalletTransaction(
        id: 'promo_${DateTime.now().millisecondsSinceEpoch}',
        title: cleanDesc,
        type: 'PROMO_BONUS',
        amount: amount,
        timestamp: 'Agora',
        status: 'COMPLETED',
      ),
      ..._transactions,
    ];
    await _persistAll();
    await OmniSoundService.playSuccess();
    addAlert(
      'Bônus Creditado (+R\$ ${amount.toStringAsFixed(2)})',
      cleanDesc,
      'success',
    );
    notifyListeners();
    return true;
  }

  /// Redefine aprovação/status online para retestar o fluxo completo de onboarding (somente dono)
  Future<bool> adminResetOnboardingForAudit() async {
    if (!isAuthorizedAppOwner) return false;
    _stopDispatchPolling();
    _stopLocationTelemetryHeartbeat();
    _ownerTestHiredMode = false;
    _driver = _driver.copyWith(
      isOnline: false,
      isBiometricVerified: false,
      isFingerprintVerified: false,
      complianceRites: const ComplianceRites(
        acceptedTerms: false,
        acceptedPrivacyLgpd: false,
        acceptedZeroTolerance: false,
        completedSafetyBriefing: false,
        termsVersion: 'OMNI-BR-2025.2',
      ),
    );
    await _persistAll();
    addAlert(
      'Auditoria Reiniciada',
      'Status online e ritos redefinidos para testar o Gatekeeper do zero.',
      'warning',
    );
    notifyListeners();
    return true;
  }

  /// Força sincronização imediata com SQL/PHP + Firebase RTDB (somente dono)
  Future<void> adminForceSyncState() async {
    if (!isAuthorizedAppOwner) return;
    await _hydrateStateFromBackendAndRtdb();
    await refreshCampaigns();
    notifyListeners();
  }

  // =========================================================================
  // LISTENERS EM TEMPO REAL FIREBASE RTDB (DISPATCH, CHAT, STATUS, TELEMETRIA, OFERTAS)
  // =========================================================================

  String _formatTimeFromMs(int ms) {
    if (ms <= 0) return TimeOfDayString.now();
    final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _hydrateStateFromBackendAndRtdb() async {
    try {
      final resp = await backend.executar(
        targetMethod: OmniBackendMethods.syncState,
        arguments: {'driver_id': _driver.id},
      );
      final data = resp['data'];
      if (resp['success'] == true && data is Map<String, dynamic>) {
        if (data['private_offers'] is Map) {
          _ingestRtdbPrivateOffers(data['private_offers'] as Map);
        }
        if (data['rtdb_payouts'] is Map) {
          _ingestRtdbPayouts(data['rtdb_payouts'] as Map);
        }
        if (data['dispatch_queue'] is Map &&
            _driver.isOnline &&
            isDriverFullyApproved &&
            _incomingTrip == null &&
            _activeTrip == null) {
          _handleDispatchQueueSnapshot(data['dispatch_queue'] as Map);
        }
        if (data['active_trip'] is Map && _activeTrip == null) {
          final tripRow = data['active_trip'] as Map;
          final rawJson = tripRow['trip_json'];
          Map<String, dynamic> decodedTrip = {};
          if (rawJson is String && rawJson.trim().isNotEmpty) {
            try {
              final parsed = jsonDecode(rawJson);
              if (parsed is Map<String, dynamic>) decodedTrip = parsed;
            } catch (_) {}
          }
          final tid = (tripRow['trip_id'] ?? '').toString();
          if (tid.isNotEmpty) {
            _activateIncomingTripFromPayload(
              tid,
              {
                ...decodedTrip,
                'trip_id': tid,
                'fare_total': tripRow['fare_amount'] ?? decodedTrip['estimated_fare'],
                'otp_pin': tripRow['expected_otp'] ?? decodedTrip['otp_code'],
              },
              asActiveStatus: (tripRow['status'] ?? '').toString(),
            );
          }
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  void _startDispatchPolling() {
    _dispatchPollTimer?.cancel();
    _dispatchRtdbSub?.cancel();

    final sdkStream = firebaseService?.valueStream(
      OmniRtdbPaths.driverDispatchQueue(_driver.id),
    );
    if (sdkStream != null) {
      _dispatchRtdbSub = sdkStream.listen((event) {
        final raw = event.snapshot.value;
        if (raw is Map) {
          _handleDispatchQueueSnapshot(raw);
        }
      });
    }

    unawaited(_pollPassengerDispatchQueue());
    _dispatchPollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollPassengerDispatchQueue(),
    );
  }

  void _stopDispatchPolling() {
    _dispatchPollTimer?.cancel();
    _dispatchPollTimer = null;
    _dispatchRtdbSub?.cancel();
    _dispatchRtdbSub = null;
  }

  Future<void> _pollPassengerDispatchQueue() async {
    if (_isPollingDispatch ||
        !_driver.isOnline ||
        !isDriverFullyApproved ||
        _incomingTrip != null ||
        _activeTrip != null) {
      return;
    }
    _isPollingDispatch = true;
    try {
      final raw = await backend.readFromFirebaseRtdb(
        OmniRtdbPaths.driverDispatchQueue(_driver.id),
      );
      if (raw is Map && raw.isNotEmpty) {
        _handleDispatchQueueSnapshot(raw);
      }
    } catch (_) {
      // Silencioso para não interromper operação offline
    } finally {
      _isPollingDispatch = false;
    }
  }

  void _handleDispatchQueueSnapshot(Map raw) {
    if (!_driver.isOnline ||
        !isDriverFullyApproved ||
        _incomingTrip != null ||
        _activeTrip != null) {
      return;
    }
    for (final entry in raw.entries) {
      final keyStr = entry.key.toString();
      if (_dismissedDispatchIds.contains(keyStr)) continue;
      if (entry.value is Map) {
        final val = Map<String, dynamic>.from(entry.value as Map);
        final status = (val['status'] ?? 'DISPATCHING').toString().toUpperCase();
        if (status == 'DISPATCHING' ||
            status == 'SEARCHING' ||
            status == 'SEARCHING_DRIVER') {
          _activateIncomingTripFromPayload(keyStr, val);
          break;
        }
      }
    }
  }

  void _activateIncomingTripFromPayload(
    String tripKey,
    Map<String, dynamic> data, {
    String? asActiveStatus,
  }) {
    final tripId = (data['trip_id'] ?? tripKey).toString();
    if (_dismissedDispatchIds.contains(tripId) && asActiveStatus == null) return;

    // Verifica expiração do dispatch conforme expires_at (§3.2)
    int countdownSeconds = 15;
    final rawExpires = data['expires_at'];
    if (rawExpires != null && asActiveStatus == null) {
      int? expiresMs;
      if (rawExpires is num) {
        expiresMs = rawExpires.toInt();
      } else if (rawExpires is String) {
        expiresMs = int.tryParse(rawExpires) ??
            DateTime.tryParse(rawExpires)?.millisecondsSinceEpoch;
      }
      if (expiresMs != null && expiresMs > 0) {
        final remaining =
            ((expiresMs - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
        if (remaining <= 0) {
          _dismissedDispatchIds.add(tripId);
          unawaited(backend.deleteFromFirebaseRtdb(
            OmniRtdbPaths.driverDispatchOffer(_driver.id, tripId),
          ));
          return;
        }
        countdownSeconds = remaining.clamp(5, 30);
      }
    }

    final rawType = (data['trip_type'] ?? data['type'] ?? data['trip_kind'] ?? 'PASSENGER')
        .toString()
        .toUpperCase();

    final originMap = data['origin'] is Map
        ? Map<String, dynamic>.from(data['origin'] as Map)
        : const <String, dynamic>{};
    final destMap = data['destination'] is Map
        ? Map<String, dynamic>.from(data['destination'] as Map)
        : const <String, dynamic>{};
    final pasMap = data['passenger'] is Map
        ? Map<String, dynamic>.from(data['passenger'] as Map)
        : const <String, dynamic>{};

    final originLat = (originMap['lat'] as num?)?.toDouble() ??
        (data['origin_lat'] as num?)?.toDouble() ??
        locationService.currentLocation.latitude;
    final originLng = (originMap['lng'] as num?)?.toDouble() ??
        (data['origin_lng'] as num?)?.toDouble() ??
        locationService.currentLocation.longitude;
    final destLat = (destMap['lat'] as num?)?.toDouble() ??
        (data['dest_lat'] as num?)?.toDouble() ??
        originLat;
    final destLng = (destMap['lng'] as num?)?.toDouble() ??
        (data['dest_lng'] as num?)?.toDouble() ??
        originLng;

    final originAddr = (originMap['address'] ??
            originMap['address_line'] ??
            data['origin_address'] ??
            'Origem confirmada pelo Passageiro')
        .toString();
    final destAddr = (destMap['address'] ??
            destMap['address_line'] ??
            data['dest_address'] ??
            'Destino informado pelo Passageiro')
        .toString();

    final distanceKm = (data['distance_km'] as num?)?.toDouble() ??
        (data['estimated_distance_km'] as num?)?.toDouble() ??
        0.0;
    final estimatedMin = (data['eta_minutes'] as num?)?.round() ??
        (data['estimated_minutes'] as num?)?.round() ??
        (data['estimated_duration_minutes'] as num?)?.round() ??
        0;
    final fareTotal = (data['estimated_fare'] as num?)?.toDouble() ??
        (data['passenger_fare_brl'] as num?)?.toDouble() ??
        (data['fare_total'] as num?)?.toDouble() ??
        0.0;
    final netEarnings = (data['driver_net_earnings'] as num?)?.toDouble() ??
        (data['driver_earnings_brl'] as num?)?.toDouble() ??
        double.parse((fareTotal * 0.85).toStringAsFixed(2));

    final tripObj = OmniTrip(
      tripId: tripId,
      status: TripStatus.dispatching,
      type: rawType,
      category: rawType == 'DELIVERY'
          ? VehicleCategory.omniFlashDelivery
          : activeVehicle.category,
      passenger: OmniPassenger(
        id: (pasMap['passenger_id'] ?? data['passenger_id'] ?? 'pas_rtdb')
            .toString(),
        name: (pasMap['name'] ?? data['passenger_name'] ?? 'Passageiro OMNI')
            .toString(),
        rating: (pasMap['rating'] as num?)?.toDouble() ??
            (data['passenger_rating'] as num?)?.toDouble() ??
            5.0,
        totalTrips: (pasMap['trips_count'] as num?)?.round() ??
            (data['passenger_total_trips'] as num?)?.round() ??
            0,
        avatarUrl: (pasMap['photo_url'] ??
                data['passenger_avatar'] ??
                '')
            .toString(),
        phoneMasked: (pasMap['phone_masked'] ??
                data['passenger_phone_masked'] ??
                'Telefone protegido')
            .toString(),
      ),
      origin: OmniPlace(
        address: originAddr,
        shortName: (data['origin_short'] ?? originAddr.split(',').first).toString(),
        coords: OmniCoordinate(latitude: originLat, longitude: originLng),
      ),
      destination: OmniPlace(
        address: destAddr,
        shortName: (data['dest_short'] ?? destAddr.split(',').first).toString(),
        coords: OmniCoordinate(latitude: destLat, longitude: destLng),
      ),
      distanceKm: distanceKm,
      estimatedMinutes: estimatedMin,
      fareTotal: fareTotal,
      driverNetEarnings: netEarnings,
      platformFee: (fareTotal - netEarnings).clamp(0.0, fareTotal),
      paymentMethod: PaymentMethod.pix,
      otpPin: (data['otp_code'] ?? data['otp_pin'] ?? '').toString(),
      surgeMultiplier: (data['surge_multiplier'] as num?)?.toDouble() ?? 1.0,
      createdAt:
          (data['created_at'] ?? DateTime.now().toIso8601String()).toString(),
    );

    if (asActiveStatus != null) {
      final mappedStatus = _mapServerTripStatus(asActiveStatus);
      _activeTrip = tripObj.copyWith(status: mappedStatus);
      final targetCoords = mappedStatus == TripStatus.tripInProgress
          ? tripObj.destination.coords
          : tripObj.origin.coords;
      final currentPos = locationService.currentLocation;
      _routePolyline = OmniLocationService.generateRoutePolyline(
        currentPos,
        targetCoords,
      );
      unawaited(
        OmniLocationService.fetchFreeOsrmRoutePolyline(
          currentPos,
          targetCoords,
        ).then((pts) {
          if (_activeTrip?.tripId == tripId && pts.isNotEmpty) {
            _routePolyline = pts;
            notifyListeners();
          }
        }),
      );
      _startTripRealtimeListeners(tripId);
      _startLocationTelemetryHeartbeat();
      unawaited(_loadChatHistoryFromBackend(tripId));
      notifyListeners();
      return;
    }

    _incomingTrip = tripObj;
    _dispatchCountdown = countdownSeconds;
    _dispatchTimer?.cancel();
    OmniSoundService.playDispatchPing();
    _dispatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_dispatchCountdown <= 1) {
        timer.cancel();
        declineIncomingTrip();
      } else {
        _dispatchCountdown--;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  TripStatus _mapServerTripStatus(String rawStatus) {
    switch (rawStatus.toUpperCase()) {
      case 'ACCEPTED':
      case 'DRIVER_EN_ROUTE':
        return TripStatus.driverEnRoute;
      case 'DRIVER_ARRIVED':
        return TripStatus.driverArrived;
      case 'BOARDING_CONFIRMED':
        return TripStatus.boardingConfirmed;
      case 'IN_PROGRESS':
      case 'TRIP_IN_PROGRESS':
        return TripStatus.tripInProgress;
      case 'COMPLETED':
        return TripStatus.completed;
      case 'CANCELLED':
      case 'CANCELLED_BY_PASSENGER':
      case 'CANCELLED_BY_DRIVER':
        return TripStatus.cancelled;
      default:
        return TripStatus.driverEnRoute;
    }
  }

  Future<void> _loadChatHistoryFromBackend(String tripId) async {
    final resp = await backend.executar(
      targetMethod: OmniBackendMethods.tripChatHistory,
      arguments: {
        'trip_id': tripId,
        if (_chatOpen) 'mark_read_for_role': 'driver',
      },
    );
    final data = resp['data'];
    if (resp['success'] == true &&
        data is Map<String, dynamic> &&
        data['messages'] is List) {
      final Map<String, dynamic> asMap = {};
      for (final item in data['messages'] as List) {
        if (item is Map) {
          final mid = (item['message_id'] ?? '').toString();
          if (mid.isNotEmpty) {
            asMap[mid] = item;
          }
        }
      }
      _ingestRtdbChatSnapshot(asMap, tripId);
    }
  }

  void _startTripRealtimeListeners(String tripId) {
    _stopTripRealtimeListeners();

    final chatStream = firebaseService?.valueStream(OmniRtdbPaths.tripChat(tripId));
    if (chatStream != null) {
      _chatRtdbSub = chatStream.listen((event) {
        final val = event.snapshot.value;
        if (val is Map) {
          _ingestRtdbChatSnapshot(val, tripId);
        }
      });
    }

    final statusStream =
        firebaseService?.valueStream(OmniRtdbPaths.tripStatus(tripId));
    if (statusStream != null) {
      _tripStatusRtdbSub = statusStream.listen((event) {
        final val = event.snapshot.value?.toString();
        if (val != null) {
          _handleRemoteTripStatusChange(val);
        }
      });
    }

    _chatPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_isPollingChat || _activeTrip == null) return;
      _isPollingChat = true;
      try {
        final raw = await backend.readFromFirebaseRtdb(
          OmniRtdbPaths.tripChat(_activeTrip!.tripId),
        );
        if (raw is Map) {
          _ingestRtdbChatSnapshot(raw, _activeTrip!.tripId);
        }
      } catch (_) {
      } finally {
        _isPollingChat = false;
      }
    });

    _tripStatusPollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_isPollingTripStatus || _activeTrip == null) return;
      _isPollingTripStatus = true;
      try {
        final rawStatus = await backend.readFromFirebaseRtdb(
          OmniRtdbPaths.tripStatus(_activeTrip!.tripId),
        );
        if (rawStatus != null) {
          _handleRemoteTripStatusChange(rawStatus.toString());
        }
      } catch (_) {
      } finally {
        _isPollingTripStatus = false;
      }
    });
  }

  void _stopTripRealtimeListeners() {
    _chatRtdbSub?.cancel();
    _chatRtdbSub = null;
    _tripStatusRtdbSub?.cancel();
    _tripStatusRtdbSub = null;
    _chatPollTimer?.cancel();
    _chatPollTimer = null;
    _tripStatusPollTimer?.cancel();
    _tripStatusPollTimer = null;
  }

  void _handleRemoteTripStatusChange(String rawStatus) {
    final trip = _activeTrip;
    if (trip == null) return;
    final up = rawStatus.toUpperCase();
    if ((up == 'CANCELLED' || up == 'CANCELLED_BY_PASSENGER') &&
        trip.status != TripStatus.completed) {
      _stopTripRealtimeListeners();
      if (!_driver.isOnline) {
        _stopLocationTelemetryHeartbeat();
      }
      _activeTrip = null;
      _routePolyline = [];
      _chatMessages = [];
      _unreadChatCount = 0;
      OmniSoundService.playAlert();
      addAlert(
        'Corrida Cancelada pelo Passageiro',
        'O passageiro encerrou a solicitação em andamento.',
        'warning',
      );
      notifyListeners();
    }
  }

  void _ingestRtdbChatSnapshot(Map rawMap, String tripId) {
    if (_activeTrip?.tripId != tripId) return;

    final List<ChatMessage> parsed = [];
    bool newPassengerMessage = false;

    for (final entry in rawMap.entries) {
      final msgId = entry.key.toString();
      final val = entry.value;
      if (val is! Map) continue;
      final text = (val['text'] ?? val['message'] ?? '').toString().trim();
      if (text.isEmpty) continue;

      final rawRole =
          (val['sender_role'] ?? val['sender'] ?? 'passenger').toString().toUpperCase();
      final role = rawRole == 'DRIVER'
          ? 'DRIVER'
          : (rawRole == 'SYSTEM' ? 'SYSTEM' : 'PASSENGER');
      final senderId = (val['sender_id'] ?? '').toString();
      final createdAtMs = (val['created_at'] as num?)?.toInt() ??
          (val['created_at_ms'] as num?)?.toInt() ??
          0;
      final isRead = val['is_read'] == true || role == 'DRIVER' || _chatOpen;

      if (!_knownChatMessageIds.contains(msgId)) {
        _knownChatMessageIds.add(msgId);
        if (role == 'PASSENGER' && !_chatOpen) {
          newPassengerMessage = true;
        }
      }

      parsed.add(ChatMessage(
        id: msgId,
        sender: role,
        text: text,
        timestamp: _formatTimeFromMs(createdAtMs),
        senderId: senderId,
        createdAtMs: createdAtMs,
        isRead: isRead,
      ));
    }

    // Preserva mensagens locais ainda aguardando confirmação do push
    for (final existing in _chatMessages) {
      if (existing.id.startsWith('local_') &&
          !parsed.any((p) =>
              p.sender == 'DRIVER' &&
              p.text == existing.text &&
              (p.createdAtMs - existing.createdAtMs).abs() < 10000)) {
        parsed.add(existing);
      }
    }

    parsed.sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
    _chatMessages = parsed;
    _unreadChatCount = _chatOpen
        ? 0
        : parsed.where((m) => m.sender == 'PASSENGER' && !m.isRead).length;

    if (newPassengerMessage) {
      OmniSoundService.playChatBeep();
      addAlert(
        'Nova Mensagem do Passageiro',
        parsed.lastWhere((m) => m.sender == 'PASSENGER').text,
        'info',
      );
    } else if (_chatOpen) {
      final hasUnreadRemote = rawMap.values.any((v) =>
          v is Map &&
          (v['sender_role'] ?? '').toString().toLowerCase() != 'driver' &&
          v['is_read'] != true);
      if (hasUnreadRemote) {
        unawaited(markChatMessagesRead());
      }
    }

    notifyListeners();
  }

  void _startLocationTelemetryHeartbeat() {
    if (_locationStreamTimer != null) return;
    _locationStreamTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_driver.isOnline && _activeTrip == null) {
        _stopLocationTelemetryHeartbeat();
        return;
      }
      final loc = locationService.currentLocation;
      unawaited(backend.executar(
        targetMethod: OmniBackendMethods.tripLocationUpdate,
        arguments: {
          'driver_id': _driver.id,
          'trip_id': _activeTrip?.tripId ?? '',
          'lat': loc.latitude,
          'lng': loc.longitude,
          'bearing': _driverHeading,
          'speed_kmh': 0.0,
          'is_online': _driver.isOnline,
        },
      ));
    });
  }

  void _stopLocationTelemetryHeartbeat() {
    _locationStreamTimer?.cancel();
    _locationStreamTimer = null;
  }

  void _startPrivateOffersAndPayoutsListeners() {
    _privateOffersRtdbSub?.cancel();
    _payoutsRtdbSub?.cancel();
    _privateOffersPollTimer?.cancel();

    final offersStream =
        firebaseService?.valueStream(OmniRtdbPaths.privateOffers);
    if (offersStream != null) {
      _privateOffersRtdbSub = offersStream.listen((event) {
        if (event.snapshot.value is Map) {
          _ingestRtdbPrivateOffers(event.snapshot.value as Map);
        }
      });
    }

    final payoutsStream =
        firebaseService?.valueStream(OmniRtdbPaths.payoutsDriver(_driver.id));
    if (payoutsStream != null) {
      _payoutsRtdbSub = payoutsStream.listen((event) {
        if (event.snapshot.value is Map) {
          _ingestRtdbPayouts(event.snapshot.value as Map);
        }
      });
    }

    _privateOffersPollTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      try {
        final rawOffers =
            await backend.readFromFirebaseRtdb(OmniRtdbPaths.privateOffers);
        if (rawOffers is Map) _ingestRtdbPrivateOffers(rawOffers);
      } catch (_) {}
    });
  }

  void _ingestRtdbPrivateOffers(Map rawOffers) {
    final List<PrivateTripOffer> remote = [];
    for (final entry in rawOffers.entries) {
      if (entry.value is! Map) continue;
      final m = Map<String, dynamic>.from(entry.value as Map);
      final id = (m['id'] ?? entry.key).toString();
      final catStr = (m['vehicle_required'] ?? 'OMNI_COMFORT').toString();
      final cat = VehicleCategory.values.firstWhere(
        (c) => c.code == catStr,
        orElse: () => VehicleCategory.omniComfort,
      );
      remote.add(PrivateTripOffer(
        id: id,
        title: (m['title'] ?? 'Viagem Particular').toString(),
        passengerName: (m['passenger_name'] ?? 'Cliente Executivo').toString(),
        passengerRating: (m['passenger_rating'] as num?)?.toDouble() ?? 4.95,
        origin: (m['origin'] ?? '').toString(),
        destination: (m['destination'] ?? '').toString(),
        dateLabel: (m['date_label'] ?? 'Agendada').toString(),
        distanceKm: (m['distance_km'] as num?)?.toDouble() ?? 15.0,
        suggestedPrice: (m['suggested_price'] as num?)?.toDouble() ?? 120.0,
        vehicleRequired: cat,
        notes: (m['notes'] ?? '').toString(),
        status: (m['status'] ?? 'OPEN').toString(),
        driverBid: (m['driver_bid'] as num?)?.toDouble(),
      ));
    }
    final existingById = {
      for (final item in _privateOffers) item.id: item,
    };
    _privateOffers = remote.map((item) {
      final existing = existingById[item.id];
      return existing?.driverBid != null
          ? item.copyWith(status: 'BID_SENT', driverBid: existing!.driverBid)
          : item;
    }).toList();
    notifyListeners();
  }

  void _ingestRtdbPayouts(Map rawPayouts) {
    final existingIds = _transactions.map((t) => t.id).toSet();
    final List<WalletTransaction> extra = [];
    for (final entry in rawPayouts.entries) {
      if (entry.value is! Map) continue;
      final m = Map<String, dynamic>.from(entry.value as Map);
      final txId = (m['transaction_id'] ?? entry.key).toString();
      if (existingIds.contains(txId)) continue;
      final amt = (m['amount'] as num?)?.toDouble() ?? 0.0;
      if (amt <= 0) continue;
      extra.add(WalletTransaction(
        id: txId,
        title: 'Saque Pix (${m['pix_key_type'] ?? 'PIX'})',
        type: 'PIX_WITHDRAWAL',
        amount: -amt,
        timestamp: (m['processed_at'] ?? 'Recente').toString(),
        status: (m['status'] ?? 'COMPLETED').toString(),
      ));
    }
    if (extra.isNotEmpty) {
      _transactions = [...extra, ..._transactions];
      notifyListeners();
    }
  }

  @override
  void dispose() {
    notificationService?.removeListener(_onNotificationServiceChanged);
    _dispatchTimer?.cancel();
    _stopDispatchPolling();
    _stopTripRealtimeListeners();
    _stopLocationTelemetryHeartbeat();
    _privateOffersRtdbSub?.cancel();
    _payoutsRtdbSub?.cancel();
    _privateOffersPollTimer?.cancel();
    super.dispose();
  }
}

class TimeOfDayString {
  static String now() {
    final dt = DateTime.now();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
