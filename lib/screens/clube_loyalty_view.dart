import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/omni_theme.dart';
import '../providers/omni_driver_provider.dart';

/// Clube OMNI & Indique e Ganhe — 1:1 com ClubeLoyaltyView.tsx
class ClubeLoyaltyView extends StatelessWidget {
  const ClubeLoyaltyView({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();
    final driver = p.driver;

    const tiers = [
      (name: 'INICIAL', trips: '0+ corridas', perk: 'Taxa padrão • Suporte 24h'),
      (name: 'PRATA', trips: '300+ corridas', perk: '-1% Taxa OMNI • Desconto IPVA'),
      (name: 'OURO', trips: '1.000+ corridas', perk: '-2% Taxa • Desconto Combustível'),
      (name: 'PLATINA', trips: '2.500+ corridas', perk: 'Prioridade Aeroporto + Seguro'),
      (name: 'ELITE', trips: '5.000+ corridas', perk: 'Taxa Mínima + Revisão VIP'),
    ];

    const partners = [
      (name: 'Shell Box Pro', benefit: 'R\$ 0,35/L desconto em gasolina e etanol'),
      (name: 'Localiza Zarp', benefit: '12% OFF na locação semanal para app'),
      (name: 'PneuStore Frota', benefit: 'Parcelamento 12x + alinhamento grátis'),
    ];

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Card Nível Atual
        Container(
          padding: const EdgeInsets.all(18),
          decoration: OmniTheme.neonCardDecoration(
            borderColor: OmniTheme.alpha(OmniTheme.amber400, 0.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: OmniTheme.alpha(OmniTheme.amber400, 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: OmniTheme.amber400, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CLUBE OMNI • NÍVEL ${driver.clubTier}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: OmniTheme.amber400,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${driver.totalTrips} viagens concluídas • Taxa de aceitação ${driver.acceptanceRate}%',
                      style: const TextStyle(
                          fontSize: 11.5, color: OmniTheme.slate300),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Indique e Ganhe R$ 150
        Container(
          padding: const EdgeInsets.all(16),
          decoration: OmniTheme.neonCardDecoration(active: true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OmniPillBadge(
                text: 'INDIQUE E GANHE R\$ 150 POR MOTORISTA',
                color: OmniTheme.neonCyan,
                icon: Icons.card_giftcard_rounded,
              ),
              const SizedBox(height: 10),
              const Text(
                'Compartilhe seu código exclusivo. Quando o novo motorista completar 20 corridas, você recebe R\$ 150 direto no OMNI Pay.',
                style: TextStyle(fontSize: 12, color: OmniTheme.slate300),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: OmniTheme.slate950,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: OmniTheme.alpha(OmniTheme.neonCyan, 0.45)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        driver.referralCode,
                        style: OmniTheme.monoStyle(
                          fontSize: 16,
                          color: OmniTheme.neonCyan,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: driver.referralCode));
                        p.addAlert(
                          'Código Copiado!',
                          'Compartilhe ${driver.referralCode} com outros motoristas.',
                          'success',
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 15),
                      label: const Text('Copiar'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _StatPill(
                        label: 'Indicados Ativos',
                        value: '${driver.referralsCount}'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatPill(
                      label: 'Bônus Acumulado',
                      value: 'R\$ ${driver.referralEarnings.toStringAsFixed(0)}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text(
          'Escada de Benefícios OMNI',
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        const SizedBox(height: 8),

        ...tiers.map((t) {
          final isCurrent = t.name == driver.clubTier;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCurrent
                  ? OmniTheme.alpha(OmniTheme.amber400, 0.12)
                  : OmniTheme.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isCurrent ? OmniTheme.amber400 : OmniTheme.slate800,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isCurrent
                      ? Icons.star_rounded
                      : Icons.workspace_premium_outlined,
                  color: isCurrent ? OmniTheme.amber400 : OmniTheme.slate500,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${t.name} (${t.trips})',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: isCurrent ? OmniTheme.amber400 : Colors.white,
                        ),
                      ),
                      Text(
                        t.perk,
                        style: const TextStyle(
                            fontSize: 11, color: OmniTheme.slate400),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 12),
        const Text(
          'Parceiros Regionais Exclusivos',
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        const SizedBox(height: 8),
        ...partners.map((partner) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: OmniTheme.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: OmniTheme.slate800),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_offer_rounded,
                    size: 18, color: OmniTheme.neonCyan),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        partner.name,
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                      Text(
                        partner.benefit,
                        style: const TextStyle(
                            fontSize: 11, color: OmniTheme.slate400),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;

  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: OmniTheme.slate900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OmniTheme.slate800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: OmniTheme.slate400)),
          const SizedBox(height: 2),
          Text(
            value,
            style: OmniTheme.monoStyle(
              fontSize: 14,
              color: OmniTheme.neonEmerald,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
