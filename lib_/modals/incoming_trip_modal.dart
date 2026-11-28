import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/omni_theme.dart';
import '../providers/omni_driver_provider.dart';

/// Modal de Despacho de Corrida / Entrega com Contagem Regressiva de 15s — 1:1 com IncomingTripModal.tsx
class IncomingTripModal extends StatelessWidget {
  const IncomingTripModal({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();
    final trip = p.incomingTrip;
    if (trip == null) return const SizedBox.shrink();

    final isDelivery = trip.type == 'DELIVERY';
    final progress = (p.dispatchCountdown / 15.0).clamp(0.0, 1.0);

    return Material(
      color: OmniTheme.alpha(Colors.black, 0.78),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            child: Container(
              decoration: OmniTheme.neonCardDecoration(
                color: OmniTheme.slate950,
                active: true,
                radius: 26,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cabeçalho com Anel Regressivo
                          Row(
                            children: [
                              OmniPillBadge(
                                text: isDelivery
                                    ? 'ENTREGA FLASH'
                                    : 'CHAMADA OMNI • ${trip.surgeMultiplier}x',
                                color: isDelivery
                                    ? OmniTheme.amber400
                                    : OmniTheme.neonCyan,
                              ),
                              const Spacer(),
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 42,
                                    height: 42,
                                    child: CircularProgressIndicator(
                                      value: progress,
                                      strokeWidth: 4,
                                      backgroundColor: OmniTheme.slate800,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                              OmniTheme.neonCyan),
                                    ),
                                  ),
                                  Text(
                                    '${p.dispatchCountdown}s',
                                    style: OmniTheme.monoStyle(
                                      fontSize: 12,
                                      color: OmniTheme.neonCyan,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Valor Líquido em Destaque
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  OmniTheme.alpha(OmniTheme.neonEmerald, 0.16),
                                  OmniTheme.slate900,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                  color: OmniTheme.alpha(
                                      OmniTheme.neonEmerald, 0.4)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'GANHO LÍQUIDO MOTORISTA',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: OmniTheme.slate400,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'R\$ ${trip.driverNetEarnings.toStringAsFixed(2)}',
                                      style: OmniTheme.monoStyle(
                                        fontSize: 26,
                                        color: OmniTheme.neonEmerald,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${trip.distanceKm.toStringAsFixed(1)} km',
                                      style: OmniTheme.monoStyle(
                                        fontSize: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      '~${trip.estimatedMinutes} min • ${trip.paymentMethod.code}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: OmniTheme.slate400,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Origem e Destino
                          _RoutePointRow(
                            dotColor: OmniTheme.neonCyan,
                            label: 'EMBARQUE / COLETA',
                            address: trip.origin.address,
                          ),
                          const SizedBox(height: 8),
                          _RoutePointRow(
                            dotColor: OmniTheme.neonRose,
                            label: 'DESTINO FINAL',
                            address: trip.destination.address,
                          ),
                          const SizedBox(height: 12),

                          // Passageiro
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: OmniTheme.slate800,
                                backgroundImage: trip.passenger.avatarUrl
                                        .startsWith('http')
                                    ? NetworkImage(trip.passenger.avatarUrl)
                                    : null,
                                child: trip.passenger.avatarUrl
                                        .startsWith('http')
                                    ? null
                                    : const Icon(
                                        Icons.person_rounded,
                                        size: 18,
                                        color: OmniTheme.slate400,
                                      ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${trip.passenger.name} • ★ ${trip.passenger.rating.toStringAsFixed(2)} (${trip.passenger.totalTrips} viagens)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: OmniTheme.slate300,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Rodapé fixo de Aceite / Recusa
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: p.declineIncomingTrip,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: OmniTheme.rose500,
                              side: BorderSide(
                                  color: OmniTheme.alpha(
                                      OmniTheme.rose500, 0.55)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text(
                              'Recusar',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: p.acceptIncomingTrip,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: OmniTheme.neonCyan,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              isDelivery ? 'ACEITAR ENTREGA' : 'ACEITAR CORRIDA',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
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

class _RoutePointRow extends StatelessWidget {
  final Color dotColor;
  final String label;
  final String address;

  const _RoutePointRow({
    required this.dotColor,
    required this.label,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: OmniTheme.slate900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OmniTheme.slate800),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: OmniTheme.slate400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  address,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
