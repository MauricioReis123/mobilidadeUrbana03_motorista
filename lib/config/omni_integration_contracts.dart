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
  static const String chatMensagens = 'omni_chat_mensagens';
  static const String campanhasMotorista = 'omni_campanhas_motorista';
  static const String promocoesRecorrentes = 'omni_promocoes_recorrentes';
  static const String dispositivosFcm = 'omni_dispositivos_fcm';
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
  static const String tripChatSend = 'driver_trip_chat_send';
  static const String tripChatHistory = 'driver_trip_chat_history';
  static const String tripSosTrigger = 'driver_trip_sos_trigger';
  static const String tripLocationUpdate = 'driver_trip_location_update';
  static const String syncState = 'driver_sync_state';
  static const String verifyAppOwner = 'driver_verify_app_owner';
  static const String ownerSimulateHired = 'driver_owner_simulate_hired';
  static const String registerFcmToken = 'driver_register_fcm_token';
  static const String campaignList = 'driver_campaign_list';
  static const String campaignSave = 'driver_campaign_save';
  static const String campaignDispatchNow = 'driver_campaign_dispatch_now';
  static const String campaignCancel = 'driver_campaign_cancel';
  static const String campaignDuplicate = 'driver_campaign_duplicate';
  static const String campaignProcessCron = 'driver_campaign_process_cron';
  static const String sendPushNotification = 'driver_send_push_notification';
  static const String dispatchTripPush = 'driver_dispatch_trip_push';
  static const String promoRuleSave = 'driver_promo_rule_save';
  static const String promoRuleDelete = 'driver_promo_rule_delete';
  static const String promoRuleList = 'driver_promo_rule_list';
}

class OmniTripStatus {
  static const String searching = 'SEARCHING';
  static const String accepted = 'ACCEPTED';
  static const String driverEnRoute = 'DRIVER_EN_ROUTE';
  static const String driverArrived = 'DRIVER_ARRIVED';
  static const String boardingConfirmed = 'BOARDING_CONFIRMED';
  static const String inProgress = 'IN_PROGRESS';
  static const String tripInProgress = 'IN_PROGRESS';
  static const String completed = 'COMPLETED';
  static const String cancelled = 'CANCELLED';
  static const String cancelledByDriver = 'CANCELLED';
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
  static const String nodeCampanhasMotorista = 'campanhas_motorista';
  static const String nodePromocoesAgendadas = 'motorista_promocoes_agendadas';
  static const String nodeMotoristaDispositivos = 'motorista_dispositivos';
}

/// Construtores centralizados de caminhos (paths) do Firebase Realtime Database.
class OmniRtdbPaths {
  static const String dispatchQueue = OmniRtdbConfig.nodeDispatchQueue;
  static const String privateOffers = OmniRtdbConfig.nodePrivateOffers;
  static const String campanhasMotorista = OmniRtdbConfig.nodeCampanhasMotorista;
  static const String motoristaDispositivos =
      OmniRtdbConfig.nodeMotoristaDispositivos;

  static String driverOnline(String driverId) =>
      '${OmniRtdbConfig.nodeDriversOnline}/$driverId';

  static String driverDispatchQueue(String driverId) =>
      '${OmniRtdbConfig.nodeDispatchQueue}/$driverId';

  static String dispatchQueueDriver(String driverId) =>
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

  static String tripChat(String tripId) =>
      '${OmniRtdbConfig.nodeTrips}/$tripId/chat';

  static String tripSosAlert(String tripId) =>
      '${OmniRtdbConfig.nodeTrips}/$tripId/sos';

  static String tripSos(String tripId) =>
      '${OmniRtdbConfig.nodeTrips}/$tripId/sos';

  static String privateOfferRoot(String offerId) =>
      '${OmniRtdbConfig.nodePrivateOffers}/$offerId';

  static String privateOfferBids(String offerId) =>
      '${OmniRtdbConfig.nodePrivateBids}/$offerId';

  static String privateOfferBid(String offerId, String bidId) =>
      '${OmniRtdbConfig.nodePrivateBids}/$offerId/$bidId';

  static String privateBidItem(String offerId, String bidId) =>
      '${OmniRtdbConfig.nodePrivateBids}/$offerId/$bidId';

  static String payoutsDriver(String driverId) =>
      '${OmniRtdbConfig.nodePayouts}/$driverId';

  static String driverPayout(String driverId, String transactionId) =>
      '${OmniRtdbConfig.nodePayouts}/$driverId/$transactionId';

  static String payoutItem(String driverId, String transactionId) =>
      '${OmniRtdbConfig.nodePayouts}/$driverId/$transactionId';

  static String campanhaMotorista(String campaignId) =>
      '${OmniRtdbConfig.nodeCampanhasMotorista}/$campaignId';

  static String motoristaDispositivo(String driverId) =>
      '${OmniRtdbConfig.nodeMotoristaDispositivos}/$driverId';

  static String promocaoAgendada(String ruleId) =>
      '${OmniRtdbConfig.nodePromocoesAgendadas}/$ruleId';
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
  static const String expiresAt = 'expires_at';
  static const String senderRole = 'sender_role';
  static const String senderId = 'sender_id';
  static const String text = 'text';
  static const String isRead = 'is_read';
  static const String triggeredBy = 'triggered_by';
  static const String incidentNote = 'incident_note';
  static const String bidId = 'bid_id';
  static const String bidAmount = 'bid_amount';
  static const String message = 'message';
  static const String transactionId = 'transaction_id';
  static const String amount = 'amount';
  static const String pixKey = 'pix_key';
  static const String pixKeyType = 'pix_key_type';
  static const String processedAt = 'processed_at';
  static const String campaignId = 'campaign_id';
  static const String titulo = 'titulo';
  static const String mensagem = 'mensagem';
  static const String imagemUrl = 'imagem_url';
  static const String tipoIncentivo = 'tipo_incentivo';
  static const String valorBonus = 'valor_ou_percentual_bonus';
  static const String cidadeAlvo = 'cidade_alvo';
  static const String dataHoraDisparo = 'data_hora_disparo';
  static const String dataHoraExpiracao = 'data_hora_expiracao';
  static const String fcmToken = 'fcm_token';
  static const String topics = 'topics';
}
