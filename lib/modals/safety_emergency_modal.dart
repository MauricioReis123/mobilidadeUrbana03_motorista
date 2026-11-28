import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/omni_theme.dart';
import '../providers/omni_driver_provider.dart';

/// Modal de Segurança e Emergência 190 / Central OMNI 24h — 1:1 com SafetyEmergencyModal.tsx
class SafetyEmergencyModal extends StatefulWidget {
  const SafetyEmergencyModal({super.key});

  @override
  State<SafetyEmergencyModal> createState() => _SafetyEmergencyModalState();
}

class _SafetyEmergencyModalState extends State<SafetyEmergencyModal> {
  final TextEditingController _incidentController = TextEditingController();
  bool _sharedLink = false;

  @override
  void dispose() {
    _incidentController.dispose();
    super.dispose();
  }

  Future<void> _callPolice() async {
    final uri = Uri.parse('tel:190');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();
    if (!p.safetyModalOpen) return const SizedBox.shrink();

    return Material(
      color: OmniTheme.alpha(Colors.black, 0.82),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 440,
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: OmniTheme.slate950,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: OmniTheme.alpha(OmniTheme.neonRose, 0.55)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: OmniTheme.alpha(
                                      OmniTheme.neonRose, 0.16),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.shield_rounded,
                                    color: OmniTheme.neonRose, size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Central de Segurança OMNI',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => p.setSafetyModalOpen(false),
                                icon: const Icon(Icons.close_rounded,
                                    color: OmniTheme.slate400),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Acionar Polícia 190
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                p.triggerEmergencySos(
                                  incidentNote:
                                      'Acionamento direto Polícia Militar (190)',
                                );
                                _callPolice();
                              },
                              icon: const Icon(Icons.call_rounded, size: 18),
                              label: const Text('LIGAR POLÍCIA MILITAR (190)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: OmniTheme.neonRose,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Compartilhar Rota
                          OutlinedButton.icon(
                            onPressed: () async {
                              final loc = p.driverLocation;
                              final tripParam = p.activeTrip != null
                                  ? '&trip=${p.activeTrip!.tripId}'
                                  : '';
                              final url =
                                  'https://omni.app/track?lat=${loc.latitude.toStringAsFixed(5)}&lng=${loc.longitude.toStringAsFixed(5)}$tripParam';
                              await Clipboard.setData(ClipboardData(text: url));
                              setState(() => _sharedLink = true);
                              p.addAlert(
                                'Link de Rota Copiado',
                                'Envie o link de telemetria em tempo real para seu contato de emergência.',
                                'success',
                              );
                            },
                            icon: Icon(
                              _sharedLink
                                  ? Icons.check_circle_rounded
                                  : Icons.share_location_rounded,
                              size: 18,
                              color: OmniTheme.neonCyan,
                            ),
                            label: Text(
                              _sharedLink
                                  ? 'Link GPS Copiado!'
                                  : 'Compartilhar Localização em Tempo Real',
                              style:
                                  const TextStyle(color: OmniTheme.neonCyan),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 46),
                              side: BorderSide(
                                  color: OmniTheme.alpha(
                                      OmniTheme.neonCyan, 0.45)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                          const SizedBox(height: 14),

                          const Text(
                            'Relatar Ocorrência para Central 24h',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: OmniTheme.slate300,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _incidentController,
                            maxLines: 3,
                            style: const TextStyle(fontSize: 12),
                            decoration: const InputDecoration(
                              hintText:
                                  'Descreva rapidamente o ocorrido para auditoria...',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              p.triggerEmergencySos(
                                incidentNote: _incidentController.text.trim(),
                              );
                              _incidentController.clear();
                              p.setSafetyModalOpen(false);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: OmniTheme.slate800,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: const Text('Enviar Protocolo para Equipe 24h'),
                          ),
                        ),
                        if (p.isSosActive) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () {
                                p.resolveEmergencySos();
                                p.setSafetyModalOpen(false);
                              },
                              child: const Text(
                                'Encerrar Alerta SOS Ativo',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: OmniTheme.neonEmerald,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
