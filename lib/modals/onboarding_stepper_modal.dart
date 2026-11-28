import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../config/omni_theme.dart';
import '../models/omni_models.dart';
import '../providers/omni_driver_provider.dart';
import '../screens/driver_forms.dart';
import '../services/behavioral_antifraud_engine.dart';
import '../services/sound_service.dart';
import '../widgets/owner_test_hired_driver_checkbox.dart';

class _StepperDef {
  final String id;
  final String shortLabel;
  final String title;
  final String subtitle;
  final bool completed;

  const _StepperDef({
    required this.id,
    required this.shortLabel,
    required this.title,
    required this.subtitle,
    required this.completed,
  });
}

/// Assistente Guiado de Contratação OMNI (12 Etapas Inteligentes)
/// 1:1 com src/components/OnboardingStepperModal.tsx
class OnboardingStepperModal extends StatefulWidget {
  const OnboardingStepperModal({super.key});

  @override
  State<OnboardingStepperModal> createState() => _OnboardingStepperModalState();
}

class _OnboardingStepperModalState extends State<OnboardingStepperModal> {
  final LocalAuthentication _localAuth = LocalAuthentication();

  int _currentStep = 0;
  bool _goingForward = true;
  bool _initialized = false;
  bool _prevStepCompleted = false;
  int _prevStepIndex = -1;
  String? _autoAdvanceBanner;
  Timer? _autoAdvanceTimer;

  bool _showVehicleEditor = false;
  bool _nativeFpBusy = false;
  String? _nativeFpMsg;
  double _touchProgress = 0.0;
  bool _isHoldingTouch = false;
  Timer? _touchTimer;

  bool _termsChecked = false;
  bool _safetyChecked = false;
  final TextEditingController _sigCtrl = TextEditingController();

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _touchTimer?.cancel();
    _sigCtrl.dispose();
    super.dispose();
  }

  List<_StepperDef> _buildSteps(OmniDriverProvider p) {
    final map = <String, bool>{};
    for (final s in p.onboardingStatus.steps) {
      map[s.id] = s.completed;
    }

    return [
      _StepperDef(
        id: 'CPF',
        shortLabel: 'CPF',
        title: 'Captura Automática do CPF (OCR)',
        subtitle:
            'Comece pelo CPF: o motor OCR lê e preenche automaticamente seu nome, CPF e data de nascimento no cadastro.',
        completed: map['doc_cpf'] ?? false,
      ),
      _StepperDef(
        id: 'RG',
        shortLabel: 'RG/CIN',
        title: 'RG / CIN — Face com Foto & Impressão Digital',
        subtitle:
            'Envie a face do documento que contém sua foto (para o reconhecimento facial) e a face com sua impressão digital e dados OCR.',
        completed: map['doc_rg'] ?? false,
      ),
      _StepperDef(
        id: 'CNH',
        shortLabel: 'CNH EAR',
        title: 'CNH com EAR — Foto & Categoria',
        subtitle:
            'Captura automática da face com foto e dos dados de registro, categoria compatível e observação EAR.',
        completed: map['doc_cnh'] ?? false,
      ),
      _StepperDef(
        id: 'FACIAL_OVAL',
        shortLabel: 'Facial',
        title: 'Reconhecimento Facial no Oval & Match RG/CNH',
        subtitle:
            'Ajuste seu rosto dentro da moldura oval para captura calibrada e validação cruzada automática contra RG e CNH.',
        completed:
            (map['bio_oval'] ?? false) && (map['bio_cross_match'] ?? false),
      ),
      _StepperDef(
        id: 'FINGERPRINT',
        shortLabel: 'Digital',
        title: 'Impressão Digital & Confronto Papiloscópico',
        subtitle:
            'Valide sua digital pelo leitor biométrico do aparelho (ou toque seguro OMNI) e cruze com a digital do RG/CNH.',
        completed: (map['bio_fingerprint'] ?? false) &&
            (map['bio_fingerprint_doc'] ?? false),
      ),
      _StepperDef(
        id: 'PERSONAL_DATA',
        shortLabel: 'Dados',
        title: 'Dados Pessoais & Habilitação (Pré-preenchidos via OCR)',
        subtitle:
            'Revise e confirme seus dados preenchidos automaticamente pelos documentos. Todos os campos permanecem editáveis.',
        completed: map['form_personal'] ?? false,
      ),
      _StepperDef(
        id: 'ADDRESS_RESIDENCE',
        shortLabel: 'Endereço',
        title: 'Endereço (GPS Automático) & Comprovante de Residência',
        subtitle:
            'Seu endereço é preenchido via localização GPS (editável). Envie também o comprovante de residência (< 90 dias) via OCR.',
        completed:
            (map['form_address'] ?? false) && (map['doc_residence'] ?? false),
      ),
      _StepperDef(
        id: 'FINANCE_SOS',
        shortLabel: 'PIX/SOS',
        title: 'Repasse PIX, Dados Bancários & Contato SOS',
        subtitle:
            'Configure sua chave PIX para recebimentos instantâneos e cadastre seu contato de emergência SOS.',
        completed: map['form_payout_sos'] ?? false,
      ),
      _StepperDef(
        id: 'VEHICLE_CRLV',
        shortLabel: 'Veículo',
        title: 'Veículo, Seguro APP, Vistoria 360° & CRLV-e',
        subtitle:
            'Regularize os dados do veículo ativo, seguro APP de passageiros, vistoria 360° e capture o CRLV-e via OCR automático.',
        completed: (map['active_vehicle'] ?? false) &&
            (map['vehicle_insurance_inspection'] ?? false) &&
            (map['doc_crlv'] ?? false),
      ),
      _StepperDef(
        id: 'SCREENING_DOCS',
        shortLabel: 'Triagem',
        title: 'Triagem Documental: Certidão & Veículo',
        subtitle:
            'Envie sua Certidão de Antecedentes Criminais e regularize CRLV, vínculo de posse e as 5 fotos nítidas do veículo para conferência inicial.',
        completed: (map['screening_criminal_cert'] ?? false) &&
            (map['vehicle_screening_docs'] ?? false),
      ),
      _StepperDef(
        id: 'TERMS_COMPLIANCE',
        shortLabel: 'Termos',
        title: 'Termos de Parceria, LGPD & Rito de Segurança',
        subtitle:
            'Penúltima etapa: confirme os termos contratuais (Lei 13.640/2018), privacidade LGPD e protocolo de segurança OMNI.',
        completed:
            (map['rite_terms'] ?? false) && (map['rite_safety'] ?? false),
      ),
      _StepperDef(
        id: 'APPROVED_100',
        shortLabel: '100% ✓',
        title: 'Aprovação 100% Concluída!',
        subtitle:
            'Parabéns por atingir 100% da aprovação! Seus dados serão analisados e sua conta será liberada para operar.',
        completed: p.isDriverFullyApproved,
      ),
    ];
  }

  void _goToStep(int targetIdx, int totalSteps) {
    final clamped = targetIdx.clamp(0, totalSteps - 1);
    if (clamped == _currentStep) return;
    _autoAdvanceTimer?.cancel();
    setState(() {
      _autoAdvanceBanner = null;
      _goingForward = clamped > _currentStep;
      _currentStep = clamped;
    });
  }

  void _openDocCaptureByType(OmniDriverProvider p, String docType) {
    final doc = p.documents.cast<DriverDocument?>().firstWhere(
          (d) => d != null && d.type == docType,
          orElse: () => null,
        );
    if (doc != null) {
      p.openDocumentCapture(doc.id, autoOpenCamera: true);
    }
  }

  Future<void> _runNativeDeviceFingerprint(OmniDriverProvider p) async {
    setState(() {
      _nativeFpBusy = true;
      _nativeFpMsg = 'Acionando leitor biométrico do aparelho...';
    });
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      bool authenticated = false;
      if (supported || canCheck) {
        try {
          authenticated = await _localAuth.authenticate(
            localizedReason:
                'Confirme sua impressão digital para validar sua conta OMNI Motorista',
            options: const AuthenticationOptions(
              stickyAuth: true,
              biometricOnly: true,
            ),
          );
        } on PlatformException {
          authenticated = await _localAuth.authenticate(
            localizedReason:
                'Confirme sua biometria ou credencial do aparelho OMNI',
            options: const AuthenticationOptions(
              stickyAuth: true,
              biometricOnly: false,
            ),
          );
        }
      }
      if (!mounted) return;
      if (authenticated) {
        HapticFeedback.heavyImpact();
        await p.verifyFingerprintBiometrics(method: 'DEVICE_BIOMETRIC_NATIVE');
        setState(() {
          _nativeFpBusy = false;
          _nativeFpMsg =
              'Impressão digital coletada pelo sensor físico do celular! Cruzando com RG/CNH...';
        });
        await p.runFingerprintDocComparison();
        return;
      }
      setState(() {
        _nativeFpBusy = false;
        _nativeFpMsg =
            'Autenticação biométrica cancelada ou indisponível no aparelho. Tente novamente ou mantenha pressionado o sensor abaixo por 1,2s.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _nativeFpBusy = false;
        _nativeFpMsg =
            'Não foi possível acessar o leitor biométrico nativo. Use o sensor abaixo mantendo pressionado por 1,2s.';
      });
    }
  }

  void _startTouchSensor(OmniDriverProvider p) {
    if (p.driver.isFingerprintVerified) return;
    _touchTimer?.cancel();
    setState(() {
      _isHoldingTouch = true;
      _touchProgress = 0.08;
    });
    final start = DateTime.now();
    _touchTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      final pct =
          (DateTime.now().difference(start).inMilliseconds / 1200.0).clamp(0.0, 1.0);
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _touchProgress = pct);
      if (pct >= 1.0) {
        t.cancel();
        HapticFeedback.heavyImpact();
        setState(() => _isHoldingTouch = false);
        p.verifyFingerprintBiometrics(method: 'OMNI_DIGITAL_SENSOR');
      }
    });
  }

  void _stopTouchSensor() {
    _touchTimer?.cancel();
    if (_touchProgress < 1.0) {
      setState(() {
        _isHoldingTouch = false;
        _touchProgress = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();
    final steps = _buildSteps(p);

    if (!_initialized) {
      _initialized = true;
      _termsChecked = p.driver.complianceRites?.acceptedTerms ?? false;
      _safetyChecked =
          p.driver.complianceRites?.completedSafetyBriefing ?? false;
      _sigCtrl.text = p.driver.name;
      if (p.stepperInitialStep != null &&
          p.stepperInitialStep! >= 0 &&
          p.stepperInitialStep! < steps.length) {
        _currentStep = p.stepperInitialStep!;
      } else if (p.isDriverFullyApproved) {
        _currentStep = steps.length - 1;
      } else {
        final firstPending = steps.indexWhere((s) => !s.completed);
        _currentStep = firstPending >= 0 ? firstPending : 0;
      }
      _prevStepIndex = _currentStep;
      _prevStepCompleted = steps[_currentStep].completed;
    }

    // Detecta conclusão da etapa atual para avanço automático
    final activeStep = steps[_currentStep];
    if (_prevStepIndex != _currentStep) {
      _prevStepIndex = _currentStep;
      _prevStepCompleted = activeStep.completed;
    } else if (!_prevStepCompleted &&
        activeStep.completed &&
        _currentStep < steps.length - 1) {
      _prevStepCompleted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        OmniSoundService.playSuccess();
        setState(() {
          _autoAdvanceBanner =
              'Etapa "${activeStep.shortLabel}" validada ✓ Avançando...';
        });
        _autoAdvanceTimer?.cancel();
        _autoAdvanceTimer = Timer(const Duration(milliseconds: 950), () {
          if (!mounted) return;
          setState(() {
            _autoAdvanceBanner = null;
            _goingForward = true;
            _currentStep = p.isDriverFullyApproved
                ? steps.length - 1
                : (_currentStep + 1).clamp(0, steps.length - 1);
          });
        });
      });
    }

    return Positioned.fill(
      child: Material(
        color: OmniTheme.alpha(OmniTheme.slate950, 0.92),
        child: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(10),
              constraints: const BoxConstraints(maxWidth: 680),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0F17),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: OmniTheme.alpha(OmniTheme.neonCyan, 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: OmniTheme.alpha(Colors.black, 0.85),
                    blurRadius: 48,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  children: [
                    // Header Fixo
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: const BoxDecoration(
                        color: OmniTheme.slate950,
                        border: Border(
                          bottom: BorderSide(color: OmniTheme.slate800),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: OmniTheme.alpha(OmniTheme.neonCyan, 0.14),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    OmniTheme.alpha(OmniTheme.neonCyan, 0.4),
                              ),
                            ),
                            child: const Icon(
                              Icons.verified_user_rounded,
                              color: OmniTheme.neonCyan,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'ETAPA ${_currentStep + 1} DE ${steps.length}',
                                      style: OmniTheme.monoStyle(
                                        fontSize: 10,
                                        color: OmniTheme.neonCyan,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: OmniTheme.slate900,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: OmniTheme.slate700),
                                      ),
                                      child: Text(
                                        '${p.onboardingScore}% Aprovado',
                                        style: OmniTheme.monoStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  activeStep.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => p.closeStepperModal(),
                            icon: const Icon(Icons.close_rounded,
                                color: OmniTheme.slate300),
                          ),
                        ],
                      ),
                    ),

                    // Trilho Horizontal de 12 Etapas
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: OmniTheme.alpha(OmniTheme.slate950, 0.7),
                        border: const Border(
                          bottom: BorderSide(color: OmniTheme.slate800),
                        ),
                      ),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: steps.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (_, idx) {
                          final st = steps[idx];
                          final isActive = idx == _currentStep;
                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _goToStep(idx, steps.length),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? OmniTheme.alpha(OmniTheme.neonCyan, 0.2)
                                    : st.completed
                                        ? OmniTheme.alpha(
                                            OmniTheme.neonEmerald, 0.14)
                                        : OmniTheme.slate900,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isActive
                                      ? OmniTheme.neonCyan
                                      : st.completed
                                          ? OmniTheme.alpha(
                                              OmniTheme.neonEmerald, 0.45)
                                          : OmniTheme.slate800,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (st.completed)
                                    const Icon(Icons.check_circle_rounded,
                                        size: 14, color: OmniTheme.neonEmerald)
                                  else
                                    Text(
                                      '${idx + 1}.',
                                      style: OmniTheme.monoStyle(
                                        fontSize: 10,
                                        color: isActive
                                            ? OmniTheme.neonCyan
                                            : OmniTheme.slate400,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  const SizedBox(width: 5),
                                  Text(
                                    st.shortLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isActive
                                          ? OmniTheme.neonCyan
                                          : st.completed
                                              ? OmniTheme.neonEmerald
                                              : OmniTheme.slate300,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    if (_autoAdvanceBanner != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        color: OmniTheme.alpha(OmniTheme.neonEmerald, 0.2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                size: 15, color: OmniTheme.neonEmerald),
                            const SizedBox(width: 6),
                            Text(
                              _autoAdvanceBanner!,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: OmniTheme.neonEmerald,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: OwnerTestHiredDriverCheckbox(compact: true),
                    ),

                    // Corpo com Transição Estilo PowerPoint
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 340),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final beginOffset = _goingForward
                              ? const Offset(0.14, 0)
                              : const Offset(-0.14, 0);
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: beginOffset,
                              end: Offset.zero,
                            ).animate(animation),
                            child: FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: Tween<double>(begin: 0.975, end: 1.0)
                                    .animate(animation),
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: SingleChildScrollView(
                          key: ValueKey<String>(
                              '${activeStep.id}_$_currentStep'),
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeStep.subtitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: OmniTheme.slate400,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _buildStepBody(p, activeStep, steps),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Rodapé Fixo de Navegação
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: const BoxDecoration(
                        color: OmniTheme.slate950,
                        border: Border(
                          top: BorderSide(color: OmniTheme.slate800),
                        ),
                      ),
                      child: Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _currentStep == 0
                                ? null
                                : () =>
                                    _goToStep(_currentStep - 1, steps.length),
                            icon:
                                const Icon(Icons.arrow_back_rounded, size: 16),
                            label: const Text('Voltar'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side:
                                  const BorderSide(color: OmniTheme.slate700),
                              minimumSize: const Size(0, 44),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(99),
                                  child: LinearProgressIndicator(
                                    value: p.onboardingScore / 100.0,
                                    minHeight: 6,
                                    backgroundColor: OmniTheme.slate800,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            OmniTheme.neonCyan),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${p.onboardingStatus.completedStepsCount}/${p.onboardingStatus.totalStepsCount} itens',
                                  style: OmniTheme.monoStyle(
                                    fontSize: 10,
                                    color: OmniTheme.slate400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (_currentStep < steps.length - 1)
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _goToStep(_currentStep + 1, steps.length),
                              icon: const Icon(Icons.arrow_forward_rounded,
                                  size: 16),
                              label: const Text('Avançar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: OmniTheme.neonCyan,
                                foregroundColor: const Color(0xFF05080F),
                                minimumSize: const Size(0, 44),
                              ),
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: () => p.closeStepperModal(),
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: const Text('Concluir'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: OmniTheme.neonEmerald,
                                foregroundColor: const Color(0xFF05080F),
                                minimumSize: const Size(0, 44),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocStepCard({
    required OmniDriverProvider p,
    required String docType,
    required String title,
    required List<String> bullets,
    required String ctaLabel,
  }) {
    final doc = p.documents.cast<DriverDocument?>().firstWhere(
          (d) => d != null && d.type == docType,
          orElse: () => null,
        );
    final approved = doc?.status == 'APPROVED';
    final rejected = doc?.status == 'REJECTED';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: approved
            ? OmniTheme.alpha(OmniTheme.neonEmerald, 0.1)
            : OmniTheme.slate900,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: approved
              ? OmniTheme.alpha(OmniTheme.neonEmerald, 0.45)
              : rejected
                  ? OmniTheme.alpha(OmniTheme.neonRose, 0.45)
                  : OmniTheme.slate800,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                approved ? Icons.check_circle_rounded : Icons.badge_rounded,
                color: approved ? OmniTheme.neonEmerald : OmniTheme.neonCyan,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: approved
                      ? OmniTheme.alpha(OmniTheme.neonEmerald, 0.18)
                      : OmniTheme.alpha(OmniTheme.amber400, 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  approved ? 'Aprovado ✓' : 'Pendente',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color:
                        approved ? OmniTheme.neonEmerald : OmniTheme.amber400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      size: 13, color: OmniTheme.neonCyan),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: OmniTheme.slate300,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openDocCaptureByType(p, docType),
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: Text(approved ? 'Recapturar Documento' : ctaLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: OmniTheme.neonCyan,
                foregroundColor: const Color(0xFF05080F),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBody(
    OmniDriverProvider p,
    _StepperDef step,
    List<_StepperDef> allSteps,
  ) {
    switch (step.id) {
      case 'CPF':
        return _buildDocStepCard(
          p: p,
          docType: 'CPF',
          title: 'CPF — Cadastro de Pessoa Física',
          bullets: const [
            'Posicione o CPF na área iluminada — a câmera dispara e lê os dados OCR automaticamente.',
            'Validação oficial Módulo 11 dos dígitos verificadores.',
            'Nome completo, CPF e nascimento preenchem seu cadastro automaticamente.',
          ],
          ctaLabel: 'Abrir Câmera Automática do CPF',
        );

      case 'RG':
        return _buildDocStepCard(
          p: p,
          docType: 'RG',
          title: 'RG / CIN (Face com Foto + Face com Impressão Digital)',
          bullets: const [
            'Parte A (Face com Foto): Envie a foto da face do documento que contenha sua foto para validar com o reconhecimento facial.',
            'Parte B (Face com Impressão Digital): A câmera avança automaticamente para a face com sua impressão digital e dados OCR.',
            'Todos os dados extraídos preenchem o formulário automaticamente.',
          ],
          ctaLabel: 'Iniciar Captura Automática do RG / CIN',
        );

      case 'CNH':
        return _buildDocStepCard(
          p: p,
          docType: 'CNH_EAR',
          title: 'CNH com EAR (Face com Foto + Dados OCR)',
          bullets: const [
            'Parte A (Face com Foto): Envie a foto da face da CNH que contenha sua foto para validação facial cruzada.',
            'Parte B (Verso / Dados): Leitura OCR automática de categoria, registro, validade e observação EAR.',
            'Verifica automaticamente compatibilidade entre sua CNH e o veículo ativo.',
          ],
          ctaLabel: 'Iniciar Captura Automática da CNH',
        );

      case 'FACIAL_OVAL':
        final rgMatched = p.driver.faceMatchRg?.status == 'MATCHED';
        final cnhMatched = p.driver.faceMatchCnh?.status == 'MATCHED';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: OmniTheme.slate900,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: OmniTheme.slate800),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _statusChip('Oval', p.driver.isBiometricVerified),
                  const SizedBox(width: 6),
                  _statusChip('Match RG', rgMatched),
                  const SizedBox(width: 6),
                  _statusChip('Match CNH', cnhMatched),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => p.setBiometricModalOpen(true),
                  icon: const Icon(Icons.face_retouching_natural_rounded,
                      size: 18),
                  label: const Text('Abrir Câmera Oval e Validar Rosto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OmniTheme.neonCyan,
                    foregroundColor: const Color(0xFF05080F),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
            ],
          ),
        );

      case 'FINGERPRINT':
        final fpOk = p.driver.isFingerprintVerified;
        final fpDocOk =
            p.driver.fingerprintDocComparison?.status == 'MATCHED';
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: OmniTheme.slate900,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: OmniTheme.slate800),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '1. Impressão Digital do Aparelho',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      _statusChip(fpOk ? 'Coletada ✓' : 'Pendente', fpOk),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _nativeFpBusy
                          ? null
                          : () => _runNativeDeviceFingerprint(p),
                      icon: const Icon(Icons.fingerprint_rounded, size: 20),
                      label: Text(_nativeFpBusy
                          ? 'Validando...'
                          : 'Usar Impressão Digital do Dispositivo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: OmniTheme.neonCyan,
                        foregroundColor: const Color(0xFF05080F),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTapDown: (_) => _startTouchSensor(p),
                    onTapUp: (_) => _stopTouchSensor(),
                    onTapCancel: _stopTouchSensor,
                    child: Container(
                      width: double.infinity,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _isHoldingTouch
                            ? OmniTheme.alpha(OmniTheme.neonCyan, 0.2)
                            : OmniTheme.slate950,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isHoldingTouch
                              ? OmniTheme.neonCyan
                              : OmniTheme.slate700,
                        ),
                      ),
                      child: Text(
                        _isHoldingTouch
                            ? 'Segure no Sensor... ${(_touchProgress * 100).round()}%'
                            : 'Opcional: Toque e Segure por 1,2s (Sensor OMNI)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (_nativeFpMsg != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _nativeFpMsg!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: OmniTheme.neonEmerald,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: OmniTheme.slate900,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: OmniTheme.slate800),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          '2. Confronto Papiloscópico vs RG/CNH',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      _statusChip(fpDocOk ? 'Vinculada ✓' : 'Pendente', fpDocOk),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (!fpOk || p.isRunningFingerprintDocCheck)
                          ? null
                          : () => p.runFingerprintDocComparison(),
                      icon: const Icon(Icons.verified_rounded, size: 18),
                      label: Text(p.isRunningFingerprintDocCheck
                          ? 'Executando confronto...'
                          : 'Cruzar Digital com Impressão do RG/CNH'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: OmniTheme.sky400,
                        foregroundColor: const Color(0xFF05080F),
                        minimumSize: const Size(double.infinity, 46),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case 'PERSONAL_DATA':
        return const DriverProfileFormCard();

      case 'ADDRESS_RESIDENCE':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDocStepCard(
              p: p,
              docType: 'RESIDENCE_PROOF',
              title: 'Comprovante de Residência (< 90 dias)',
              bullets: const [
                'Conta de luz, água, gás ou internet com menos de 90 dias.',
                'Seu endereço residencial abaixo já é pré-preenchido via GPS (editável).',
              ],
              ctaLabel: 'Capturar Comprovante de Residência (Auto-OCR)',
            ),
            const SizedBox(height: 12),
            const DriverProfileFormCard(),
          ],
        );

      case 'FINANCE_SOS':
        return const DriverFinanceAndSafetyFormCard();

      case 'VEHICLE_CRLV':
        final activeVeh = p.vehicles.cast<OmniVehicle?>().firstWhere(
              (v) => v != null && v.isActive,
              orElse: () => p.vehicles.isNotEmpty ? p.vehicles.first : null,
            );
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: OmniTheme.slate900,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: OmniTheme.slate800),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          activeVeh != null
                              ? '${activeVeh.brand} ${activeVeh.model} (${activeVeh.plate})'
                              : 'Cadastre seu Veículo Ativo',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(
                            () => _showVehicleEditor = !_showVehicleEditor),
                        child: Text(
                          _showVehicleEditor ? 'Fechar' : 'Editar',
                          style: const TextStyle(
                            color: OmniTheme.neonCyan,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_showVehicleEditor || activeVeh == null)
                    VehicleRegistrationForm(
                      initialVehicle: activeVeh,
                      onDone: () => setState(() => _showVehicleEditor = false),
                      onCancel: () =>
                          setState(() => _showVehicleEditor = false),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _buildDocStepCard(
              p: p,
              docType: 'CRLV',
              title: 'CRLV-e Digital (Licenciamento)',
              bullets: const [
                'Fotografe ou envie o CRLV-e digital vigente do veículo.',
                'Leitura automática OCR de placa, RENAVAM e licenciamento.',
              ],
              ctaLabel: 'Capturar CRLV-e Digital (Auto-OCR)',
            ),
          ],
        );

      case 'SCREENING_DOCS':
        final activeVeh = p.vehicles.cast<OmniVehicle?>().firstWhere(
              (v) => v != null && v.isActive,
              orElse: () => p.vehicles.isNotEmpty ? p.vehicles.first : null,
            );
        final vehPkgOk = p.onboardingStatus.steps.any(
            (s) => s.id == 'vehicle_screening_docs' && s.completed);
        final crlvOk = p.onboardingStatus.steps.any(
            (s) => s.id == 'doc_crlv' && s.completed);
        final vehScreening = activeVeh?.vehicleScreening;
        final photosCount = BehavioralAntifraudEngine.countVehiclePhotos(
            activeVeh?.visualPhotos);
        return Column(
          children: [
            const CriminalCertificateFormCard(),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: OmniTheme.slate900,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: OmniTheme.slate800),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          '2. Pacote Documental do Veículo (CRLV, Vínculo & 5 Fotos)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      _statusChip(
                        vehPkgOk
                            ? 'Aprovado ✓'
                            : BehavioralAntifraudEngine.statusLabel(
                                vehScreening?.status ?? 'PENDING_SUBMISSION'),
                        vehPkgOk,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    activeVeh != null
                        ? '${activeVeh.brand} ${activeVeh.model} (${activeVeh.plate}) • CRLV ${crlvOk ? "✓" : "pendente"} • Vínculo ${vehScreening?.ownershipVerified == true ? "✓" : "pendente"} • $photosCount/5 fotos'
                        : 'Cadastre ou selecione seu veículo ativo para concluir esta etapa.',
                    style: const TextStyle(
                        fontSize: 11, color: OmniTheme.slate400),
                  ),
                  if (vehScreening != null && vehScreening.findings.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: OmniTheme.slate950,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: OmniTheme.slate800),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: vehScreening.findings
                            .take(3)
                            .map((f) => Text(
                                  '• $f',
                                  style: const TextStyle(
                                      fontSize: 10.5,
                                      color: OmniTheme.slate300),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openDocCaptureByType(p, 'CRLV'),
                          icon: const Icon(Icons.document_scanner_rounded,
                              size: 16),
                          label:
                              Text(crlvOk ? 'CRLV OK ✓' : 'Anexar CRLV'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: OmniTheme.neonCyan,
                            side: BorderSide(
                                color: OmniTheme.alpha(
                                    OmniTheme.neonCyan, 0.45)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => setState(
                              () => _showVehicleEditor = !_showVehicleEditor),
                          icon: const Icon(Icons.directions_car_rounded,
                              size: 16),
                          label: Text(_showVehicleEditor
                              ? 'Ocultar Form'
                              : 'Vínculo & 5 Fotos'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: OmniTheme.sky400,
                            foregroundColor: const Color(0xFF05080F),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_showVehicleEditor || !vehPkgOk) ...[
                    const SizedBox(height: 12),
                    VehicleRegistrationForm(
                      initialVehicle: activeVeh,
                      onDone: () => setState(() => _showVehicleEditor = false),
                      onCancel: () =>
                          setState(() => _showVehicleEditor = false),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: OmniTheme.alpha(OmniTheme.amber400, 0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: OmniTheme.alpha(OmniTheme.amber400, 0.3)),
              ),
              child: Text(
                BehavioralAntifraudEngine.legalDisclaimer,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: OmniTheme.slate300,
                  height: 1.35,
                ),
              ),
            ),
          ],
        );

      case 'TERMS_COMPLIANCE':
        final canSign =
            _termsChecked && _safetyChecked && _sigCtrl.text.trim().length >= 4;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: OmniTheme.slate900,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: OmniTheme.slate800),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: OmniTheme.slate950,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: OmniTheme.alpha(OmniTheme.amber400, 0.35)),
                ),
                child: Text(
                  BehavioralAntifraudEngine.legalDisclaimer,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: OmniTheme.slate300,
                    height: 1.35,
                  ),
                ),
              ),
              CheckboxListTile(
                value: _termsChecked,
                activeColor: OmniTheme.neonCyan,
                checkColor: const Color(0xFF05080F),
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _termsChecked = v ?? false),
                title: const Text(
                  'Aceito o Contrato de Parceria (Lei 13.640/2018) e a Política de Privacidade LGPD da OMNI.',
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
              CheckboxListTile(
                value: _safetyChecked,
                activeColor: OmniTheme.neonCyan,
                checkColor: const Color(0xFF05080F),
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _safetyChecked = v ?? false),
                title: const Text(
                  'Confirmo a conclusão do Rito de Segurança OMNI (PIN/OTP, veracidade documental, conduta e revalidação comportamental).',
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _sigCtrl,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Assinatura Digital (Nome Completo)',
                  labelStyle: const TextStyle(color: OmniTheme.slate400),
                  filled: true,
                  fillColor: OmniTheme.slate950,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canSign
                      ? () => p.updateComplianceRites(
                            const ComplianceRites(
                              acceptedTerms: true,
                              acceptedPrivacyLgpd: true,
                              acceptedZeroTolerance: true,
                              completedSafetyBriefing: true,
                            ),
                          )
                      : null,
                  icon: const Icon(Icons.draw_rounded, size: 18),
                  label:
                      const Text('Assinar Digitalmente e Finalizar Contratação'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OmniTheme.neonCyan,
                    foregroundColor: const Color(0xFF05080F),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
            ],
          ),
        );

      case 'APPROVED_100':
      default:
        final approved = p.isDriverFullyApproved;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: approved
                ? OmniTheme.alpha(OmniTheme.neonEmerald, 0.12)
                : OmniTheme.slate900,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: approved
                  ? OmniTheme.alpha(OmniTheme.neonEmerald, 0.5)
                  : OmniTheme.alpha(OmniTheme.amber400, 0.45),
            ),
          ),
          child: Column(
            children: [
              Icon(
                approved ? Icons.workspace_premium_rounded : Icons.verified_user,
                size: 52,
                color: approved ? OmniTheme.neonEmerald : OmniTheme.amber400,
              ),
              const SizedBox(height: 10),
              Text(
                '${p.onboardingScore}% APROVADO',
                style: OmniTheme.monoStyle(
                  fontSize: 13,
                  color: approved ? OmniTheme.neonEmerald : OmniTheme.amber400,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                approved
                    ? 'Parabéns por atingir 100% da aprovação!'
                    : 'Faltam ${p.onboardingStatus.pendingSteps.length} etapa(s) para 100%',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                approved
                    ? 'Seus dados serão analisados e sua conta será liberada para operar corridas e entregas na plataforma OMNI.'
                    : 'Volte rapidamente às etapas pendentes na barra superior para completar 100% da aprovação.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: OmniTheme.slate300,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              if (approved)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (!p.driver.isOnline) p.toggleOnlineStatus();
                      p.closeStepperModal();
                    },
                    icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                    label: const Text('Ativar Modo ONLINE Agora'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OmniTheme.neonCyan,
                      foregroundColor: const Color(0xFF05080F),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () {
                    final idx = allSteps.indexWhere((s) => !s.completed);
                    if (idx >= 0) _goToStep(idx, allSteps.length);
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Ir para Próxima Etapa Pendente'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OmniTheme.neonCyan,
                    foregroundColor: const Color(0xFF05080F),
                  ),
                ),
            ],
          ),
        );
    }
  }

  Widget _statusChip(String label, bool ok) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ok
            ? OmniTheme.alpha(OmniTheme.neonEmerald, 0.16)
            : OmniTheme.alpha(OmniTheme.amber400, 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ok
              ? OmniTheme.alpha(OmniTheme.neonEmerald, 0.45)
              : OmniTheme.alpha(OmniTheme.amber400, 0.4),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: ok ? OmniTheme.neonEmerald : OmniTheme.amber400,
        ),
      ),
    );
  }
}
