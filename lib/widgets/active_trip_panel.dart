import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/omni_theme.dart';
import '../models/omni_models.dart';
import '../providers/omni_driver_provider.dart';

/// Cockpit Inferior de Corrida / Entrega Ativa — 1:1 com ActiveTripPanel.tsx
class ActiveTripPanel extends StatefulWidget {
  const ActiveTripPanel({super.key});

  @override
  State<ActiveTripPanel> createState() => _ActiveTripPanelState();
}

class _ActiveTripPanelState extends State<ActiveTripPanel> {
  final TextEditingController _pinController = TextEditingController();
  int _selectedStars = 5;
  bool _verifying = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  String _phaseLabel(TripStatus status, bool isDelivery) {
    switch (status) {
      case TripStatus.driverEnRoute:
        return isDelivery
            ? 'A CAMINHO DA COLETA'
            : 'A CAMINHO DO PASSAGEIRO';
      case TripStatus.driverArrived:
        return isDelivery
            ? 'CHEGOU NA COLETA • PIN'
            : 'CHEGOU AO EMBARQUE • PIN';
      case TripStatus.boardingConfirmed:
        return isDelivery ? 'PACOTE COLETADO' : 'EMBARQUE CONFIRMADO';
      case TripStatus.tripInProgress:
        return isDelivery ? 'EM ROTA DE ENTREGA' : 'VIAGEM EM ANDAMENTO';
      case TripStatus.completed:
        return 'FINALIZADA COM SUCESSO';
      default:
        return 'EM OPERAÇÃO';
    }
  }

  Future<void> _openExternalMaps(OmniCoordinate coords) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${coords.latitude},${coords.longitude}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();
    final trip = p.activeTrip;
    if (trip == null) return const SizedBox.shrink();

    final isDelivery = trip.type == 'DELIVERY';
    final status = trip.status;

    return Container(
      decoration: BoxDecoration(
        color: OmniTheme.alpha(OmniTheme.slate950, 0.97),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: OmniTheme.alpha(
            status == TripStatus.completed
                ? OmniTheme.neonEmerald
                : OmniTheme.neonCyan,
            0.55,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: OmniTheme.alpha(Colors.black, 0.78),
            blurRadius: 28,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho da Corrida
          Row(
            children: [
              OmniPillBadge(
                text: _phaseLabel(status, isDelivery),
                color: status == TripStatus.completed
                    ? OmniTheme.neonEmerald
                    : status == TripStatus.driverArrived
                        ? OmniTheme.amber400
                        : OmniTheme.neonCyan,
              ),
              const Spacer(),
              Text(
                'R\$ ${trip.driverNetEarnings.toStringAsFixed(2)}',
                style: OmniTheme.monoStyle(
                  fontSize: 16,
                  color: OmniTheme.neonEmerald,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Dados do Passageiro + Botões Chat / GPS
          Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: OmniTheme.slate800,
                backgroundImage: NetworkImage(trip.passenger.avatarUrl),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.passenger.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 13, color: OmniTheme.amber400),
                        const SizedBox(width: 3),
                        Text(
                          '${trip.passenger.rating.toStringAsFixed(2)} • ${trip.passenger.phoneMasked}',
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
              IconButton(
                onPressed: () => p.setChatOpen(true),
                tooltip: 'Chat Seguro',
                style: IconButton.styleFrom(
                  backgroundColor: OmniTheme.slate900,
                  side: const BorderSide(color: OmniTheme.slate700),
                ),
                icon: const Icon(Icons.chat_bubble_rounded,
                    size: 18, color: OmniTheme.neonCyan),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: () => _openExternalMaps(
                  status == TripStatus.tripInProgress
                      ? trip.destination.coords
                      : trip.origin.coords,
                ),
                tooltip: 'Abrir GPS Externo',
                style: IconButton.styleFrom(
                  backgroundColor: OmniTheme.slate900,
                  side: const BorderSide(color: OmniTheme.slate700),
                ),
                icon: const Icon(Icons.navigation_rounded,
                    size: 18, color: OmniTheme.sky400),
              ),
            ],
          ),

          if (trip.deliveryDetails != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: OmniTheme.alpha(OmniTheme.amber400, 0.10),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: OmniTheme.alpha(OmniTheme.amber400, 0.3)),
              ),
              child: Text(
                'Pacote: ${trip.deliveryDetails!.packageType} (${trip.deliveryDetails!.weightKg}kg) • Destinatário: ${trip.deliveryDetails!.recipientName}',
                style: const TextStyle(
                  fontSize: 11,
                  color: OmniTheme.amber400,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Endereço atual (Embarque ou Destino)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: OmniTheme.slate900,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: OmniTheme.slate800),
            ),
            child: Row(
              children: [
                Icon(
                  status == TripStatus.tripInProgress
                      ? Icons.flag_rounded
                      : Icons.place_rounded,
                  size: 16,
                  color: status == TripStatus.tripInProgress
                      ? OmniTheme.neonRose
                      : OmniTheme.neonCyan,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status == TripStatus.tripInProgress
                        ? trip.destination.address
                        : trip.origin.address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: OmniTheme.slate200,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Controles por Status
          if (status == TripStatus.driverEnRoute)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: p.arriveAtPickup,
                icon: const Icon(Icons.location_on_rounded, size: 18),
                label: Text(isDelivery
                    ? 'CHEGUEI NA COLETA'
                    : 'CHEGUEI AO EMBARQUE'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            )
          else if (status == TripStatus.driverArrived)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Código PIN de Segurança (Demo: 4829)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: OmniTheme.amber400,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        style: OmniTheme.monoStyle(
                            fontSize: 16, color: OmniTheme.neonCyan),
                        decoration: const InputDecoration(
                          hintText: '4829',
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _verifying
                          ? null
                          : () async {
                              setState(() => _verifying = true);
                              await p.verifyOtpAndBoard(_pinController.text);
                              if (mounted) setState(() => _verifying = false);
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                      ),
                      child: _verifying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Validar PIN'),
                    ),
                  ],
                ),
              ],
            )
          else if (status == TripStatus.boardingConfirmed)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: p.startTripToDestination,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(isDelivery
                    ? 'INICIAR ROTA DE ENTREGA'
                    : 'INICIAR VIAGEM'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OmniTheme.neonEmerald,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            )
          else if (status == TripStatus.tripInProgress)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => p.completeCurrentTrip(5),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(isDelivery
                    ? 'CONFIRMAR ENTREGA FINALIZADA'
                    : 'FINALIZAR CORRIDA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OmniTheme.neonEmerald,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            )
          else if (status == TripStatus.completed)
            Column(
              children: [
                const Text(
                  'Avalie o Passageiro / Cliente:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: OmniTheme.slate300,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final star = index + 1;
                    return IconButton(
                      onPressed: () => setState(() => _selectedStars = star),
                      icon: Icon(
                        Icons.star_rounded,
                        size: 28,
                        color: star <= _selectedStars
                            ? OmniTheme.amber400
                            : OmniTheme.slate700,
                      ),
                    );
                  }),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: p.finishRatingAndCloseTrip,
                    child: const Text('Concluir & Receber na Carteira'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
