import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/omni_theme.dart';
import '../models/omni_models.dart';
import '../providers/omni_driver_provider.dart';
import '../utils/vehicle_catalog.dart';

/// Marketplace de Viagens Particulares & Traslados — 1:1 com PrivateTripsView.tsx
class PrivateTripsView extends StatefulWidget {
  const PrivateTripsView({super.key});

  @override
  State<PrivateTripsView> createState() => _PrivateTripsViewState();
}

class _PrivateTripsViewState extends State<PrivateTripsView> {
  String _filter = 'ALL'; // 'ALL' | 'AIRPORT' | 'INTERCITY'

  void _openBidDialog(
    BuildContext context,
    OmniDriverProvider p,
    PrivateTripOffer offer,
  ) {
    if (!p.requireFullOnboardingGate('enviar propostas em viagens particulares')) {
      return;
    }
    final ctrl = TextEditingController(
      text: offer.suggestedPrice.toStringAsFixed(2),
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniTheme.slate950,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: OmniTheme.alpha(OmniTheme.neonCyan, 0.45)),
        ),
        title: const Text(
          'Enviar Proposta de Lance',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                offer.title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: OmniTheme.neonCyan,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${offer.origin} → ${offer.destination} (${offer.distanceKm.toStringAsFixed(1)} km)',
                style: const TextStyle(fontSize: 11.5, color: OmniTheme.slate400),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: OmniTheme.monoStyle(
                    fontSize: 18, color: OmniTheme.neonEmerald),
                decoration: const InputDecoration(
                  labelText: 'Valor da Sua Proposta (R\$)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar',
                style: TextStyle(color: OmniTheme.slate400)),
          ),
          ElevatedButton(
            onPressed: () {
              final val =
                  double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0;
              if (val > 0) {
                p.submitPrivateBid(offer.id, val);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Enviar Lance'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();
    final approved = p.isDriverFullyApproved;

    final filtered = p.privateOffers.where((o) {
      if (_filter == 'AIRPORT') {
        return o.title.toLowerCase().contains('aeroporto');
      }
      if (_filter == 'INTERCITY') {
        return o.title.toLowerCase().contains('intermunicipal');
      }
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Banner Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: OmniTheme.neonCardDecoration(),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OmniPillBadge(
                text: 'MARKETPLACE EXECUTIVO',
                color: OmniTheme.neonCyan,
                icon: Icons.flight_takeoff_rounded,
              ),
              SizedBox(height: 8),
              Text(
                'Viagens Particulares & Traslados',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Negocie diretamente corridas agendadas, transfers para aeroportos e fretes corporativos.',
                style: TextStyle(fontSize: 12, color: OmniTheme.slate400),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (!approved)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: OmniTheme.alpha(OmniTheme.amber400, 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: OmniTheme.alpha(OmniTheme.amber400, 0.45)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_rounded,
                    color: OmniTheme.amber400, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Envio de propostas bloqueado até completar 100% do cadastro (${p.onboardingScore}% concluído).',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: OmniTheme.amber400,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Filtros Horizontais
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChipPill(
                label: 'Todas (${p.privateOffers.length})',
                selected: _filter == 'ALL',
                onTap: () => setState(() => _filter = 'ALL'),
              ),
              const SizedBox(width: 8),
              _FilterChipPill(
                label: 'Transfer Aeroporto',
                selected: _filter == 'AIRPORT',
                onTap: () => setState(() => _filter = 'AIRPORT'),
              ),
              const SizedBox(width: 8),
              _FilterChipPill(
                label: 'Intermunicipal',
                selected: _filter == 'INTERCITY',
                onTap: () => setState(() => _filter = 'INTERCITY'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Cards de Ofertas
        ...filtered.map((offer) {
          final isSent = offer.status == 'BID_SENT';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: OmniTheme.neonCardDecoration(
              borderColor: isSent
                  ? OmniTheme.alpha(OmniTheme.neonEmerald, 0.55)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    OmniPillBadge(
                      text: formatVehicleCategoryLabel(offer.vehicleRequired),
                      color: OmniTheme.sky400,
                    ),
                    const SizedBox(width: 6),
                    OmniPillBadge(
                      text: offer.dateLabel,
                      color: OmniTheme.amber400,
                    ),
                    const Spacer(),
                    Text(
                      'R\$ ${(offer.driverBid ?? offer.suggestedPrice).toStringAsFixed(2)}',
                      style: OmniTheme.monoStyle(
                        fontSize: 16,
                        color: OmniTheme.neonEmerald,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  offer.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'De: ${offer.origin}\nPara: ${offer.destination}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: OmniTheme.slate300,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  offer.notes,
                  style: const TextStyle(
                    fontSize: 11,
                    color: OmniTheme.slate400,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${offer.passengerName} • ★ ${offer.passengerRating.toStringAsFixed(2)} • ${offer.distanceKm.toStringAsFixed(1)} km',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: OmniTheme.slate400,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: isSent
                          ? null
                          : () => _openBidDialog(context, p, offer),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSent
                            ? OmniTheme.slate800
                            : OmniTheme.neonCyan,
                        foregroundColor: isSent
                            ? OmniTheme.neonEmerald
                            : const Color(0xFF05080F),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                      child: Text(isSent ? 'Proposta Enviada ✓' : 'Fazer Lance'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _FilterChipPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? OmniTheme.alpha(OmniTheme.neonCyan, 0.16)
              : OmniTheme.slate900,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? OmniTheme.neonCyan : OmniTheme.slate800,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: selected ? OmniTheme.neonCyan : OmniTheme.slate300,
          ),
        ),
      ),
    );
  }
}
