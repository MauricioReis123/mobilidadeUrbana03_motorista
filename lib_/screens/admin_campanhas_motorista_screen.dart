import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/omni_integration_contracts.dart';
import '../config/omni_theme.dart';
import '../models/omni_models.dart';
import '../providers/omni_driver_provider.dart';
import '../services/sound_service.dart';
import '../widgets/owner_test_hired_driver_checkbox.dart';

/// Painel Administrativo Exclusivo do Dono (E-mail autorizado)
/// Gerencia Campanhas de Bônus, Alta Demanda e Push FCM HTTP v1 para Motoristas.
class AdminCampanhasMotoristaScreen extends StatefulWidget {
  final bool embedded;

  const AdminCampanhasMotoristaScreen({super.key, this.embedded = false});

  @override
  State<AdminCampanhasMotoristaScreen> createState() =>
      _AdminCampanhasMotoristaScreenState();
}

class _AdminCampanhasMotoristaScreenState
    extends State<AdminCampanhasMotoristaScreen> {
  final _emailAuthCtrl = TextEditingController();

  final _tituloCtrl = TextEditingController();
  final _mensagemCtrl = TextEditingController();
  final _imagemUrlCtrl = TextEditingController();
  final _bonusValorCtrl = TextEditingController(text: '+R\$ 25,00');
  final _cidadeAlvoCtrl = TextEditingController();

  String _tipoIncentivo = 'bonus_corridas';
  DateTime _dataDisparo = DateTime.now();
  DateTime _dataExpiracao = DateTime.now().add(const Duration(hours: 24));
  String _statusFilter = 'TODAS';
  bool _busy = false;
  bool _authBusy = false;
  String? _statusMsg;
  bool _statusIsError = false;
  List<DriverCampaign> _serverCampaigns = const [];

  static const List<String> _cityPresets = [
    'TODAS',
    'Balneário Camboriú',
    'Camboriú',
    'Itajaí',
    'Itapema',
    'Florianópolis',
    'São Paulo',
  ];

  static const Map<String, String> _incentiveLabels = {
    'bonus_corridas': 'Bônus por Corridas',
    'alta_demanda': 'Alta Demanda / Evento',
    'meta_periodo': 'Meta por Período',
    'aviso_operacional': 'Aviso Operacional',
  };

  @override
  void initState() {
    super.initState();
    final p = context.read<OmniDriverProvider>();
    _emailAuthCtrl.text = (p.driver.email ?? '').trim().isNotEmpty
        ? p.driver.email!.trim()
        : p.backend.ownerEmail;
    _cidadeAlvoCtrl.text =
        p.resolvedDriverCity.isNotEmpty ? p.resolvedDriverCity : 'TODAS';
    _serverCampaigns = p.allCampaigns;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCampaigns();
    });
  }

  @override
  void dispose() {
    _emailAuthCtrl.dispose();
    _tituloCtrl.dispose();
    _mensagemCtrl.dispose();
    _imagemUrlCtrl.dispose();
    _bonusValorCtrl.dispose();
    _cidadeAlvoCtrl.dispose();
    super.dispose();
  }

  String _formatIsoLocal(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm:00';
  }

  String _formatDisplayDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year} $hh:$mm';
  }

  void _setFeedback(String msg, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _statusMsg = msg;
      _statusIsError = isError;
    });
  }

  Future<void> _authenticateOwner(OmniDriverProvider p) async {
    if (_authBusy) return;
    FocusScope.of(context).unfocus();
    setState(() => _authBusy = true);
    try {
      final ok = await p.authenticateOwnerByEmail(_emailAuthCtrl.text.trim());
      if (ok) {
        await OmniSoundService.playSuccess();
        _setFeedback('Dono reconhecido pelo e-mail autorizado!');
        await _loadCampaigns();
      } else {
        OmniSoundService.playAlert();
        _setFeedback(
          'Informe o e-mail de dono autorizado (${OwnerTestConfig.primaryOwnerEmail}).',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  Future<void> _loadCampaigns() async {
    final p = context.read<OmniDriverProvider>();
    setState(() => _busy = true);
    try {
      final resp = await p.backend.executar(
        targetMethod: OmniBackendMethods.campaignList,
        arguments: {
          'email': p.driver.email ?? p.backend.ownerEmail,
        },
      );
      final data = resp['data'];
      if (resp['success'] == true &&
          data is Map<String, dynamic> &&
          data['campaigns'] is List) {
        final list = <DriverCampaign>[];
        for (final item in data['campaigns'] as List) {
          if (item is Map) {
            list.add(DriverCampaign.fromJson(Map<String, dynamic>.from(item)));
          }
        }
        if (mounted) {
          setState(() => _serverCampaigns = list);
        }
      }
      await p.refreshCampaigns();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDateTime({required bool isDispatch}) async {
    final initial = isDispatch ? _dataDisparo : _dataExpiracao;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isDispatch) {
        _dataDisparo = combined;
        if (!_dataExpiracao.isAfter(_dataDisparo)) {
          _dataExpiracao = _dataDisparo.add(const Duration(hours: 24));
        }
      } else {
        _dataExpiracao = combined;
      }
    });
  }

  Future<void> _saveCampaign(
    OmniDriverProvider p, {
    required bool dispatchNow,
  }) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();

    final titulo = _tituloCtrl.text.trim();
    final mensagem = _mensagemCtrl.text.trim();
    final cidade = _cidadeAlvoCtrl.text.trim().isEmpty
        ? 'TODAS'
        : _cidadeAlvoCtrl.text.trim();

    if (titulo.length < 3 || mensagem.length < 5) {
      OmniSoundService.playAlert();
      _setFeedback(
        'Informe título (mín. 3 letras) e mensagem (mín. 5 letras) da campanha.',
        isError: true,
      );
      return;
    }

    final rawImageUrl = _imagemUrlCtrl.text.trim();
    if (rawImageUrl.isNotEmpty) {
      final parsedUrl = Uri.tryParse(rawImageUrl);
      final validScheme = parsedUrl != null &&
          (parsedUrl.scheme == 'https' || parsedUrl.scheme == 'http') &&
          parsedUrl.host.isNotEmpty;
      if (!validScheme) {
        OmniSoundService.playAlert();
        _setFeedback(
          'URL da imagem inválida. Use apenas links completos com https:// ou http://.',
          isError: true,
        );
        return;
      }
    }

    setState(() => _busy = true);
    try {
      final resp = await p.backend.executar(
        targetMethod: OmniBackendMethods.campaignSave,
        arguments: {
          'email': p.driver.email ?? p.backend.ownerEmail,
          'titulo': titulo,
          'mensagem': mensagem,
          'imagem_url': _imagemUrlCtrl.text.trim(),
          'tipo_incentivo': _tipoIncentivo,
          'valor_ou_percentual_bonus': _bonusValorCtrl.text.trim(),
          'cidade_alvo': cidade,
          'data_hora_disparo': _formatIsoLocal(
            dispatchNow ? DateTime.now() : _dataDisparo,
          ),
          'data_hora_expiracao': _formatIsoLocal(_dataExpiracao),
          'disparar_agora': dispatchNow,
        },
      );

      if (resp['success'] == true) {
        await OmniSoundService.playSuccess();
        _tituloCtrl.clear();
        _mensagemCtrl.clear();
        _imagemUrlCtrl.clear();
        _setFeedback(
          dispatchNow
              ? 'Campanha criada, salva no MySQL/RTDB e push disparado!'
              : 'Campanha agendada para ${_formatDisplayDate(_dataDisparo)}!',
        );
        await _loadCampaigns();
      } else {
        OmniSoundService.playAlert();
        _setFeedback(
          (resp['error'] ?? resp['message'] ?? 'Erro ao salvar campanha.')
              .toString(),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _campaignAction(
    OmniDriverProvider p, {
    required String method,
    required DriverCampaign campaign,
    required String successMessage,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final resp = await p.backend.executar(
        targetMethod: method,
        arguments: {
          'email': p.driver.email ?? p.backend.ownerEmail,
          'campaign_id': campaign.id,
        },
      );
      if (resp['success'] == true) {
        await OmniSoundService.playSuccess();
        _setFeedback(successMessage);
        await _loadCampaigns();
      } else {
        OmniSoundService.playAlert();
        _setFeedback(
          (resp['error'] ?? resp['message'] ?? 'Não foi possível executar ação.')
              .toString(),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runCronSweep(OmniDriverProvider p) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final resp = await p.backend.executar(
        targetMethod: OmniBackendMethods.campaignProcessCron,
        arguments: {
          'email': p.driver.email ?? p.backend.ownerEmail,
        },
      );
      final data = resp['data'];
      final count = data is Map ? (data['processed_count'] ?? 0) : 0;
      _setFeedback('Varredura WP-Cron executada: $count campanha(s) disparada(s).');
      await _loadCampaigns();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'enviada':
      case 'disparada':
        return OmniTheme.neonEmerald;
      case 'agendada':
        return OmniTheme.amber400;
      case 'cancelada':
        return OmniTheme.rose500;
      default:
        return OmniTheme.neonCyan;
    }
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
      if (widget.embedded) {
        return const SizedBox.shrink();
      }
      return Scaffold(
        backgroundColor: OmniTheme.bgDark,
        appBar: AppBar(
          backgroundColor: OmniTheme.slate950,
          title: const Text(
            'Acesso Restrito',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  color: OmniTheme.rose500,
                  size: 42,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Painel exclusivo do dono do aplicativo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
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

    final listSource =
        _serverCampaigns.isNotEmpty ? _serverCampaigns : p.allCampaigns;
    final filtered = _statusFilter == 'TODAS'
        ? listSource
        : listSource.where((c) {
            final st = c.status.toLowerCase();
            if (_statusFilter == 'enviada') {
              return st == 'enviada' || st == 'disparada';
            }
            return st == _statusFilter;
          }).toList();

    final listBody = ListView(
      padding: const EdgeInsets.all(14),
      children: [
        if (widget.embedded) ...[
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Campanhas & Cron FCM (PHP / MySQL / RTDB)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _runCronSweep(p),
                icon: const Icon(Icons.schedule_send_rounded,
                    size: 14, color: OmniTheme.amber400),
                label: const Text(
                  'Cron',
                  style: TextStyle(fontSize: 11, color: OmniTheme.amber400),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Atualizar',
                onPressed: _busy ? null : _loadCampaigns,
                icon: const Icon(Icons.refresh_rounded,
                    color: OmniTheme.neonCyan, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
          // Cartão de Autenticação Exclusiva do Dono (E-mail autorizado)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: OmniTheme.neonCardDecoration(
              borderColor: isAuthorized
                  ? OmniTheme.neonEmerald
                  : OmniTheme.amber400,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isAuthorized
                          ? Icons.verified_user_rounded
                          : Icons.admin_panel_settings_rounded,
                      color: isAuthorized
                          ? OmniTheme.neonEmerald
                          : OmniTheme.amber400,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isAuthorized
                            ? 'DONO RECONHECIDO (${_emailAuthCtrl.text.trim().isEmpty ? OwnerTestConfig.primaryOwnerEmail : _emailAuthCtrl.text.trim().toLowerCase()})'
                            : 'IDENTIFICAÇÃO DE DONO • SOMENTE E-MAIL',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: isAuthorized
                              ? OmniTheme.neonEmerald
                              : OmniTheme.amber400,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailAuthCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'E-mail do Dono',
                    hintText: OwnerTestConfig.primaryOwnerEmail,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _authBusy ? null : () => _authenticateOwner(p),
                    icon: const Icon(Icons.verified_user_rounded, size: 17),
                    label: Text(
                      _authBusy
                          ? 'CONFIRMANDO...'
                          : isAuthorized
                              ? 'RECONFIRMAR E-MAIL DE DONO'
                              : 'LIBERAR ACESSO DE DONO',
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_statusMsg != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: OmniTheme.alpha(
                  _statusIsError ? OmniTheme.rose500 : OmniTheme.neonEmerald,
                  0.14,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _statusIsError
                      ? OmniTheme.rose500
                      : OmniTheme.neonEmerald,
                ),
              ),
              child: Text(
                _statusMsg!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _statusIsError
                      ? OmniTheme.rose500
                      : OmniTheme.neonEmerald,
                ),
              ),
            ),
          ],

          const SizedBox(height: 4),
            // Formulário de Criação / Agendamento de Campanha
            Container(
              padding: const EdgeInsets.all(14),
              decoration: OmniTheme.neonCardDecoration(active: true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const OmniPillBadge(
                    text: 'CRIAR / AGENDAR CAMPANHA DE MOTORISTA',
                    color: OmniTheme.neonCyan,
                    icon: Icons.campaign_rounded,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _tituloCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Título da Campanha *',
                      hintText: 'Ex.: Festival de Camboriú • Bônus +R\$ 25',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _mensagemCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Mensagem do Push / Incentivo *',
                      hintText:
                          'Ex.: Complete 5 corridas no centro entre 19h e 02h e ganhe bônus extra direto na carteira.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _tipoIncentivo,
                          dropdownColor: OmniTheme.slate900,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12.5),
                          decoration: const InputDecoration(
                              labelText: 'Tipo de Incentivo'),
                          items: _incentiveLabels.entries
                              .map((e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(e.value),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _tipoIncentivo = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _bonusValorCtrl,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Valor / % Bônus',
                            hintText: '+R\$ 25,00 ou +30%',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _cidadeAlvoCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Cidade Alvo (ou TODAS)',
                      hintText: 'Ex.: Balneário Camboriú',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _cityPresets.map((city) {
                      final active = _cidadeAlvoCtrl.text.trim().toLowerCase() ==
                          city.toLowerCase();
                      return InkWell(
                        onTap: () =>
                            setState(() => _cidadeAlvoCtrl.text = city),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: active
                                ? OmniTheme.alpha(OmniTheme.neonCyan, 0.2)
                                : OmniTheme.slate900,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: active
                                  ? OmniTheme.neonCyan
                                  : OmniTheme.slate700,
                            ),
                          ),
                          child: Text(
                            city,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? OmniTheme.neonCyan
                                  : OmniTheme.slate300,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _imagemUrlCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'URL da Imagem (Opcional)',
                      hintText: 'https://...',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDateTime(isDispatch: true),
                          icon: const Icon(Icons.schedule_rounded,
                              size: 15, color: OmniTheme.amber400),
                          label: Text(
                            'Disparo: ${_formatDisplayDate(_dataDisparo)}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDateTime(isDispatch: false),
                          icon: const Icon(Icons.event_busy_rounded,
                              size: 15, color: OmniTheme.neonCyan),
                          label: Text(
                            'Expira: ${_formatDisplayDate(_dataExpiracao)}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _saveCampaign(p, dispatchNow: false),
                          icon: const Icon(Icons.event_available_rounded,
                              size: 16, color: OmniTheme.amber400),
                          label: const Text(
                            'Agendar',
                            style: TextStyle(
                                color: OmniTheme.amber400,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _saveCampaign(p, dispatchNow: true),
                          icon: const Icon(Icons.send_rounded, size: 16),
                          label: Text(_busy
                              ? 'ENVIANDO...'
                              : 'Criar e Disparar Push Agora'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Campanhas Registradas',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                DropdownButton<String>(
                  value: _statusFilter,
                  dropdownColor: OmniTheme.slate900,
                  style: const TextStyle(color: OmniTheme.neonCyan, fontSize: 12),
                  items: const [
                    DropdownMenuItem(value: 'TODAS', child: Text('Todas')),
                    DropdownMenuItem(value: 'agendada', child: Text('Agendadas')),
                    DropdownMenuItem(value: 'enviada', child: Text('Enviadas')),
                    DropdownMenuItem(value: 'cancelada', child: Text('Canceladas')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _statusFilter = v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: OmniTheme.neonCardDecoration(),
                child: const Text(
                  'Nenhuma campanha cadastrada neste filtro.',
                  style: TextStyle(fontSize: 12, color: OmniTheme.slate400),
                ),
              )
            else
              ...filtered.map((camp) {
                final color = _statusColor(camp.status);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: OmniTheme.neonCardDecoration(
                    borderColor: OmniTheme.alpha(color, 0.45),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          OmniPillBadge(
                            text: camp.status.toUpperCase(),
                            color: color,
                          ),
                          const SizedBox(width: 6),
                          OmniPillBadge(
                            text: camp.cidadeAlvo,
                            color: OmniTheme.neonCyan,
                          ),
                          const Spacer(),
                          if (camp.valorOuPercentualBonus.isNotEmpty)
                            Text(
                              camp.valorOuPercentualBonus,
                              style: OmniTheme.monoStyle(
                                fontSize: 12,
                                color: OmniTheme.neonEmerald,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        camp.titulo,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        camp.mensagem,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: OmniTheme.slate300,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tipo: ${_incentiveLabels[camp.tipoIncentivo] ?? camp.tipoIncentivo} • Disparo: ${camp.dataHoraDisparo}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: OmniTheme.slate400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (camp.status.toLowerCase() != 'cancelada')
                            OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _campaignAction(
                                        p,
                                        method: OmniBackendMethods
                                            .campaignDispatchNow,
                                        campaign: camp,
                                        successMessage:
                                            'Push FCM disparado para ${camp.cidadeAlvo}!',
                                      ),
                              icon: const Icon(Icons.notifications_active_rounded,
                                  size: 14, color: OmniTheme.neonEmerald),
                              label: const Text(
                                'Disparar Agora',
                                style: TextStyle(
                                    fontSize: 11, color: OmniTheme.neonEmerald),
                              ),
                            ),
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _campaignAction(
                                      p,
                                      method:
                                          OmniBackendMethods.campaignDuplicate,
                                      campaign: camp,
                                      successMessage:
                                          'Campanha duplicada como rascunho agendado.',
                                    ),
                            icon: const Icon(Icons.copy_rounded,
                                size: 14, color: OmniTheme.neonCyan),
                            label: const Text(
                              'Duplicar',
                              style: TextStyle(
                                  fontSize: 11, color: OmniTheme.neonCyan),
                            ),
                          ),
                          if (camp.status.toLowerCase() != 'cancelada')
                            OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _campaignAction(
                                        p,
                                        method:
                                            OmniBackendMethods.campaignCancel,
                                        campaign: camp,
                                        successMessage:
                                            'Campanha cancelada e removida do feed ativo.',
                                      ),
                              icon: const Icon(Icons.cancel_rounded,
                                  size: 14, color: OmniTheme.rose500),
                              label: const Text(
                                'Cancelar',
                                style: TextStyle(
                                    fontSize: 11, color: OmniTheme.rose500),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
        ],
      );

    if (widget.embedded) {
      return listBody;
    }

    return Scaffold(
      backgroundColor: OmniTheme.bgDark,
      appBar: AppBar(
        backgroundColor: OmniTheme.slate950,
        title: const Text(
          'Campanhas & Push Motoristas (Dono)',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        actions: [
          if (isAuthorized)
            IconButton(
              tooltip: 'Executar Cron Agora',
              onPressed: _busy ? null : () => _runCronSweep(p),
              icon: const Icon(Icons.schedule_send_rounded,
                  color: OmniTheme.amber400),
            ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _busy ? null : _loadCampaigns,
            icon: const Icon(Icons.refresh_rounded, color: OmniTheme.neonCyan),
          ),
        ],
      ),
      body: listBody,
    );
  }
}
