import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/omni_theme.dart';
import '../models/omni_models.dart';
import '../providers/omni_driver_provider.dart';
import '../widgets/backend_domain_config_card.dart';
import 'driver_avatar.dart';

/// Barra Superior Executiva OMNI Motorista — 1:1 com src/components/Navbar.tsx
class OmniNavbar extends StatelessWidget {
  const OmniNavbar({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();
    final driver = p.driver;
    final score = p.onboardingScore;
    final approved = p.isDriverFullyApproved;
    final pendingCount = p.onboardingStatus.pendingSteps.length;

    return Container(
      decoration: BoxDecoration(
        color: OmniTheme.alpha(OmniTheme.bgDark, 0.96),
        border: Border(
          bottom: BorderSide(color: OmniTheme.alpha(OmniTheme.slate800, 0.9)),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Linha principal do header com rolagem horizontal segura nas ações em telas estreitas
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Logo OMNI
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [OmniTheme.neonCyan, OmniTheme.neonTeal],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: OmniTheme.alpha(OmniTheme.neonCyan, 0.4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Ω',
                      style: TextStyle(
                        color: Color(0xFF05080F),
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                            color: Colors.white,
                          ),
                          children: [
                            TextSpan(text: 'OMNI '),
                            TextSpan(
                              text: 'MOTORISTA',
                              style: TextStyle(color: OmniTheme.neonCyan),
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        'EXECUÇÃO • NEON',
                        style: TextStyle(
                          fontSize: 9,
                          color: OmniTheme.slate400,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),

                  // Ações da barra direita em SingleChildScrollView horizontal (zero overflow!)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Botão Online / Gatekeeper
                            InkWell(
                              borderRadius: BorderRadius.circular(99),
                              onTap: () => p.toggleOnlineStatus(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(99),
                                  color: !approved
                                      ? OmniTheme.alpha(
                                          OmniTheme.amber400, 0.14)
                                      : driver.isOnline
                                          ? OmniTheme.alpha(
                                              OmniTheme.neonEmerald, 0.18)
                                          : OmniTheme.slate900,
                                  border: Border.all(
                                    color: !approved
                                        ? OmniTheme.alpha(
                                            OmniTheme.amber400, 0.65)
                                        : driver.isOnline
                                            ? OmniTheme.neonEmerald
                                            : OmniTheme.slate700,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      !approved
                                          ? Icons.lock_rounded
                                          : Icons.power_settings_new_rounded,
                                      size: 13,
                                      color: !approved
                                          ? OmniTheme.amber400
                                          : driver.isOnline
                                              ? OmniTheme.neonEmerald
                                              : OmniTheme.slate300,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      !approved
                                          ? '$score% Aprovado'
                                          : driver.isOnline
                                              ? 'ONLINE'
                                              : 'FICAR ONLINE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: !approved
                                            ? OmniTheme.amber400
                                            : driver.isOnline
                                                ? OmniTheme.neonEmerald
                                                : OmniTheme.slate300,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Saldo rápido (Carteira)
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => p.setActiveTab(MainTab.wallet),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: OmniTheme.slate900,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: OmniTheme.slate800),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.account_balance_wallet_rounded,
                                      size: 13,
                                      color: OmniTheme.neonCyan,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'R\$ ${driver.walletBalance.toStringAsFixed(2)}',
                                      style: OmniTheme.monoStyle(
                                        fontSize: 11,
                                        color: OmniTheme.neonCyan,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Configurar Domínio / Servidor Backend
                            _IconActionPill(
                              icon: Icons.public_rounded,
                              color: p.hasCustomBackendDomain
                                  ? OmniTheme.neonCyan
                                  : OmniTheme.slate300,
                              onTap: () => showBackendDomainDialog(context),
                            ),
                            const SizedBox(width: 5),

                            // Simulador 14 cenários
                            _IconActionPill(
                              icon: Icons.science_rounded,
                              color: p.activeTab == MainTab.simulator
                                  ? OmniTheme.neonCyan
                                  : OmniTheme.slate300,
                              onTap: () => p.setActiveTab(MainTab.simulator),
                            ),
                            const SizedBox(width: 5),

                            // Som / Mudo
                            _IconActionPill(
                              icon: p.muted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              color: p.muted
                                  ? OmniTheme.rose500
                                  : OmniTheme.slate300,
                              onTap: () => p.toggleMute(),
                            ),
                            const SizedBox(width: 5),

                            // Biometria Facial
                            _IconActionPill(
                              icon: Icons.face_retouching_natural,
                              color: driver.isBiometricVerified
                                  ? OmniTheme.neonEmerald
                                  : OmniTheme.amber400,
                              onTap: () => p.setBiometricModalOpen(true),
                            ),
                            const SizedBox(width: 6),

                            // Avatar real do motorista (atalho perfil)
                            InkWell(
                              borderRadius: BorderRadius.circular(99),
                              onTap: () => p.setActiveTab(MainTab.profile),
                              child: DriverAvatar(
                                driver: driver,
                                radius: 14,
                                borderColor: driver.isBiometricVerified
                                    ? OmniTheme.neonEmerald
                                    : OmniTheme.neonCyan,
                                borderWidth: 1.6,
                              ),
                            ),
                            const SizedBox(width: 6),

                            // SOS Emergência
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => p.setSafetyModalOpen(true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: OmniTheme.alpha(
                                      OmniTheme.neonRose, 0.16),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: OmniTheme.alpha(
                                        OmniTheme.neonRose, 0.65),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.shield_rounded,
                                        size: 13, color: OmniTheme.neonRose),
                                    SizedBox(width: 3),
                                    Text(
                                      'SOS',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: OmniTheme.neonRose,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Faixa Gatekeeper (sempre visível até 100%)
            if (!approved)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: OmniTheme.alpha(OmniTheme.amber400, 0.10),
                  border: Border(
                    top: BorderSide(
                        color: OmniTheme.alpha(OmniTheme.amber400, 0.25)),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 14, color: OmniTheme.amber400),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Modo Auditoria: $score% concluído ($pendingCount pendência(s)). Conclua para ficar ONLINE.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: OmniTheme.amber400,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        final next = p.onboardingStatus.nextRecommendedStep;
                        if (next != null) {
                          p.navigateToOnboardingAction(next.action);
                        } else {
                          p.setActiveTab(MainTab.profile);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: OmniTheme.amber400,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Resolver',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF05080F),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IconActionPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconActionPill({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6.5),
        decoration: BoxDecoration(
          color: OmniTheme.slate900,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: OmniTheme.slate800),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}
