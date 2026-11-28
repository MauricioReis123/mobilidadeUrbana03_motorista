import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/omni_theme.dart';
import '../models/omni_models.dart';
import '../providers/omni_driver_provider.dart';

/// Barra de Navegação Inferior 6 Abas OMNI — 1:1 com BottomNav.tsx
class OmniBottomNav extends StatelessWidget {
  const OmniBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();
    final activeTab = p.activeTab;

    final items = [
      (tab: MainTab.map, label: 'Mapa', icon: Icons.map_rounded, badge: null as String?),
      (
        tab: MainTab.privateTrips,
        label: 'Particulares',
        icon: Icons.flight_takeoff_rounded,
        badge: p.privateOffers.where((o) => o.status == 'OPEN').length.toString()
      ),
      (tab: MainTab.wallet, label: 'Carteira', icon: Icons.account_balance_wallet_rounded, badge: null),
      (tab: MainTab.clube, label: 'Clube', icon: Icons.workspace_premium_rounded, badge: null),
      (
        tab: MainTab.profile,
        label: 'Perfil',
        icon: Icons.person_rounded,
        badge: !p.isDriverFullyApproved ? '${p.onboardingScore}%' : null
      ),
      (tab: MainTab.simulator, label: 'Cenários', icon: Icons.science_rounded, badge: '14'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: OmniTheme.alpha(OmniTheme.slate950, 0.97),
        border: Border(
          top: BorderSide(color: OmniTheme.alpha(OmniTheme.slate800, 0.95)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: items.map((item) {
              final selected = activeTab == item.tab;
              return Expanded(
                child: InkWell(
                  onTap: () => p.setActiveTab(item.tab),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: selected
                                  ? OmniTheme.alpha(OmniTheme.neonCyan, 0.14)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              item.icon,
                              size: 20,
                              color: selected
                                  ? OmniTheme.neonCyan
                                  : OmniTheme.slate400,
                            ),
                          ),
                          if (item.badge != null)
                            Positioned(
                              top: -4,
                              right: -6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: item.tab == MainTab.profile
                                      ? OmniTheme.amber400
                                      : OmniTheme.neonCyan,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.badge!,
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF05080F),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected
                              ? OmniTheme.neonCyan
                              : OmniTheme.slate400,
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
    );
  }
}
