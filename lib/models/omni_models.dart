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

  const OmniCoordinate({
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };

  factory OmniCoordinate.fromJson(Map<String, dynamic> json) => OmniCoordinate(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );
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
  final CriminalBackgroundCheckAudit? criminalBackgroundAudit;
  final FingerprintDocComparison? fingerprintDocComparison;

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
    this.criminalBackgroundAudit,
    this.fingerprintDocComparison,
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
    CriminalBackgroundCheckAudit? criminalBackgroundAudit,
    FingerprintDocComparison? fingerprintDocComparison,
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
      criminalBackgroundAudit:
          criminalBackgroundAudit ?? this.criminalBackgroundAudit,
      fingerprintDocComparison:
          fingerprintDocComparison ?? this.fingerprintDocComparison,
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
        'criminalBackgroundAudit': criminalBackgroundAudit?.toJson(),
        'fingerprintDocComparison': fingerprintDocComparison?.toJson(),
      };

  factory OmniDriver.fromJson(Map<String, dynamic> json) => OmniDriver(
        id: json['id'] as String? ?? 'usr_drv_88419201824',
        name: json['name'] as String? ?? 'Carlos Eduardo Silveira',
        cpf: json['cpf'] as String? ?? '',
        rg: json['rg'] as String?,
        rgIssuer: json['rgIssuer'] as String?,
        birthDate: json['birthDate'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String? ?? '(11) 98412-3901',
        cnhNumber: json['cnhNumber'] as String? ?? '',
        cnhCategory: json['cnhCategory'] as String?,
        cnhExpiry: json['cnhExpiry'] as String? ?? '2028-06-20',
        cnhIssueState: json['cnhIssueState'] as String?,
        cnhEar: json['cnhEar'] as bool? ?? true,
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
        rating: (json['rating'] as num?)?.toDouble() ?? 4.96,
        acceptanceRate: (json['acceptanceRate'] as num?)?.toDouble() ?? 98.4,
        cancellationRate: (json['cancellationRate'] as num?)?.toDouble() ?? 1.2,
        totalTrips: json['totalTrips'] as int? ?? 1842,
        clubTier: json['clubTier'] as String? ?? 'OURO',
        avatarUrl: json['avatarUrl'] as String? ??
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop&crop=faces',
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
        walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 348.60,
        todayEarnings: (json['todayEarnings'] as num?)?.toDouble() ?? 218.40,
        todayTripsCount: json['todayTripsCount'] as int? ?? 7,
        onlineHoursToday: (json['onlineHoursToday'] as num?)?.toDouble() ?? 4.75,
        referralCode: json['referralCode'] as String? ?? 'OMNI-CARLOS98',
        referralsCount: json['referralsCount'] as int? ?? 4,
        referralEarnings: (json['referralEarnings'] as num?)?.toDouble() ?? 600.0,
        criminalBackgroundAudit:
            json['criminalBackgroundAudit'] is Map<String, dynamic>
                ? CriminalBackgroundCheckAudit.fromJson(
                    json['criminalBackgroundAudit'] as Map<String, dynamic>)
                : null,
        fingerprintDocComparison:
            json['fingerprintDocComparison'] is Map<String, dynamic>
                ? FingerprintDocComparison.fromJson(
                    json['fingerprintDocComparison'] as Map<String, dynamic>)
                : null,
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
  final VehicleDeepAudit? deepAudit;

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
    this.deepAudit,
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
    VehicleDeepAudit? deepAudit,
    bool clearDeepAudit = false,
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
      deepAudit: clearDeepAudit ? null : (deepAudit ?? this.deepAudit),
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
        'deepAudit': deepAudit?.toJson(),
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
      deepAudit: json['deepAudit'] is Map<String, dynamic>
          ? VehicleDeepAudit.fromJson(
              json['deepAudit'] as Map<String, dynamic>)
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

  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
  });
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

/// Auditoria Inteligente de Antecedentes Criminais e Idoneidade — 1:1 com CriminalBackgroundCheckAudit em types/omni.ts
class CriminalBackgroundCheckAudit {
  final String status; // 'PENDING' | 'RUNNING' | 'APPROVED' | 'REVIEW' | 'REJECTED'
  final String riskLevel; // 'LOW' | 'MEDIUM' | 'HIGH'
  final int score; // 0..100
  final String protocolCode;
  final String checkedAt;
  final String pfSinicStatus; // 'CLEAR' | 'ALERT' | 'UNVERIFIED'
  final String tjStateStatus; // 'CLEAR' | 'ALERT' | 'UNVERIFIED'
  final String trfBnmpStatus; // 'CLEAR' | 'ALERT' | 'UNVERIFIED'
  final String cnhSuitabilityStatus; // 'REGULAR' | 'SUSPENDED' | 'INVALID'
  final String summary;
  final List<String> findings;
  final String? rejectionReason;
  final int? resolutionTier;
  final String? engineUsed;

  const CriminalBackgroundCheckAudit({
    required this.status,
    required this.riskLevel,
    required this.score,
    required this.protocolCode,
    required this.checkedAt,
    required this.pfSinicStatus,
    required this.tjStateStatus,
    required this.trfBnmpStatus,
    required this.cnhSuitabilityStatus,
    required this.summary,
    required this.findings,
    this.rejectionReason,
    this.resolutionTier,
    this.engineUsed,
  });

  Map<String, dynamic> toJson() => {
        'status': status,
        'riskLevel': riskLevel,
        'score': score,
        'protocolCode': protocolCode,
        'checkedAt': checkedAt,
        'pfSinicStatus': pfSinicStatus,
        'tjStateStatus': tjStateStatus,
        'trfBnmpStatus': trfBnmpStatus,
        'cnhSuitabilityStatus': cnhSuitabilityStatus,
        'summary': summary,
        'findings': findings,
        'rejectionReason': rejectionReason,
        'resolutionTier': resolutionTier,
        'engineUsed': engineUsed,
      };

  factory CriminalBackgroundCheckAudit.fromJson(Map<String, dynamic> json) =>
      CriminalBackgroundCheckAudit(
        status: json['status'] as String? ?? 'PENDING',
        riskLevel: json['riskLevel'] as String? ?? 'MEDIUM',
        score: (json['score'] as num?)?.round() ?? 0,
        protocolCode: json['protocolCode'] as String? ?? '',
        checkedAt: json['checkedAt'] as String? ?? '',
        pfSinicStatus: json['pfSinicStatus'] as String? ?? 'UNVERIFIED',
        tjStateStatus: json['tjStateStatus'] as String? ?? 'UNVERIFIED',
        trfBnmpStatus: json['trfBnmpStatus'] as String? ?? 'UNVERIFIED',
        cnhSuitabilityStatus:
            json['cnhSuitabilityStatus'] as String? ?? 'INVALID',
        summary: json['summary'] as String? ?? '',
        findings: (json['findings'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        rejectionReason: json['rejectionReason'] as String?,
        resolutionTier: (json['resolutionTier'] as num?)?.round(),
        engineUsed: json['engineUsed'] as String?,
      );
}

/// Auditoria Profunda do Veículo (Documentação + Histórico) — 1:1 com VehicleDeepAudit em types/omni.ts
class VehicleDeepAudit {
  final String status; // 'PENDING' | 'RUNNING' | 'APPROVED' | 'REVIEW' | 'REJECTED'
  final String riskLevel; // 'LOW' | 'MEDIUM' | 'HIGH'
  final int score; // 0..100
  final String protocolCode;
  final String checkedAt;
  final String theftRobberyStatus; // 'CLEAR' | 'ALERT' | 'UNVERIFIED'
  final String judicialRenajudStatus; // 'CLEAR' | 'ALERT' | 'UNVERIFIED'
  final String auctionSinisterStatus; // 'CLEAR' | 'MEDIUM_RISK' | 'HIGH_RISK'
  final String licensingDebtsStatus; // 'REGULAR' | 'EXPIRED' | 'IRREGULAR'
  final bool renavamValid;
  final bool plateValid;
  final bool chassiValid;
  final String summary;
  final List<String> findings;
  final String? rejectionReason;
  final int? resolutionTier;
  final String? engineUsed;

  const VehicleDeepAudit({
    required this.status,
    required this.riskLevel,
    required this.score,
    required this.protocolCode,
    required this.checkedAt,
    required this.theftRobberyStatus,
    required this.judicialRenajudStatus,
    required this.auctionSinisterStatus,
    required this.licensingDebtsStatus,
    required this.renavamValid,
    required this.plateValid,
    required this.chassiValid,
    required this.summary,
    required this.findings,
    this.rejectionReason,
    this.resolutionTier,
    this.engineUsed,
  });

  Map<String, dynamic> toJson() => {
        'status': status,
        'riskLevel': riskLevel,
        'score': score,
        'protocolCode': protocolCode,
        'checkedAt': checkedAt,
        'theftRobberyStatus': theftRobberyStatus,
        'judicialRenajudStatus': judicialRenajudStatus,
        'auctionSinisterStatus': auctionSinisterStatus,
        'licensingDebtsStatus': licensingDebtsStatus,
        'renavamValid': renavamValid,
        'plateValid': plateValid,
        'chassiValid': chassiValid,
        'summary': summary,
        'findings': findings,
        'rejectionReason': rejectionReason,
        'resolutionTier': resolutionTier,
        'engineUsed': engineUsed,
      };

  factory VehicleDeepAudit.fromJson(Map<String, dynamic> json) =>
      VehicleDeepAudit(
        status: json['status'] as String? ?? 'PENDING',
        riskLevel: json['riskLevel'] as String? ?? 'MEDIUM',
        score: (json['score'] as num?)?.round() ?? 0,
        protocolCode: json['protocolCode'] as String? ?? '',
        checkedAt: json['checkedAt'] as String? ?? '',
        theftRobberyStatus:
            json['theftRobberyStatus'] as String? ?? 'UNVERIFIED',
        judicialRenajudStatus:
            json['judicialRenajudStatus'] as String? ?? 'UNVERIFIED',
        auctionSinisterStatus:
            json['auctionSinisterStatus'] as String? ?? 'CLEAR',
        licensingDebtsStatus:
            json['licensingDebtsStatus'] as String? ?? 'IRREGULAR',
        renavamValid: json['renavamValid'] as bool? ?? false,
        plateValid: json['plateValid'] as bool? ?? false,
        chassiValid: json['chassiValid'] as bool? ?? true,
        summary: json['summary'] as String? ?? '',
        findings: (json['findings'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        rejectionReason: json['rejectionReason'] as String?,
        resolutionTier: (json['resolutionTier'] as num?)?.round(),
        engineUsed: json['engineUsed'] as String?,
      );
}

