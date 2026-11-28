import '../models/omni_models.dart';
import '../services/behavioral_antifraud_engine.dart';
import 'document_validators.dart';

/// Motor Canônico de Aptidão Global do Motorista OMNI (Gatekeeper 0%–100%)
/// 1:1 com src/utils/driverOnboarding.ts — 18 etapas somando exatamente 100%

enum OnboardingTargetAction {
  openBioModal,
  openDocCpf,
  openDocRg,
  openDocCnh,
  openDocCrlv,
  openDocResidence,
  openPersonalForm,
  openVehiclesForm,
  openComplianceTerms,
}

enum OnboardingPillarId {
  documents,
  biometrics,
  formsVehicle,
  compliance,
}

class OnboardingStepItem {
  final String id;
  final OnboardingPillarId pillar;
  final String label;
  final String description;
  final bool completed;
  final bool hasError;
  final String statusLabel;
  final int weight;
  final OnboardingTargetAction action;

  const OnboardingStepItem({
    required this.id,
    required this.pillar,
    required this.label,
    required this.description,
    required this.completed,
    this.hasError = false,
    this.statusLabel = '',
    required this.weight,
    required this.action,
  });
}

class OnboardingPillarSummary {
  final OnboardingPillarId id;
  final String label;
  final int completedCount;
  final int totalCount;
  final bool isComplete;

  const OnboardingPillarSummary({
    required this.id,
    required this.label,
    required this.completedCount,
    required this.totalCount,
    required this.isComplete,
  });
}

class DriverOnboardingStatus {
  final int onboardingScore;
  final bool isDriverFullyApproved;
  final int completedStepsCount;
  final int totalStepsCount;
  final List<OnboardingStepItem> steps;
  final List<OnboardingStepItem> pendingSteps;
  final List<OnboardingPillarSummary> pillars;
  final OnboardingStepItem? nextRecommendedStep;
  final String gatekeeperHeadline;
  final String gatekeeperSubtext;

  const DriverOnboardingStatus({
    required this.onboardingScore,
    required this.isDriverFullyApproved,
    required this.completedStepsCount,
    required this.totalStepsCount,
    required this.steps,
    required this.pendingSteps,
    required this.pillars,
    required this.nextRecommendedStep,
    required this.gatekeeperHeadline,
    required this.gatekeeperSubtext,
  });
}

DriverDocument? _findDoc(List<DriverDocument> docs, String docType) {
  return docs.cast<DriverDocument?>().firstWhere(
        (d) => d != null && d.type == docType,
        orElse: () => null,
      );
}

DriverOnboardingStatus evaluateDriverOnboarding({
  required OmniDriver driver,
  required List<DriverDocument> documents,
  required List<OmniVehicle> vehicles,
}) {
  final cpfDoc = _findDoc(documents, 'CPF');
  final rgDoc = _findDoc(documents, 'RG');
  final cnhDoc = _findDoc(documents, 'CNH_EAR') ?? _findDoc(documents, 'CNH');
  final crlvDoc = _findDoc(documents, 'CRLV');
  final residenceDoc = _findDoc(documents, 'RESIDENCE_PROOF');

  final cpfDocApproved = cpfDoc?.status == 'APPROVED';
  final rgDocApproved = rgDoc?.status == 'APPROVED';
  final cnhDocApproved = cnhDoc?.status == 'APPROVED';
  final crlvDocApproved = crlvDoc?.status == 'APPROVED';
  final residenceDocApproved = residenceDoc?.status == 'APPROVED';

  final activeVehicle = vehicles.cast<OmniVehicle?>().firstWhere(
        (v) => v != null && v.isActive && v.status == 'APPROVED',
        orElse: () => vehicles.isNotEmpty ? vehicles.first : null,
      );
  final isMotoActive = activeVehicle?.type == VehicleType.moto ||
      activeVehicle?.category == VehicleCategory.omniMoto;

  // Compatibilidade da CNH com o veículo ativo e flag EAR
  final cnhExt = cnhDoc?.aiAudit?.extractedValidation;
  final effectiveCnhCat =
      (cnhExt?.cnhCategory ?? driver.cnhCategory ?? '').toUpperCase().trim();
  final cnhCompatible = effectiveCnhCat.isEmpty
      ? false
      : isMotoActive
          ? (cnhExt?.cnhMotoQualified ??
              const {'A', 'AB', 'AC', 'AD', 'AE'}.contains(effectiveCnhCat))
          : (cnhExt?.cnhCarQualified ??
              const {'B', 'AB', 'AC', 'AD', 'AE', 'C', 'D', 'E'}
                  .contains(effectiveCnhCat));
  final cnhEarActive = (cnhExt?.cnhHasEar ?? true) &&
      driver.cnhEar &&
      (driver.workPreferences?.hasEar ?? true);
  final cnhStepOk = cnhDocApproved && cnhCompatible && cnhEarActive;

  // Biometria Oval + Match Cruzado Bidirecional + Digital Nativa + Digital vs RG/CNH
  final hasOvalFace = (driver.capturedOvalFaceBytes != null &&
          driver.capturedOvalFaceBytes!.isNotEmpty) ||
      (driver.capturedOvalFacePath != null &&
          driver.capturedOvalFacePath!.isNotEmpty);
  final rgMatched = driver.faceMatchRg?.status == 'MATCHED';
  final cnhMatched = driver.faceMatchCnh?.status == 'MATCHED';
  final hasFaceMismatch = driver.faceMatchRg?.status == 'MISMATCH' ||
      driver.faceMatchCnh?.status == 'MISMATCH';
  final ovalStepOk = hasOvalFace && driver.isBiometricVerified;
  final crossMatchStepOk =
      hasOvalFace && rgMatched && cnhMatched && !hasFaceMismatch;
  final fingerprintStepOk = driver.isFingerprintVerified;

  final fpCmp = driver.fingerprintDocComparison;
  final fpDocCompareOk = fingerprintStepOk && fpCmp?.status == 'MATCHED';
  final fpDocCompareMismatch = fpCmp?.status == 'MISMATCH';

  // Formulário Pessoal Completo (idade >= 21, CPF Mod-11 ou doc aprovado, RG >= 5, CNH 11 dígitos)
  final fullNameOk =
      driver.name.trim().length >= 5 && driver.name.trim().contains(' ');
  final age = calculateAgeFromIso(driver.birthDate);
  final ageOk = age != null && age >= 21;
  final emailStr = driver.email?.trim() ?? '';
  final emailOk = emailStr.contains('@') && emailStr.contains('.');
  final phoneDigits = driver.phone.replaceAll(RegExp(r'\D'), '');
  final phoneOk = phoneDigits.length >= 10;

  final cpfDigits = driver.cpf.replaceAll(RegExp(r'\D'), '');
  final cpfFormOk = (!driver.cpf.contains('*') &&
          cpfDigits.length == 11 &&
          isValidBrazilianCpf(cpfDigits)) ||
      cpfDocApproved;
  final rgFormOk = (driver.rg ?? '').trim().length >= 5;
  final cnhDigits = driver.cnhNumber.replaceAll(RegExp(r'\D'), '');
  final cnhFormOk =
      cnhDigits.length == 11 && isValidBrazilianCnhNumber(cnhDigits);

  final personalMissing = <String>[];
  if (!fullNameOk) personalMissing.add('nome completo');
  if (!ageOk) personalMissing.add('nascimento (>= 21 anos)');
  if (!cpfFormOk) personalMissing.add('CPF válido');
  if (!rgFormOk) personalMissing.add('nº do RG');
  if (!cnhFormOk) personalMissing.add('nº CNH (11 dígitos)');
  if (!emailOk || !phoneOk) personalMissing.add('e-mail/telefone');
  final personalStepOk = personalMissing.isEmpty;

  // Endereço Completo
  final addr = driver.address;
  final addressStepOk = addr != null &&
      addr.cep.replaceAll(RegExp(r'\D'), '').length == 8 &&
      addr.street.trim().length >= 3 &&
      addr.number.trim().isNotEmpty &&
      addr.neighborhood.trim().length >= 2 &&
      addr.city.trim().length >= 2 &&
      addr.state.trim().length == 2;

  // PIX + Dados Bancários + Contato SOS
  final payout = driver.bankPayout;
  final sos = driver.emergencyContact;
  final payoutOk = payout != null &&
      payout.pixKey.trim().length >= 4 &&
      payout.bankName.trim().length >= 2 &&
      payout.agency.trim().length >= 2 &&
      payout.account.trim().length >= 3;
  final sosOk = sos != null &&
      sos.name.trim().length >= 3 &&
      sos.phone.replaceAll(RegExp(r'\D'), '').length >= 10;
  final payoutSosStepOk = payoutOk && sosOk;

  // Veículo Ativo Regularizado
  final vehicleStepOk = activeVehicle != null &&
      activeVehicle.status == 'APPROVED' &&
      activeVehicle.brand.trim().length >= 2 &&
      activeVehicle.model.trim().length >= 2 &&
      activeVehicle.color.trim().length >= 2 &&
      activeVehicle.plate
              .replaceAll(RegExp(r'[^A-Z0-9]', caseSensitive: false), '')
              .length >=
          7 &&
      activeVehicle.year >= 2005;

  final vehScreening = activeVehicle != null
      ? BehavioralAntifraudEngine.evaluateVehiclePackage(activeVehicle, crlvDoc)
      : null;
  final vehScreeningOk = vehScreening?.status == 'APPROVED';
  final vehScreeningRejected = vehScreening?.status == 'REJECTED' ||
      vehScreening?.status == 'SUSPENDED';

  // Seguro APP Passageiros + 5 Fotos Nítidas / Vistoria 360°
  final hasInsuranceData = activeVehicle != null &&
      activeVehicle.insuranceAppActive != false &&
      (activeVehicle.insuranceCompany ?? '').trim().length >= 3 &&
      (activeVehicle.insurancePolicy ?? '').trim().length >= 4;
  final hasInspection360 = activeVehicle?.inspection360Completed == true ||
      (vehScreening != null && vehScreening.photosCount >= 5);
  final insuranceInspectionStepOk = hasInsuranceData && hasInspection360;

  // Ritos de Conformidade e Triagem de Certidão de Antecedentes Criminais
  final rites = driver.complianceRites;
  final termsAccepted = rites != null && rites.acceptedTerms;
  final safetyBriefingCompleted =
      rites != null && rites.completedSafetyBriefing;

  final bgDoc = _findDoc(documents, 'BACKGROUND_CHECK');
  final crimScreening = BehavioralAntifraudEngine.evaluateCriminalCertificate(
    driver.criminalCertificate,
    bgDoc,
    driverName: driver.name,
  );
  final bgCheckOk = crimScreening.status == 'APPROVED';
  final bgCheckRejected = crimScreening.status == 'REJECTED' ||
      crimScreening.status == 'SUSPENDED';

  // Matriz 100% blindada: 18 etapas somando exatamente 100 pontos:
  // DOCUMENTS (32%): 7 + 8 + 8 + 5 + 4 = 32
  // BIOMETRICS (27%): 6 + 10 + 5 + 6 = 27
  // FORMS_VEHICLE (29%): 6 + 3 + 4 + 5 + 6 + 5 = 29
  // COMPLIANCE (12%): 6 + 3 + 3 = 12
  final steps = <OnboardingStepItem>[
    OnboardingStepItem(
      id: 'doc_cpf',
      pillar: OnboardingPillarId.documents,
      label: 'CPF Validado por IA (Módulo 11)',
      description: cpfDocApproved
          ? 'Documento CPF aprovado pela auditoria OCR e dígitos verificadores.'
          : 'Envie ou fotografe seu CPF para validação OCR e cálculo Módulo 11.',
      completed: cpfDocApproved,
      hasError: cpfDoc?.status == 'REJECTED',
      statusLabel: cpfDoc?.status == 'REJECTED'
          ? 'Reprovado'
          : cpfDocApproved
              ? 'Aprovado'
              : 'Pendente',
      weight: 7,
      action: OnboardingTargetAction.openDocCpf,
    ),
    OnboardingStepItem(
      id: 'doc_rg',
      pillar: OnboardingPillarId.documents,
      label: 'RG / CIN Autêntico por IA',
      description: rgDocApproved
          ? 'Identidade RG/CIN aprovada na auditoria visual, OCR e papiloscopia.'
          : 'Envie ou fotografe seu RG aberto (com foto e polegar direito legíveis).',
      completed: rgDocApproved,
      hasError: rgDoc?.status == 'REJECTED',
      statusLabel: rgDoc?.status == 'REJECTED'
          ? 'Reprovado'
          : rgDocApproved
              ? 'Aprovado'
              : 'Pendente',
      weight: 8,
      action: OnboardingTargetAction.openDocRg,
    ),
    OnboardingStepItem(
      id: 'doc_cnh',
      pillar: OnboardingPillarId.documents,
      label:
          'CNH com EAR (${isMotoActive ? 'Cat. A/AB p/ Moto' : 'Cat. B+ p/ Carro'})',
      description: cnhStepOk
          ? 'CNH Cat. $effectiveCnhCat com EAR compatível com o veículo ativo.'
          : cnhDocApproved && !cnhCompatible
              ? 'CNH Cat. ${effectiveCnhCat.isEmpty ? '?' : effectiveCnhCat} incompatível com o veículo ativo (${isMotoActive ? 'Moto exige A/AB' : 'Carro exige B+'}).'
              : cnhDocApproved && !cnhEarActive
                  ? 'CNH sem observação EAR (Exerce Atividade Remunerada).'
                  : 'Envie sua CNH com observação EAR e categoria compatível com o veículo.',
      completed: cnhStepOk,
      hasError: cnhDoc?.status == 'REJECTED' ||
          (cnhDocApproved && (!cnhCompatible || !cnhEarActive)),
      statusLabel: cnhDoc?.status == 'REJECTED'
          ? 'Reprovada'
          : cnhStepOk
              ? 'Compatível & EAR'
              : cnhDocApproved
                  ? 'Incompatível'
                  : 'Pendente',
      weight: 8,
      action: (cnhDocApproved && !cnhCompatible)
          ? OnboardingTargetAction.openVehiclesForm
          : OnboardingTargetAction.openDocCnh,
    ),
    OnboardingStepItem(
      id: 'doc_crlv',
      pillar: OnboardingPillarId.documents,
      label: 'CRLV-e Digital (Licenciamento do Veículo)',
      description: crlvDocApproved
          ? 'CRLV-e digital autenticado e licenciamento em dia.'
          : 'Envie ou fotografe o CRLV-e digital vigente do veículo.',
      completed: crlvDocApproved,
      hasError: crlvDoc?.status == 'REJECTED',
      statusLabel: crlvDoc?.status == 'REJECTED'
          ? 'Reprovado'
          : crlvDocApproved
              ? 'Aprovado'
              : 'Pendente',
      weight: 5,
      action: OnboardingTargetAction.openDocCrlv,
    ),
    OnboardingStepItem(
      id: 'doc_residence',
      pillar: OnboardingPillarId.documents,
      label: 'Comprovante de Residência (< 90 dias)',
      description: residenceDocApproved
          ? 'Comprovante de residência recente validado por OCR.'
          : 'Envie conta de luz, água, gás ou internet em seu nome.',
      completed: residenceDocApproved,
      hasError: residenceDoc?.status == 'REJECTED',
      statusLabel: residenceDoc?.status == 'REJECTED'
          ? 'Reprovado'
          : residenceDocApproved
              ? 'Aprovado'
              : 'Pendente',
      weight: 4,
      action: OnboardingTargetAction.openDocResidence,
    ),
    OnboardingStepItem(
      id: 'bio_oval',
      pillar: OnboardingPillarId.biometrics,
      label: 'Selfie Biométrica no Elemento Oval',
      description: ovalStepOk
          ? 'Foto facial ao vivo capturada na moldura oval e autenticada.'
          : 'Ligue a câmera e capture seu rosto no elemento oval com detecção ao vivo.',
      completed: ovalStepOk,
      statusLabel: ovalStepOk ? 'Capturada' : 'Pendente',
      weight: 6,
      action: OnboardingTargetAction.openBioModal,
    ),
    OnboardingStepItem(
      id: 'bio_cross_match',
      pillar: OnboardingPillarId.biometrics,
      label: 'Match Facial Cruzado (Oval vs RG & CNH)',
      description: hasFaceMismatch
          ? 'Divergência facial detectada entre a selfie e o documento. Refaça a captura.'
          : crossMatchStepOk
              ? 'Rosto do oval compatível com RG e CNH sem divergências.'
              : 'Necessário confirmar match facial do rosto no oval tanto no RG quanto na CNH.',
      completed: crossMatchStepOk,
      hasError: hasFaceMismatch,
      statusLabel: hasFaceMismatch
          ? 'Divergência'
          : crossMatchStepOk
              ? 'Match RG + CNH'
              : (rgMatched || cnhMatched)
                  ? 'Parcial'
                  : 'Pendente',
      weight: 10,
      action: OnboardingTargetAction.openBioModal,
    ),
    OnboardingStepItem(
      id: 'bio_fingerprint',
      pillar: OnboardingPillarId.biometrics,
      label: 'Impressão Digital Nativa do Aparelho',
      description: fingerprintStepOk
          ? 'Impressão digital validada diretamente no sensor biométrico do aparelho.'
          : 'Acione o sensor biométrico nativo do celular na aba Perfil.',
      completed: fingerprintStepOk,
      statusLabel: fingerprintStepOk ? 'Validada' : 'Pendente',
      weight: 5,
      action: OnboardingTargetAction.openPersonalForm,
    ),
    OnboardingStepItem(
      id: 'bio_fingerprint_doc',
      pillar: OnboardingPillarId.biometrics,
      label: 'Cruzamento Digital Aparelho vs Polegar RG/CNH',
      description: fpDocCompareOk
          ? 'Papiloscopia e vínculo biométrico confirmados (${fpCmp?.score ?? 94}% via ${fpCmp?.docTypeUsed ?? 'RG'}).'
          : fpDocCompareMismatch
              ? (fpCmp?.rejectionReason ??
                  'Divergência ou baixa legibilidade ao cruzar digital com RG/CNH.')
              : 'Cruze a impressão digital do aparelho contra o polegar papiloscópico do RG ou CNH.',
      completed: fpDocCompareOk,
      hasError: fpDocCompareMismatch,
      statusLabel: fpDocCompareMismatch
          ? 'Divergência'
          : fpDocCompareOk
              ? 'Vinculada ✓'
              : 'Pendente',
      weight: 6,
      action: OnboardingTargetAction.openPersonalForm,
    ),
    OnboardingStepItem(
      id: 'form_personal',
      pillar: OnboardingPillarId.formsVehicle,
      label: 'Dados Pessoais & Registro da CNH/RG',
      description: personalStepOk
          ? 'Nome completo, idade (>= 21), RG, registro CNH e contato salvos.'
          : 'Faltando: ${personalMissing.join(', ')}.',
      completed: personalStepOk,
      statusLabel: personalStepOk ? 'Completo' : 'Incompleto',
      weight: 6,
      action: OnboardingTargetAction.openPersonalForm,
    ),
    OnboardingStepItem(
      id: 'form_address',
      pillar: OnboardingPillarId.formsVehicle,
      label: 'Endereço Residencial Completo',
      description: addressStepOk
          ? '${addr?.street ?? ''}, ${addr?.number ?? ''} — ${addr?.city ?? ''}/${addr?.state ?? ''}'
          : 'Preencha CEP, logradouro, número, bairro, cidade e UF.',
      completed: addressStepOk,
      statusLabel: addressStepOk ? 'Completo' : 'Incompleto',
      weight: 3,
      action: OnboardingTargetAction.openPersonalForm,
    ),
    OnboardingStepItem(
      id: 'form_payout_sos',
      pillar: OnboardingPillarId.formsVehicle,
      label: 'Conta PIX Bancária & Contato SOS',
      description: payoutSosStepOk
          ? 'Chave PIX (${payout?.pixKeyType ?? ''}) e contato SOS (${sos?.name ?? ''}) configurados.'
          : 'Informe chave PIX, dados bancários de repasse e contato de emergência SOS.',
      completed: payoutSosStepOk,
      statusLabel: payoutSosStepOk ? 'Configurado' : 'Pendente',
      weight: 4,
      action: OnboardingTargetAction.openPersonalForm,
    ),
    OnboardingStepItem(
      id: 'active_vehicle',
      pillar: OnboardingPillarId.formsVehicle,
      label: 'Veículo Ativo Regularizado',
      description: vehicleStepOk
          ? '${activeVehicle?.brand ?? ''} ${activeVehicle?.model ?? ''} (${activeVehicle?.plate ?? ''})'
          : 'Cadastre e selecione um veículo ativo (Carro ou Moto) com placa válida.',
      completed: vehicleStepOk,
      statusLabel: vehicleStepOk ? 'Ativo' : 'Pendente',
      weight: 5,
      action: OnboardingTargetAction.openVehiclesForm,
    ),
    OnboardingStepItem(
      id: 'vehicle_screening_docs',
      pillar: OnboardingPillarId.formsVehicle,
      label: 'Triagem Veicular: CRLV, Vínculo & 5 Fotos Nítidas',
      description: vehScreeningOk
          ? 'CRLV, vínculo (${activeVehicle?.ownershipType ?? 'PROPRIO'}) e 5/5 fotos conferidos na triagem inicial.'
          : (vehScreening?.summary ??
              'Envie o CRLV atualizado, informe vínculo/autorização do proprietário e anexe as 5 fotos nítidas.'),
      completed: vehScreeningOk,
      hasError: vehScreeningRejected,
      statusLabel: vehScreening != null
          ? BehavioralAntifraudEngine.statusLabel(vehScreening.status)
          : 'Pendente de envio',
      weight: 6,
      action: OnboardingTargetAction.openVehiclesForm,
    ),
    OnboardingStepItem(
      id: 'vehicle_insurance_inspection',
      pillar: OnboardingPillarId.formsVehicle,
      label: 'Seguro APP Passageiros & Vistoria Fotográfica',
      description: insuranceInspectionStepOk
          ? 'Apólice APP ${activeVehicle!.insurancePolicy} (${activeVehicle.insuranceCompany}) e 5 fotos nítidas confirmadas.'
          : !hasInsuranceData
              ? 'Informe a Seguradora e nº da Apólice APP Passageiros no veículo ativo.'
              : 'Envie as 5 fotos nítidas do veículo (ou confirme a vistoria) no formulário da frota.',
      completed: insuranceInspectionStepOk,
      statusLabel:
          insuranceInspectionStepOk ? 'Assegurado & Fotografado' : 'Pendente',
      weight: 5,
      action: OnboardingTargetAction.openVehiclesForm,
    ),
    OnboardingStepItem(
      id: 'screening_criminal_cert',
      pillar: OnboardingPillarId.compliance,
      label: 'Certidão de Antecedentes & Declaração',
      description: bgCheckOk
          ? 'Certidão (${driver.criminalCertificate?.issuingPortal ?? 'PF'}) e código ${driver.criminalCertificate?.validationCode ?? ''} conferidos na triagem.'
          : crimScreening.summary,
      completed: bgCheckOk,
      hasError: bgCheckRejected,
      statusLabel: BehavioralAntifraudEngine.statusLabel(crimScreening.status),
      weight: 6,
      action: OnboardingTargetAction.openPersonalForm,
    ),
    OnboardingStepItem(
      id: 'rite_terms',
      pillar: OnboardingPillarId.compliance,
      label: 'Aceite do Contrato de Parceria & LGPD',
      description: termsAccepted
          ? 'Contrato autônomo (Lei 13.640/2018) e política LGPD assinados digitalmente.'
          : 'Leia e confirme o aceite formal dos termos de parceria e privacidade LGPD.',
      completed: termsAccepted,
      statusLabel: termsAccepted ? 'Assinado' : 'Pendente',
      weight: 3,
      action: OnboardingTargetAction.openComplianceTerms,
    ),
    OnboardingStepItem(
      id: 'rite_safety',
      pillar: OnboardingPillarId.compliance,
      label: 'Rito de Segurança, Conduta & Operação OMNI',
      description: safetyBriefingCompleted
          ? 'Treinamento de conduta, protocolo OTP/PIN, entregas e botão SOS concluído.'
          : 'Conclua a leitura e confirmação do rito de segurança e padrões de atendimento.',
      completed: safetyBriefingCompleted,
      statusLabel: safetyBriefingCompleted ? 'Concluído' : 'Pendente',
      weight: 3,
      action: OnboardingTargetAction.openComplianceTerms,
    ),
  ];

  final rawWeight = steps.fold<int>(
    0,
    (acc, step) => acc + (step.completed ? step.weight : 0),
  );
  final pendingSteps = steps.where((s) => !s.completed).toList();
  final completedStepsCount = steps.length - pendingSteps.length;
  final onboardingScore = rawWeight.clamp(0, 100);

  final beh = driver.behavioralRisk;
  final behStatus = beh?.accountStatus;
  final behavioralBlocked = behStatus == 'REVALIDATION_PENDING' ||
      behStatus == 'SUSPENDED' ||
      behStatus == 'REJECTED' ||
      (beh?.revalidationRequired == true);

  final isDriverFullyApproved =
      onboardingScore == 100 && pendingSteps.isEmpty && !behavioralBlocked;

  OnboardingPillarSummary buildPillar(OnboardingPillarId id, String label) {
    final pSteps = steps.where((s) => s.pillar == id).toList();
    final done = pSteps.where((s) => s.completed).length;
    return OnboardingPillarSummary(
      id: id,
      label: label,
      completedCount: done,
      totalCount: pSteps.length,
      isComplete: done == pSteps.length,
    );
  }

  final pillars = [
    buildPillar(OnboardingPillarId.documents, 'Documentos & CNH'),
    buildPillar(OnboardingPillarId.biometrics, 'Biometria IA'),
    buildPillar(OnboardingPillarId.formsVehicle, 'Cadastro & Veículo'),
    buildPillar(OnboardingPillarId.compliance, 'Conformidade'),
  ];

  final headline = behavioralBlocked
      ? (behStatus == 'SUSPENDED' || behStatus == 'REJECTED'
          ? 'Conta Suspensa Preventivamente'
          : 'Revalidação Biométrica Obrigatória')
      : isDriverFullyApproved
          ? '100% Aprovado — Apto para Operar'
          : 'Onboarding Obrigatório em Andamento ($onboardingScore%)';

  final subtext = behavioralBlocked
      ? (behStatus == 'SUSPENDED' || behStatus == 'REJECTED'
          ? (beh?.preventiveBlockReason ??
              'Conta suspensa preventivamente pela gestão contínua de risco comportamental.')
          : (beh?.revalidationReason ??
              'Revalidação facial ao vivo pendente: capture uma nova selfie no molde oval para voltar a operar.'))
      : isDriverFullyApproved
          ? 'Todas as validações documentais, biométricas cruzadas (facial + digital), cadastrais, veiculares e de conformidade foram concluídas.'
          : 'Por segurança e conformidade OMNI, você só poderá ficar ONLINE, receber corridas ou enviar propostas após concluir todas as ${pendingSteps.length} etapa(s) pendente(s).';

  return DriverOnboardingStatus(
    onboardingScore: onboardingScore,
    isDriverFullyApproved: isDriverFullyApproved,
    completedStepsCount: completedStepsCount,
    totalStepsCount: steps.length,
    steps: steps,
    pendingSteps: pendingSteps,
    pillars: pillars,
    nextRecommendedStep: pendingSteps.isNotEmpty ? pendingSteps.first : null,
    gatekeeperHeadline: headline,
    gatekeeperSubtext: subtext,
  );
}
