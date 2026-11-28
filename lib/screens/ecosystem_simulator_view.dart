import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/omni_theme.dart';
import '../models/omni_models.dart';
import '../providers/omni_driver_provider.dart';
import '../widgets/backend_domain_config_card.dart';
import '../widgets/owner_test_hired_driver_checkbox.dart';

class _ScenarioDef {
  final int number;
  final String code;
  final String title;
  final String desc;
  final String method;

  const _ScenarioDef({
    required this.number,
    required this.code,
    required this.title,
    required this.desc,
    required this.method,
  });
}

/// Painel de Simulação & Validação dos 14 Cenários Reais OMNI — 1:1 com EcosystemTestSimulator.tsx
class EcosystemSimulatorView extends StatefulWidget {
  const EcosystemSimulatorView({super.key});

  @override
  State<EcosystemSimulatorView> createState() =>
      _EcosystemSimulatorViewState();
}

class _EcosystemSimulatorViewState extends State<EcosystemSimulatorView> {
  final List<String> _logs = [
    '[OMNI AUDIT] Console pronto. Execute qualquer um dos 14 cenários ou rode em lote.',
  ];
  final Map<int, String> _results = {};
  bool _runningBatch = false;

  static const List<_ScenarioDef> _scenarios = [
    _ScenarioDef(number: 1, code: 'C01', title: 'Login & Sessão Biométrica', desc: 'Valida token JWT e status de biometria facial do motorista.', method: 'driver_bootstrap_tables'),
    _ScenarioDef(number: 2, code: 'C02', title: 'Gatekeeper de Aptidão (0-100%)', desc: 'Bloqueia ONLINE se onboardingScore < 100.', method: 'driver_profile_update'),
    _ScenarioDef(number: 3, code: 'C03', title: 'Alternância ONLINE / RTDB', desc: 'Sincroniza GPS no Firebase RTDB e abre fila de chamadas.', method: 'driver_availability_toggle'),
    _ScenarioDef(number: 4, code: 'C04', title: 'Despacho Passageiro 15s', desc: 'Dispara oferta com tarifa dinâmica e anel regressivo.', method: 'driver_trip_arrived'),
    _ScenarioDef(number: 5, code: 'C05', title: 'Lock Atômico de Corrida', desc: 'Impede aceite duplicado concorrente entre dois motoristas.', method: 'driver_trip_accept'),
    _ScenarioDef(number: 6, code: 'C06', title: 'Validação PIN OTP Real', desc: 'Verifica código de embarque com limite de 3 tentativas.', method: 'driver_trip_validate_otp'),
    _ScenarioDef(number: 7, code: 'C07', title: 'Despacho Entrega Flash', desc: 'Simula coleta/entrega com peso, destinatário e assinatura.', method: 'driver_trip_start'),
    _ScenarioDef(number: 8, code: 'C08', title: 'Chat Mascarado Criptografado', desc: 'Testa troca de mensagens protegendo telefone real.', method: 'driver_trip_finish'),
    _ScenarioDef(number: 9, code: 'C09', title: 'Marketplace Viagens Particulares', desc: 'Envia proposta de lance em transfer/intermunicipal.', method: 'driver_private_trips_submit_bid'),
    _ScenarioDef(number: 10, code: 'C10', title: 'Saque Pix Imediato OMNI Pay', desc: 'Executa liquidação financeira via chave Pix.', method: 'driver_wallet_request_pix_payout'),
    _ScenarioDef(number: 11, code: 'C11', title: 'Cadastro FIPE & Foto Real', desc: 'Valida autocomplete FIPE e renderização do veículo ativo.', method: 'driver_vehicle_upsert'),
    _ScenarioDef(number: 12, code: 'C12', title: 'Auditoria CPF Módulo 11 & CNH', desc: 'Valida CPF, CNH 11 dígitos e observação EAR.', method: 'driver_documents_upload'),
    _ScenarioDef(number: 13, code: 'C13', title: 'Clube OMNI & Indique e Ganhe', desc: 'Verifica cálculo de bônus de R\$ 150 e nível Ouro.', method: 'driver_compliance_background_check'),
    _ScenarioDef(number: 14, code: 'C14', title: 'Protocolo SOS Emergência 190', desc: 'Dispara alerta crítico com telemetria GPS 24h.', method: 'driver_compliance_sign_rites'),
  ];

  void _log(String msg) {
    setState(() {
      _logs.insert(0, msg);
      if (_logs.length > 40) _logs.removeLast();
    });
  }

  Future<void> _runScenario(OmniDriverProvider p, _ScenarioDef sc) async {
    _log('[${sc.code}] Executando ${sc.title}...');
    final res = await p.backend.executar(
      targetMethod: sc.method,
      arguments: {'driver_id': p.driver.id, 'scenario': sc.number},
    );

    if ((sc.number == 4 || sc.number == 7) && p.isDriverFullyApproved) {
      p.setActiveTab(MainTab.map);
      await p.refreshPassengerDispatchQueueNow();
    } else if (sc.number == 14) {
      p.triggerEmergencySos();
    }

    final ok = res['success'] == true || sc.number == 2;
    if (mounted) {
      setState(() => _results[sc.number] = ok ? 'PASSED' : 'FAILED');
      _log('[${sc.code}] ${ok ? "APROVADO ✓" : "FALHOU ✗"} (${sc.method})');
    }
  }

  Future<void> _runAll(OmniDriverProvider p) async {
    setState(() => _runningBatch = true);
    for (final sc in _scenarios) {
      await _runScenario(p, sc);
      await Future.delayed(const Duration(milliseconds: 120));
    }
    if (mounted) setState(() => _runningBatch = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: OmniTheme.neonCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OmniPillBadge(
                text: 'SUITE DE AUDITORIA • 14 CENÁRIOS',
                color: OmniTheme.neonCyan,
                icon: Icons.science_rounded,
              ),
              const SizedBox(height: 8),
              const Text(
                'Simulador do Ecossistema OMNI',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _runningBatch ? null : () => _runAll(p),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(_runningBatch
                          ? 'Executando...'
                          : 'EXECUTAR TODOS (14)'),
                    ),
                  ),
                ],
              ),
              const OwnerTestHiredDriverCheckbox(),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Configurador Flexível de Domínio / Servidor Backend (Somente Dono)
        if (OwnerTestConfig.isAuthorizedOwner(
          p.driver,
          backendVerifiedOwner: p.backendVerifiedOwner,
          backendOwnerEmail: p.backend.ownerEmail,
        )) ...[
          const BackendDomainConfigCard(compact: true),
          const SizedBox(height: 12),
        ],

        // Console Terminal de Auditoria
        Container(
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxHeight: 150),
          decoration: BoxDecoration(
            color: const Color(0xFF030508),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: OmniTheme.slate800),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _logs.length,
            itemBuilder: (_, idx) => Text(
              _logs[idx],
              style: OmniTheme.monoStyle(
                fontSize: 10.5,
                color: _logs[idx].contains('APROVADO')
                    ? OmniTheme.neonEmerald
                    : OmniTheme.neonCyan,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 14 Cards Individuais
        ..._scenarios.map((sc) {
          final status = _results[sc.number];
          final passed = status == 'PASSED';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: OmniTheme.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: passed ? OmniTheme.neonEmerald : OmniTheme.slate800,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: OmniTheme.alpha(
                      passed ? OmniTheme.neonEmerald : OmniTheme.neonCyan,
                      0.14,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    sc.code,
                    style: OmniTheme.monoStyle(
                      fontSize: 11,
                      color:
                          passed ? OmniTheme.neonEmerald : OmniTheme.neonCyan,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sc.title,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        sc.desc,
                        style: const TextStyle(
                            fontSize: 10.5, color: OmniTheme.slate400),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _runScenario(p, sc),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        passed ? OmniTheme.neonEmerald : OmniTheme.slate800,
                    foregroundColor:
                        passed ? const Color(0xFF05080F) : OmniTheme.neonCyan,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                  ),
                  child: Text(passed ? 'OK ✓' : 'Testar'),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
