import 'dart:typed_data';

/// Modelos Canônicos OMNI Mobilidade Urbana — 1:1 com src/types/omni.ts

enum TripStatus {
  idle('IDLE'),
  searching('SEARCHING'),
  dispatching('DISPATCHING'),
  accepted('ACCEPTED'),
  driverEnRoute('DRIVER_EN_ROUTE'),
  driverArrived('DRIVER_ARRIVED'),
  boardingConfirmed('BOARDING_CONFIRMED'),
  tripInProgress('TRIP_IN_PROGRESS'),
  completed('COMPLETED'),
  cancelled('CANCELLED');

  final String code;
  const TripStatus(this.code);
}

enum VehicleType {
  car('CAR'),
  moto('MOTO');

  final String code;
  const VehicleType(this.code);
}

enum VehicleCategory {
  omniX('OMNI_X'),
  omniComfort('OMNI_COMFORT'),
  omniBlack('OMNI_BLACK'),
  omniMoto('OMNI_MOTO'),
  omniFlashDelivery('OMNI_FLASH_DELIVERY');

  final String code;
  const VehicleCategory(this.code);
}

enum PaymentMethod {
  pix('PIX'),
  creditCard('CREDIT_CARD'),
  cash('CASH'),
  wallet('WALLET');

  final String code;
  const PaymentMethod(this.code);
}

enum MainTab {
  map('map'),
  privateTrips('private_trips'),
  wallet('wallet'),
  clube('clube'),
  profile('profile'),
  simulator('simulator');

  final String id;
  const MainTab(this.id);
}

enum ProfileSubTab {
  personal('personal'),
  documents('documents'),
  vehicles('vehicles'),
  terms('terms');

  final String id;
  const ProfileSubTab(this.id);
}

class OmniCoordinate {
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final bool isApproximateOnly;

  const OmniCoordinate({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.isApproximateOnly = false,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        if (accuracyMeters != null) 'accuracy_meters': accuracyMeters,
        'is_approximate_only': isApproximateOnly,
      };

  factory OmniCoordinate.fromJson(Map<String, dynamic> json) => OmniCoordinate(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        accuracyMeters: (json['accuracy_meters'] as num?)?.toDouble(),
        isApproximateOnly: json['is_approximate_only'] as bool? ?? false,
      );
}

enum GpsFixQuality {
  precise,
  approximate,
  searching,
  unavailable,
}

class ReverseGeocodedAddress {
  final String cep;
  final String street;
  final String number;
  final String neighborhood;
  final String city;
  final String state;
  final String source;
  final double? accuracyMeters;

  const ReverseGeocodedAddress({
    this.cep = '',
    this.street = '',
    this.number = '',
    this.neighborhood = '',
    this.city = '',
    this.state = '',
    this.source = 'nominatim',
    this.accuracyMeters,
  });

  String get streetAndNumber {
    if (street.isEmpty) return '';
    if (number.isEmpty || number.toUpperCase() == 'S/N') return street;
    return '$street, $number';
  }

  String get formattedStreetLine => streetAndNumber;

  String get formattedLine {
    final parts = <String>[
      if (streetAndNumber.isNotEmpty) streetAndNumber,
      if (neighborhood.isNotEmpty) neighborhood,
      if (city.isNotEmpty) (state.isNotEmpty ? '$city - $state' : city),
    ];
    return parts.isEmpty ? 'Localização selecionada no mapa' : parts.join(' • ');
  }

  Map<String, String> toMap() => {
        'cep': cep,
        'street': street,
        'number': number,
        'neighborhood': neighborhood,
        'city': city,
        'state': state,
        'source': source,
      };
}

class OmniPlace {
  final String address;
  final String shortName;
  final OmniCoordinate coords;

  const OmniPlace({
    required this.address,
    required this.shortName,
    required this.coords,
  });
}

class OmniPassenger {
  final String id;
  final String name;
  final double rating;
  final int totalTrips;
  final String avatarUrl;
  final String phoneMasked;

  const OmniPassenger({
    required this.id,
    required this.name,
    required this.rating,
    required this.totalTrips,
    required this.avatarUrl,
    required this.phoneMasked,
  });
}

class DeliveryDetails {
  final String packageType;
  final double weightKg;
  final String recipientName;
  final String instructions;
  final bool requiresSignature;

  const DeliveryDetails({
    required this.packageType,
    required this.weightKg,
    required this.recipientName,
    required this.instructions,
    required this.requiresSignature,
  });
}

class OmniTrip {
  final String tripId;
  final TripStatus status;
  final String type; // 'PASSENGER' | 'DELIVERY' | 'PRIVATE_CHARTER'
  final VehicleCategory category;
  final OmniPassenger passenger;
  final OmniPlace origin;
  final OmniPlace destination;
  final double distanceKm;
  final int estimatedMinutes;
  final double fareTotal;
  final double driverNetEarnings;
  final double platformFee;
  final PaymentMethod paymentMethod;
  final String otpPin;
  final double surgeMultiplier;
  final String createdAt;
  final DeliveryDetails? deliveryDetails;
  final String? scheduledTime;
  final String? notes;

  const OmniTrip({
    required this.tripId,
    required this.status,
    required this.type,
    required this.category,
    required this.passenger,
    required this.origin,
    required this.destination,
    required this.distanceKm,
    required this.estimatedMinutes,
    required this.fareTotal,
    required this.driverNetEarnings,
    required this.platformFee,
    required this.paymentMethod,
    required this.otpPin,
    required this.surgeMultiplier,
    required this.createdAt,
    this.deliveryDetails,
    this.scheduledTime,
    this.notes,
  });

  OmniTrip copyWith({
    TripStatus? status,
  }) {
    return OmniTrip(
      tripId: tripId,
      status: status ?? this.status,
      type: type,
      category: category,
      passenger: passenger,
      origin: origin,
      destination: destination,
      distanceKm: distanceKm,
      estimatedMinutes: estimatedMinutes,
      fareTotal: fareTotal,
      driverNetEarnings: driverNetEarnings,
      platformFee: platformFee,
      paymentMethod: paymentMethod,
      otpPin: otpPin,
      surgeMultiplier: surgeMultiplier,
      createdAt: createdAt,
      deliveryDetails: deliveryDetails,
      scheduledTime: scheduledTime,
      notes: notes,
    );
  }
}

/// Estado individual de Match Facial Cruzado (Selfie Oval vs RG / CNH) — 1:1 com FaceMatchEntry em types/omni.ts
class FaceMatchEntry {
  final String status; // 'PENDING' | 'WAITING_FACE' | 'WAITING_DOC' | 'MATCHED' | 'MISMATCH'
  final double? score;
  final String? analysis;
  final String? updatedAt;

  const FaceMatchEntry({
    required this.status,
    this.score,
    this.analysis,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'status': status,
        'score': score,
        'analysis': analysis,
        'updatedAt': updatedAt,
      };

  factory FaceMatchEntry.fromJson(Map<String, dynamic> json) => FaceMatchEntry(
        status: json['status'] as String? ?? 'PENDING',
        score: (json['score'] as num?)?.toDouble(),
        analysis: json['analysis'] as String?,
        updatedAt: json['updatedAt'] as String?,
      );
}

class DriverAddress {
  final String cep;
  final String street;
  final String number;
  final String? complement;
  final String neighborhood;
  final String city;
  final String state;

  const DriverAddress({
    required this.cep,
    required this.street,
    required this.number,
    this.complement,
    required this.neighborhood,
    required this.city,
    required this.state,
  });

  DriverAddress copyWith({
    String? cep,
    String? street,
    String? number,
    String? complement,
    String? neighborhood,
    String? city,
    String? state,
  }) =>
      DriverAddress(
        cep: cep ?? this.cep,
        street: street ?? this.street,
        number: number ?? this.number,
        complement: complement ?? this.complement,
        neighborhood: neighborhood ?? this.neighborhood,
        city: city ?? this.city,
        state: state ?? this.state,
      );

  Map<String, dynamic> toJson() => {
        'cep': cep,
        'street': street,
        'number': number,
        'complement': complement,
        'neighborhood': neighborhood,
        'city': city,
        'state': state,
      };

  factory DriverAddress.fromJson(Map<String, dynamic> json) => DriverAddress(
        cep: json['cep'] as String? ?? '',
        street: json['street'] as String? ?? '',
        number: json['number'] as String? ?? '',
        complement: json['complement'] as String?,
        neighborhood: json['neighborhood'] as String? ?? '',
        city: json['city'] as String? ?? '',
        state: json['state'] as String? ?? '',
      );
}

class DriverEmergencyContact {
  final String name;
  final String relationship;
  final String phone;

  const DriverEmergencyContact({
    required this.name,
    required this.relationship,
    required this.phone,
  });

  DriverEmergencyContact copyWith({
    String? name,
    String? relationship,
    String? phone,
  }) =>
      DriverEmergencyContact(
        name: name ?? this.name,
        relationship: relationship ?? this.relationship,
        phone: phone ?? this.phone,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'relationship': relationship,
        'phone': phone,
      };

  factory DriverEmergencyContact.fromJson(Map<String, dynamic> json) =>
      DriverEmergencyContact(
        name: json['name'] as String? ?? '',
        relationship: json['relationship'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
      );
}

class DriverBankPayout {
  final String pixKeyType; // 'CPF' | 'EMAIL' | 'PHONE' | 'RANDOM'
  final String pixKey;
  final String bankName;
  final String agency;
  final String account;
  final String accountType; // 'CORRENTE' | 'POUPANCA'

  const DriverBankPayout({
    required this.pixKeyType,
    required this.pixKey,
    required this.bankName,
    required this.agency,
    required this.account,
    required this.accountType,
  });

  DriverBankPayout copyWith({
    String? pixKeyType,
    String? pixKey,
    String? bankName,
    String? agency,
    String? account,
    String? accountType,
  }) =>
      DriverBankPayout(
        pixKeyType: pixKeyType ?? this.pixKeyType,
        pixKey: pixKey ?? this.pixKey,
        bankName: bankName ?? this.bankName,
        agency: agency ?? this.agency,
        account: account ?? this.account,
        accountType: accountType ?? this.accountType,
      );

  Map<String, dynamic> toJson() => {
        'pixKeyType': pixKeyType,
        'pixKey': pixKey,
        'bankName': bankName,
        'agency': agency,
        'account': account,
        'accountType': accountType,
      };

  factory DriverBankPayout.fromJson(Map<String, dynamic> json) =>
      DriverBankPayout(
        pixKeyType: json['pixKeyType'] as String? ?? 'CPF',
        pixKey: json['pixKey'] as String? ?? '',
        bankName: json['bankName'] as String? ?? '',
        agency: json['agency'] as String? ?? '',
        account: json['account'] as String? ?? '',
        accountType: json['accountType'] as String? ?? 'CORRENTE',
      );
}

class DriverWorkPreferences {
  final bool acceptsPassengers;
  final bool acceptsDeliveries;
  final bool acceptsPrivateTrips;
  final bool acceptsCash;
  final bool acceptsPets;
  final bool acceptsLargeLuggage;
  final bool hasEar;
  final double maxRadiusKm;

  const DriverWorkPreferences({
    required this.acceptsPassengers,
    required this.acceptsDeliveries,
    required this.acceptsPrivateTrips,
    required this.acceptsCash,
    this.acceptsPets = true,
    this.acceptsLargeLuggage = true,
    required this.hasEar,
    required this.maxRadiusKm,
  });

  DriverWorkPreferences copyWith({
    bool? acceptsPassengers,
    bool? acceptsDeliveries,
    bool? acceptsPrivateTrips,
    bool? acceptsCash,
    bool? acceptsPets,
    bool? acceptsLargeLuggage,
    bool? hasEar,
    double? maxRadiusKm,
  }) =>
      DriverWorkPreferences(
        acceptsPassengers: acceptsPassengers ?? this.acceptsPassengers,
        acceptsDeliveries: acceptsDeliveries ?? this.acceptsDeliveries,
        acceptsPrivateTrips: acceptsPrivateTrips ?? this.acceptsPrivateTrips,
        acceptsCash: acceptsCash ?? this.acceptsCash,
        acceptsPets: acceptsPets ?? this.acceptsPets,
        acceptsLargeLuggage: acceptsLargeLuggage ?? this.acceptsLargeLuggage,
        hasEar: hasEar ?? this.hasEar,
        maxRadiusKm: maxRadiusKm ?? this.maxRadiusKm,
      );

  Map<String, dynamic> toJson() => {
        'acceptsPassengers': acceptsPassengers,
        'acceptsDeliveries': acceptsDeliveries,
        'acceptsPrivateTrips': acceptsPrivateTrips,
        'acceptsCash': acceptsCash,
        'acceptsPets': acceptsPets,
        'acceptsLargeLuggage': acceptsLargeLuggage,
        'hasEar': hasEar,
        'maxRadiusKm': maxRadiusKm,
      };

  factory DriverWorkPreferences.fromJson(Map<String, dynamic> json) =>
      DriverWorkPreferences(
        acceptsPassengers: json['acceptsPassengers'] as bool? ?? true,
        acceptsDeliveries: json['acceptsDeliveries'] as bool? ?? true,
        acceptsPrivateTrips: json['acceptsPrivateTrips'] as bool? ?? true,
        acceptsCash: json['acceptsCash'] as bool? ?? true,
        acceptsPets: json['acceptsPets'] as bool? ?? true,
        acceptsLargeLuggage: json['acceptsLargeLuggage'] as bool? ?? true,
        hasEar: json['hasEar'] as bool? ?? true,
        maxRadiusKm: (json['maxRadiusKm'] as num?)?.toDouble() ?? 12.0,
      );
}

class ComplianceRites {
  final bool acceptedTerms;
  final bool acceptedPrivacyLgpd;
  final bool acceptedZeroTolerance;
  final bool completedSafetyBriefing;
  final String? signedAt;
  final String? termsVersion;
  final String? signatureHash;

  const ComplianceRites({
    required this.acceptedTerms,
    required this.acceptedPrivacyLgpd,
    required this.acceptedZeroTolerance,
    required this.completedSafetyBriefing,
    this.signedAt,
    this.termsVersion,
    this.signatureHash,
  });

  ComplianceRites copyWith({
    bool? acceptedTerms,
    bool? acceptedPrivacyLgpd,
    bool? acceptedZeroTolerance,
    bool? completedSafetyBriefing,
    String? signedAt,
    String? termsVersion,
    String? signatureHash,
  }) =>
      ComplianceRites(
        acceptedTerms: acceptedTerms ?? this.acceptedTerms,
        acceptedPrivacyLgpd: acceptedPrivacyLgpd ?? this.acceptedPrivacyLgpd,
        acceptedZeroTolerance:
            acceptedZeroTolerance ?? this.acceptedZeroTolerance,
        completedSafetyBriefing:
            completedSafetyBriefing ?? this.completedSafetyBriefing,
        signedAt: signedAt ?? this.signedAt,
        termsVersion: termsVersion ?? this.termsVersion,
        signatureHash: signatureHash ?? this.signatureHash,
      );

  Map<String, dynamic> toJson() => {
        'acceptedTerms': acceptedTerms,
        'acceptedPrivacyLgpd': acceptedPrivacyLgpd,
        'acceptedZeroTolerance': acceptedZeroTolerance,
        'completedSafetyBriefing': completedSafetyBriefing,
        'signedAt': signedAt,
        'termsVersion': termsVersion,
        'signatureHash': signatureHash,
      };

  factory ComplianceRites.fromJson(Map<String, dynamic> json) =>
      ComplianceRites(
        acceptedTerms: json['acceptedTerms'] as bool? ?? false,
        acceptedPrivacyLgpd: json['acceptedPrivacyLgpd'] as bool? ?? false,
        acceptedZeroTolerance: json['acceptedZeroTolerance'] as bool? ?? false,
        completedSafetyBriefing:
            json['completedSafetyBriefing'] as bool? ?? false,
        signedAt: json['signedAt'] as String?,
        termsVersion: json['termsVersion'] as String?,
        signatureHash: json['signatureHash'] as String?,
      );
}

class OmniDriver {
  final String id;
  final String name;
  final String cpf;
  final String? rg;
  final String? rgIssuer;
  final String? birthDate;
  final String? email;
  final String phone;
  final String cnhNumber;
  final String? cnhCategory;
  final String cnhExpiry;
  final String? cnhIssueState;
  final bool cnhEar;
  final String? operationalCity;
  final String? bio;
  final DriverAddress? address;
  final DriverEmergencyContact? emergencyContact;
  final DriverBankPayout? bankPayout;
  final DriverWorkPreferences? workPreferences;
  final ComplianceRites? complianceRites;
  final double rating;
  final double acceptanceRate;
  final double cancellationRate;
  final int totalTrips;
  final String clubTier; // 'INICIAL' | 'PRATA' | 'OURO' | 'PLATINA' | 'ELITE'
  final String avatarUrl;
  final String? avatarFilePath;
  final Uint8List? avatarBytes;
  final String? capturedOvalFacePath;
  final Uint8List? capturedOvalFaceBytes;
  final String? biometricDocumentPath;
  final Uint8List? biometricDocumentBytes;
  final String? selfieVerifiedAt;
  final double? biometricScore;
  final String? biometricAnalysis;
  final FaceMatchEntry? faceMatchRg;
  final FaceMatchEntry? faceMatchCnh;
  final bool isOnline;
  final bool isBiometricVerified;
  final bool isFingerprintVerified;
  final String? fingerprintVerifiedAt;
  final String? fingerprintMethod;
  final String? fingerprintHash;
  final double walletBalance;
  final double todayEarnings;
  final int todayTripsCount;
  final double onlineHoursToday;
  final String referralCode;
  final int referralsCount;
  final double referralEarnings;
  final CriminalCertificateSubmission? criminalCertificate;
  final CriminalScreeningResult? criminalScreening;
  final BehavioralRiskState? behavioralRisk;
  final FingerprintDocComparison? fingerprintDocComparison;
  final String? authUid;
  final String? role;
  final bool isAppOwner;

  const OmniDriver({
    required this.id,
    required this.name,
    required this.cpf,
    this.rg,
    this.rgIssuer,
    this.birthDate,
    this.email,
    required this.phone,
    required this.cnhNumber,
    this.cnhCategory,
    required this.cnhExpiry,
    this.cnhIssueState,
    this.cnhEar = true,
    this.operationalCity,
    this.bio,
    this.address,
    this.emergencyContact,
    this.bankPayout,
    this.workPreferences,
    this.complianceRites,
    required this.rating,
    required this.acceptanceRate,
    required this.cancellationRate,
    required this.totalTrips,
    required this.clubTier,
    required this.avatarUrl,
    this.avatarFilePath,
    this.avatarBytes,
    this.capturedOvalFacePath,
    this.capturedOvalFaceBytes,
    this.biometricDocumentPath,
    this.biometricDocumentBytes,
    this.selfieVerifiedAt,
    this.biometricScore,
    this.biometricAnalysis,
    this.faceMatchRg,
    this.faceMatchCnh,
    required this.isOnline,
    required this.isBiometricVerified,
    this.isFingerprintVerified = false,
    this.fingerprintVerifiedAt,
    this.fingerprintMethod,
    this.fingerprintHash,
    required this.walletBalance,
    required this.todayEarnings,
    required this.todayTripsCount,
    required this.onlineHoursToday,
    required this.referralCode,
    required this.referralsCount,
    required this.referralEarnings,
    this.criminalCertificate,
    this.criminalScreening,
    this.behavioralRisk,
    this.fingerprintDocComparison,
    this.authUid,
    this.role,
    this.isAppOwner = false,
  });

  OmniDriver copyWith({
    String? id,
    String? name,
    String? cpf,
    String? rg,
    String? rgIssuer,
    String? birthDate,
    String? email,
    String? phone,
    String? cnhNumber,
    String? cnhCategory,
    String? cnhExpiry,
    String? cnhIssueState,
    bool? cnhEar,
    String? operationalCity,
    String? bio,
    DriverAddress? address,
    DriverEmergencyContact? emergencyContact,
    DriverBankPayout? bankPayout,
    DriverWorkPreferences? workPreferences,
    ComplianceRites? complianceRites,
    double? rating,
    double? acceptanceRate,
    double? cancellationRate,
    int? totalTrips,
    String? clubTier,
    String? avatarUrl,
    String? avatarFilePath,
    Uint8List? avatarBytes,
    String? capturedOvalFacePath,
    Uint8List? capturedOvalFaceBytes,
    String? biometricDocumentPath,
    Uint8List? biometricDocumentBytes,
    String? selfieVerifiedAt,
    double? biometricScore,
    String? biometricAnalysis,
    FaceMatchEntry? faceMatchRg,
    FaceMatchEntry? faceMatchCnh,
    bool? isOnline,
    bool? isBiometricVerified,
    bool? isFingerprintVerified,
    String? fingerprintVerifiedAt,
    String? fingerprintMethod,
    String? fingerprintHash,
    double? walletBalance,
    double? todayEarnings,
    int? todayTripsCount,
    double? onlineHoursToday,
    String? referralCode,
    int? referralsCount,
    double? referralEarnings,
    CriminalCertificateSubmission? criminalCertificate,
    CriminalScreeningResult? criminalScreening,
    BehavioralRiskState? behavioralRisk,
    FingerprintDocComparison? fingerprintDocComparison,
    String? authUid,
    String? role,
    bool? isAppOwner,
  }) {
    return OmniDriver(
      id: id ?? this.id,
      name: name ?? this.name,
      cpf: cpf ?? this.cpf,
      rg: rg ?? this.rg,
      rgIssuer: rgIssuer ?? this.rgIssuer,
      birthDate: birthDate ?? this.birthDate,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      cnhNumber: cnhNumber ?? this.cnhNumber,
      cnhCategory: cnhCategory ?? this.cnhCategory,
      cnhExpiry: cnhExpiry ?? this.cnhExpiry,
      cnhIssueState: cnhIssueState ?? this.cnhIssueState,
      cnhEar: cnhEar ?? this.cnhEar,
      operationalCity: operationalCity ?? this.operationalCity,
      bio: bio ?? this.bio,
      address: address ?? this.address,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      bankPayout: bankPayout ?? this.bankPayout,
      workPreferences: workPreferences ?? this.workPreferences,
      complianceRites: complianceRites ?? this.complianceRites,
      rating: rating ?? this.rating,
      acceptanceRate: acceptanceRate ?? this.acceptanceRate,
      cancellationRate: cancellationRate ?? this.cancellationRate,
      totalTrips: totalTrips ?? this.totalTrips,
      clubTier: clubTier ?? this.clubTier,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarFilePath: avatarFilePath ?? this.avatarFilePath,
      avatarBytes: avatarBytes ?? this.avatarBytes,
      capturedOvalFacePath: capturedOvalFacePath ?? this.capturedOvalFacePath,
      capturedOvalFaceBytes: capturedOvalFaceBytes ?? this.capturedOvalFaceBytes,
      biometricDocumentPath: biometricDocumentPath ?? this.biometricDocumentPath,
      biometricDocumentBytes:
          biometricDocumentBytes ?? this.biometricDocumentBytes,
      selfieVerifiedAt: selfieVerifiedAt ?? this.selfieVerifiedAt,
      biometricScore: biometricScore ?? this.biometricScore,
      biometricAnalysis: biometricAnalysis ?? this.biometricAnalysis,
      faceMatchRg: faceMatchRg ?? this.faceMatchRg,
      faceMatchCnh: faceMatchCnh ?? this.faceMatchCnh,
      isOnline: isOnline ?? this.isOnline,
      isBiometricVerified: isBiometricVerified ?? this.isBiometricVerified,
      isFingerprintVerified:
          isFingerprintVerified ?? this.isFingerprintVerified,
      fingerprintVerifiedAt:
          fingerprintVerifiedAt ?? this.fingerprintVerifiedAt,
      fingerprintMethod: fingerprintMethod ?? this.fingerprintMethod,
      fingerprintHash: fingerprintHash ?? this.fingerprintHash,
      walletBalance: walletBalance ?? this.walletBalance,
      todayEarnings: todayEarnings ?? this.todayEarnings,
      todayTripsCount: todayTripsCount ?? this.todayTripsCount,
      onlineHoursToday: onlineHoursToday ?? this.onlineHoursToday,
      referralCode: referralCode ?? this.referralCode,
      referralsCount: referralsCount ?? this.referralsCount,
      referralEarnings: referralEarnings ?? this.referralEarnings,
      criminalCertificate: criminalCertificate ?? this.criminalCertificate,
      criminalScreening: criminalScreening ?? this.criminalScreening,
      behavioralRisk: behavioralRisk ?? this.behavioralRisk,
      fingerprintDocComparison:
          fingerprintDocComparison ?? this.fingerprintDocComparison,
      authUid: authUid ?? this.authUid,
      role: role ?? this.role,
      isAppOwner: isAppOwner ?? this.isAppOwner,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cpf': cpf,
        'rg': rg,
        'rgIssuer': rgIssuer,
        'birthDate': birthDate,
        'email': email,
        'phone': phone,
        'cnhNumber': cnhNumber,
        'cnhCategory': cnhCategory,
        'cnhExpiry': cnhExpiry,
        'cnhIssueState': cnhIssueState,
        'cnhEar': cnhEar,
        'operationalCity': operationalCity,
        'bio': bio,
        'address': address?.toJson(),
        'emergencyContact': emergencyContact?.toJson(),
        'bankPayout': bankPayout?.toJson(),
        'workPreferences': workPreferences?.toJson(),
        'complianceRites': complianceRites?.toJson(),
        'rating': rating,
        'acceptanceRate': acceptanceRate,
        'cancellationRate': cancellationRate,
        'totalTrips': totalTrips,
        'clubTier': clubTier,
        'avatarUrl': avatarUrl,
        'avatarFilePath': avatarFilePath,
        'capturedOvalFacePath': capturedOvalFacePath,
        'biometricDocumentPath': biometricDocumentPath,
        'selfieVerifiedAt': selfieVerifiedAt,
        'biometricScore': biometricScore,
        'biometricAnalysis': biometricAnalysis,
        'faceMatchRg': faceMatchRg?.toJson(),
        'faceMatchCnh': faceMatchCnh?.toJson(),
        'isOnline': isOnline,
        'isBiometricVerified': isBiometricVerified,
        'isFingerprintVerified': isFingerprintVerified,
        'fingerprintVerifiedAt': fingerprintVerifiedAt,
        'fingerprintMethod': fingerprintMethod,
        'fingerprintHash': fingerprintHash,
        'walletBalance': walletBalance,
        'todayEarnings': todayEarnings,
        'todayTripsCount': todayTripsCount,
        'onlineHoursToday': onlineHoursToday,
        'referralCode': referralCode,
        'referralsCount': referralsCount,
        'referralEarnings': referralEarnings,
        'criminalCertificate': criminalCertificate?.toJson(),
        'criminalScreening': criminalScreening?.toJson(),
        'behavioralRisk': behavioralRisk?.toJson(),
        'fingerprintDocComparison': fingerprintDocComparison?.toJson(),
        'authUid': authUid,
        'role': role,
        'isAppOwner': isAppOwner,
      };

  factory OmniDriver.fromJson(Map<String, dynamic> json) => OmniDriver(
        id: json['id'] as String? ?? 'usr_drv_local',
        name: json['name'] as String? ?? '',
        cpf: json['cpf'] as String? ?? '',
        rg: json['rg'] as String?,
        rgIssuer: json['rgIssuer'] as String?,
        birthDate: json['birthDate'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String? ?? '',
        cnhNumber: json['cnhNumber'] as String? ?? '',
        cnhCategory: json['cnhCategory'] as String?,
        cnhExpiry: json['cnhExpiry'] as String? ?? '',
        cnhIssueState: json['cnhIssueState'] as String?,
        cnhEar: json['cnhEar'] as bool? ?? false,
        operationalCity: json['operationalCity'] as String?,
        bio: json['bio'] as String?,
        address: json['address'] is Map<String, dynamic>
            ? DriverAddress.fromJson(json['address'] as Map<String, dynamic>)
            : null,
        emergencyContact: json['emergencyContact'] is Map<String, dynamic>
            ? DriverEmergencyContact.fromJson(
                json['emergencyContact'] as Map<String, dynamic>)
            : null,
        bankPayout: json['bankPayout'] is Map<String, dynamic>
            ? DriverBankPayout.fromJson(
                json['bankPayout'] as Map<String, dynamic>)
            : null,
        workPreferences: json['workPreferences'] is Map<String, dynamic>
            ? DriverWorkPreferences.fromJson(
                json['workPreferences'] as Map<String, dynamic>)
            : null,
        complianceRites: json['complianceRites'] is Map<String, dynamic>
            ? ComplianceRites.fromJson(
                json['complianceRites'] as Map<String, dynamic>)
            : null,
        rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
        acceptanceRate: (json['acceptanceRate'] as num?)?.toDouble() ?? 100.0,
        cancellationRate: (json['cancellationRate'] as num?)?.toDouble() ?? 0.0,
        totalTrips: json['totalTrips'] as int? ?? 0,
        clubTier: json['clubTier'] as String? ?? 'INICIAL',
        avatarUrl: json['avatarUrl'] as String? ?? '',
        avatarFilePath: json['avatarFilePath'] as String?,
        capturedOvalFacePath: json['capturedOvalFacePath'] as String?,
        biometricDocumentPath: json['biometricDocumentPath'] as String?,
        selfieVerifiedAt: json['selfieVerifiedAt'] as String?,
        biometricScore: (json['biometricScore'] as num?)?.toDouble(),
        biometricAnalysis: json['biometricAnalysis'] as String?,
        faceMatchRg: json['faceMatchRg'] is Map<String, dynamic>
            ? FaceMatchEntry.fromJson(
                json['faceMatchRg'] as Map<String, dynamic>)
            : null,
        faceMatchCnh: json['faceMatchCnh'] is Map<String, dynamic>
            ? FaceMatchEntry.fromJson(
                json['faceMatchCnh'] as Map<String, dynamic>)
            : null,
        isOnline: json['isOnline'] as bool? ?? false,
        isBiometricVerified: json['isBiometricVerified'] as bool? ?? false,
        isFingerprintVerified: json['isFingerprintVerified'] as bool? ?? false,
        fingerprintVerifiedAt: json['fingerprintVerifiedAt'] as String?,
        fingerprintMethod: json['fingerprintMethod'] as String?,
        fingerprintHash: json['fingerprintHash'] as String?,
        walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 0.0,
        todayEarnings: (json['todayEarnings'] as num?)?.toDouble() ?? 0.0,
        todayTripsCount: json['todayTripsCount'] as int? ?? 0,
        onlineHoursToday: (json['onlineHoursToday'] as num?)?.toDouble() ?? 0.0,
        referralCode: json['referralCode'] as String? ?? 'OMNI-DRIVER',
        referralsCount: json['referralsCount'] as int? ?? 0,
        referralEarnings: (json['referralEarnings'] as num?)?.toDouble() ?? 0.0,
        criminalCertificate: json['criminalCertificate'] is Map<String, dynamic>
            ? CriminalCertificateSubmission.fromJson(
                json['criminalCertificate'] as Map<String, dynamic>)
            : null,
        criminalScreening: json['criminalScreening'] is Map<String, dynamic>
            ? CriminalScreeningResult.fromJson(
                json['criminalScreening'] as Map<String, dynamic>)
            : null,
        behavioralRisk: json['behavioralRisk'] is Map<String, dynamic>
            ? BehavioralRiskState.fromJson(
                json['behavioralRisk'] as Map<String, dynamic>)
            : null,
        fingerprintDocComparison:
            json['fingerprintDocComparison'] is Map<String, dynamic>
                ? FingerprintDocComparison.fromJson(
                    json['fingerprintDocComparison'] as Map<String, dynamic>)
                : null,
        authUid: json['authUid'] as String?,
        role: json['role'] as String?,
        isAppOwner: json['isAppOwner'] as bool? ?? false,
      );
}

class FingerprintDocComparison {
  final String status; // 'PENDING' | 'WAITING_DOC' | 'WAITING_HARDWARE' | 'MATCHED' | 'MISMATCH'
  final int score;
  final String ridgeQuality; // 'ALTA' | 'MEDIA' | 'BAIXA' | 'INDISPONIVEL'
  final String? docTypeUsed; // 'RG' | 'CNH_EAR'
  final String protocolCode;
  final String checkedAt;
  final String summary;
  final List<String> findings;
  final String? rejectionReason;
  final int? resolutionTier;
  final String? engineUsed;

  const FingerprintDocComparison({
    required this.status,
    required this.score,
    required this.ridgeQuality,
    this.docTypeUsed,
    required this.protocolCode,
    required this.checkedAt,
    required this.summary,
    this.findings = const [],
    this.rejectionReason,
    this.resolutionTier,
    this.engineUsed,
  });

  Map<String, dynamic> toJson() => {
        'status': status,
        'score': score,
        'ridgeQuality': ridgeQuality,
        'docTypeUsed': docTypeUsed,
        'protocolCode': protocolCode,
        'checkedAt': checkedAt,
        'summary': summary,
        'findings': findings,
        'rejectionReason': rejectionReason,
        'resolutionTier': resolutionTier,
        'engineUsed': engineUsed,
      };

  factory FingerprintDocComparison.fromJson(Map<String, dynamic> json) =>
      FingerprintDocComparison(
        status: json['status'] as String? ?? 'PENDING',
        score: (json['score'] as num?)?.toInt() ?? 0,
        ridgeQuality: json['ridgeQuality'] as String? ?? 'INDISPONIVEL',
        docTypeUsed: json['docTypeUsed'] as String?,
        protocolCode: json['protocolCode'] as String? ?? 'OMNI-FP-000',
        checkedAt:
            json['checkedAt'] as String? ?? DateTime.now().toIso8601String(),
        summary: json['summary'] as String? ?? '',
        findings: (json['findings'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        rejectionReason: json['rejectionReason'] as String?,
        resolutionTier: (json['resolutionTier'] as num?)?.toInt(),
        engineUsed: json['engineUsed'] as String?,
      );
}

class OmniVehicle {
  final String id;
  final VehicleType type;
  final VehicleCategory category;
  final String brand;
  final String model;
  final int year;
  final String plate;
  final String color;
  final int seats;
  final String? renavam;
  final String? chassi;
  final String? crlvExpiry;
  final String? fuelType;
  final String? transmission;
  final int? doors;
  final bool? hasAirConditioning;
  final bool? hasTrunkLarge;
  final bool? hasDeliveryBox;
  final bool? hasExtraHelmet;
  final int? engineCc;
  final String? insuranceCompany;
  final String? insurancePolicy;
  final bool? insuranceAppActive;
  final bool? inspection360Completed;
  final String? inspection360Date;
  final String? bodyStyle;
  final String? photoUrl;
  final String status; // 'APPROVED' | 'PENDING'
  final bool isActive;
  final String? ownershipType; // 'PROPRIO' | 'FAMILIAR' | 'TERCEIRO_AUTORIZADO' | 'LOCADORA'
  final String? ownerName;
  final String? ownerDocument;
  final String? authorizationDocPath;
  final String? authorizationDocName;
  final Uint8List? authorizationDocBytes;
  final VehicleVisualPhotos? visualPhotos;
  final VehicleScreeningResult? vehicleScreening;

  const OmniVehicle({
    required this.id,
    required this.type,
    required this.category,
    required this.brand,
    required this.model,
    required this.year,
    required this.plate,
    required this.color,
    this.seats = 4,
    this.renavam,
    this.chassi,
    this.crlvExpiry,
    this.fuelType,
    this.transmission,
    this.doors,
    this.hasAirConditioning,
    this.hasTrunkLarge,
    this.hasDeliveryBox,
    this.hasExtraHelmet,
    this.engineCc,
    this.insuranceCompany,
    this.insurancePolicy,
    this.insuranceAppActive,
    this.inspection360Completed,
    this.inspection360Date,
    this.bodyStyle,
    this.photoUrl,
    required this.status,
    required this.isActive,
    this.ownershipType,
    this.ownerName,
    this.ownerDocument,
    this.authorizationDocPath,
    this.authorizationDocName,
    this.authorizationDocBytes,
    this.visualPhotos,
    this.vehicleScreening,
  });

  OmniVehicle copyWith({
    String? id,
    VehicleType? type,
    VehicleCategory? category,
    String? brand,
    String? model,
    int? year,
    String? plate,
    String? color,
    int? seats,
    String? renavam,
    String? chassi,
    String? crlvExpiry,
    String? fuelType,
    String? transmission,
    int? doors,
    bool? hasAirConditioning,
    bool? hasTrunkLarge,
    bool? hasDeliveryBox,
    bool? hasExtraHelmet,
    int? engineCc,
    String? insuranceCompany,
    String? insurancePolicy,
    bool? insuranceAppActive,
    bool? inspection360Completed,
    String? inspection360Date,
    String? bodyStyle,
    String? photoUrl,
    String? status,
    bool? isActive,
    String? ownershipType,
    String? ownerName,
    String? ownerDocument,
    String? authorizationDocPath,
    String? authorizationDocName,
    Uint8List? authorizationDocBytes,
    VehicleVisualPhotos? visualPhotos,
    VehicleScreeningResult? vehicleScreening,
  }) {
    return OmniVehicle(
      id: id ?? this.id,
      type: type ?? this.type,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      plate: plate ?? this.plate,
      color: color ?? this.color,
      seats: seats ?? this.seats,
      renavam: renavam ?? this.renavam,
      chassi: chassi ?? this.chassi,
      crlvExpiry: crlvExpiry ?? this.crlvExpiry,
      fuelType: fuelType ?? this.fuelType,
      transmission: transmission ?? this.transmission,
      doors: doors ?? this.doors,
      hasAirConditioning: hasAirConditioning ?? this.hasAirConditioning,
      hasTrunkLarge: hasTrunkLarge ?? this.hasTrunkLarge,
      hasDeliveryBox: hasDeliveryBox ?? this.hasDeliveryBox,
      hasExtraHelmet: hasExtraHelmet ?? this.hasExtraHelmet,
      engineCc: engineCc ?? this.engineCc,
      insuranceCompany: insuranceCompany ?? this.insuranceCompany,
      insurancePolicy: insurancePolicy ?? this.insurancePolicy,
      insuranceAppActive: insuranceAppActive ?? this.insuranceAppActive,
      inspection360Completed:
          inspection360Completed ?? this.inspection360Completed,
      inspection360Date: inspection360Date ?? this.inspection360Date,
      bodyStyle: bodyStyle ?? this.bodyStyle,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      ownershipType: ownershipType ?? this.ownershipType,
      ownerName: ownerName ?? this.ownerName,
      ownerDocument: ownerDocument ?? this.ownerDocument,
      authorizationDocPath: authorizationDocPath ?? this.authorizationDocPath,
      authorizationDocName: authorizationDocName ?? this.authorizationDocName,
      authorizationDocBytes:
          authorizationDocBytes ?? this.authorizationDocBytes,
      visualPhotos: visualPhotos ?? this.visualPhotos,
      vehicleScreening: vehicleScreening ?? this.vehicleScreening,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.code,
        'category': category.code,
        'brand': brand,
        'model': model,
        'year': year,
        'plate': plate,
        'color': color,
        'seats': seats,
        'renavam': renavam,
        'chassi': chassi,
        'crlvExpiry': crlvExpiry,
        'fuelType': fuelType,
        'transmission': transmission,
        'doors': doors,
        'hasAirConditioning': hasAirConditioning,
        'hasTrunkLarge': hasTrunkLarge,
        'hasDeliveryBox': hasDeliveryBox,
        'hasExtraHelmet': hasExtraHelmet,
        'engineCc': engineCc,
        'insuranceCompany': insuranceCompany,
        'insurancePolicy': insurancePolicy,
        'insuranceAppActive': insuranceAppActive,
        'inspection360Completed': inspection360Completed,
        'inspection360Date': inspection360Date,
        'bodyStyle': bodyStyle,
        'photoUrl': photoUrl,
        'status': status,
        'isActive': isActive,
        'ownershipType': ownershipType,
        'ownerName': ownerName,
        'ownerDocument': ownerDocument,
        'authorizationDocPath': authorizationDocPath,
        'authorizationDocName': authorizationDocName,
        'visualPhotos': visualPhotos?.toJson(),
        'vehicleScreening': vehicleScreening?.toJson(),
      };

  factory OmniVehicle.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'CAR';
    final catStr = json['category'] as String? ?? 'OMNI_X';
    return OmniVehicle(
      id: json['id'] as String? ?? 'veh_${DateTime.now().millisecondsSinceEpoch}',
      type: typeStr == 'MOTO' ? VehicleType.moto : VehicleType.car,
      category: VehicleCategory.values.firstWhere(
        (c) => c.code == catStr,
        orElse: () => VehicleCategory.omniX,
      ),
      brand: json['brand'] as String? ?? '',
      model: json['model'] as String? ?? '',
      year: json['year'] as int? ?? 2023,
      plate: json['plate'] as String? ?? '',
      color: json['color'] as String? ?? '',
      seats: json['seats'] as int? ?? (typeStr == 'MOTO' ? 1 : 4),
      renavam: json['renavam'] as String?,
      chassi: json['chassi'] as String?,
      crlvExpiry: json['crlvExpiry'] as String?,
      fuelType: json['fuelType'] as String?,
      transmission: json['transmission'] as String?,
      doors: json['doors'] as int?,
      hasAirConditioning: json['hasAirConditioning'] as bool?,
      hasTrunkLarge: json['hasTrunkLarge'] as bool?,
      hasDeliveryBox: json['hasDeliveryBox'] as bool?,
      hasExtraHelmet: json['hasExtraHelmet'] as bool?,
      engineCc: json['engineCc'] as int?,
      insuranceCompany: json['insuranceCompany'] as String?,
      insurancePolicy: json['insurancePolicy'] as String?,
      insuranceAppActive: json['insuranceAppActive'] as bool?,
      inspection360Completed: json['inspection360Completed'] as bool?,
      inspection360Date: json['inspection360Date'] as String?,
      bodyStyle: json['bodyStyle'] as String?,
      photoUrl: json['photoUrl'] as String?,
      status: json['status'] as String? ?? 'APPROVED',
      isActive: json['isActive'] as bool? ?? false,
      ownershipType: json['ownershipType'] as String?,
      ownerName: json['ownerName'] as String?,
      ownerDocument: json['ownerDocument'] as String?,
      authorizationDocPath: json['authorizationDocPath'] as String?,
      authorizationDocName: json['authorizationDocName'] as String?,
      visualPhotos: json['visualPhotos'] is Map<String, dynamic>
          ? VehicleVisualPhotos.fromJson(
              json['visualPhotos'] as Map<String, dynamic>)
          : null,
      vehicleScreening: json['vehicleScreening'] is Map<String, dynamic>
          ? VehicleScreeningResult.fromJson(
              json['vehicleScreening'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ExtractedDocumentValidation {
  final bool? cpfValid;
  final String? cpfMasked;
  final String? cpfDigits;
  final bool? rgValid;
  final String? rgMasked;
  final String? rgNumber;
  final String? rgIssuer;
  final bool? cnhRegistryValid;
  final String? cnhRegistryMasked;
  final String? cnhRegistryDigits;
  final String? cnhCategory;
  final bool? cnhCategoryQualified;
  final bool? cnhCarQualified;
  final bool? cnhMotoQualified;
  final bool? cnhHasEar;
  final String? cnhExpiryIso;
  final String? fullName;
  final String? birthDateIso;
  final String? birthDateBr;
  final String? dataMatchStatus; // 'FIRST_DOC' | 'MATCHED' | 'MISMATCH'
  final String? dataMatchSummary;
  final List<String>? matchedFields;

  const ExtractedDocumentValidation({
    this.cpfValid,
    this.cpfMasked,
    this.cpfDigits,
    this.rgValid,
    this.rgMasked,
    this.rgNumber,
    this.rgIssuer,
    this.cnhRegistryValid,
    this.cnhRegistryMasked,
    this.cnhRegistryDigits,
    this.cnhCategory,
    this.cnhCategoryQualified,
    this.cnhCarQualified,
    this.cnhMotoQualified,
    this.cnhHasEar,
    this.cnhExpiryIso,
    this.fullName,
    this.birthDateIso,
    this.birthDateBr,
    this.dataMatchStatus,
    this.dataMatchSummary,
    this.matchedFields,
  });

  ExtractedDocumentValidation copyWith({
    bool? cpfValid,
    String? cpfMasked,
    String? cpfDigits,
    bool? rgValid,
    String? rgMasked,
    String? rgNumber,
    String? rgIssuer,
    bool? cnhRegistryValid,
    String? cnhRegistryMasked,
    String? cnhRegistryDigits,
    String? cnhCategory,
    bool? cnhCategoryQualified,
    bool? cnhCarQualified,
    bool? cnhMotoQualified,
    bool? cnhHasEar,
    String? cnhExpiryIso,
    String? fullName,
    String? birthDateIso,
    String? birthDateBr,
    String? dataMatchStatus,
    String? dataMatchSummary,
    List<String>? matchedFields,
  }) =>
      ExtractedDocumentValidation(
        cpfValid: cpfValid ?? this.cpfValid,
        cpfMasked: cpfMasked ?? this.cpfMasked,
        cpfDigits: cpfDigits ?? this.cpfDigits,
        rgValid: rgValid ?? this.rgValid,
        rgMasked: rgMasked ?? this.rgMasked,
        rgNumber: rgNumber ?? this.rgNumber,
        rgIssuer: rgIssuer ?? this.rgIssuer,
        cnhRegistryValid: cnhRegistryValid ?? this.cnhRegistryValid,
        cnhRegistryMasked: cnhRegistryMasked ?? this.cnhRegistryMasked,
        cnhRegistryDigits: cnhRegistryDigits ?? this.cnhRegistryDigits,
        cnhCategory: cnhCategory ?? this.cnhCategory,
        cnhCategoryQualified: cnhCategoryQualified ?? this.cnhCategoryQualified,
        cnhCarQualified: cnhCarQualified ?? this.cnhCarQualified,
        cnhMotoQualified: cnhMotoQualified ?? this.cnhMotoQualified,
        cnhHasEar: cnhHasEar ?? this.cnhHasEar,
        cnhExpiryIso: cnhExpiryIso ?? this.cnhExpiryIso,
        fullName: fullName ?? this.fullName,
        birthDateIso: birthDateIso ?? this.birthDateIso,
        birthDateBr: birthDateBr ?? this.birthDateBr,
        dataMatchStatus: dataMatchStatus ?? this.dataMatchStatus,
        dataMatchSummary: dataMatchSummary ?? this.dataMatchSummary,
        matchedFields: matchedFields ?? this.matchedFields,
      );

  Map<String, dynamic> toJson() => {
        'cpfValid': cpfValid,
        'cpfMasked': cpfMasked,
        'cpfDigits': cpfDigits,
        'rgValid': rgValid,
        'rgMasked': rgMasked,
        'rgNumber': rgNumber,
        'rgIssuer': rgIssuer,
        'cnhRegistryValid': cnhRegistryValid,
        'cnhRegistryMasked': cnhRegistryMasked,
        'cnhRegistryDigits': cnhRegistryDigits,
        'cnhCategory': cnhCategory,
        'cnhCategoryQualified': cnhCategoryQualified,
        'cnhCarQualified': cnhCarQualified,
        'cnhMotoQualified': cnhMotoQualified,
        'cnhHasEar': cnhHasEar,
        'cnhExpiryIso': cnhExpiryIso,
        'fullName': fullName,
        'birthDateIso': birthDateIso,
        'birthDateBr': birthDateBr,
        'dataMatchStatus': dataMatchStatus,
        'dataMatchSummary': dataMatchSummary,
        'matchedFields': matchedFields,
      };

  factory ExtractedDocumentValidation.fromJson(Map<String, dynamic> json) =>
      ExtractedDocumentValidation(
        cpfValid: json['cpfValid'] as bool?,
        cpfMasked: json['cpfMasked'] as String?,
        cpfDigits: json['cpfDigits'] as String?,
        rgValid: json['rgValid'] as bool?,
        rgMasked: json['rgMasked'] as String?,
        rgNumber: json['rgNumber'] as String?,
        rgIssuer: json['rgIssuer'] as String?,
        cnhRegistryValid: json['cnhRegistryValid'] as bool?,
        cnhRegistryMasked: json['cnhRegistryMasked'] as String?,
        cnhRegistryDigits: json['cnhRegistryDigits'] as String?,
        cnhCategory: json['cnhCategory'] as String?,
        cnhCategoryQualified: json['cnhCategoryQualified'] as bool?,
        cnhCarQualified: json['cnhCarQualified'] as bool?,
        cnhMotoQualified: json['cnhMotoQualified'] as bool?,
        cnhHasEar: json['cnhHasEar'] as bool?,
        cnhExpiryIso: json['cnhExpiryIso'] as String?,
        fullName: json['fullName'] as String?,
        birthDateIso: json['birthDateIso'] as String?,
        birthDateBr: json['birthDateBr'] as String?,
        dataMatchStatus: json['dataMatchStatus'] as String?,
        dataMatchSummary: json['dataMatchSummary'] as String?,
        matchedFields: (json['matchedFields'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList(),
      );
}

/// Resultado real da Auditoria Documental Antifraude — 1:1 com DocumentAiAuditResult em types/omni.ts
class DocumentAiAuditResult {
  final bool isAuthentic;
  final bool matchesExpectedType;
  final String documentTypeDetected;
  final int integrityScore; // 0..100
  final String fraudRisk; // 'LOW' | 'MEDIUM' | 'HIGH'
  final bool hasHolderPhoto;
  final List<String> detectedDetails;
  final String? ocrTextExcerpt;
  final String? rejectionReason;
  final int? resolutionTier; // 1 | 2 | 3
  final String? engineUsed;
  final ExtractedDocumentValidation? extractedValidation;

  const DocumentAiAuditResult({
    required this.isAuthentic,
    required this.matchesExpectedType,
    required this.documentTypeDetected,
    required this.integrityScore,
    required this.fraudRisk,
    required this.hasHolderPhoto,
    required this.detectedDetails,
    this.ocrTextExcerpt,
    this.rejectionReason,
    this.resolutionTier,
    this.engineUsed,
    this.extractedValidation,
  });

  bool get isValid => isAuthentic;

  Map<String, dynamic> toJson() => {
        'isAuthentic': isAuthentic,
        'matchesExpectedType': matchesExpectedType,
        'documentTypeDetected': documentTypeDetected,
        'integrityScore': integrityScore,
        'fraudRisk': fraudRisk,
        'hasHolderPhoto': hasHolderPhoto,
        'detectedDetails': detectedDetails,
        'ocrTextExcerpt': ocrTextExcerpt,
        'rejectionReason': rejectionReason,
        'resolutionTier': resolutionTier,
        'engineUsed': engineUsed,
        'extractedValidation': extractedValidation?.toJson(),
      };

  factory DocumentAiAuditResult.fromJson(Map<String, dynamic> json) =>
      DocumentAiAuditResult(
        isAuthentic: json['isAuthentic'] as bool? ?? false,
        matchesExpectedType: json['matchesExpectedType'] as bool? ?? false,
        documentTypeDetected:
            json['documentTypeDetected'] as String? ?? 'UNKNOWN',
        integrityScore: (json['integrityScore'] as num?)?.round() ?? 0,
        fraudRisk: json['fraudRisk'] as String? ?? 'HIGH',
        hasHolderPhoto: json['hasHolderPhoto'] as bool? ?? false,
        detectedDetails: (json['detectedDetails'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        ocrTextExcerpt: json['ocrTextExcerpt'] as String?,
        rejectionReason: json['rejectionReason'] as String?,
        resolutionTier: json['resolutionTier'] as int?,
        engineUsed: json['engineUsed'] as String?,
        extractedValidation:
            json['extractedValidation'] is Map<String, dynamic>
                ? ExtractedDocumentValidation.fromJson(
                    json['extractedValidation'] as Map<String, dynamic>)
                : null,
      );
}

class DriverDocument {
  final String id;
  final String name;
  // Tipos canônicos: 'CPF' | 'RG' | 'CNH_EAR' | 'CRLV' | 'BACKGROUND_CHECK' | 'RESIDENCE_PROOF' | 'PROFILE_PHOTO' | 'BIOMETRIC_VALIDATION'
  final String type;
  final String status; // 'APPROVED' | 'PENDING' | 'REJECTED' | 'EXPIRING_SOON'
  final String? expiryDate;
  final String updatedAt;
  final String? fileUrl;
  final String? filePath;
  final Uint8List? fileBytes;
  final String? faceFileUrl;
  final String? faceFilePath;
  final Uint8List? faceFileBytes;
  final String? fileName;
  final DocumentAiAuditResult? aiAudit;

  const DriverDocument({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    this.expiryDate,
    required this.updatedAt,
    this.fileUrl,
    this.filePath,
    this.fileBytes,
    this.faceFileUrl,
    this.faceFilePath,
    this.faceFileBytes,
    this.fileName,
    this.aiAudit,
  });

  DriverDocument copyWith({
    String? name,
    String? status,
    String? updatedAt,
    String? fileUrl,
    String? filePath,
    Uint8List? fileBytes,
    String? faceFileUrl,
    String? faceFilePath,
    Uint8List? faceFileBytes,
    String? fileName,
    DocumentAiAuditResult? aiAudit,
  }) =>
      DriverDocument(
        id: id,
        name: name ?? this.name,
        type: type,
        status: status ?? this.status,
        expiryDate: expiryDate,
        updatedAt: updatedAt ?? this.updatedAt,
        fileUrl: fileUrl ?? this.fileUrl,
        filePath: filePath ?? this.filePath,
        fileBytes: fileBytes ?? this.fileBytes,
        faceFileUrl: faceFileUrl ?? this.faceFileUrl,
        faceFilePath: faceFilePath ?? this.faceFilePath,
        faceFileBytes: faceFileBytes ?? this.faceFileBytes,
        fileName: fileName ?? this.fileName,
        aiAudit: aiAudit ?? this.aiAudit,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'status': status,
        'expiryDate': expiryDate,
        'updatedAt': updatedAt,
        'fileUrl': fileUrl,
        'filePath': filePath,
        'faceFileUrl': faceFileUrl,
        'faceFilePath': faceFilePath,
        'fileName': fileName,
        'aiAudit': aiAudit?.toJson(),
      };

  factory DriverDocument.fromJson(Map<String, dynamic> json) => DriverDocument(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        type: json['type'] as String? ?? 'CNH_EAR',
        status: json['status'] as String? ?? 'PENDING',
        expiryDate: json['expiryDate'] as String?,
        updatedAt: json['updatedAt'] as String? ?? '',
        fileUrl: json['fileUrl'] as String?,
        filePath: json['filePath'] as String?,
        faceFileUrl: json['faceFileUrl'] as String?,
        faceFilePath: json['faceFilePath'] as String?,
        fileName: json['fileName'] as String?,
        aiAudit: json['aiAudit'] is Map<String, dynamic>
            ? DocumentAiAuditResult.fromJson(
                json['aiAudit'] as Map<String, dynamic>)
            : null,
      );
}

class WalletTransaction {
  final String id;
  final String title;
  final String type; // 'TRIP_EARNING' | 'PIX_WITHDRAWAL' | 'BONUS' | 'REFERRAL' | 'PLATFORM_FEE' | 'TIP'
  final double amount;
  final String timestamp;
  final String status; // 'COMPLETED' | 'PROCESSING'

  const WalletTransaction({
    required this.id,
    required this.title,
    required this.type,
    required this.amount,
    required this.timestamp,
    required this.status,
  });
}

class PrivateTripOffer {
  final String id;
  final String title;
  final String passengerName;
  final double passengerRating;
  final String origin;
  final String destination;
  final String dateLabel;
  final double distanceKm;
  final double suggestedPrice;
  final VehicleCategory vehicleRequired;
  final String notes;
  final String status; // 'OPEN' | 'BID_SENT' | 'ACCEPTED'
  final double? driverBid;

  const PrivateTripOffer({
    required this.id,
    required this.title,
    required this.passengerName,
    required this.passengerRating,
    required this.origin,
    required this.destination,
    required this.dateLabel,
    required this.distanceKm,
    required this.suggestedPrice,
    required this.vehicleRequired,
    required this.notes,
    required this.status,
    this.driverBid,
  });

  PrivateTripOffer copyWith({
    String? status,
    double? driverBid,
  }) =>
      PrivateTripOffer(
        id: id,
        title: title,
        passengerName: passengerName,
        passengerRating: passengerRating,
        origin: origin,
        destination: destination,
        dateLabel: dateLabel,
        distanceKm: distanceKm,
        suggestedPrice: suggestedPrice,
        vehicleRequired: vehicleRequired,
        notes: notes,
        status: status ?? this.status,
        driverBid: driverBid ?? this.driverBid,
      );
}

class ChatMessage {
  final String id;
  final String sender; // 'DRIVER' | 'PASSENGER' | 'SYSTEM'
  final String text;
  final String timestamp;
  final String senderId;
  final int createdAtMs;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.senderId = '',
    this.createdAtMs = 0,
    this.isRead = false,
  });

  ChatMessage copyWith({
    String? id,
    String? sender,
    String? text,
    String? timestamp,
    String? senderId,
    int? createdAtMs,
    bool? isRead,
  }) =>
      ChatMessage(
        id: id ?? this.id,
        sender: sender ?? this.sender,
        text: text ?? this.text,
        timestamp: timestamp ?? this.timestamp,
        senderId: senderId ?? this.senderId,
        createdAtMs: createdAtMs ?? this.createdAtMs,
        isRead: isRead ?? this.isRead,
      );
}

class SmartAlert {
  final String id;
  final String title;
  final String message;
  final String severity; // 'info' | 'warning' | 'danger' | 'success'
  final bool visible;

  const SmartAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.visible,
  });
}

/// Resultado real da Comparação Biométrica Facial — 1:1 com FaceComparisonAiResult em types/omni.ts
class FaceComparisonAiResult {
  final bool approved;
  final bool documentValid;
  final String documentTypeDetected;
  final bool livenessCheckPassed;
  final bool isSamePerson;
  final double confidenceScore;
  final String facialFeaturesAnalysis;
  final String? rejectionReason;
  final int? resolutionTier;
  final String? engineUsed;

  const FaceComparisonAiResult({
    required this.approved,
    required this.documentValid,
    required this.documentTypeDetected,
    required this.livenessCheckPassed,
    required this.isSamePerson,
    required this.confidenceScore,
    required this.facialFeaturesAnalysis,
    this.rejectionReason,
    this.resolutionTier,
    this.engineUsed,
  });

  factory FaceComparisonAiResult.fromJson(Map<String, dynamic> json) =>
      FaceComparisonAiResult(
        approved: json['approved'] as bool? ?? false,
        documentValid: json['documentValid'] as bool? ?? false,
        documentTypeDetected:
            json['documentTypeDetected'] as String? ?? 'Documento',
        livenessCheckPassed: json['livenessCheckPassed'] as bool? ?? false,
        isSamePerson: json['isSamePerson'] as bool? ?? false,
        confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0.0,
        facialFeaturesAnalysis:
            json['facialFeaturesAnalysis'] as String? ?? '',
        rejectionReason: json['rejectionReason'] as String?,
        resolutionTier: json['resolutionTier'] as int?,
        engineUsed: json['engineUsed'] as String?,
      );
}

/// Envio estruturado da Certidão de Antecedentes Criminais — 1:1 com CriminalCertificateSubmission
class CriminalCertificateSubmission {
  final String issuingPortal; // 'PF' | 'TJ_ESTADUAL' | 'AMBOS'
  final String validationCode;
  final String issueDate; // YYYY-MM-DD
  final String ufJurisdiction;
  final bool selfDeclaredClean;
  final String? submittedAt;

  const CriminalCertificateSubmission({
    required this.issuingPortal,
    required this.validationCode,
    required this.issueDate,
    required this.ufJurisdiction,
    required this.selfDeclaredClean,
    this.submittedAt,
  });

  CriminalCertificateSubmission copyWith({
    String? issuingPortal,
    String? validationCode,
    String? issueDate,
    String? ufJurisdiction,
    bool? selfDeclaredClean,
    String? submittedAt,
  }) =>
      CriminalCertificateSubmission(
        issuingPortal: issuingPortal ?? this.issuingPortal,
        validationCode: validationCode ?? this.validationCode,
        issueDate: issueDate ?? this.issueDate,
        ufJurisdiction: ufJurisdiction ?? this.ufJurisdiction,
        selfDeclaredClean: selfDeclaredClean ?? this.selfDeclaredClean,
        submittedAt: submittedAt ?? this.submittedAt,
      );

  Map<String, dynamic> toJson() => {
        'issuingPortal': issuingPortal,
        'validationCode': validationCode,
        'issueDate': issueDate,
        'ufJurisdiction': ufJurisdiction,
        'selfDeclaredClean': selfDeclaredClean,
        'submittedAt': submittedAt,
      };

  factory CriminalCertificateSubmission.fromJson(Map<String, dynamic> json) =>
      CriminalCertificateSubmission(
        issuingPortal: json['issuingPortal'] as String? ?? 'PF',
        validationCode: json['validationCode'] as String? ?? '',
        issueDate: json['issueDate'] as String? ?? '',
        ufJurisdiction: json['ufJurisdiction'] as String? ?? '',
        selfDeclaredClean: json['selfDeclaredClean'] as bool? ?? false,
        submittedAt: json['submittedAt'] as String?,
      );
}

/// Resultado da triagem inicial de certidão e conduta — 1:1 com CriminalScreeningResult
class CriminalScreeningResult {
  final String status; // ScreeningStatus
  final int score;
  final String riskLevel; // 'LOW' | 'MEDIUM' | 'HIGH'
  final String protocolCode;
  final String checkedAt;
  final bool hasAttachment;
  final bool hasValidCode;
  final bool hasValidDate;
  final bool hasDeclaration;
  final String summary;
  final List<String> findings;
  final String? rejectionReason;

  const CriminalScreeningResult({
    required this.status,
    required this.score,
    required this.riskLevel,
    required this.protocolCode,
    required this.checkedAt,
    required this.hasAttachment,
    required this.hasValidCode,
    required this.hasValidDate,
    required this.hasDeclaration,
    required this.summary,
    required this.findings,
    this.rejectionReason,
  });

  Map<String, dynamic> toJson() => {
        'status': status,
        'score': score,
        'riskLevel': riskLevel,
        'protocolCode': protocolCode,
        'checkedAt': checkedAt,
        'hasAttachment': hasAttachment,
        'hasValidCode': hasValidCode,
        'hasValidDate': hasValidDate,
        'hasDeclaration': hasDeclaration,
        'summary': summary,
        'findings': findings,
        'rejectionReason': rejectionReason,
      };

  factory CriminalScreeningResult.fromJson(Map<String, dynamic> json) =>
      CriminalScreeningResult(
        status: json['status'] as String? ?? 'PENDING_SUBMISSION',
        score: (json['score'] as num?)?.round() ?? 0,
        riskLevel: json['riskLevel'] as String? ?? 'MEDIUM',
        protocolCode: json['protocolCode'] as String? ?? '',
        checkedAt: json['checkedAt'] as String? ?? '',
        hasAttachment: json['hasAttachment'] as bool? ?? false,
        hasValidCode: json['hasValidCode'] as bool? ?? false,
        hasValidDate: json['hasValidDate'] as bool? ?? false,
        hasDeclaration: json['hasDeclaration'] as bool? ?? false,
        summary: json['summary'] as String? ?? '',
        findings: (json['findings'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        rejectionReason: json['rejectionReason'] as String?,
      );
}

/// 5 fotos nítidas do veículo (Frente, Traseira, Laterais e Placa) — 1:1 com VehicleVisualPhotos
class VehicleVisualPhotos {
  final String? front;
  final String? rear;
  final String? leftSide;
  final String? rightSide;
  final String? plate;

  const VehicleVisualPhotos({
    this.front,
    this.rear,
    this.leftSide,
    this.rightSide,
    this.plate,
  });

  VehicleVisualPhotos copyWith({
    String? front,
    String? rear,
    String? leftSide,
    String? rightSide,
    String? plate,
  }) =>
      VehicleVisualPhotos(
        front: front ?? this.front,
        rear: rear ?? this.rear,
        leftSide: leftSide ?? this.leftSide,
        rightSide: rightSide ?? this.rightSide,
        plate: plate ?? this.plate,
      );

  Map<String, dynamic> toJson() => {
        'front': front,
        'rear': rear,
        'leftSide': leftSide,
        'rightSide': rightSide,
        'plate': plate,
      };

  factory VehicleVisualPhotos.fromJson(Map<String, dynamic> json) =>
      VehicleVisualPhotos(
        front: json['front'] as String?,
        rear: json['rear'] as String?,
        leftSide: json['leftSide'] as String?,
        rightSide: json['rightSide'] as String?,
        plate: json['plate'] as String?,
      );
}

/// Resultado da triagem estrutural do veículo (CRLV, Vínculo e 5 Fotos) — 1:1 com VehicleScreeningResult
class VehicleScreeningResult {
  final String status;
  final int score;
  final String riskLevel;
  final String protocolCode;
  final String checkedAt;
  final bool crlvAttached;
  final bool ownershipVerified;
  final int photosCount;
  final bool renavamValid;
  final bool plateValid;
  final bool chassiValid;
  final String summary;
  final List<String> findings;
  final String? rejectionReason;

  const VehicleScreeningResult({
    required this.status,
    required this.score,
    required this.riskLevel,
    required this.protocolCode,
    required this.checkedAt,
    required this.crlvAttached,
    required this.ownershipVerified,
    required this.photosCount,
    required this.renavamValid,
    required this.plateValid,
    required this.chassiValid,
    required this.summary,
    required this.findings,
    this.rejectionReason,
  });

  Map<String, dynamic> toJson() => {
        'status': status,
        'score': score,
        'riskLevel': riskLevel,
        'protocolCode': protocolCode,
        'checkedAt': checkedAt,
        'crlvAttached': crlvAttached,
        'ownershipVerified': ownershipVerified,
        'photosCount': photosCount,
        'renavamValid': renavamValid,
        'plateValid': plateValid,
        'chassiValid': chassiValid,
        'summary': summary,
        'findings': findings,
        'rejectionReason': rejectionReason,
      };

  factory VehicleScreeningResult.fromJson(Map<String, dynamic> json) =>
      VehicleScreeningResult(
        status: json['status'] as String? ?? 'PENDING_SUBMISSION',
        score: (json['score'] as num?)?.round() ?? 0,
        riskLevel: json['riskLevel'] as String? ?? 'MEDIUM',
        protocolCode: json['protocolCode'] as String? ?? '',
        checkedAt: json['checkedAt'] as String? ?? '',
        crlvAttached: json['crlvAttached'] as bool? ?? false,
        ownershipVerified: json['ownershipVerified'] as bool? ?? false,
        photosCount: (json['photosCount'] as num?)?.round() ?? 0,
        renavamValid: json['renavamValid'] as bool? ?? false,
        plateValid: json['plateValid'] as bool? ?? false,
        chassiValid: json['chassiValid'] as bool? ?? false,
        summary: json['summary'] as String? ?? '',
        findings: (json['findings'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        rejectionReason: json['rejectionReason'] as String?,
      );
}

class BehavioralEventRecord {
  final String id;
  final String type;
  final String severity;
  final int points;
  final bool requiresRevalidation;
  final String title;
  final String description;
  final String occurredAt;

  const BehavioralEventRecord({
    required this.id,
    required this.type,
    required this.severity,
    required this.points,
    required this.requiresRevalidation,
    required this.title,
    required this.description,
    required this.occurredAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'severity': severity,
        'points': points,
        'requiresRevalidation': requiresRevalidation,
        'title': title,
        'description': description,
        'occurredAt': occurredAt,
      };

  factory BehavioralEventRecord.fromJson(Map<String, dynamic> json) =>
      BehavioralEventRecord(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? 'ROUTE_DEVIATION',
        severity: json['severity'] as String? ?? 'LOW',
        points: (json['points'] as num?)?.round() ?? 0,
        requiresRevalidation: json['requiresRevalidation'] as bool? ?? false,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        occurredAt: json['occurredAt'] as String? ?? '',
      );
}

class BehavioralRiskState {
  final String accountStatus; // ScreeningStatus
  final int riskScore;
  final String riskLevel; // 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'
  final bool revalidationRequired;
  final String? revalidationTrigger;
  final String? revalidationReason;
  final String? preventiveBlockReason;
  final String? lastLivenessAt;
  final String? deviceFingerprint;
  final int vehicleSwitchCountRecent;
  final int incidentCount;
  final List<BehavioralEventRecord> events;

  const BehavioralRiskState({
    required this.accountStatus,
    required this.riskScore,
    required this.riskLevel,
    required this.revalidationRequired,
    this.revalidationTrigger,
    this.revalidationReason,
    this.preventiveBlockReason,
    this.lastLivenessAt,
    this.deviceFingerprint,
    this.vehicleSwitchCountRecent = 0,
    this.incidentCount = 0,
    this.events = const [],
  });

  BehavioralRiskState copyWith({
    String? accountStatus,
    int? riskScore,
    String? riskLevel,
    bool? revalidationRequired,
    String? revalidationTrigger,
    bool clearRevalidationTrigger = false,
    String? revalidationReason,
    String? preventiveBlockReason,
    bool clearPreventiveBlock = false,
    String? lastLivenessAt,
    String? deviceFingerprint,
    int? vehicleSwitchCountRecent,
    int? incidentCount,
    List<BehavioralEventRecord>? events,
  }) =>
      BehavioralRiskState(
        accountStatus: accountStatus ?? this.accountStatus,
        riskScore: riskScore ?? this.riskScore,
        riskLevel: riskLevel ?? this.riskLevel,
        revalidationRequired: revalidationRequired ?? this.revalidationRequired,
        revalidationTrigger: clearRevalidationTrigger
            ? null
            : (revalidationTrigger ?? this.revalidationTrigger),
        revalidationReason: clearRevalidationTrigger
            ? null
            : (revalidationReason ?? this.revalidationReason),
        preventiveBlockReason: clearPreventiveBlock
            ? null
            : (preventiveBlockReason ?? this.preventiveBlockReason),
        lastLivenessAt: lastLivenessAt ?? this.lastLivenessAt,
        deviceFingerprint: deviceFingerprint ?? this.deviceFingerprint,
        vehicleSwitchCountRecent:
            vehicleSwitchCountRecent ?? this.vehicleSwitchCountRecent,
        incidentCount: incidentCount ?? this.incidentCount,
        events: events ?? this.events,
      );

  Map<String, dynamic> toJson() => {
        'accountStatus': accountStatus,
        'riskScore': riskScore,
        'riskLevel': riskLevel,
        'revalidationRequired': revalidationRequired,
        'revalidationTrigger': revalidationTrigger,
        'revalidationReason': revalidationReason,
        'preventiveBlockReason': preventiveBlockReason,
        'lastLivenessAt': lastLivenessAt,
        'deviceFingerprint': deviceFingerprint,
        'vehicleSwitchCountRecent': vehicleSwitchCountRecent,
        'incidentCount': incidentCount,
        'events': events.map((e) => e.toJson()).toList(),
      };

  factory BehavioralRiskState.fromJson(Map<String, dynamic> json) =>
      BehavioralRiskState(
        accountStatus: json['accountStatus'] as String? ?? 'PENDING_SUBMISSION',
        riskScore: (json['riskScore'] as num?)?.round() ?? 8,
        riskLevel: json['riskLevel'] as String? ?? 'LOW',
        revalidationRequired: json['revalidationRequired'] as bool? ?? false,
        revalidationTrigger: json['revalidationTrigger'] as String?,
        revalidationReason: json['revalidationReason'] as String?,
        preventiveBlockReason: json['preventiveBlockReason'] as String?,
        lastLivenessAt: json['lastLivenessAt'] as String?,
        deviceFingerprint: json['deviceFingerprint'] as String?,
        vehicleSwitchCountRecent:
            (json['vehicleSwitchCountRecent'] as num?)?.round() ?? 0,
        incidentCount: (json['incidentCount'] as num?)?.round() ?? 0,
        events: (json['events'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(BehavioralEventRecord.fromJson)
                .toList() ??
            const [],
      );
}

/// Modelo Canônico de Campanha & Incentivo para Motoristas
/// Espelha `omni_campanhas_motorista` (SQL) e `/campanhas_motorista/{campaign_id}` (RTDB)
class DriverCampaign {
  final String id;
  final String titulo;
  final String mensagem;
  final String imagemUrl;
  final String tipoIncentivo; // 'bonus_corridas' | 'alta_demanda' | 'meta_periodo' | 'aviso_operacional'
  final String valorOuPercentualBonus;
  final String cidadeAlvo;
  final String dataHoraDisparo;
  final String dataHoraExpiracao;
  final String status; // 'agendada' | 'enviada' | 'cancelada'
  final String fcmMessageId;
  final String sentAt;
  final String createdAt;

  const DriverCampaign({
    required this.id,
    required this.titulo,
    required this.mensagem,
    this.imagemUrl = '',
    this.tipoIncentivo = 'bonus_corridas',
    this.valorOuPercentualBonus = '',
    this.cidadeAlvo = 'TODAS',
    required this.dataHoraDisparo,
    this.dataHoraExpiracao = '',
    this.status = 'agendada',
    this.fcmMessageId = '',
    this.sentAt = '',
    this.createdAt = '',
  });

  bool get isExpired {
    final trimmed = dataHoraExpiracao.trim();
    if (trimmed.isEmpty) return false;
    final normalized = trimmed.contains('T') ? trimmed : trimmed.replaceFirst(' ', 'T');
    final parsed = DateTime.tryParse(normalized) ?? DateTime.tryParse('${normalized}Z');
    if (parsed == null) return false;
    return parsed.toUtc().isBefore(DateTime.now().toUtc());
  }

  bool get isActiveForDriver => status == 'enviada' && !isExpired;

  String get tipoIncentivoLabel {
    switch (tipoIncentivo) {
      case 'bonus_corridas':
        return 'Bônus por Corridas';
      case 'alta_demanda':
        return 'Alta Demanda / Evento';
      case 'meta_periodo':
        return 'Meta Diária / Semanal';
      case 'aviso_operacional':
        return 'Aviso Operacional';
      default:
        return 'Campanha OMNI';
    }
  }

  DriverCampaign copyWith({
    String? id,
    String? titulo,
    String? mensagem,
    String? imagemUrl,
    String? tipoIncentivo,
    String? valorOuPercentualBonus,
    String? cidadeAlvo,
    String? dataHoraDisparo,
    String? dataHoraExpiracao,
    String? status,
    String? fcmMessageId,
    String? sentAt,
    String? createdAt,
  }) =>
      DriverCampaign(
        id: id ?? this.id,
        titulo: titulo ?? this.titulo,
        mensagem: mensagem ?? this.mensagem,
        imagemUrl: imagemUrl ?? this.imagemUrl,
        tipoIncentivo: tipoIncentivo ?? this.tipoIncentivo,
        valorOuPercentualBonus:
            valorOuPercentualBonus ?? this.valorOuPercentualBonus,
        cidadeAlvo: cidadeAlvo ?? this.cidadeAlvo,
        dataHoraDisparo: dataHoraDisparo ?? this.dataHoraDisparo,
        dataHoraExpiracao: dataHoraExpiracao ?? this.dataHoraExpiracao,
        status: status ?? this.status,
        fcmMessageId: fcmMessageId ?? this.fcmMessageId,
        sentAt: sentAt ?? this.sentAt,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toJson() => {
        'campaign_id': id,
        'titulo': titulo,
        'mensagem': mensagem,
        'imagem_url': imagemUrl,
        'tipo_incentivo': tipoIncentivo,
        'valor_ou_percentual_bonus': valorOuPercentualBonus,
        'cidade_alvo': cidadeAlvo,
        'data_hora_disparo': dataHoraDisparo,
        'data_hora_expiracao': dataHoraExpiracao,
        'status': status,
        'fcm_message_id': fcmMessageId,
        'sent_at': sentAt,
        'created_at': createdAt,
      };

  factory DriverCampaign.fromJson(Map<String, dynamic> json) => DriverCampaign(
        id: (json['campaign_id'] ?? json['id'] ?? '').toString(),
        titulo: (json['titulo'] ?? '').toString(),
        mensagem: (json['mensagem'] ?? '').toString(),
        imagemUrl: (json['imagem_url'] ?? '').toString(),
        tipoIncentivo: (json['tipo_incentivo'] ?? 'bonus_corridas').toString(),
        valorOuPercentualBonus:
            (json['valor_ou_percentual_bonus'] ?? '').toString(),
        cidadeAlvo: (json['cidade_alvo'] ?? 'TODAS').toString(),
        dataHoraDisparo: (json['data_hora_disparo'] ?? '').toString(),
        dataHoraExpiracao: (json['data_hora_expiracao'] ?? '').toString(),
        status: (json['status'] ?? 'agendada').toString(),
        fcmMessageId: (json['fcm_message_id'] ?? '').toString(),
        sentAt: (json['sent_at'] ?? '').toString(),
        createdAt: (json['created_at'] ?? '').toString(),
      );
}

/// Regra de Notificação Push Promocional Programável pelo Dono (Recorrência de tempo em tempo)
class ScheduledPromoNotificationRule {
  final String id;
  final String title;
  final String message;
  final String bonusHighlight;
  final String promoStyle; // 'bonus_corridas' | 'alta_demanda' | 'meta_relampago' | 'clube_vip' | 'combustivel' | 'aviso_frota'
  final String targetCity;
  final int intervalSeconds;
  final bool enabled;
  final int lastTriggeredAtMs;
  final int triggerCount;
  final String createdAt;

  const ScheduledPromoNotificationRule({
    required this.id,
    required this.title,
    required this.message,
    this.bonusHighlight = '',
    this.promoStyle = 'bonus_corridas',
    this.targetCity = 'TODAS',
    this.intervalSeconds = 300,
    this.enabled = true,
    this.lastTriggeredAtMs = 0,
    this.triggerCount = 0,
    this.createdAt = '',
  });

  String get iconEmoji {
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

  String get styleLabel {
    switch (promoStyle) {
      case 'alta_demanda':
        return 'Alta Demanda / Dinâmica';
      case 'meta_relampago':
        return 'Meta Relâmpago';
      case 'clube_vip':
        return 'Clube VIP / Elite';
      case 'combustivel':
        return 'Desconto Combustível';
      case 'aviso_frota':
        return 'Aviso da Frota';
      case 'bonus_corridas':
      default:
        return 'Bônus de Corridas';
    }
  }

  String get intervalLabel {
    if (intervalSeconds < 60) {
      return 'A cada ${intervalSeconds}s';
    }
    if (intervalSeconds < 3600) {
      final mins = (intervalSeconds / 60).round();
      return mins == 1 ? 'A cada 1 min' : 'A cada $mins min';
    }
    final hours = (intervalSeconds / 3600).round();
    return hours == 1 ? 'A cada 1 hora' : 'A cada ${hours}h';
  }

  ScheduledPromoNotificationRule copyWith({
    String? id,
    String? title,
    String? message,
    String? bonusHighlight,
    String? promoStyle,
    String? targetCity,
    int? intervalSeconds,
    bool? enabled,
    int? lastTriggeredAtMs,
    int? triggerCount,
    String? createdAt,
  }) =>
      ScheduledPromoNotificationRule(
        id: id ?? this.id,
        title: title ?? this.title,
        message: message ?? this.message,
        bonusHighlight: bonusHighlight ?? this.bonusHighlight,
        promoStyle: promoStyle ?? this.promoStyle,
        targetCity: targetCity ?? this.targetCity,
        intervalSeconds: intervalSeconds ?? this.intervalSeconds,
        enabled: enabled ?? this.enabled,
        lastTriggeredAtMs: lastTriggeredAtMs ?? this.lastTriggeredAtMs,
        triggerCount: triggerCount ?? this.triggerCount,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'bonus_highlight': bonusHighlight,
        'promo_style': promoStyle,
        'target_city': targetCity,
        'interval_seconds': intervalSeconds,
        'enabled': enabled,
        'last_triggered_at_ms': lastTriggeredAtMs,
        'trigger_count': triggerCount,
        'created_at': createdAt,
      };

  factory ScheduledPromoNotificationRule.fromJson(Map<String, dynamic> json) =>
      ScheduledPromoNotificationRule(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        message: (json['message'] ?? '').toString(),
        bonusHighlight: (json['bonus_highlight'] ?? '').toString(),
        promoStyle: (json['promo_style'] ?? 'bonus_corridas').toString(),
        targetCity: (json['target_city'] ?? 'TODAS').toString(),
        intervalSeconds: (json['interval_seconds'] as num?)?.round() ?? 300,
        enabled: json['enabled'] as bool? ?? true,
        lastTriggeredAtMs: (json['last_triggered_at_ms'] as num?)?.round() ?? 0,
        triggerCount: (json['trigger_count'] as num?)?.round() ?? 0,
        createdAt: (json['created_at'] ?? '').toString(),
      );
}




