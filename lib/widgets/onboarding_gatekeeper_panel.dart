import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/omni_theme.dart';
import '../providers/omni_driver_provider.dart';
import '../utils/driver_onboarding.dart';

/// Painel Visual do Portão de Segurança (Gatekeeper 0%–100%)
/// 1:1 com src/components/OnboardingGatekeeperPanel.tsx (modos compact e home)
class OnboardingGatekeeperPanel extends StatelessWidget {
  final bool compact;

  const OnboardingGatekeeperPanel({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();
    final status = p.onboardingStatus;
    final score = status.onboardingScore;
    final approved = status.isDriverFullyApproved;

    final accentColor = approved ? OmniTheme.neonEmerald : OmniTheme.amber400;

    return Container(
      decoration: BoxDecoration(
        color: OmniTheme.alpha(OmniTheme.slate950, 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OmniTheme.alpha(accentColor, 0.45)),
        boxShadow: [
          BoxShadow(
            color: OmniTheme.alpha(Colors.black, 0.65),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(compact ? 14 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cabeçalho + Score Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: OmniTheme.alpha(accentColor, 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: OmniTheme.alpha(accentColor, 0.35)),
                ),
                child: Icon(
                  approved ? Icons.verified_user_rounded : Icons.lock_rounded,
                  size: 18,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.gatekeeperHeadline,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status.gatekeeperSubtext,
                      style: const TextStyle(
                        fontSize: 11,
                        color: OmniTheme.slate400,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$score%',
                    style: OmniTheme.monoStyle(
                      fontSize: 18,
                      color: accentColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${status.completedStepsCount}/${status.totalStepsCount}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: OmniTheme.slate400,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Barra de Progresso
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: score / 100.0,
              minHeight: 7,
              backgroundColor: OmniTheme.slate800,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: 10),

          // 4 Pilares em Grid 2x2 responsivo
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: status.pillars.map((pillar) {
              final ok = pillar.isComplete;
              final pColor = ok ? OmniTheme.neonEmerald : OmniTheme.amber400;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: OmniTheme.slate900,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: ok
                        ? OmniTheme.alpha(OmniTheme.neonEmerald, 0.35)
                        : OmniTheme.slate800,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      ok ? Icons.check_circle_rounded : Icons.schedule_rounded,
                      size: 12,
                      color: pColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${pillar.label} (${pillar.completedCount}/${pillar.totalCount})',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: ok ? OmniTheme.neonEmerald : OmniTheme.slate300,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          if (!approved) ...[
            const SizedBox(height: 10),
            Container(
              constraints: BoxConstraints(maxHeight: compact ? 150 : 190),
              child: SingleChildScrollView(
                child: Column(
                  children: status.pendingSteps.map((step) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => p.navigateToOnboardingAction(step.action),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: OmniTheme.slate900,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: OmniTheme.slate800),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.radio_button_unchecked_rounded,
                                size: 15, color: OmniTheme.amber400),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    step.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    step.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: OmniTheme.slate400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: OmniTheme.alpha(OmniTheme.neonCyan, 0.14),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: OmniTheme.alpha(
                                        OmniTheme.neonCyan, 0.35)),
                              ),
                              child: const Text(
                                'Completar',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: OmniTheme.neonCyan,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => p.openStepperModal(),
                icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                label: const Text(
                  'Iniciar Assistente Passo a Passo (12 Etapas)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OmniTheme.neonCyan,
                  foregroundColor: const Color(0xFF05080F),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
            ),
            if (status.nextRecommendedStep != null) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => p.navigateToOnboardingAction(
                    status.nextRecommendedStep!.action,
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                  label: Text(
                    'Atalho Direto: ${status.nextRecommendedStep!.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OmniTheme.amber400,
                    side: BorderSide(
                      color: OmniTheme.alpha(OmniTheme.amber400, 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
