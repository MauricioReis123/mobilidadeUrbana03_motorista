import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/omni_theme.dart';
import '../models/omni_models.dart';
import '../providers/omni_driver_provider.dart';

/// CONFIGURAÇÃO DE ACESSO EXCLUSIVO DO DONO DO APLICATIVO
///
/// Este arquivo controla a visibilidade e a ativação do Checkbox de simulação
/// de motorista contratado/aprovado para testes de comunicação entre os apps
/// Motorista <-> Passageiro, integrado ao backend PHP
/// `backend_php/class-omni-motorista-backend-pro.php` (`driver_verify_app_owner`
/// e `driver_owner_simulate_hired`).
///
/// REGRA DE RECONHECIMENTO:
/// 1) O acesso de dono é liberado automaticamente somente pelo e-mail
///    `yahnzinho1@gmail.com` em qualquer build (debug ou APK release).
/// 2) Para qualquer outro usuário, retorna `const SizedBox.shrink()`.
class OwnerTestConfig {
  static const String primaryOwnerEmail = 'yahnzinho1@gmail.com';

  /// Mantido como `true` para compatibilidade em builds release e debug
  static const bool isTestBuildEnabled = true;

  /// E-MAIL AUTORIZADO DO DONO DO APLICATIVO
  static const Set<String> allowedOwnerEmails = {
    primaryOwnerEmail,
  };

  static bool isOwnerEmailString(String? rawEmail) {
    final normalized = (rawEmail ?? '').trim().toLowerCase();
    return normalized.isNotEmpty && allowedOwnerEmails.contains(normalized);
  }

  static bool isOwnerEmailMatch(
    OmniDriver driver, {
    String? emailOverride,
    String? backendOwnerEmail,
  }) {
    return isOwnerEmailString(emailOverride) ||
        isOwnerEmailString(driver.email) ||
        isOwnerEmailString(backendOwnerEmail);
  }

  /// Libera exclusivamente quando o e-mail corresponde a yahnzinho1@gmail.com.
  static bool isAuthorizedOwner(
    OmniDriver driver, {
    bool backendVerifiedOwner = false,
    String? emailOverride,
    String? backendOwnerEmail,
  }) {
    return isOwnerEmailMatch(
      driver,
      emailOverride: emailOverride,
      backendOwnerEmail: backendOwnerEmail,
    );
  }
}

/// WIDGET: OwnerTestHiredDriverCheckbox
///
/// Checkbox exclusivo do dono do aplicativo que simula em segundo plano o
/// motorista como já contratado, 100% validado, aprovado e ONLINE para testar
/// a comunicação em tempo real entre o App do Motorista e o App do Passageiro.
///
/// Para qualquer outro usuário, retorna `const SizedBox.shrink()`.
class OwnerTestHiredDriverCheckbox extends StatefulWidget {
  /// Exibe layout mais compacto para cards menores ou painéis flutuantes.
  final bool compact;

  /// ONDE CONECTAR A FUNÇÃO DE ATIVAÇÃO PERSONALIZADA (CALLBACK OPCIONAL)
  /// Se omitido (`null`), o widget conecta automaticamente em:
  /// `context.read<OmniDriverProvider>().setOwnerSimulatedHiredDriver(enabled)`.
  final Future<void> Function(bool enabled)? onToggleHiredDriver;

  /// E-mail opcional vindo do provedor de autenticação
  final String? ownerEmailOverride;

  const OwnerTestHiredDriverCheckbox({
    super.key,
    this.compact = false,
    this.onToggleHiredDriver,
    this.ownerEmailOverride,
  });

  @override
  State<OwnerTestHiredDriverCheckbox> createState() =>
      _OwnerTestHiredDriverCheckboxState();
}

class _OwnerTestHiredDriverCheckboxState
    extends State<OwnerTestHiredDriverCheckbox> {
  bool _localBusy = false;

  Future<void> _handleCheckboxChanged(
    BuildContext context,
    OmniDriverProvider provider,
    bool nextValue,
  ) async {
    if (_localBusy || provider.ownerTestBusy) return;

    final authorized = OwnerTestConfig.isAuthorizedOwner(
      provider.driver,
      backendVerifiedOwner: provider.backendVerifiedOwner,
      backendOwnerEmail: provider.backend.ownerEmail,
      emailOverride: widget.ownerEmailOverride,
    );
    if (!authorized) return;

    setState(() => _localBusy = true);
    try {
      if (widget.onToggleHiredDriver != null) {
        await widget.onToggleHiredDriver!(nextValue);
      } else {
        await provider.setOwnerSimulatedHiredDriver(nextValue);
      }
    } finally {
      if (mounted) {
        setState(() => _localBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();

    final bool isAuthorized = OwnerTestConfig.isAuthorizedOwner(
      p.driver,
      backendVerifiedOwner: p.backendVerifiedOwner,
      backendOwnerEmail: p.backend.ownerEmail,
      emailOverride: widget.ownerEmailOverride,
    );
    if (!isAuthorized) {
      return const SizedBox.shrink();
    }

    final bool isActive =
        p.ownerTestHiredMode || (p.isDriverFullyApproved && p.driver.isOnline);
    final bool isBusy = _localBusy || p.ownerTestBusy;
    final Color accentColor =
        isActive ? OmniTheme.neonEmerald : OmniTheme.amber400;

    return Container(
      margin: EdgeInsets.only(top: widget.compact ? 8 : 10),
      padding: EdgeInsets.all(widget.compact ? 10 : 12),
      decoration: BoxDecoration(
        color: OmniTheme.alpha(accentColor, 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: OmniTheme.alpha(accentColor, isActive ? 0.65 : 0.42),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.admin_panel_settings_rounded,
                size: 15,
                color: accentColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  p.backendVerifiedOwner
                      ? 'MODO DONO LIBERADO (${(p.driver.email ?? OwnerTestConfig.primaryOwnerEmail).toLowerCase()})'
                      : 'MODO DONO • TESTE REAL COM PASSAGEIRO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    color: accentColor,
                  ),
                ),
              ),
              if (isBusy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: OmniTheme.neonCyan,
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: OmniTheme.alpha(accentColor, 0.16),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    isActive ? 'APTO & ONLINE' : 'INATIVO',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: accentColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Theme(
            data: Theme.of(context).copyWith(
              checkboxTheme: CheckboxThemeData(
                fillColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return OmniTheme.neonEmerald;
                  }
                  return OmniTheme.slate800;
                }),
                checkColor: WidgetStateProperty.all(const Color(0xFF05080F)),
                side: BorderSide(color: accentColor, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            child: CheckboxListTile(
              value: isActive,
              onChanged: isBusy
                  ? null
                  : (val) => _handleCheckboxChanged(context, p, val == true),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Simular motorista já contratado e aprovado',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              subtitle: Text(
                isActive
                    ? 'Onboarding 100% liberado • Veículo ${p.activeVehicle.plate} aprovado • Escutando solicitações reais do App Passageiro (ID: ${p.driver.id}).'
                    : 'Marca documentos, biometria, triagem e veículo como aprovados em segundo plano (MySQL/PHP + RTDB) e ativa o modo ONLINE.',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: OmniTheme.slate300,
                  height: 1.35,
                ),
              ),
            ),
          ),
          if (isActive && !widget.compact) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  p.setActiveTab(MainTab.map);
                  p.refreshPassengerDispatchQueueNow();
                },
                icon: const Icon(
                  Icons.notifications_active_rounded,
                  size: 15,
                  color: OmniTheme.neonCyan,
                ),
                label: const Text(
                  'Verificar Chamadas Reais do Passageiro (RTDB)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: OmniTheme.neonCyan,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: OmniTheme.alpha(OmniTheme.neonCyan, 0.45),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
