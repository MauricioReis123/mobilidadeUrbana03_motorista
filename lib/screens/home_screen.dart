import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/omni_theme.dart';
import '../modals/biometric_verification_modal.dart';
import '../modals/chat_drawer.dart';
import '../modals/document_capture_modal.dart';
import '../modals/incoming_trip_modal.dart';
import '../modals/onboarding_stepper_modal.dart';
import '../modals/safety_emergency_modal.dart';
import '../models/omni_models.dart';
import '../providers/omni_driver_provider.dart';
import '../widgets/omni_bottom_nav.dart';
import '../widgets/omni_navbar.dart';
import 'clube_loyalty_view.dart';
import 'ecosystem_simulator_view.dart';
import 'map_cockpit_view.dart';
import 'private_trips_view.dart';
import 'profile_documents_view.dart';
import 'wallet_view.dart';

/// Shell Principal OMNI Motorista — 1:1 com src/App.tsx
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();

    Widget currentBody;
    switch (p.activeTab) {
      case MainTab.map:
        currentBody = const MapCockpitView();
        break;
      case MainTab.privateTrips:
        currentBody = const PrivateTripsView();
        break;
      case MainTab.wallet:
        currentBody = const WalletView();
        break;
      case MainTab.clube:
        currentBody = const ClubeLoyaltyView();
        break;
      case MainTab.profile:
        currentBody = const ProfileDocumentsView();
        break;
      case MainTab.simulator:
        currentBody = const EcosystemSimulatorView();
        break;
    }

    return Scaffold(
      backgroundColor: OmniTheme.bgDark,
      body: Stack(
        children: [
          Column(
            children: [
              const OmniNavbar(),
              Expanded(child: currentBody),
              const OmniBottomNav(),
            ],
          ),

          // Notificações / Smart Alerts flutuantes no topo
          if (p.alerts.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 64,
              left: 12,
              right: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: p.alerts.take(2).map((alert) {
                  final color = alert.severity == 'danger'
                      ? OmniTheme.neonRose
                      : alert.severity == 'warning'
                          ? OmniTheme.amber400
                          : alert.severity == 'success'
                              ? OmniTheme.neonEmerald
                              : OmniTheme.neonCyan;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: OmniTheme.alpha(OmniTheme.slate950, 0.96),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: OmniTheme.alpha(color, 0.7)),
                      boxShadow: [
                        BoxShadow(
                          color: OmniTheme.alpha(Colors.black, 0.65),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.notifications_active_rounded,
                            size: 18, color: color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alert.title,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                              Text(
                                alert.message,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => p.dismissAlert(alert.id),
                          icon: const Icon(Icons.close_rounded,
                              size: 16, color: OmniTheme.slate400),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          // Overlays Modais Globais
          const IncomingTripModal(),
          const SafetyEmergencyModal(),
          const ChatDrawerModal(),
          if (p.stepperModalOpen) const OnboardingStepperModal(),
          if (p.documentCaptureDocId != null) const DocumentCaptureModal(),
          if (p.biometricModalOpen) const BiometricVerificationModal(),
        ],
      ),
    );
  }
}
