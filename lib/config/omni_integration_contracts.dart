/// OMNI Mobilidade Urbana — Contratos Centralizados de Integração (SQL + Firebase RTDB + Roteador Híbrido)
/// Espelho 1:1 de `src/config/omniIntegrationContracts.ts` e `backend_php/class-omni-motorista-backend-pro.php`.
/// Documentação oficial: `/mapeamento_sql.md` e `/mapeamento_realtime_firebase.md`.

class OmniRouterConfig {
  static const String defaultDomain = 'http://192.168.12.9/servshop';
  static const String ajaxPath = '/wp-admin/admin-ajax.php';
  static const String baseUrl = '$defaultDomain$ajaxPath';
  static const String domainStorageKey = 'omni_backend_domain_v1';
  static const String nonceAction = 'omni_get_router_nonce';
  static const String routerAction = 'omni_global_router';
  static const String backendFile = 'class-omni-motorista-backend-pro.php';
  static const String className = 'class_omni_motorista_backend_pro';

  static String normalizeBackendDomain(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) {
      return defaultDomain;
    }

    String withScheme = trimmed;
    final hasScheme = RegExp(r'^https?://', caseSensitive: false).hasMatch(withScheme);
    if (!hasScheme) {
      final isNumericOrLocal =
          RegExp(r'^\d{1,3}(\.\d{1,3}){3}([:/]|$)').hasMatch(withScheme) ||
          RegExp(r'^localhost([:/]|$)', caseSensitive: false).hasMatch(withScheme);
      withScheme = '${isNumericOrLocal ? 'http' : 'https'}://$withScheme';
    }

    return withScheme.replaceAll(RegExp(r'/+$'), '');
  }

  static bool isValidBackendDomainInput(String rawInput) {
    final normalized = normalizeBackendDomain(rawInput);
    final uri = Uri.tryParse(normalized);
    if (uri == null) return false;
    final schemeOk = uri.scheme == 'http' || uri.scheme == 'https';
    return schemeOk && uri.host.isNotEmpty && !uri.host.contains(' ');
  }

  static String resolveAjaxEndpointFromDomain(String rawInput) {
    final normalized = normalizeBackendDomain(rawInput);
    if (RegExp(r'\.php(\?.*)?$', caseSensitive: false).hasMatch(normalized)) {
      return normalized;
    }
    if (RegExp(r'/wp-admin$', caseSensitive: false).hasMatch(normalized)) {
      return '$normalized/admin-ajax.php';
    }
    return '$normalized$ajaxPath';
  }
}

class OmniSqlTables {
  static const String motoristas = 'omni_motoristas';
  static const String veiculos = 'omni_veiculos';
  static const String corridas = 'omni_corridas';
  static const String corridaLances = 'omni_corrida_lances';
  static const String documentosKyc = 'omni_documentos_kyc';
  static const String biometriaLogs = 'omni_biometria_logs';
  static const String complianceChecks = 'omni_compliance_checks';
  static const String carteiraSaques = 'omni_carteira_saques';
}

class OmniBackendMethods {
  static const String bootstrapTables = 'driver_bootstrap_tables';
  static const String locationDetect = 'driver_location_detect';
  static const String availabilityToggle = 'driver_availability_toggle';
  static const String tripAccept = 'driver_trip_accept';
  static const String tripDecline = 'driver_trip_decline';
  static const String tripArrived = 'driver_trip_arrived';
  static const String tripValidateOtp = 'driver_trip_validate_otp';
  static const String tripStart = 'driver_trip_start';
  static const String tripFinish = 'driver_trip_finish';
  static const String tripCancel = 'driver_trip_cancel';
  static const String walletRequestPixPayout = 'driver_wallet_request_pix_payout';
  static const String walletGeneratePixCharge = 'driver_wallet_generate_pix_charge';
  static const String privateTripsSubmitBid = 'driver_private_trips_submit_bid';
  static const String profileUpdate = 'driver_profile_update';
  static const String vehicleUpsert = 'driver_vehicle_upsert';
  static const String documentsUpload = 'driver_documents_upload';
  static const String biometricsFingerprint = 'driver_biometrics_fingerprint';
  static const String biometricsFingerprintDocCross = 'driver_biometrics_fingerprint_doc_cross';
  static const String complianceBackgroundCheck = 'driver_compliance_background_check';
  static const String vehicleDeepCheck = 'driver_vehicle_deep_check';
  static const String complianceSignRites = 'driver_compliance_sign_rites';
}

class OmniTripStatus {
  static const String searching = 'SEARCHING';
  static const String accepted = 'ACCEPTED';
  static const String driverEnRoute = 'DRIVER_EN_ROUTE';
  static const String driverArrived = 'DRIVER_ARRIVED';
  static const String boardingConfirmed = 'BOARDING_CONFIRMED';
  static const String inProgress = 'IN_PROGRESS';
  static const String completed = 'COMPLETED';
  static const String cancelled = 'CANCELLED';
  static const String declined = 'DECLINED';
}

class OmniRtdbConfig {
  static const String baseUrl =
      'https://catalogo-dropshipping-b9546-default-rtdb.firebaseio.com';

  static const String nodeDriversOnline = 'drivers_online';
  static const String nodeDispatchQueue = 'dispatch_queue';
  static const String nodeTrips = 'trips';
  static const String nodePrivateOffers = 'private_offers';
  static const String nodePrivateBids = 'private_bids';
  static const String nodePayouts = 'payouts';
}

/// Construtores centralizados de caminhos (paths) do Firebase Realtime Database.
class OmniRtdbPaths {
  static String driverOnline(String driverId) =>
      '${OmniRtdbConfig.nodeDriversOnline}/$driverId';

  static String driverDispatchQueue(String driverId) =>
      '${OmniRtdbConfig.nodeDispatchQueue}/$driverId';

  static String driverDispatchOffer(String driverId, String tripId) =>
      '${OmniRtdbConfig.nodeDispatchQueue}/$driverId/$tripId';

  static String tripRoot(String tripId) =>
      '${OmniRtdbConfig.nodeTrips}/$tripId';

  static String tripStatus(String tripId) =>
      '${OmniRtdbConfig.nodeTrips}/$tripId/status';

  static String tripDriverId(String tripId) =>
      '${OmniRtdbConfig.nodeTrips}/$tripId/driver_id';

  static String tripDriverLocation(String tripId) =>
      '${OmniRtdbConfig.nodeTrips}/$tripId/driver_location';

  static String tripChatMessages(String tripId) =>
      '${OmniRtdbConfig.nodeTrips}/$tripId/chat';

  static String tripSosAlert(String tripId) =>
      '${OmniRtdbConfig.nodeTrips}/$tripId/sos';

  static String privateOfferRoot(String offerId) =>
      '${OmniRtdbConfig.nodePrivateOffers}/$offerId';

  static String privateOfferBids(String offerId) =>
      '${OmniRtdbConfig.nodePrivateBids}/$offerId';

  static String privateOfferBid(String offerId, String bidId) =>
      '${OmniRtdbConfig.nodePrivateBids}/$offerId/$bidId';

  static String driverPayout(String driverId, String transactionId) =>
      '${OmniRtdbConfig.nodePayouts}/$driverId/$transactionId';
}

class OmniRtdbFields {
  static const String driverId = 'driver_id';
  static const String passengerId = 'passenger_id';
  static const String tripId = 'trip_id';
  static const String isOnline = 'is_online';
  static const String lat = 'lat';
  static const String lng = 'lng';
  static const String bearing = 'bearing';
  static const String speedKmh = 'speed_kmh';
  static const String status = 'status';
  static const String updatedAt = 'updated_at';
  static const String createdAt = 'created_at';
  static const String senderRole = 'sender_role';
  static const String text = 'text';
  static const String bidId = 'bid_id';
  static const String bidAmount = 'bid_amount';
  static const String message = 'message';
  static const String transactionId = 'transaction_id';
  static const String amount = 'amount';
  static const String pixKey = 'pix_key';
  static const String pixKeyType = 'pix_key_type';
  static const String processedAt = 'processed_at';
}
