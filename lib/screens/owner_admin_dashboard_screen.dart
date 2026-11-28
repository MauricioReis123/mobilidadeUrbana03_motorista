import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/omni_integration_contracts.dart';
import '../config/omni_theme.dart';
import '../models/omni_models.dart';
import '../providers/omni_driver_provider.dart';
import '../services/sound_service.dart';
import '../widgets/backend_domain_config_card.dart';
import '../widgets/owner_test_hired_driver_checkbox.dart';
import 'admin_campanhas_motorista_screen.dart';

/// Painel Administrativo Exclusivo do Dono do Aplicativo (`yahnzinho1@gmail.com`)
/// Centraliza:
/// 1) Programador de Notificações Heads-Up (no topo do celular Android/iOS) com
///    ícones/desenhos promocionais e repetição de tempo em tempo;
/// 2) Campanhas FCM HTTP v1 / Cron PHP / RTDB;
/// 3) Gestão Administrativa da Frota, Clube, Bônus na Carteira e Auditoria;
/// 4) Configuração de Domínio / IP / Cache e Teste de Conexão do Servidor.
class OwnerAdminDashboardScreen extends StatefulWidget {
  final int initialTabIndex;

  const OwnerAdminDashboardScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<OwnerAdminDashboardScreen> createState() =>
      _OwnerAdminDashboardScreenState();
}

class _OwnerAdminDashboardScreenState extends State<OwnerAdminDashboardScreen> {
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _bonusCtrl = TextEditingController(text: '+R\$ 25,00');
  final _cityCtrl = TextEditingController(text: 'TODAS');
  final _customIntervalMinCtrl = TextEditingController(text: '10');

  final _opCityCtrl = TextEditingController();
  final _walletBonusAmountCtrl = TextEditingController(text: '25.00');
  final _walletBonusDescCtrl =
      TextEditingController(text: 'Bônus Promocional OMNI (Dono)');

  String _selectedPromoStyle = 'bonus_corridas';
  int _selectedIntervalSeconds = 300; // 5 min padrão
  bool _useCustomMinutes = false;
  bool _busy = false;
  String? _feedback;
  bool _feedbackIsError = false;
  Timer? _countdownTicker;

  static const List<({String id, String emoji, String label, Color color})>
      _promoStyles = [
    (
      id: 'bonus_corridas',
      emoji: '🎁',
      label: 'Bônus Corridas',
      color: OmniTheme.neonEmerald,
    ),
    (
      id: 'alta_demanda',
      emoji: '🔥',
      label: 'Alta Demanda',
      color: OmniTheme.amber400,
    ),
    (
      id: 'meta_relampago',
      emoji: '⚡',
      label: 'Meta Relâmpago',
      color: OmniTheme.neonCyan,
    ),
    (
      id: 'clube_vip',
      emoji: '👑',
      label: 'Clube VIP',
      color: Color(0xFFA855F7),
    ),
    (
      id: 'combustivel',
      emoji: '⛽',
      label: 'Combustível',
      color: Color(0xFF38BDF8),
    ),
    (
      id: 'aviso_frota',
      emoji: '📢',
      label: 'Aviso Frota',
      color: OmniTheme.rose500,
    ),
  ];

  static const List<({int seconds, String label})> _intervalPresets = [
    (seconds: 15, label: '15s (Teste)'),
    (seconds: 60, label: '1 min'),
    (seconds: 120, label: '2 min'),
    (seconds: 300, label: '5 min'),
    (seconds: 900, label: '15 min'),
    (seconds: 1800, label: '30 min'),
    (seconds: 3600, label: '1 hora'),
    (seconds: 10800, label: '3 horas'),
    (seconds: 21600, label: '6 horas'),
    (seconds: 43200, label: '12 horas'),
    (seconds: 86400, label: '24 horas'),
  ];

  static const List<
      ({
        String style,
        String title,
        String message,
        String bonus,
        int intervalSeconds,
      })> _quickTemplates = [
    (
      style: 'alta_demanda',
      title: 'Pico de Chamadas na Sua Região!',
      message:
          'Demanda 1.8x ativa agora no centro e bairros próximos. Fique ONLINE e aproveite tarifas turbinadas.',
      bonus: '1.8x Dinâmica',
      intervalSeconds: 900,
    ),
    (
      style: 'bonus_corridas',
      title: 'Meta 5 Corridas Liberada',
      message:
          'Complete 5 corridas seguidas nas próximas 3 horas e receba bônus garantido direto na sua carteira OMNI.',
      bonus: '+R\$ 25,00',
      intervalSeconds: 1800,
    ),
    (
      style: 'meta_relampago',
      title: 'Taxa Zero Relâmpago OMNI',
      message:
          'Durante as próximas 2 horas você fica com 100% do valor das corridas aceitas na plataforma.',
      bonus: 'Taxa 0%',
      intervalSeconds: 3600,
    ),
    (
      style: 'combustivel',
      title: 'Cupom Parceiro Combustível',
      message:
          'Abasteça hoje nos postos credenciados Shell Box Pro com desconto exclusivo para motoristas ativos.',
      bonus: '-R\$ 0,35/L',
      intervalSeconds: 21600,
    ),
  ];

  @override
  void initState() {
    super.initState();
    final p = context.read<OmniDriverProvider>();
    _opCityCtrl.text = p.resolvedDriverCity;
    if (p.resolvedDriverCity.isNotEmpty) {
      _cityCtrl.text = p.resolvedDriverCity;
    }
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    _bonusCtrl.dispose();
    _cityCtrl.dispose();
    _customIntervalMinCtrl.dispose();
    _opCityCtrl.dispose();
    _walletBonusAmountCtrl.dispose();
    _walletBonusDescCtrl.dispose();
    super.dispose();
  }

  void _setFeedback(String msg, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _feedback = msg;
      _feedbackIsError = isError;
    });
  }

  ({String id, String emoji, String label, Color color}) get _currentStyleMeta =>
      _promoStyles.firstWhere(
        (s) => s.id == _selectedPromoStyle,
        orElse: () => _promoStyles.first,
      );

  int _resolvedIntervalSeconds() {
    if (_useCustomMinutes) {
      final mins = int.tryParse(_customIntervalMinCtrl.text.trim()) ?? 5;
      return (mins.clamp(1, 1440)) * 60;
    }
    return _selectedIntervalSeconds;
  }

  Future<void> _fireTestHeadsUpNow(OmniDriverProvider p) async {
    final title = _titleCtrl.text.trim().isNotEmpty
        ? _titleCtrl.text.trim()
        : 'Bônus Especial para Motoristas OMNI';
    final body = _messageCtrl.text.trim().isNotEmpty
        ? _messageCtrl.text.trim()
        : 'Fique ONLINE agora e ganhe bônus extra por corrida concluída!';
    final bonus = _bonusCtrl.text.trim();
    final notifSvc = p.notificationService;
    if (notifSvc == null) {
      _setFeedback('Serviço de notificações não inicializado.', isError: true);
      return;
    }

    await notifSvc.requestNotificationsPermissionExplicit();
    final fullTitle = bonus.isNotEmpty ? '$title • $bonus' : title;
    await notifSvc.showHeadsUpLocalNotification(
      title: fullTitle,
      body: body,
      promoStyle: _selectedPromoStyle,
      bonusHighlight: bonus,
      data: {
        'action': 'open_promotions',
        'promo_style': _selectedPromoStyle,
        'target_city': _cityCtrl.text.trim().isEmpty
            ? 'TODAS'
            : _cityCtrl.text.trim(),
      },
    );
    p.addAlert(
      '${_currentStyleMeta.emoji} $fullTitle',
      body,
      'success',
    );
    await OmniSoundService.playSuccess();
    _setFeedback(
      'Notificação enviada para o topo do dispositivo com estilo "${_currentStyleMeta.label}"!',
    );
  }

  Future<void> _saveRecurringPromoRule(OmniDriverProvider p) async {
    final title = _titleCtrl.text.trim();
    final body = _messageCtrl.text.trim();
    if (title.length < 3 || body.length < 5) {
      OmniSoundService.playAlert();
      _setFeedback(
        'Preencha o título (mín. 3 letras) e a mensagem promocional (mín. 5 letras).',
        isError: true,
      );
      return;
    }
    final notifSvc = p.notificationService;
    if (notifSvc == null) {
      _setFeedback('Serviço de notificações indisponível.', isError: true);
      return;
    }

    setState(() => _busy = true);
    try {
      await notifSvc.requestNotificationsPermissionExplicit();
      final rule = ScheduledPromoNotificationRule(
        id: 'promo_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        message: body,
        bonusHighlight: _bonusCtrl.text.trim(),
        promoStyle: _selectedPromoStyle,
        targetCity:
            _cityCtrl.text.trim().isEmpty ? 'TODAS' : _cityCtrl.text.trim(),
        intervalSeconds: _resolvedIntervalSeconds(),
        enabled: true,
      );
      await notifSvc.addOrUpdateScheduledPromoRule(
        rule,
        triggerImmediately: true,
      );
      await OmniSoundService.playSuccess();
      final remoteNote = notifSvc.lastRemoteFcmStatus != null
          ? ' (${notifSvc.lastRemoteFcmStatus})'
          : '';
      _setFeedback(
        'Promoção agendada (${rule.intervalLabel}) com ${notifSvc.pendingOsScheduledCount} alarmes no Android$remoteNote',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publishCampaignToNetwork(OmniDriverProvider p) async {
    final title = _titleCtrl.text.trim();
    final body = _messageCtrl.text.trim();
    if (title.length < 3 || body.length < 5) {
      OmniSoundService.playAlert();
      _setFeedback(
        'Informe título e mensagem antes de publicar na rede FCM/RTDB.',
        isError: true,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final exp = now.add(const Duration(hours: 24));
      String fmt(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:00';
      final resp = await p.backend.executar(
        targetMethod: OmniBackendMethods.campaignSave,
        arguments: {
          'email': p.driver.email ?? p.backend.ownerEmail,
          'owner_email': p.driver.email ?? p.backend.ownerEmail,
          'titulo': '${_currentStyleMeta.emoji} $title',
          'mensagem': body,
          'tipo_incentivo': _selectedPromoStyle,
          'valor_ou_percentual_bonus': _bonusCtrl.text.trim(),
          'cidade_alvo':
              _cityCtrl.text.trim().isEmpty ? 'TODAS' : _cityCtrl.text.trim(),
          'data_hora_disparo': fmt(now),
          'data_hora_expiracao': fmt(exp),
          'disparar_agora': true,
        },
      );
      if (resp['success'] == true) {
        await p.refreshCampaigns();
        await OmniSoundService.playSuccess();
        _setFeedback(
          'Campanha publicada no servidor PHP + Firebase RTDB e push FCM disparado!',
        );
      } else {
        OmniSoundService.playAlert();
        _setFeedback(
          (resp['error'] ?? 'Falha ao publicar campanha.').toString(),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendDirectFcmTokenPush(OmniDriverProvider p) async {
    final notifSvc = p.notificationService;
    if (notifSvc == null) {
      _setFeedback('Serviço de notificações indisponível.', isError: true);
      return;
    }
    final title = _titleCtrl.text.trim().isNotEmpty
        ? _titleCtrl.text.trim()
        : 'OMNI Motorista • Alerta Prioritário';
    final body = _messageCtrl.text.trim().isNotEmpty
        ? _messageCtrl.text.trim()
        : 'Nova atualização de corrida/bônus enviada via FCM HTTP v1.';
    setState(() => _busy = true);
    try {
      await notifSvc.syncDriverIdentityAndToken(
        driverId: p.driver.id,
        city: p.resolvedDriverCity,
        email: p.driver.email,
      );
      final resp = await notifSvc.sendRemoteFcmPush(
        title: '${_currentStyleMeta.emoji} $title',
        body: body,
        targetFcmToken: notifSvc.fcmToken,
        targetDriverId: p.driver.id,
        data: {
          'event_type': 'owner_direct_fcm_push',
          'promo_style': _selectedPromoStyle,
          'valor_ou_percentual_bonus': _bonusCtrl.text.trim(),
          'cidade_alvo':
              _cityCtrl.text.trim().isEmpty ? 'TODAS' : _cityCtrl.text.trim(),
        },
      );
      if (resp['success'] == true) {
        await OmniSoundService.playSuccess();
        _setFeedback(
          'Push FCM HTTP v1 enviado diretamente para o token do dispositivo!',
        );
      } else {
        OmniSoundService.playAlert();
        _setFeedback(
          (resp['error'] ??
                  'Falha no envio FCM HTTP v1. Verifique a Service Account no servidor PHP.')
              .toString(),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runServerFcmCronNow(OmniDriverProvider p) async {
    final notifSvc = p.notificationService;
    if (notifSvc == null) {
      _setFeedback('Serviço de notificações indisponível.', isError: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final resp = await notifSvc.triggerServerCronTick();
      if (resp['success'] == true) {
        await OmniSoundService.playSuccess();
        _setFeedback(
          notifSvc.lastRemoteFcmStatus ??
              'Cron FCM executado no servidor PHP com sucesso!',
        );
      } else {
        OmniSoundService.playAlert();
        _setFeedback(
          (resp['error'] ??
                  'Não foi possível executar o cron FCM no servidor PHP.')
              .toString(),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatCountdown(int? seconds) {
    if (seconds == null) return 'Pausado';
    if (seconds <= 0) return 'Disparando...';
    if (seconds < 60) return '${seconds}s';
    final mins = seconds ~/ 60;
    final rem = seconds % 60;
    if (mins < 60) return '${mins}m ${rem.toString().padLeft(2, '0')}s';
    final hrs = mins ~/ 60;
    return '${hrs}h ${(mins % 60).toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();
    final bool isAuthorized = OwnerTestConfig.isAuthorizedOwner(
      p.driver,
      backendVerifiedOwner: p.backendVerifiedOwner,
      backendOwnerEmail: p.backend.ownerEmail,
    );

    if (!isAuthorized) {
      return Scaffold(
        backgroundColor: OmniTheme.bgDark,
        appBar: AppBar(
          backgroundColor: OmniTheme.slate950,
          title: const Text(
            'Acesso Restrito ao Dono',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded,
                    color: OmniTheme.rose500, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Este painel administrativo é renderizado exclusivamente para o dono do aplicativo validado por e-mail.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Voltar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final initialIndex = widget.initialTabIndex.clamp(0, 3);

    return DefaultTabController(
      length: 4,
      initialIndex: initialIndex,
      child: Scaffold(
        backgroundColor: OmniTheme.bgDark,
        appBar: AppBar(
          backgroundColor: OmniTheme.slate950,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Painel Administrativo (Dono)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              Text(
                OwnerTestConfig.primaryOwnerEmail,
                style: OmniTheme.monoStyle(
                  fontSize: 10.5,
                  color: OmniTheme.neonEmerald,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Sincronizar Tudo',
              onPressed: () => p.adminForceSyncState(),
              icon: const Icon(Icons.sync_rounded, color: OmniTheme.neonCyan),
            ),
          ],
          bottom: const TabBar(
            isScrollable: false,
            indicatorColor: OmniTheme.neonCyan,
            labelColor: OmniTheme.neonCyan,
            unselectedLabelColor: OmniTheme.slate400,
            labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            tabs: [
              Tab(icon: Icon(Icons.notifications_active_rounded, size: 18), text: 'Push Topo'),
              Tab(icon: Icon(Icons.campaign_rounded, size: 18), text: 'Campanhas'),
              Tab(icon: Icon(Icons.admin_panel_settings_rounded, size: 18), text: 'Adm Frota'),
              Tab(icon: Icon(Icons.dns_rounded, size: 18), text: 'Servidor/IP'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildScheduledPushTab(context, p),
            const AdminCampanhasMotoristaScreen(embedded: true),
            _buildFleetAdminTab(context, p),
            _buildServerDomainTab(context, p),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduledPushTab(BuildContext context, OmniDriverProvider p) {
    final notifSvc = p.notificationService;
    final permGranted = notifSvc?.notificationsPermissionGranted ?? false;
    final exactAlarmOk = notifSvc?.exactAlarmPermissionGranted ?? true;
    final osQueuedCount = notifSvc?.pendingOsScheduledCount ?? 0;
    final firebaseOk = notifSvc?.isFirebaseInitialized ?? false;
    final hasFcmToken = notifSvc?.hasFcmToken ?? false;
    final remoteStatus = notifSvc?.lastRemoteFcmStatus;
    final remoteOk = notifSvc?.lastRemoteFcmOk ?? false;
    final rules = p.scheduledPromoRules;
    final styleMeta = _currentStyleMeta;

    final previewTitle = _titleCtrl.text.trim().isNotEmpty
        ? _titleCtrl.text.trim()
        : 'Bônus Especial para Motoristas OMNI';
    final previewMsg = _messageCtrl.text.trim().isNotEmpty
        ? _messageCtrl.text.trim()
        : 'Complete corridas no horário de pico e receba bônus extra na hora!';
    final previewBonus = _bonusCtrl.text.trim();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Card de Permissão Android / iOS + Fila Nativa em App Fechado + Diagnóstico FCM Real
        Container(
          padding: const EdgeInsets.all(12),
          decoration: OmniTheme.neonCardDecoration(
            borderColor: permGranted && exactAlarmOk
                ? OmniTheme.neonEmerald
                : OmniTheme.amber400,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    permGranted
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_off_rounded,
                    color: permGranted
                        ? OmniTheme.neonEmerald
                        : OmniTheme.amber400,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          permGranted
                              ? 'Push no Topo (App Fechado e Aberto): ATIVO ✓'
                              : 'Permissão de Notificação Pendente',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: permGranted
                                ? OmniTheme.neonEmerald
                                : OmniTheme.amber400,
                          ),
                        ),
                        Text(
                          osQueuedCount > 0
                              ? '$osQueuedCount alarmes exatos gravados no Android ($osQueuedCount ciclos garantidos com o app fechado).'
                              : 'Canal Heads-Up + AlarmManager nativo prontos para disparar no topo mesmo com o app fechado.',
                          style: const TextStyle(
                              fontSize: 10.5, color: OmniTheme.slate300),
                        ),
                      ],
                    ),
                  ),
                  if (!permGranted)
                    ElevatedButton(
                      onPressed: () async {
                        await notifSvc?.requestNotificationsPermissionExplicit();
                      },
                      child: const Text('Liberar'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  OmniPillBadge(
                    text: permGranted ? 'Notificações: OK' : 'Notificações: Negada',
                    color: permGranted ? OmniTheme.neonEmerald : OmniTheme.amber400,
                  ),
                  OmniPillBadge(
                    text: exactAlarmOk
                        ? 'AlarmManager Exato: OK'
                        : 'Alarme Exato: Pendente',
                    color: exactAlarmOk ? OmniTheme.neonEmerald : OmniTheme.amber400,
                  ),
                  OmniPillBadge(
                    text: hasFcmToken
                        ? 'Token FCM: Ativo'
                        : (firebaseOk
                            ? 'Token FCM: Aguardando'
                            : 'Sem google-services.json no APK'),
                    color: hasFcmToken ? OmniTheme.neonCyan : OmniTheme.amber400,
                  ),
                ],
              ),
              if (remoteStatus != null && remoteStatus.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Servidor FCM/PHP: $remoteStatus',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: remoteOk ? OmniTheme.neonEmerald : OmniTheme.amber400,
                  ),
                ),
              ],
              if (!hasFcmToken) ...[
                const SizedBox(height: 6),
                const Text(
                  'Obs.: Inclua android/app/google-services.json no APK para gerar token FCM remoto; enquanto isso, os alarmes nativos (AlarmManager) continuam entregando com o app fechado.',
                  style: TextStyle(
                    fontSize: 10,
                    color: OmniTheme.slate400,
                  ),
                ),
              ],
              if (permGranted && !exactAlarmOk) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Alarme exato pendente no Android: libere para entregas no segundo exato com o app fechado.',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: OmniTheme.amber400,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () async {
                        await notifSvc?.requestExactAlarmPermissionExplicit();
                      },
                      child: const Text(
                        'Alarme Exato',
                        style: TextStyle(
                            fontSize: 11, color: OmniTheme.amber400),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Preview ao Vivo de como chega no Topo do Celular/iPhone
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: OmniTheme.slate950,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: OmniTheme.alpha(styleMeta.color, 0.55)),
            boxShadow: [
              BoxShadow(
                color: OmniTheme.alpha(styleMeta.color, 0.16),
                blurRadius: 14,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    styleMeta.emoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'PREVIEW NO TOPO DO CELULAR • ${styleMeta.label.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: styleMeta.color,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (previewBonus.isNotEmpty)
                    OmniPillBadge(
                      text: previewBonus,
                      color: styleMeta.color,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${styleMeta.emoji} $previewTitle${previewBonus.isNotEmpty ? ' • $previewBonus' : ''}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                previewMsg,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: OmniTheme.slate300,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (_feedback != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: OmniTheme.alpha(
                _feedbackIsError ? OmniTheme.rose500 : OmniTheme.neonEmerald,
                0.14,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    _feedbackIsError ? OmniTheme.rose500 : OmniTheme.neonEmerald,
              ),
            ),
            child: Text(
              _feedback!,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color:
                    _feedbackIsError ? OmniTheme.rose500 : OmniTheme.neonEmerald,
              ),
            ),
          ),
        ],

        // Templates Prontos de Promoções
        const Text(
          'MODELOS RÁPIDOS DE PROMOÇÃO',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            color: OmniTheme.slate400,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _quickTemplates.map((tpl) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  backgroundColor: OmniTheme.slate900,
                  side: const BorderSide(color: OmniTheme.slate700),
                  label: Text(
                    tpl.title,
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedPromoStyle = tpl.style;
                      _titleCtrl.text = tpl.title;
                      _messageCtrl.text = tpl.message;
                      _bonusCtrl.text = tpl.bonus;
                      _useCustomMinutes = false;
                      _selectedIntervalSeconds = tpl.intervalSeconds;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Formulário Principal de Programação de Notificações
        Container(
          padding: const EdgeInsets.all(14),
          decoration: OmniTheme.neonCardDecoration(active: true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OmniPillBadge(
                text: 'PROGRAMAR NOTIFICAÇÃO PROMOCIONAL',
                color: OmniTheme.neonCyan,
                icon: Icons.edit_notifications_rounded,
              ),
              const SizedBox(height: 10),

              const Text(
                'Ícone / Desenho Promocional da Notificação:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: OmniTheme.slate300,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _promoStyles.map((st) {
                  final active = _selectedPromoStyle == st.id;
                  return ChoiceChip(
                    selected: active,
                    selectedColor: OmniTheme.alpha(st.color, 0.24),
                    backgroundColor: OmniTheme.slate900,
                    side: BorderSide(
                      color: active ? st.color : OmniTheme.slate700,
                    ),
                    label: Text(
                      '${st.emoji} ${st.label}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: active ? st.color : OmniTheme.slate300,
                      ),
                    ),
                    onSelected: (_) =>
                        setState(() => _selectedPromoStyle = st.id),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _titleCtrl,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Título da Notificação *',
                  hintText: 'Ex.: Bônus Hora do Rush Ativo!',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _messageCtrl,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Mensagem Promocional no Topo do Celular *',
                  hintText:
                      'Ex.: Faça 3 corridas agora no centro e ganhe +R\$ 25,00 extras na sua carteira!',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _bonusCtrl,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Destaque / Bônus',
                        hintText: '+R\$ 25,00',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _cityCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Cidade Alvo',
                        hintText: 'TODAS',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              const Text(
                'Frequência de Repetição (de tempo em tempo):',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: OmniTheme.slate300,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ..._intervalPresets.map((preset) {
                    final active = !_useCustomMinutes &&
                        _selectedIntervalSeconds == preset.seconds;
                    return ChoiceChip(
                      selected: active,
                      selectedColor: OmniTheme.alpha(OmniTheme.neonCyan, 0.22),
                      backgroundColor: OmniTheme.slate900,
                      side: BorderSide(
                        color: active ? OmniTheme.neonCyan : OmniTheme.slate700,
                      ),
                      label: Text(
                        preset.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: active ? OmniTheme.neonCyan : OmniTheme.slate300,
                        ),
                      ),
                      onSelected: (_) {
                        setState(() {
                          _useCustomMinutes = false;
                          _selectedIntervalSeconds = preset.seconds;
                        });
                      },
                    );
                  }),
                  ChoiceChip(
                    selected: _useCustomMinutes,
                    selectedColor: OmniTheme.alpha(OmniTheme.amber400, 0.22),
                    backgroundColor: OmniTheme.slate900,
                    side: BorderSide(
                      color: _useCustomMinutes
                          ? OmniTheme.amber400
                          : OmniTheme.slate700,
                    ),
                    label: Text(
                      'Personalizado',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _useCustomMinutes
                            ? OmniTheme.amber400
                            : OmniTheme.slate300,
                      ),
                    ),
                    onSelected: (_) => setState(() => _useCustomMinutes = true),
                  ),
                ],
              ),
              if (_useCustomMinutes) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _customIntervalMinCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Intervalo personalizado (minutos)',
                    hintText: 'Ex.: 10',
                  ),
                ),
              ],
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _fireTestHeadsUpNow(p),
                      icon: const Icon(Icons.bolt_rounded,
                          size: 16, color: OmniTheme.amber400),
                      label: const Text(
                        'Testar no Topo',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: OmniTheme.amber400,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed:
                          _busy ? null : () => _saveRecurringPromoRule(p),
                      icon: const Icon(Icons.repeat_rounded, size: 17),
                      label: Text(_busy
                          ? 'SALVANDO...'
                          : 'Programar Recorrência'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _publishCampaignToNetwork(p),
                  icon: const Icon(Icons.cloud_upload_rounded,
                      size: 16, color: OmniTheme.neonCyan),
                  label: const Text(
                    'Publicar Também na Rede FCM + Firebase RTDB',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: OmniTheme.neonCyan,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _sendDirectFcmTokenPush(p),
                  icon: const Icon(Icons.phonelink_ring_rounded,
                      size: 16, color: OmniTheme.neonEmerald),
                  label: const Text(
                    'Disparar Push FCM HTTP v1 Direto (Token do Motorista)',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: OmniTheme.neonEmerald,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _runServerFcmCronNow(p),
                  icon: const Icon(Icons.schedule_send_rounded,
                      size: 16, color: OmniTheme.amber400),
                  label: const Text(
                    'Executar Cron FCM Agora (Promoções Vencidas)',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: OmniTheme.amber400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: Text(
                'Promoções Programadas (${rules.length})',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            if (rules.isNotEmpty)
              TextButton.icon(
                onPressed: () => notifSvc?.clearAllDeliveredNotifications(),
                icon: const Icon(Icons.clear_all_rounded,
                    size: 16, color: OmniTheme.slate400),
                label: const Text(
                  'Limpar Barra',
                  style: TextStyle(fontSize: 11, color: OmniTheme.slate400),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),

        if (rules.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: OmniTheme.neonCardDecoration(),
            child: const Text(
              'Nenhuma notificação recorrente programada ainda. Preencha acima ou escolha um modelo rápido para começar.',
              style: TextStyle(fontSize: 12, color: OmniTheme.slate400),
            ),
          )
        else
          ...rules.map((rule) {
            final secLeft = notifSvc?.secondsUntilNextFire(rule);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: OmniTheme.neonCardDecoration(
                borderColor: rule.enabled
                    ? OmniTheme.neonEmerald
                    : OmniTheme.slate700,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(rule.iconEmoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rule.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Switch(
                        value: rule.enabled,
                        activeColor: OmniTheme.neonEmerald,
                        onChanged: (val) =>
                            notifSvc?.toggleScheduledPromoRule(rule.id, val),
                      ),
                    ],
                  ),
                  Text(
                    rule.message,
                    style: const TextStyle(
                        fontSize: 11.5, color: OmniTheme.slate300),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      OmniPillBadge(
                        text: rule.intervalLabel,
                        color: OmniTheme.neonCyan,
                      ),
                      OmniPillBadge(
                        text: 'Próx.: ${_formatCountdown(secLeft)}',
                        color: rule.enabled
                            ? OmniTheme.neonEmerald
                            : OmniTheme.slate400,
                      ),
                      OmniPillBadge(
                        text: 'Enviadas: ${rule.triggerCount}',
                        color: OmniTheme.amber400,
                      ),
                      if (rule.bonusHighlight.isNotEmpty)
                        OmniPillBadge(
                          text: rule.bonusHighlight,
                          color: OmniTheme.neonEmerald,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => notifSvc?.triggerPromoRuleNow(rule),
                        icon: const Icon(Icons.send_rounded,
                            size: 14, color: OmniTheme.neonEmerald),
                        label: const Text(
                          'Disparar Agora',
                          style: TextStyle(
                              fontSize: 11, color: OmniTheme.neonEmerald),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Excluir regra',
                        onPressed: () =>
                            notifSvc?.deleteScheduledPromoRule(rule.id),
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: OmniTheme.rose500, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildFleetAdminTab(BuildContext context, OmniDriverProvider p) {
    final driver = p.driver;
    final double currentRadius = driver.workPreferences?.maxRadiusKm ?? 15.0;
    final loc = p.driverLocation;
    final fcmToken = p.notificationService?.fcmToken;
    const tiers = ['INICIAL', 'PRATA', 'OURO', 'PLATINA', 'ELITE'];

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const OwnerTestHiredDriverCheckbox(),
        const SizedBox(height: 12),

        // Controle Administrativo de Clube, Raio e Cidade Operacional
        Container(
          padding: const EdgeInsets.all(14),
          decoration: OmniTheme.neonCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OmniPillBadge(
                text: 'CONTROLES OPERACIONAIS DO MOTORISTA',
                color: OmniTheme.neonCyan,
                icon: Icons.tune_rounded,
              ),
              const SizedBox(height: 10),
              const Text(
                'Nível Clube OMNI (Taxa da Plataforma):',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: OmniTheme.slate300,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tiers.map((tier) {
                  final active = driver.clubTier == tier;
                  return ChoiceChip(
                    selected: active,
                    selectedColor: OmniTheme.alpha(OmniTheme.neonEmerald, 0.24),
                    backgroundColor: OmniTheme.slate900,
                    side: BorderSide(
                      color: active ? OmniTheme.neonEmerald : OmniTheme.slate700,
                    ),
                    label: Text(
                      tier,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color:
                            active ? OmniTheme.neonEmerald : OmniTheme.slate300,
                      ),
                    ),
                    onSelected: (_) =>
                        p.adminUpdateOperationalControls(clubTier: tier),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              Text(
                'Raio Máximo de Chamadas: ${currentRadius.round()} km',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Slider(
                value: currentRadius.clamp(3.0, 80.0),
                min: 3.0,
                max: 80.0,
                divisions: 77,
                activeColor: OmniTheme.neonCyan,
                label: '${currentRadius.round()} km',
                onChanged: (v) => p.adminUpdateOperationalControls(
                  maxRadiusKm: v.roundToDouble(),
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _opCityCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Cidade Operacional / Tópico Push',
                        hintText: 'Ex.: Florianópolis',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      await p.adminUpdateOperationalControls(
                        operationalCity: _opCityCtrl.text,
                      );
                      p.addAlert(
                        'Cidade Atualizada',
                        'Tópico de notificações sincronizado para "${_opCityCtrl.text.trim()}".',
                        'success',
                      );
                    },
                    child: const Text('Aplicar'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Crédito Administrativo de Bônus na Carteira
        Container(
          padding: const EdgeInsets.all(14),
          decoration: OmniTheme.neonCardDecoration(
            borderColor: OmniTheme.alpha(OmniTheme.neonEmerald, 0.45),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const OmniPillBadge(
                    text: 'CARTEIRA & BÔNUS PROMOCIONAL',
                    color: OmniTheme.neonEmerald,
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                  const Spacer(),
                  Text(
                    'Saldo: R\$ ${driver.walletBalance.toStringAsFixed(2)}',
                    style: OmniTheme.monoStyle(
                      fontSize: 12,
                      color: OmniTheme.neonEmerald,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _walletBonusAmountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Valor do Bônus (R\$)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _walletBonusDescCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Descrição da Transação',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final parsed = double.tryParse(
                          _walletBonusAmountCtrl.text
                              .trim()
                              .replaceAll(',', '.'),
                        ) ??
                        0.0;
                    if (parsed <= 0) return;
                    await p.adminGrantPromoWalletBonus(
                      amount: parsed,
                      description: _walletBonusDescCtrl.text,
                    );
                  },
                  icon: const Icon(Icons.add_card_rounded, size: 17),
                  label: const Text('Creditar Bônus na Carteira'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Auditoria de Onboarding & Diagnóstico em Tempo Real
        Container(
          padding: const EdgeInsets.all(14),
          decoration: OmniTheme.neonCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OmniPillBadge(
                text: 'AUDITORIA & TELEMETRIA EM TEMPO REAL',
                color: OmniTheme.amber400,
                icon: Icons.analytics_rounded,
              ),
              const SizedBox(height: 10),
              Text(
                'Score Gatekeeper: ${p.onboardingScore}% • Status: ${p.isDriverFullyApproved ? '100% APTO' : 'PENDENTE'} • Online: ${driver.isOnline ? 'SIM' : 'NÃO'}',
                style: const TextStyle(fontSize: 11.5, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                'GPS: ${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)} (precisão ${p.locationService.lastAccuracyMeters.toStringAsFixed(1)}m)',
                style: OmniTheme.monoStyle(
                  fontSize: 11,
                  color: OmniTheme.neonCyan,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Backend Ativo: ${p.backendAjaxUrl}',
                style: OmniTheme.monoStyle(
                  fontSize: 10.5,
                  color: OmniTheme.slate300,
                ),
              ),
              if (fcmToken != null && fcmToken.isNotEmpty) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: fcmToken));
                    p.addAlert(
                      'Token FCM Copiado',
                      'Token do dispositivo copiado para a área de transferência.',
                      'info',
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: OmniTheme.slate950,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: OmniTheme.slate800),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'FCM Token: $fcmToken',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: OmniTheme.monoStyle(
                              fontSize: 10,
                              color: OmniTheme.slate400,
                            ),
                          ),
                        ),
                        const Icon(Icons.copy_rounded,
                            size: 14, color: OmniTheme.neonCyan),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => p.unlockAllOnboardingForSimulation(),
                      icon: const Icon(Icons.verified_rounded,
                          size: 15, color: OmniTheme.neonEmerald),
                      label: const Text(
                        'Aprovar Onboarding',
                        style: TextStyle(
                            fontSize: 11, color: OmniTheme.neonEmerald),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => p.adminResetOnboardingForAudit(),
                      icon: const Icon(Icons.restart_alt_rounded,
                          size: 15, color: OmniTheme.amber400),
                      label: const Text(
                        'Resetar Gatekeeper',
                        style:
                            TextStyle(fontSize: 11, color: OmniTheme.amber400),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServerDomainTab(BuildContext context, OmniDriverProvider p) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: OmniTheme.neonCardDecoration(
            borderColor: OmniTheme.alpha(OmniTheme.neonCyan, 0.45),
          ),
          child: const Row(
            children: [
              Icon(Icons.security_rounded,
                  color: OmniTheme.neonCyan, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'A configuração de IP/Domínio, cache do roteador e teste de conexão aparece exclusivamente para o dono do aplicativo.',
                  style: TextStyle(fontSize: 11.5, color: OmniTheme.slate300),
                ),
              ),
            ],
          ),
        ),
        const BackendDomainConfigCard(),
      ],
    );
  }
}
