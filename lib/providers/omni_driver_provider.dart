import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/omni_models.dart';
import '../services/backend_service.dart';
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
  double _driverHeading = 35.0;

  // Navegação e UI
  MainTab _activeTab = MainTab.map;
  ProfileSubTab _profileSubTab = ProfileSubTab.personal;
  bool _mapDarkMode = true;
  bool _muted = false;
  bool _biometricModalOpen = false;
  bool _stepperModalOpen = true;
  int? _stepperInitialStep;
  bool _safetyModalOpen = false;
  bool _chatOpen = false;
  String? _documentCaptureDocId;
  bool _documentCaptureAutoCamera = true;
  int _recenterTick = 0;
  bool _isRunningBackgroundCheck = false;
  bool _isRunningVehicleDeepCheck = false;
  bool _isRunningFingerprintDocCheck = false;

  Timer? _dispatchTimer;
  Timer? _driveTimer;

  OmniDriverProvider({
    required this.backend,
    required this.locationService,
  }) {
    _initDefaults();
    _loadPersistedState();
  }

  String get backendDomain => backend.configuredDomain;
  String get backendAjaxUrl => backend.resolvedAjaxUrl;
  bool get hasCustomBackendDomain => backend.hasCustomDomainCached;

  Future<Map<String, String>> saveBackendDomain(String rawDomain) async {
    final res = await backend.saveConfiguredDomain(rawDomain);
    OmniSoundService.playSuccess();
    notifyListeners();
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
      id: 'usr_drv_88419201824',
      name: 'Carlos Eduardo Silveira',
      cpf: '384.910.228-99',
      rg: '42.819.304-7',
      rgIssuer: 'SSP/SP',
      birthDate: '1989-07-14',
      email: 'carlos.silveira@omnimobilidade.com.br',
      phone: '(11) 98412-3901',
      cnhNumber: '05981234506',
      cnhCategory: 'AB',
      cnhExpiry: '2028-06-20',
      cnhIssueState: 'SP',
      cnhEar: true,
      operationalCity: 'São Paulo - SP',
      bio:
          'Motorista parceiro 5 estrelas especializado em viagens executivas, traslados de aeroportos e entregas expressas na Grande São Paulo.',
      address: DriverAddress(
        cep: '01310-100',
        street: 'Avenida Paulista',
        number: '1578',
        complement: 'Apto 84 - Bela Vista',
        neighborhood: 'Bela Vista',
        city: 'São Paulo',
        state: 'SP',
      ),
      emergencyContact: DriverEmergencyContact(
        name: 'Mariana Silveira',
        relationship: 'Esposa',
        phone: '(11) 99123-4410',
      ),
      bankPayout: DriverBankPayout(
        pixKeyType: 'CPF',
        pixKey: '384.910.228-99',
        bankName: 'Nubank (260)',
        agency: '0001',
        account: '8472910-4',
        accountType: 'CORRENTE',
      ),
      workPreferences: DriverWorkPreferences(
        acceptsPassengers: true,
        acceptsDeliveries: true,
        acceptsPrivateTrips: true,
        acceptsCash: true,
        acceptsPets: true,
        acceptsLargeLuggage: true,
        hasEar: true,
        maxRadiusKm: 18,
      ),
      complianceRites: ComplianceRites(
        acceptedTerms: false,
        acceptedPrivacyLgpd: false,
        acceptedZeroTolerance: false,
        completedSafetyBriefing: false,
        termsVersion: 'OMNI-BR-2025.2',
      ),
      rating: 4.96,
      acceptanceRate: 98.4,
      cancellationRate: 1.2,
      totalTrips: 1842,
      clubTier: 'OURO',
      avatarUrl:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop&crop=faces',
      faceMatchRg: FaceMatchEntry(status: 'PENDING'),
      faceMatchCnh: FaceMatchEntry(status: 'PENDING'),
      isOnline: false,
      isBiometricVerified: false,
      walletBalance: 348.60,
      todayEarnings: 218.40,
      todayTripsCount: 7,
      onlineHoursToday: 4.75,
      referralCode: 'OMNI-CARLOS98',
      referralsCount: 4,
      referralEarnings: 600.00,
    );

    _vehicles = const [
      const OmniVehicle(
        id: 'veh_1',
        type: VehicleType.car,
        category: VehicleCategory.omniComfort,
        brand: 'Toyota',
        model: 'Corolla XEi 2.0',
        year: 2023,
        plate: 'OMN8A42',
        color: 'Prata Metálico',
        seats: 4,
        renavam: '01284950120',
        crlvExpiry: '2026-09-30',
        fuelType: 'FLEX',
        transmission: 'AUTOMATIC',
        doors: 4,
        hasAirConditioning: true,
        hasTrunkLarge: true,
        insuranceCompany: 'Porto Seguro Auto',
        insurancePolicy: '99841201-APP',
        insuranceAppActive: true,
        inspection360Completed: false,
        bodyStyle: 'SEDAN_4P',
        photoUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/2020_Toyota_Corolla_Hybrid_Icon_Tech_1.8_Front.jpg/640px-2020_Toyota_Corolla_Hybrid_Icon_Tech_1.8_Front.jpg',
        status: 'APPROVED',
        isActive: true,
      ),
      const OmniVehicle(
        id: 'veh_2',
        type: VehicleType.moto,
        category: VehicleCategory.omniMoto,
        brand: 'Honda',
        model: 'CG 160 Titan',
        year: 2024,
        plate: 'FLS4E99',
        color: 'Vermelho',
        seats: 1,
        renavam: '01394811206',
        crlvExpiry: '2026-10-15',
        fuelType: 'FLEX',
        transmission: 'MANUAL',
        doors: 0,
        hasAirConditioning: false,
        hasTrunkLarge: false,
        hasDeliveryBox: true,
        hasExtraHelmet: true,
        engineCc: 162,
        insuranceCompany: 'Suhai Seguradora',
        insurancePolicy: '77120488-APP',
        insuranceAppActive: true,
        inspection360Completed: false,
        bodyStyle: 'MOTO_STREET',
        photoUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/8/89/Honda_CG_160_Titan_EX.jpg/640px-Honda_CG_160_Titan_EX.jpg',
        status: 'APPROVED',
        isActive: false,
      ),
      const OmniVehicle(
        id: 'veh_3',
        type: VehicleType.car,
        category: VehicleCategory.omniBlack,
        brand: 'BYD',
        model: 'Dolphin Plus EV',
        year: 2024,
        plate: 'OMN9E24',
        color: 'Preto',
        seats: 4,
        renavam: '01450298114',
        crlvExpiry: '2027-03-10',
        fuelType: 'ELECTRIC',
        transmission: 'AUTOMATIC',
        doors: 4,
        hasAirConditioning: true,
        hasTrunkLarge: true,
        insuranceCompany: 'Allianz Seguros',
        insurancePolicy: '88492011-APP',
        insuranceAppActive: true,
        inspection360Completed: false,
        bodyStyle: 'HATCH_4P',
        status: 'APPROVED',
        isActive: false,
      ),
    ];

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
        expiryDate: '2028-06-20',
        updatedAt: 'Aguardando envio',
      ),
      DriverDocument(
        id: 'doc_crlv',
        name: 'CRLV-e Digital (Licenciamento Anual)',
        type: 'CRLV',
        status: 'APPROVED',
        expiryDate: '2026-09-30',
        updatedAt: '05/02/2025',
      ),
      DriverDocument(
        id: 'doc_bg',
        name: 'Certidão Antecedentes Criminais (PF / SSP)',
        type: 'BACKGROUND_CHECK',
        status: 'APPROVED',
        expiryDate: '2025-12-01',
        updatedAt: '15/01/2025',
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
        status: 'APPROVED',
        updatedAt: '10/01/2025',
      ),
    ];

    _transactions = const [
      WalletTransaction(
        id: 'tx_1',
        title: 'Corrida #OM-9482 • Jardins → Pinheiros',
        type: 'TRIP_EARNING',
        amount: 34.80,
        timestamp: 'Hoje, 14:22',
        status: 'COMPLETED',
      ),
      WalletTransaction(
        id: 'tx_2',
        title: 'Bônus Meta Dinâmica Zona Sul',
        type: 'BONUS',
        amount: 65.00,
        timestamp: 'Hoje, 13:05',
        status: 'COMPLETED',
      ),
      WalletTransaction(
        id: 'tx_3',
        title: 'Entrega Flash #FL-3011 • Itaim Bibi',
        type: 'TRIP_EARNING',
        amount: 19.40,
        timestamp: 'Hoje, 11:48',
        status: 'COMPLETED',
      ),
      WalletTransaction(
        id: 'tx_4',
        title: 'Saque Pix Mercado Pago (Chave CPF)',
        type: 'PIX_WITHDRAWAL',
        amount: -420.00,
        timestamp: 'Ontem, 19:15',
        status: 'COMPLETED',
      ),
      WalletTransaction(
        id: 'tx_5',
        title: 'Bônus Indique e Ganhe (Motorista Rafael)',
        type: 'REFERRAL',
        amount: 150.00,
        timestamp: '12/02/2025',
        status: 'COMPLETED',
      ),
    ];

    _privateOffers = const [
      PrivateTripOffer(
        id: 'priv_1',
        title: 'Transfer Executivo Aeroporto GRU (Terminal 3)',
        passengerName: 'Dra. Beatriz Alencar',
        passengerRating: 4.98,
        origin: 'Itaim Bibi (Rua Joaquim Floriano, 466)',
        destination: 'Aeroporto Internacional de Guarulhos (GRU T3)',
        dateLabel: 'Amanhã, 06:30',
        distanceKm: 36.4,
        suggestedPrice: 185.00,
        vehicleRequired: VehicleCategory.omniComfort,
        notes: '2 malas grandes. Necessário porta-malas livre e ar-condicionado.',
        status: 'OPEN',
      ),
      PrivateTripOffer(
        id: 'priv_2',
        title: 'Viagem Intermunicipal • Campinas Corporativo',
        passengerName: 'Marcos Vinícius Lima',
        passengerRating: 4.91,
        origin: 'Av. Faria Lima, 3477 (Pinheiros)',
        destination: 'Centro Empresarial Galleria, Campinas - SP',
        dateLabel: 'Sexta-feira, 08:00',
        distanceKm: 98.2,
        suggestedPrice: 390.00,
        vehicleRequired: VehicleCategory.omniComfort,
        notes: 'Ida direta pela Rodovia Anhanguera. Pedágios incluídos no lance.',
        status: 'OPEN',
      ),
      PrivateTripOffer(
        id: 'priv_3',
        title: 'Frete Corporativo Urgente — Documentos Cartório',
        passengerName: 'Cartório 15º Tabelionato',
        passengerRating: 5.00,
        origin: 'Av. Paulista, 1374 (Bela Vista)',
        destination: 'Centro Empresarial Alphaville, Barueri',
        dateLabel: 'Hoje, 17:00',
        distanceKm: 28.5,
        suggestedPrice: 95.00,
        vehicleRequired: VehicleCategory.omniFlashDelivery,
        notes: 'Envelope lacrado com coleta de assinatura e PIN na entrega.',
        status: 'OPEN',
      ),
    ];

    _chatMessages = const [
      ChatMessage(
        id: 'msg_1',
        sender: 'SYSTEM',
        text: 'Canal criptografado OMNI ativo. Seu telefone real está protegido por mascaramento.',
        timestamp: '14:28',
      ),
    ];

    _alerts = const [
      SmartAlert(
        id: 'al_1',
        title: 'Zona de Alta Demanda (1.6x)',
        message: 'Av. Paulista e Faria Lima com tarifa dinâmica ativa neste momento.',
        severity: 'info',
        visible: true,
      ),
    ];
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
    } catch (e) {
      debugPrint('[OMNI Provider] Erro ao ler cache local: $e');
    }
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
  OmniVehicle get activeVehicle => _vehicles.firstWhere(
        (v) => v.isActive,
        orElse: () => _vehicles.first,
      );
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
  bool get biometricModalOpen => _biometricModalOpen;
  bool get stepperModalOpen => _stepperModalOpen;
  int? get stepperInitialStep => _stepperInitialStep;
  bool get safetyModalOpen => _safetyModalOpen;
  bool get chatOpen => _chatOpen;
  String? get documentCaptureDocId => _documentCaptureDocId;
  bool get documentCaptureAutoCamera => _documentCaptureAutoCamera;
  int get recenterTick => _recenterTick;
  bool get isRunningBackgroundCheck => _isRunningBackgroundCheck;
  bool get isRunningVehicleDeepCheck => _isRunningVehicleDeepCheck;
  bool get isRunningFingerprintDocCheck => _isRunningFingerprintDocCheck;

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

  void triggerSimulatedTrip({required String type}) {
    if (!requireFullOnboardingGate('receber chamadas de passageiros ou entregas')) {
      return;
    }
    if (_incomingTrip != null || _activeTrip != null) return;

    final isDelivery = type == 'DELIVERY';
    final origin = const OmniPlace(
      address: 'Av. Paulista, 1374 - Bela Vista, São Paulo - SP',
      shortName: 'Av. Paulista, 1374',
      coords: OmniCoordinate(latitude: -23.5629, longitude: -46.6544),
    );
    final destination = isDelivery
        ? const OmniPlace(
            address: 'Rua Oscar Freire, 820 - Jardins, São Paulo - SP',
            shortName: 'Rua Oscar Freire, 820',
            coords: OmniCoordinate(latitude: -23.5656, longitude: -46.6697),
          )
        : const OmniPlace(
            address: 'Av. Brigadeiro Faria Lima, 2277 - Jardim Paulistano',
            shortName: 'Faria Lima, 2277',
            coords: OmniCoordinate(latitude: -23.5739, longitude: -46.6879),
          );

    _incomingTrip = OmniTrip(
      tripId: 'OM-${DateTime.now().millisecondsSinceEpoch % 10000}',
      status: TripStatus.dispatching,
      type: type,
      category: isDelivery
          ? VehicleCategory.omniFlashDelivery
          : activeVehicle.category,
      passenger: OmniPassenger(
        id: 'pas_104',
        name: isDelivery ? 'Loja TechStore Paulista' : 'Juliana Vasconcelos',
        rating: 4.94,
        totalTrips: 87,
        avatarUrl:
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=180&h=180&fit=crop&crop=faces',
        phoneMasked: '(11) 9****-4821',
      ),
      origin: origin,
      destination: destination,
      distanceKm: isDelivery ? 3.2 : 5.8,
      estimatedMinutes: isDelivery ? 11 : 17,
      fareTotal: isDelivery ? 22.90 : 38.50,
      driverNetEarnings: isDelivery ? 19.45 : 32.70,
      platformFee: isDelivery ? 3.45 : 5.80,
      paymentMethod: isDelivery ? PaymentMethod.pix : PaymentMethod.creditCard,
      otpPin: '4829',
      surgeMultiplier: 1.4,
      createdAt: DateTime.now().toIso8601String(),
      deliveryDetails: isDelivery
          ? const DeliveryDetails(
              packageType: 'Eletrônico Lacrado (Pequeno Porte)',
              weightKg: 1.2,
              recipientName: 'Fernanda Ribeiro',
              instructions: 'Entregar na recepção mediante PIN de 4 dígitos.',
              requiresSignature: true,
            )
          : null,
    );

    _dispatchCountdown = 15;
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

  Future<void> acceptIncomingTrip() async {
    if (!requireFullOnboardingGate('aceitar solicitações de corrida')) return;
    final trip = _incomingTrip;
    if (trip == null) return;

    _dispatchTimer?.cancel();
    await backend.executar(
      targetMethod: 'driver_trip_accept',
      arguments: {
        'driver_id': _driver.id,
        'trip': {'trip_id': trip.tripId},
      },
    );

    _activeTrip = trip.copyWith(status: TripStatus.driverEnRoute);
    _incomingTrip = null;
    _routePolyline = OmniLocationService.generateRoutePolyline(
      locationService.currentLocation,
      trip.origin.coords,
    );
    _chatMessages = [
      const ChatMessage(
        id: 'sys_start',
        sender: 'SYSTEM',
        text: 'Corrida aceita! Canal de chat seguro ativo com o passageiro.',
        timestamp: 'Agora',
      ),
    ];

    await OmniSoundService.playSuccess();
    _startAnimatedNavigation(_routePolyline, onArrive: () {
      arriveAtPickup();
    });
    notifyListeners();
  }

  void declineIncomingTrip() {
    _dispatchTimer?.cancel();
    _incomingTrip = null;
    notifyListeners();
  }

  void _startAnimatedNavigation(
    List<OmniCoordinate> poly, {
    required VoidCallback onArrive,
  }) {
    _driveTimer?.cancel();
    if (poly.length < 2) return;
    int idx = 0;
    _driveTimer = Timer.periodic(const Duration(milliseconds: 650), (timer) {
      if (idx >= poly.length - 1) {
        timer.cancel();
        onArrive();
        return;
      }
      final curr = poly[idx];
      final next = poly[idx + 1];
      _driverHeading = OmniLocationService.calculateBearing(curr, next);
      locationService.updateSimulatedPosition(next, nextHeading: _driverHeading);
      idx++;
      notifyListeners();
    });
  }

  void arriveAtPickup() {
    _driveTimer?.cancel();
    if (_activeTrip == null) return;
    _activeTrip = _activeTrip!.copyWith(status: TripStatus.driverArrived);
    _routePolyline = OmniLocationService.generateRoutePolyline(
      _activeTrip!.origin.coords,
      _activeTrip!.destination.coords,
    );
    OmniSoundService.playAlert();
    addAlert(
      'Você chegou ao embarque!',
      'Solicite o código PIN de 4 dígitos (4829) ao cliente.',
      'info',
    );
    notifyListeners();
  }

  Future<bool> verifyOtpAndBoard(String pin) async {
    final trip = _activeTrip;
    if (trip == null) return false;
    final resp = await backend.executar(
      targetMethod: 'driver_trip_validate_otp',
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
    if (_activeTrip == null) return;
    _activeTrip = _activeTrip!.copyWith(status: TripStatus.tripInProgress);
    _routePolyline = OmniLocationService.generateRoutePolyline(
      _activeTrip!.origin.coords,
      _activeTrip!.destination.coords,
    );
    _startAnimatedNavigation(_routePolyline, onArrive: () {
      completeCurrentTrip(5);
    });
    notifyListeners();
  }

  Future<void> completeCurrentTrip(int passengerRating) async {
    _driveTimer?.cancel();
    final trip = _activeTrip;
    if (trip == null) return;

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

  void finishRatingAndCloseTrip() {
    _driveTimer?.cancel();
    _activeTrip = null;
    _routePolyline = [];
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
      targetMethod: 'driver_wallet_request_pix_payout',
      arguments: {
        'amount': amount,
        'pix_key': pixKey,
        'pix_key_type': keyType,
      },
    );
    if (resp['success'] == true) {
      _driver = _driver.copyWith(walletBalance: _driver.walletBalance - amount);
      _transactions = [
        WalletTransaction(
          id: 'tx_pix_${DateTime.now().millisecondsSinceEpoch}',
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

  void submitPrivateBid(String offerId, double bidAmount) {
    if (!requireFullOnboardingGate('enviar propostas de viagens particulares')) return;
    _privateOffers = _privateOffers
        .map((o) =>
            o.id == offerId ? o.copyWith(status: 'BID_SENT', driverBid: bidAmount) : o)
        .toList();
    OmniSoundService.playSuccess();
    addAlert(
      'Proposta Enviada!',
      'Seu lance de R\$ ${bidAmount.toStringAsFixed(2)} foi enviado ao passageiro.',
      'success',
    );
    notifyListeners();
  }

  Future<void> toggleActiveVehicle(String vehicleId) async {
    _vehicles = _vehicles
        .map((v) => v.copyWith(isActive: v.id == vehicleId))
        .toList();
    await _persistAll();
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
    if (created.isActive) {
      _vehicles = _vehicles.map((v) => v.copyWith(isActive: false)).toList();
    }
    _vehicles = [created, ..._vehicles];
    await _persistAll();
    addAlert('Veículo Adicionado',
        '${created.brand} ${created.model} cadastrado com sucesso.', 'success');
    notifyListeners();
  }

  Future<void> updateVehicle(OmniVehicle updated) async {
    final existing = _vehicles.cast<OmniVehicle?>().firstWhere(
          (v) => v?.id == updated.id,
          orElse: () => null,
        );
    final identifiersChanged = existing == null ||
        existing.plate.trim().toUpperCase() != updated.plate.trim().toUpperCase() ||
        (existing.renavam ?? '').replaceAll(RegExp(r'\D'), '') !=
            (updated.renavam ?? '').replaceAll(RegExp(r'\D'), '') ||
        (existing.chassi ?? '').trim().toUpperCase() !=
            (updated.chassi ?? '').trim().toUpperCase() ||
        existing.year != updated.year ||
        (existing.crlvExpiry ?? '') != (updated.crlvExpiry ?? '');

    var next = updated.copyWith(
      clearDeepAudit: identifiersChanged,
      deepAudit: identifiersChanged ? null : (updated.deepAudit ?? existing?.deepAudit),
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
    _vehicles = _vehicles.map((v) {
      if (v.id == next.id) return next;
      if (next.isActive) return v.copyWith(isActive: false);
      return v;
    }).toList();
    await _persistAll();
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

  Future<void> updateDriverProfile(OmniDriver updated) async {
    _driver = updated;
    await _persistAll();
    addAlert('Perfil Atualizado',
        'Dados salvos e sincronizados com segurança.', 'success');
    notifyListeners();
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

    _driver = _driver.copyWith(
      avatarBytes: ovalBytes,
      avatarFilePath: savedPath,
      capturedOvalFaceBytes: ovalBytes,
      capturedOvalFacePath: savedPath,
      selfieVerifiedAt: nowIso,
      isBiometricVerified: !anyMismatch,
      faceMatchRg: nextRgMatch,
      faceMatchCnh: nextCnhMatch,
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

    if (enrichedAudit.isAuthentic && docType == 'BACKGROUND_CHECK') {
      unawaited(runCriminalBackgroundCheck(
        ocrExcerpt: enrichedAudit.ocrTextExcerpt,
        filePath: savedPath ?? filePath,
        fileBytes: fileBytes,
        isPdf: (fileName ?? savedPath ?? '').toLowerCase().endsWith('.pdf'),
      ));
    } else if (enrichedAudit.isAuthentic && docType == 'CRLV') {
      unawaited(runVehicleDeepCheck(
        vehicleId: activeVehicle.id,
        ocrExcerpt: enrichedAudit.ocrTextExcerpt,
        filePath: savedPath ?? filePath,
        fileBytes: fileBytes,
        isPdf: (fileName ?? savedPath ?? '').toLowerCase().endsWith('.pdf'),
      ));
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

    return DocumentUploadCrossResult(
      faceMatchStatus: faceMatchStatus,
      faceMatchMessage: faceMatchMessage,
      dataMatchStatus: ext?.dataMatchStatus,
      dataMatchMessage: ext?.dataMatchSummary,
    );
  }

  void sendChatMessage(String text) {
    if (text.trim().isEmpty) return;
    _chatMessages = [
      ..._chatMessages,
      ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'DRIVER',
        text: text.trim(),
        timestamp: TimeOfDayString.now(),
      ),
    ];
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 1100), () {
      _chatMessages = [
        ..._chatMessages,
        ChatMessage(
          id: 'msg_r_${DateTime.now().millisecondsSinceEpoch}',
          sender: 'PASSENGER',
          text: 'Combinado! Já estou aguardando no ponto de embarque.',
          timestamp: TimeOfDayString.now(),
        ),
      ];
      notifyListeners();
    });
  }

  void triggerEmergencySos() {
    OmniSoundService.playAlert();
    addAlert(
      'ALERTA SOS ATIVADO!',
      'Central de Segurança OMNI 24h recebeu sua telemetria GPS em tempo real.',
      'danger',
    );
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
    unawaited(runFingerprintDocComparison(
      method: method,
      hash: resolvedHash,
      verifiedAt: nowIso,
    ));
  }

  /// Executa Checagem Inteligente e Real de Antecedentes Criminais & Idoneidade
  Future<CriminalBackgroundCheckAudit> runCriminalBackgroundCheck({
    String? ocrExcerpt,
    String? filePath,
    Uint8List? fileBytes,
    bool isPdf = false,
  }) async {
    _isRunningBackgroundCheck = true;
    notifyListeners();
    try {
      DriverDocument? findByType(String type) => _documents
          .cast<DriverDocument?>()
          .firstWhere((d) => d?.type == type, orElse: () => null);

      final cpfDoc = findByType('CPF');
      final rgDoc = findByType('RG');
      final cnhDoc = findByType('CNH_EAR') ?? findByType('CNH');
      final bgDoc = findByType('BACKGROUND_CHECK');

      final result = await OmniVisionService.runCriminalBackgroundCheck(
        driverName: _driver.name,
        cpf: _driver.cpf,
        rgNumber: _driver.rg,
        birthDate: _driver.birthDate,
        cnhNumber: _driver.cnhNumber,
        cnhCategory: _driver.cnhCategory,
        cnhExpiry: _driver.cnhExpiry,
        cnhEar: _driver.cnhEar,
        city: _driver.address?.city ?? _driver.operationalCity,
        state: _driver.address?.state ?? 'SP',
        hasApprovedCpfDoc: cpfDoc?.status == 'APPROVED',
        hasApprovedRgDoc: rgDoc?.status == 'APPROVED',
        hasApprovedCnhDoc: cnhDoc?.status == 'APPROVED',
        hasApprovedBgCheckDoc: bgDoc?.status == 'APPROVED',
        crossDocDataMatchStatus:
            cnhDoc?.aiAudit?.extractedValidation?.dataMatchStatus ??
                rgDoc?.aiAudit?.extractedValidation?.dataMatchStatus,
        bgCertOcrExcerpt: ocrExcerpt ?? bgDoc?.aiAudit?.ocrTextExcerpt,
        bgCertFilePath: filePath ?? bgDoc?.filePath,
        bgCertBytes: fileBytes ?? bgDoc?.fileBytes,
        bgCertIsPdf: isPdf ||
            ((filePath ?? bgDoc?.filePath ?? '').toLowerCase().endsWith('.pdf')),
      );

      _driver = _driver.copyWith(criminalBackgroundAudit: result);
      await _persistAll();

      if (result.status == 'APPROVED') {
        await OmniSoundService.playSuccess();
        addAlert(
          'Antecedentes Aprovados (${result.score}%)',
          'Nada Consta em PF/SINIC, TJ Estadual e TRF/BNMP (${result.protocolCode}).',
          'success',
        );
      } else {
        OmniSoundService.playAlert();
        addAlert(
          result.status == 'REJECTED'
              ? 'Restrição em Antecedentes'
              : 'Análise em Revisão',
          result.rejectionReason ?? result.summary,
          result.status == 'REJECTED' ? 'danger' : 'warning',
        );
      }

      await backend.executar(
        targetMethod: 'driver_compliance_background_check',
        arguments: {
          'driver_id': _driver.id,
          'status': result.status,
          'risk_level': result.riskLevel,
          'score': result.score,
          'protocol': result.protocolCode,
        },
      );

      return result;
    } finally {
      _isRunningBackgroundCheck = false;
      notifyListeners();
    }
  }

  /// Executa Checagem Profunda do Veículo (Documentação CRLV/RENAVAM + Roubo/Furto/RENAJUD/Leilão)
  Future<VehicleDeepAudit?> runVehicleDeepCheck({
    String? vehicleId,
    String? ocrExcerpt,
    String? filePath,
    Uint8List? fileBytes,
    bool isPdf = false,
  }) async {
    if (_vehicles.isEmpty) return null;
    final target = vehicleId != null
        ? _vehicles.firstWhere(
            (v) => v.id == vehicleId,
            orElse: () => activeVehicle,
          )
        : activeVehicle;

    _isRunningVehicleDeepCheck = true;
    notifyListeners();
    try {
      final crlvDoc = _documents.cast<DriverDocument?>().firstWhere(
            (d) => d?.type == 'CRLV',
            orElse: () => null,
          );

      int parsedCrlvYear = 2026;
      final expiryStr = (target.crlvExpiry ?? '').trim();
      if (expiryStr.length >= 4) {
        final maybeYear = int.tryParse(expiryStr.substring(0, 4));
        if (maybeYear != null && maybeYear >= 2000 && maybeYear <= 2035) {
          parsedCrlvYear = maybeYear;
        }
      }

      final result = await OmniVisionService.runVehicleDeepCheck(
        vehicleType: target.type == VehicleType.moto ? 'MOTORCYCLE' : 'CAR',
        brand: target.brand,
        model: target.model,
        year: target.year,
        color: target.color,
        plate: target.plate,
        renavam: target.renavam,
        chassi: target.chassi,
        crlvYear: parsedCrlvYear,
        category: target.category.code,
        fuelType: target.fuelType,
        insuranceCompany: target.insuranceCompany,
        crlvOcrExcerpt: ocrExcerpt ?? crlvDoc?.aiAudit?.ocrTextExcerpt,
        crlvFilePath: filePath ?? crlvDoc?.filePath,
        crlvBytes: fileBytes ?? crlvDoc?.fileBytes,
        crlvIsPdf: isPdf ||
            ((filePath ?? crlvDoc?.filePath ?? '').toLowerCase().endsWith('.pdf')),
      );

      _vehicles = _vehicles
          .map((v) => v.id == target.id ? v.copyWith(deepAudit: result) : v)
          .toList();
      await _persistAll();

      if (result.status == 'APPROVED') {
        await OmniSoundService.playSuccess();
        addAlert(
          'Veículo Aprovado (${result.score}%)',
          '${target.brand} ${target.model} (${target.plate}) sem Roubo/Furto, RENAJUD ou Leilão (${result.protocolCode}).',
          'success',
        );
      } else {
        OmniSoundService.playAlert();
        addAlert(
          result.status == 'REJECTED'
              ? 'Veículo com Restrição'
              : 'Vistoria em Revisão',
          result.rejectionReason ?? result.summary,
          result.status == 'REJECTED' ? 'danger' : 'warning',
        );
      }

      await backend.executar(
        targetMethod: 'driver_vehicle_deep_check',
        arguments: {
          'driver_id': _driver.id,
          'vehicle_id': target.id,
          'plate': target.plate,
          'status': result.status,
          'risk_level': result.riskLevel,
          'score': result.score,
          'protocol': result.protocolCode,
        },
      );

      return result;
    } finally {
      _isRunningVehicleDeepCheck = false;
      notifyListeners();
    }
  }

  /// Libera rapidamente todas as pendências no modo de teste do Simulador (Cenário 100%)
  Future<void> unlockAllOnboardingForSimulation() async {
    final nowIso = DateTime.now().toIso8601String();
    _documents = _documents
        .map((d) => d.copyWith(
              status: 'APPROVED',
              updatedAt: 'Validado Simulação',
            ))
        .toList();
    _vehicles = _vehicles
        .map((v) => v.copyWith(
              insurancePolicy: v.insurancePolicy ?? 'OMNI-APP-2026',
              insuranceAppActive: true,
              inspection360Completed: true,
              inspection360Date: nowIso,
              deepAudit: VehicleDeepAudit(
                status: 'APPROVED',
                riskLevel: 'LOW',
                score: 97,
                protocolCode: 'OMNI-SIM-VEH',
                checkedAt: nowIso,
                theftRobberyStatus: 'CLEAR',
                judicialRenajudStatus: 'CLEAR',
                auctionSinisterStatus: 'CLEAR',
                licensingDebtsStatus: 'REGULAR',
                renavamValid: true,
                plateValid: true,
                chassiValid: true,
                summary:
                    'Vistoria veicular completa aprovada: sem Roubo/Furto, RENAJUD ou sinistro/leilão.',
                findings: const [
                  'Placa brasileira/Mercosul e RENAVAM Módulo 11 validados.',
                  'Sem registro de Roubo/Furto ou restrição judicial RENAJUD.',
                  'CRLV licenciamento regular e sem histórico de leilão.',
                ],
                resolutionTier: 1,
                engineUsed: 'Auditoria Completa OMNI (Simulação)',
              ),
            ))
        .toList();
    _driver = _driver.copyWith(
      isBiometricVerified: true,
      isFingerprintVerified: true,
      fingerprintVerifiedAt: nowIso,
      fingerprintMethod: 'DEVICE_BIOMETRIC_NATIVE',
      fingerprintHash: 'OMNI-SIM-FP-SHA256',
      fingerprintDocComparison: FingerprintDocComparison(
        status: 'MATCHED',
        score: 96,
        ridgeQuality: 'NITIDA',
        docTypeUsed: 'RG',
        protocolCode: 'OMNI-SIM-FP',
        checkedAt: nowIso,
        summary:
            'Impressão digital do aparelho vinculada com sucesso à identificação papiloscópica do RG/CNH.',
        findings: const [
          'Sensor biométrico nativo autenticado sem divergências.',
          'Polegar papiloscópico do documento íntegro e consistente.',
        ],
        resolutionTier: 1,
        engineUsed: 'Auditoria Completa OMNI (Simulação)',
      ),
      cnhEar: true,
      capturedOvalFacePath:
          _driver.capturedOvalFacePath ?? 'sim://oval_face_verified',
      selfieVerifiedAt: nowIso,
      faceMatchRg: const FaceMatchEntry(
        status: 'MATCHED',
        score: 98.4,
        analysis: 'Match facial com RG validado em modo de auditoria.',
      ),
      faceMatchCnh: const FaceMatchEntry(
        status: 'MATCHED',
        score: 97.9,
        analysis: 'Match facial com CNH validado em modo de auditoria.',
      ),
      criminalBackgroundAudit: CriminalBackgroundCheckAudit(
        status: 'APPROVED',
        riskLevel: 'LOW',
        score: 98,
        protocolCode: 'OMNI-SIM-BGC',
        checkedAt: nowIso,
        pfSinicStatus: 'CLEAR',
        tjStateStatus: 'CLEAR',
        trfBnmpStatus: 'CLEAR',
        cnhSuitabilityStatus: 'REGULAR',
        summary:
            'Idoneidade 100% confirmada: Nada Consta em PF/SINIC, TJ Estadual e TRF/BNMP.',
        findings: const [
          'PF / SINIC sem apontamentos impeditivos.',
          'TJ Estadual e TRF / BNMP sem mandados ou restrições criminais.',
          'CNH com observação EAR ativa e regular no SENATRAN.',
        ],
        resolutionTier: 1,
        engineUsed: 'Auditoria Completa OMNI (Simulação)',
      ),
      complianceRites: const ComplianceRites(
        acceptedTerms: true,
        acceptedPrivacyLgpd: true,
        acceptedZeroTolerance: true,
        completedSafetyBriefing: true,
        termsVersion: 'OMNI-BR-2025.2',
        signatureHash: 'OMNI-SIM-100',
      ),
    );
    await _persistAll();
    notifyListeners();
  }

  @override
  void dispose() {
    _dispatchTimer?.cancel();
    _driveTimer?.cancel();
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
