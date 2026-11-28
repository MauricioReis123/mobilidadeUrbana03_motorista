import '../models/omni_models.dart';
import '../utils/document_validators.dart';

/// Motor Modular de Triagem Documental & Antifraude Comportamental OMNI
/// Paridade 1:1 com src/services/behavioralAntifraudEngine.ts
class BehavioralAntifraudEngine {
  static const String legalDisclaimer =
      'A verificação documental e cadastral da OMNI realiza triagem inicial e conferência antes da aprovação, com gestão contínua de risco comportamental. Esta conferência não garante 100% de segurança nem elimina a possibilidade de eventos futuros; inconsistências documentais, falta de autenticidade ou desvios de conduta podem resultar em reprovação ou suspensão preventiva.';

  static String statusLabel(String status) {
    switch (status) {
      case 'PENDING_SUBMISSION':
        return 'Pendente de envio';
      case 'IN_REVIEW':
        return 'Em análise';
      case 'APPROVED':
        return 'Aprovado';
      case 'ADJUSTMENT_REQUIRED':
        return 'Ajuste necessário';
      case 'REVALIDATION_PENDING':
        return 'Revalidação pendente';
      case 'SUSPENDED':
        return 'Suspenso';
      case 'REJECTED':
        return 'Reprovado';
      default:
        return 'Pendente de envio';
    }
  }

  static bool isValidCpfOrCnpjDigits(String? raw) {
    final digits = (raw ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11) {
      if (RegExp(r'^(\d)\1{10}$').hasMatch(digits)) return false;
      int sum = 0;
      for (int i = 0; i < 9; i++) {
        sum += int.parse(digits[i]) * (10 - i);
      }
      int r = (sum * 10) % 11;
      if (r == 10) r = 0;
      if (r != int.parse(digits[9])) return false;
      sum = 0;
      for (int i = 0; i < 10; i++) {
        sum += int.parse(digits[i]) * (11 - i);
      }
      r = (sum * 10) % 11;
      if (r == 10) r = 0;
      return r == int.parse(digits[10]);
    }
    if (digits.length == 14) {
      if (RegExp(r'^(\d)\1{13}$').hasMatch(digits)) return false;
      const w1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
      const w2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
      int sum = 0;
      for (int i = 0; i < 12; i++) {
        sum += int.parse(digits[i]) * w1[i];
      }
      int rem = sum % 11;
      final d1 = rem < 2 ? 0 : 11 - rem;
      if (d1 != int.parse(digits[12])) return false;
      sum = 0;
      for (int i = 0; i < 13; i++) {
        sum += int.parse(digits[i]) * w2[i];
      }
      rem = sum % 11;
      final d2 = rem < 2 ? 0 : 11 - rem;
      return d2 == int.parse(digits[13]);
    }
    return false;
  }

  static int countVehiclePhotos(VehicleVisualPhotos? photos) {
    if (photos == null) return 0;
    int count = 0;
    if ((photos.front ?? '').trim().isNotEmpty) count++;
    if ((photos.rear ?? '').trim().isNotEmpty) count++;
    if ((photos.leftSide ?? '').trim().isNotEmpty) count++;
    if ((photos.rightSide ?? '').trim().isNotEmpty) count++;
    if ((photos.plate ?? '').trim().isNotEmpty) count++;
    return count;
  }

  static CriminalScreeningResult evaluateCriminalCertificate(
    CriminalCertificateSubmission? submission,
    DriverDocument? bgDoc, {
    String? driverName,
  }) {
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final codeSuffix =
        now.millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    final protocolCode =
        'OMNI-TRG-${codeSuffix.length >= 6 ? codeSuffix.substring(codeSuffix.length - 6) : codeSuffix}';

    final code = (submission?.validationCode ?? '').trim();
    final issueDate = (submission?.issueDate ?? '').trim();
    final uf = (submission?.ufJurisdiction ?? '').trim().toUpperCase();
    final portal = submission?.issuingPortal ?? 'PF';
    final selfDeclared = submission?.selfDeclaredClean ?? false;

    final hasAttachment = bgDoc != null &&
        bgDoc.status != 'REJECTED' &&
        ((bgDoc.fileUrl ?? '').isNotEmpty ||
            (bgDoc.filePath ?? '').isNotEmpty ||
            (bgDoc.fileBytes != null && bgDoc.fileBytes!.isNotEmpty) ||
            bgDoc.status == 'APPROVED');

    final hasValidCode = RegExp(r'^[A-Za-z0-9.\-]{6,40}$').hasMatch(code);

    bool hasValidDate = false;
    int daysOld = 999;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(issueDate)) {
      final parsed = DateTime.tryParse('${issueDate}T00:00:00');
      if (parsed != null) {
        daysOld = now.difference(parsed).inDays;
        hasValidDate = daysOld >= -1 && daysOld <= 90;
      }
    }

    final hasValidUf = RegExp(r'^[A-Z]{2}$').hasMatch(uf) || portal == 'PF';

    final ocrText = (bgDoc?.aiAudit?.ocrTextExcerpt ?? '').toUpperCase();
    const adverseKeywords = [
      'CONDENACAO PENAL',
      'MANDADO DE PRISAO',
      'POSITIVA COM PROCESSO',
      'RESTRICAO CRIMINAL',
      'TRANSITADO EM JULGADO',
    ];
    final hasAdverseText =
        adverseKeywords.any((k) => ocrText.contains(k));

    final findings = <String>[
      hasAttachment
          ? 'Arquivo da certidão anexado para conferência documental.'
          : 'Anexo da Certidão de Antecedentes (PF ou Justiça Estadual) pendente.',
      hasValidCode
          ? 'Código de autenticação informado ($portal: ${code.toUpperCase()}).'
          : 'Código de validação/autenticação da certidão não informado (mín. 6 caracteres).',
      hasValidDate
          ? 'Data de emissão recente verificada ($issueDate • ${daysOld < 0 ? 0 : daysOld} dias).'
          : 'Informe uma data de emissão válida com até 90 dias de validade.',
      selfDeclared
          ? 'Declaração de veracidade documental e ausência de impedimentos assinada.'
          : 'Confirme a declaração de veracidade da certidão enviada.',
    ];

    if (bgDoc?.status == 'REJECTED' || hasAdverseText) {
      return CriminalScreeningResult(
        status: 'REJECTED',
        score: 15,
        riskLevel: 'HIGH',
        protocolCode: protocolCode,
        checkedAt: nowIso,
        hasAttachment: false,
        hasValidCode: hasValidCode,
        hasValidDate: hasValidDate,
        hasDeclaration: selfDeclared,
        summary:
            'Inconsistência ou apontamento detectado na conferência da certidão enviada. Envio reprovado na triagem inicial.',
        findings: findings,
        rejectionReason: bgDoc?.aiAudit?.rejectionReason ??
            'A certidão anexada apresenta inconsistência ou apontamento incompatível na conferência inicial.',
      );
    }

    if (!hasAttachment && code.isEmpty && issueDate.isEmpty && !selfDeclared) {
      return CriminalScreeningResult(
        status: 'PENDING_SUBMISSION',
        score: 0,
        riskLevel: 'MEDIUM',
        protocolCode: protocolCode,
        checkedAt: nowIso,
        hasAttachment: false,
        hasValidCode: false,
        hasValidDate: false,
        hasDeclaration: false,
        summary:
            'Envie sua Certidão de Antecedentes Criminais (Polícia Federal ou Justiça Estadual) com código de validação para iniciar a triagem.',
        findings: findings,
      );
    }

    int score = 0;
    if (hasAttachment) score += 35;
    if (hasValidCode) score += 25;
    if (hasValidDate) score += 20;
    if (hasValidUf) score += 5;
    if (selfDeclared) score += 15;

    final missing = <String>[];
    if (!hasAttachment) missing.add('anexo da certidão');
    if (!hasValidCode) missing.add('código de validação oficial');
    if (!hasValidDate) missing.add('data de emissão (máx. 90 dias)');
    if (!hasValidUf) missing.add('UF emissora');
    if (!selfDeclared) missing.add('declaração de veracidade');

    if (missing.isNotEmpty) {
      return CriminalScreeningResult(
        status: 'ADJUSTMENT_REQUIRED',
        score: score,
        riskLevel: score >= 60 ? 'MEDIUM' : 'HIGH',
        protocolCode: protocolCode,
        checkedAt: nowIso,
        hasAttachment: hasAttachment,
        hasValidCode: hasValidCode,
        hasValidDate: hasValidDate,
        hasDeclaration: selfDeclared,
        summary:
            'Ajuste necessário na triagem (${driverName ?? 'motorista'}): complete ${missing.join(', ')}.',
        findings: findings,
        rejectionReason: 'Complete os itens pendentes: ${missing.join(', ')}.',
      );
    }

    if (bgDoc?.status == 'PENDING') {
      return CriminalScreeningResult(
        status: 'IN_REVIEW',
        score: 85,
        riskLevel: 'LOW',
        protocolCode: protocolCode,
        checkedAt: nowIso,
        hasAttachment: true,
        hasValidCode: true,
        hasValidDate: true,
        hasDeclaration: true,
        summary:
            'Certidão recebida e em análise de conferência documental (triagem pré-aprovação).',
        findings: findings,
      );
    }

    return CriminalScreeningResult(
      status: 'APPROVED',
      score: 100,
      riskLevel: 'LOW',
      protocolCode: protocolCode,
      checkedAt: nowIso,
      hasAttachment: true,
      hasValidCode: true,
      hasValidDate: true,
      hasDeclaration: true,
      summary:
          'Triagem documental aprovada ($portal) • Conferência inicial concluída sem pendências.',
      findings: findings,
    );
  }

  static VehicleScreeningResult evaluateVehiclePackage(
    OmniVehicle vehicle,
    DriverDocument? crlvDoc,
  ) {
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final codeSuffix =
        now.millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    final protocolCode =
        'OMNI-VEH-${codeSuffix.length >= 6 ? codeSuffix.substring(codeSuffix.length - 6) : codeSuffix}';

    final plateValid = isValidBrazilianPlate(vehicle.plate);
    final renavamDigits = (vehicle.renavam ?? '').replaceAll(RegExp(r'\D'), '');
    final renavamValid =
        renavamDigits.length == 11 && isValidBrazilianRenavam(renavamDigits);
    final chassiClean = (vehicle.chassi ?? '').trim();
    final chassiValid =
        chassiClean.isNotEmpty && isValidBrazilianChassi(chassiClean);

    final parsedCrlvYear =
        int.tryParse((vehicle.crlvExpiry ?? '').replaceAll(RegExp(r'\D'), ''));
    final crlvNotExpired =
        parsedCrlvYear == null || parsedCrlvYear >= now.year - 1;

    final crlvAttached = crlvDoc != null &&
        crlvDoc.status != 'REJECTED' &&
        ((crlvDoc.fileUrl ?? '').isNotEmpty ||
            (crlvDoc.filePath ?? '').isNotEmpty ||
            (crlvDoc.fileBytes != null && crlvDoc.fileBytes!.isNotEmpty) ||
            crlvDoc.status == 'APPROVED');

    final ownershipType = vehicle.ownershipType ?? 'PROPRIO';
    final requiresOwnerAuth = ownershipType != 'PROPRIO';
    final ownerNameOk =
        !requiresOwnerAuth || (vehicle.ownerName ?? '').trim().length >= 3;
    final ownerDocOk =
        !requiresOwnerAuth || isValidCpfOrCnpjDigits(vehicle.ownerDocument);
    final authDocOk = !requiresOwnerAuth ||
        (vehicle.authorizationDocPath ?? '').trim().isNotEmpty ||
        (vehicle.authorizationDocName ?? '').trim().isNotEmpty ||
        (vehicle.authorizationDocBytes != null &&
            vehicle.authorizationDocBytes!.isNotEmpty);
    final ownershipVerified = ownerNameOk && ownerDocOk && authDocOk;

    final photosCount = countVehiclePhotos(vehicle.visualPhotos);
    final photosComplete = photosCount >= 5;

    final findings = <String>[
      crlvAttached && crlvNotExpired
          ? 'CRLV anexado e compatível (${vehicle.crlvExpiry ?? now.year}).'
          : !crlvNotExpired
              ? 'CRLV com exercício desatualizado (${vehicle.crlvExpiry}).'
              : 'Anexo do CRLV atualizado pendente.',
      renavamValid && plateValid
          ? 'Placa ${vehicle.plate} e RENAVAM (Módulo 11) estruturalmente válidos.'
          : 'Verifique Placa e os 11 dígitos do RENAVAM.',
      requiresOwnerAuth
          ? ownershipVerified
              ? 'Vínculo ($ownershipType) com proprietário e autorização anexada.'
              : 'Informe nome, CPF/CNPJ do proprietário e anexe o termo/contrato de autorização.'
          : 'Veículo declarado como próprio pelo motorista.',
      photosComplete
          ? '5/5 fotos nítidas do veículo enviadas (frente, traseira, laterais e placa).'
          : 'Fotos nítidas do veículo: $photosCount/5 ângulos enviados.',
    ];

    if (crlvDoc?.status == 'REJECTED' || !crlvNotExpired) {
      return VehicleScreeningResult(
        status: 'ADJUSTMENT_REQUIRED',
        score: 30,
        riskLevel: 'HIGH',
        protocolCode: protocolCode,
        checkedAt: nowIso,
        crlvAttached: false,
        ownershipVerified: ownershipVerified,
        photosCount: photosCount,
        renavamValid: renavamValid,
        plateValid: plateValid,
        chassiValid: chassiValid,
        summary: !crlvNotExpired
            ? 'CRLV fora do exercício vigente. Envie o licenciamento atualizado.'
            : 'CRLV reprovado na conferência. Reenvie um documento legível.',
        findings: findings,
        rejectionReason: crlvDoc?.aiAudit?.rejectionReason ??
            'Atualize o CRLV do veículo para seguir.',
      );
    }

    if (renavamDigits.isEmpty && !crlvAttached && photosCount == 0) {
      return VehicleScreeningResult(
        status: 'PENDING_SUBMISSION',
        score: 0,
        riskLevel: 'MEDIUM',
        protocolCode: protocolCode,
        checkedAt: nowIso,
        crlvAttached: false,
        ownershipVerified: ownershipVerified,
        photosCount: 0,
        renavamValid: renavamValid,
        plateValid: plateValid,
        chassiValid: chassiValid,
        summary:
            'Envie o CRLV, informe o vínculo de posse do veículo e capture as 5 fotos nítidas para triagem.',
        findings: findings,
      );
    }

    int score = 0;
    if (crlvAttached) score += 25;
    if (plateValid) score += 15;
    if (renavamValid) score += 15;
    if (ownershipVerified) score += 20;
    score += ((photosCount > 5 ? 5 : photosCount) * 5);

    final missing = <String>[];
    if (!crlvAttached) missing.add('CRLV atualizado');
    if (!plateValid) missing.add('placa válida');
    if (!renavamValid) missing.add('RENAVAM válido (11 dígitos)');
    if (!ownershipVerified) missing.add('dados/autorização do proprietário');
    if (!photosComplete) missing.add('fotos nítidas do veículo ($photosCount/5)');

    if (missing.isNotEmpty) {
      return VehicleScreeningResult(
        status: 'ADJUSTMENT_REQUIRED',
        score: score,
        riskLevel: score >= 70 ? 'MEDIUM' : 'HIGH',
        protocolCode: protocolCode,
        checkedAt: nowIso,
        crlvAttached: crlvAttached,
        ownershipVerified: ownershipVerified,
        photosCount: photosCount,
        renavamValid: renavamValid,
        plateValid: plateValid,
        chassiValid: chassiValid,
        summary:
            'Ajuste necessário na triagem veicular: pendente ${missing.join(', ')}.',
        findings: findings,
        rejectionReason: 'Complete: ${missing.join(', ')}.',
      );
    }

    return VehicleScreeningResult(
      status: 'APPROVED',
      score: 100,
      riskLevel: 'LOW',
      protocolCode: protocolCode,
      checkedAt: nowIso,
      crlvAttached: true,
      ownershipVerified: true,
      photosCount: 5,
      renavamValid: true,
      plateValid: true,
      chassiValid: chassiValid,
      summary:
          'Triagem veicular concluída (${vehicle.plate}) • CRLV, vínculo de uso e 5 fotos nítidas conferidos.',
      findings: findings,
    );
  }

  static BehavioralRiskState createDefaultState({
    String initialStatus = 'PENDING_SUBMISSION',
  }) {
    return BehavioralRiskState(
      accountStatus: initialStatus,
      riskScore: 8,
      riskLevel: 'LOW',
      revalidationRequired: false,
      vehicleSwitchCountRecent: 0,
      incidentCount: 0,
      events: const [],
      deviceFingerprint: 'OMNI-DEV-PRIMARY',
    );
  }

  static _TriggerDef _triggerDef(String type) {
    switch (type) {
      case 'ROUTE_DEVIATION':
        return const _TriggerDef(
          title: 'Desvio Atípico de Rota',
          desc:
              'Trajeto divergente da rota sugerida sem justificativa operacional registrada.',
          points: 18,
          severity: 'MEDIUM',
          requiresRevalidation: false,
        );
      case 'UNUSUAL_STOP':
        return const _TriggerDef(
          title: 'Parada Prolongada Atípica',
          desc:
              'Veículo permaneceu imóvel em área fora do ponto de embarque/destino durante corrida ativa.',
          points: 12,
          severity: 'LOW',
          requiresRevalidation: false,
        );
      case 'REGION_SHIFT':
        return const _TriggerDef(
          title: 'Mudança Brusca de Região',
          desc:
              'Atividade iniciada em área distante do histórico operacional habitual.',
          points: 15,
          severity: 'MEDIUM',
          requiresRevalidation: false,
        );
      case 'SCHEDULE_SHIFT':
        return const _TriggerDef(
          title: 'Alteração Repentina de Horário',
          desc: 'Padrão de operação fora da faixa horária recorrente do motorista.',
          points: 10,
          severity: 'LOW',
          requiresRevalidation: false,
        );
      case 'EXCESSIVE_CANCELLATION':
        return const _TriggerDef(
          title: 'Cancelamentos Excessivos',
          desc:
              'Taxa elevada de cancelamentos recentes pode indicar recusa seletiva ou fraude operacional.',
          points: 22,
          severity: 'HIGH',
          requiresRevalidation: false,
        );
      case 'REPETITIVE_TRIPS':
        return const _TriggerDef(
          title: 'Padrão Repetitivo de Corridas',
          desc:
              'Múltiplas corridas em sequência entre o mesmo par de origem/destino ou contas correlacionadas.',
          points: 25,
          severity: 'HIGH',
          requiresRevalidation: true,
        );
      case 'FREQUENT_VEHICLE_SWITCH':
        return const _TriggerDef(
          title: 'Trocas Frequentes de Veículo',
          desc:
              'Múltiplas alternâncias de veículo ativo em curto intervalo exigem confirmação biométrica.',
          points: 20,
          severity: 'HIGH',
          requiresRevalidation: true,
        );
      case 'SHIFT_START':
        return const _TriggerDef(
          title: 'Revalidação Periódica de Turno',
          desc:
              'Confirmação aleatória/periódica no molde oval para assegurar que o titular está ao volante.',
          points: 0,
          severity: 'INFO',
          requiresRevalidation: true,
        );
      case 'DEVICE_CHANGE':
        return const _TriggerDef(
          title: 'Troca de Dispositivo Detectada',
          desc:
              'Acesso realizado a partir de um novo aparelho ou navegador exige nova selfie ao vivo.',
          points: 25,
          severity: 'HIGH',
          requiresRevalidation: true,
        );
      case 'PROFILE_EDIT':
        return const _TriggerDef(
          title: 'Alteração Cadastral Sensível',
          desc:
              'Edição em dados sensíveis (CPF, RG, telefone ou nome) com cadastro já ativo requer revalidação facial.',
          points: 18,
          severity: 'MEDIUM',
          requiresRevalidation: true,
        );
      case 'DOC_EXPIRY':
        return const _TriggerDef(
          title: 'Documento Vencido ou Vencendo',
          desc:
              'CNH, CRLV ou Certidão fora do prazo regulamentar exige atualização e revalidação.',
          points: 20,
          severity: 'HIGH',
          requiresRevalidation: true,
        );
      case 'INCIDENT_REPORT':
      default:
        return const _TriggerDef(
          title: 'Relato de Incidente / Denúncia',
          desc:
              'Ocorrência ou reclamação grave reportada por passageiro acionou revisão preventiva imediata.',
          points: 35,
          severity: 'CRITICAL',
          requiresRevalidation: true,
        );
    }
  }

  static BehavioralRiskState recalculateRiskState(
    BehavioralRiskState state, {
    double rating = 5.0,
    double cancellationRate = 0.0,
    bool onboardingApproved = false,
  }) {
    int eventsScore = 0;
    for (final ev in state.events.take(8)) {
      eventsScore += ev.points;
    }
    if (eventsScore > 75) eventsScore = 75;

    int metricPenalty = 0;
    if (cancellationRate > 12) metricPenalty += 15;
    if (rating < 4.5) metricPenalty += 15;
    if (state.vehicleSwitchCountRecent >= 3) metricPenalty += 15;
    if (state.incidentCount >= 2) metricPenalty += 20;

    int riskScore = 8 + eventsScore + metricPenalty;
    if (riskScore > 100) riskScore = 100;
    if (riskScore < 5) riskScore = 5;

    String riskLevel = 'LOW';
    if (riskScore >= 80) {
      riskLevel = 'CRITICAL';
    } else if (riskScore >= 55) {
      riskLevel = 'HIGH';
    } else if (riskScore >= 30) {
      riskLevel = 'MEDIUM';
    }

    String accountStatus = state.accountStatus;
    String? preventiveBlockReason = state.preventiveBlockReason;
    bool revalidationRequired = state.revalidationRequired;

    if (riskScore >= 80 || state.incidentCount >= 3) {
      accountStatus = 'SUSPENDED';
      preventiveBlockReason = preventiveBlockReason ??
          'Conta suspensa preventivamente devido ao índice elevado de risco comportamental / incidentes acumulados.';
    } else if (revalidationRequired || riskScore >= 55) {
      revalidationRequired = true;
      accountStatus = 'REVALIDATION_PENDING';
    } else if (onboardingApproved) {
      accountStatus = 'APPROVED';
      preventiveBlockReason = null;
    }

    return state.copyWith(
      riskScore: riskScore,
      riskLevel: riskLevel,
      revalidationRequired: revalidationRequired,
      accountStatus: accountStatus,
      preventiveBlockReason: preventiveBlockReason,
      clearPreventiveBlock: !isCritical(riskScore, state.incidentCount) &&
          onboardingApproved &&
          !revalidationRequired,
    );
  }

  static bool isCritical(int riskScore, int incidentCount) =>
      riskScore >= 80 || incidentCount >= 3;

  static BehavioralRiskState recordEvent(
    BehavioralRiskState? current,
    String triggerType, {
    double rating = 5.0,
    double cancellationRate = 0.0,
    bool onboardingApproved = false,
    String? customDescription,
  }) {
    final base = current ?? createDefaultState(initialStatus: 'IN_REVIEW');
    final def = _triggerDef(triggerType);
    final now = DateTime.now();
    final nowIso = now.toIso8601String();

    final newEv = BehavioralEventRecord(
      id: 'bev_${now.millisecondsSinceEpoch}_${base.events.length}',
      type: triggerType,
      severity: def.severity,
      points: def.points,
      requiresRevalidation: def.requiresRevalidation,
      title: def.title,
      description: customDescription ?? def.desc,
      occurredAt: nowIso,
    );

    final nextSwitch = triggerType == 'FREQUENT_VEHICLE_SWITCH'
        ? base.vehicleSwitchCountRecent + 1
        : base.vehicleSwitchCountRecent;
    final nextIncidents = triggerType == 'INCIDENT_REPORT'
        ? base.incidentCount + 1
        : base.incidentCount;

    final updated = base.copyWith(
      vehicleSwitchCountRecent: nextSwitch,
      incidentCount: nextIncidents,
      revalidationRequired:
          base.revalidationRequired || def.requiresRevalidation,
      revalidationTrigger: def.requiresRevalidation
          ? triggerType
          : base.revalidationTrigger,
      revalidationReason: def.requiresRevalidation
          ? (customDescription ?? def.desc)
          : base.revalidationReason,
      events: [newEv, ...base.events].take(25).toList(),
    );

    return recalculateRiskState(
      updated,
      rating: rating,
      cancellationRate: cancellationRate,
      onboardingApproved: onboardingApproved,
    );
  }

  static BehavioralRiskState clearRevalidationAfterOvalSelfie(
    BehavioralRiskState? current, {
    required bool onboardingApproved,
  }) {
    final base = current ??
        createDefaultState(
            initialStatus: onboardingApproved ? 'APPROVED' : 'IN_REVIEW');
    final nowIso = DateTime.now().toIso8601String();
    final isSuspended = base.incidentCount >= 3;

    int resolvedScore = base.riskScore - 25;
    if (resolvedScore < 8) resolvedScore = 8;
    String riskLevel = 'LOW';
    if (resolvedScore >= 80) {
      riskLevel = 'CRITICAL';
    } else if (resolvedScore >= 55) {
      riskLevel = 'HIGH';
    } else if (resolvedScore >= 30) {
      riskLevel = 'MEDIUM';
    }

    final nextStatus = isSuspended
        ? 'SUSPENDED'
        : onboardingApproved
            ? 'APPROVED'
            : 'IN_REVIEW';

    final okEvent = BehavioralEventRecord(
      id: 'bev_${DateTime.now().millisecondsSinceEpoch}_liveness',
      type: 'SHIFT_START',
      severity: 'INFO',
      points: 0,
      requiresRevalidation: false,
      title: 'Revalidação Facial ao Vivo Concluída',
      description:
          'Prova de vida no molde oval concluída com êxito; bloqueio de revalidação liberado.',
      occurredAt: nowIso,
    );

    return base.copyWith(
      accountStatus: nextStatus,
      riskScore: resolvedScore,
      riskLevel: riskLevel,
      revalidationRequired: false,
      clearRevalidationTrigger: true,
      clearPreventiveBlock: !isSuspended,
      lastLivenessAt: nowIso,
      events: [okEvent, ...base.events].take(25).toList(),
    );
  }
}

class _TriggerDef {
  final String title;
  final String desc;
  final int points;
  final String severity;
  final bool requiresRevalidation;

  const _TriggerDef({
    required this.title,
    required this.desc,
    required this.points,
    required this.severity,
    required this.requiresRevalidation,
  });
}
