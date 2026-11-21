import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../config/omni_theme.dart';
import '../models/omni_models.dart';
import '../providers/omni_driver_provider.dart';
import '../widgets/active_trip_panel.dart';
import '../widgets/onboarding_gatekeeper_panel.dart';
import '../widgets/vehicle_image.dart';

/// Cockpit de Mapa Interativo + Radar Online + Cards Flutuantes — 1:1 com MapCanvas.tsx
class MapCockpitView extends StatefulWidget {
  const MapCockpitView({super.key});

  @override
  State<MapCockpitView> createState() => _MapCockpitViewState();
}

class _MapCockpitViewState extends State<MapCockpitView>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late AnimationController _pulseController;
  int _lastRecenterTick = 0;

  // Matriz de cores escuras Neon Luxuoso equivalente ao CSS dark-map-tiles
  static const List<double> _darkTileMatrix = <double>[
    -0.85, 0, 0, 0, 225,
    0, -0.78, 0, 0, 232,
    0, 0, -0.65, 0, 245,
    0, 0, 0, 1, 0,
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();
    final driver = p.driver;
    final loc = p.driverLocation;
    final trip = p.activeTrip;
    final approved = p.isDriverFullyApproved;
    final activeVehicle = p.activeVehicle;

    if (p.recenterTick != _lastRecenterTick) {
      _lastRecenterTick = p.recenterTick;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(LatLng(loc.latitude, loc.longitude), 15.2);
      });
    }

    final driverLatLng = LatLng(loc.latitude, loc.longitude);

    return Stack(
      children: [
        // 1. Mapa OpenStreetMap (Gratuito, sem token)
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: driverLatLng,
            initialZoom: 15.0,
            minZoom: 3.0,
            maxZoom: 18.5,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'br.com.omni.motorista',
              tileBuilder: (context, tileWidget, tile) {
                if (!p.mapDarkMode) return tileWidget;
                return ColorFiltered(
                  colorFilter: const ColorFilter.matrix(_darkTileMatrix),
                  child: tileWidget,
                );
              },
            ),

            // Polilinha da Rota Ativa
            if (p.routePolyline.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: p.routePolyline
                        .map((c) => LatLng(c.latitude, c.longitude))
                        .toList(),
                    color: OmniTheme.neonCyan,
                    strokeWidth: 5.0,
                  ),
                ],
              ),

            // Marcadores Origem / Destino + Veículo do Motorista
            MarkerLayer(
              markers: [
                if (trip != null) ...[
                  Marker(
                    point: LatLng(trip.origin.coords.latitude,
                        trip.origin.coords.longitude),
                    width: 36,
                    height: 36,
                    child: _PinBadge(label: 'A', color: OmniTheme.neonCyan),
                  ),
                  Marker(
                    point: LatLng(trip.destination.coords.latitude,
                        trip.destination.coords.longitude),
                    width: 36,
                    height: 36,
                    child: _PinBadge(label: 'B', color: OmniTheme.neonRose),
                  ),
                ],
                Marker(
                  point: driverLatLng,
                  width: 58,
                  height: 58,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      final pulseScale =
                          driver.isOnline ? 1.0 + _pulseController.value * 0.55 : 1.0;
                      final pulseOpacity =
                          driver.isOnline ? (1.0 - _pulseController.value) * 0.45 : 0.0;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          if (driver.isOnline)
                            Transform.scale(
                              scale: pulseScale,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: OmniTheme.alpha(
                                      OmniTheme.neonCyan, pulseOpacity),
                                  border: Border.all(
                                    color: OmniTheme.alpha(
                                        OmniTheme.neonCyan, pulseOpacity + 0.15),
                                  ),
                                ),
                              ),
                            ),
                          Transform.rotate(
                            angle: (p.driverHeading * math.pi) / 180.0,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: OmniTheme.slate950,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: driver.isOnline
                                      ? OmniTheme.neonCyan
                                      : OmniTheme.slate500,
                                  width: 2.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: OmniTheme.alpha(
                                      driver.isOnline
                                          ? OmniTheme.neonCyan
                                          : Colors.black,
                                      0.55,
                                    ),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: Icon(
                                activeVehicle.type == VehicleType.moto
                                    ? Icons.two_wheeler_rounded
                                    : Icons.directions_car_rounded,
                                size: 20,
                                color: driver.isOnline
                                    ? OmniTheme.neonCyan
                                    : OmniTheme.slate300,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),

        // 2. Controles Flutuantes do Mapa (Modo Noturno + Centralizar GPS)
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            children: [
              _FloatingMapButton(
                icon: p.mapDarkMode
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                tooltip: p.mapDarkMode ? 'Mapa Claro' : 'Mapa Escuro Neon',
                onTap: p.toggleMapDarkMode,
              ),
              const SizedBox(height: 8),
              _FloatingMapButton(
                icon: Icons.my_location_rounded,
                tooltip: 'Centralizar GPS',
                onTap: p.triggerRecenter,
              ),
            ],
          ),
        ),

        // 3. Painéis Flutuantes Inferiores (Gatekeeper / Offline / Online / Corrida Ativa)
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.56,
            ),
            child: SingleChildScrollView(
              child: trip != null
                  ? const ActiveTripPanel()
                  : !approved
                      ? const OnboardingGatekeeperPanel()
                      : !driver.isOnline
                          ? Container(
                              decoration: OmniTheme.neonCardDecoration(
                                color: OmniTheme.alpha(OmniTheme.slate950, 0.96),
                              ),
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      const OmniPillBadge(
                                        text: '100% APROVADO & APTO',
                                        color: OmniTheme.neonEmerald,
                                        icon: Icons.verified_user_rounded,
                                      ),
                                      const Spacer(),
                                      Text(
                                        activeVehicle.plate,
                                        style: OmniTheme.monoStyle(
                                          fontSize: 11,
                                          color: OmniTheme.neonCyan,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 84,
                                        child: VehicleImage(
                                          type: activeVehicle.type,
                                          brand: activeVehicle.brand,
                                          model: activeVehicle.model,
                                          color: activeVehicle.color,
                                          bodyStyle: activeVehicle.bodyStyle,
                                          doors: activeVehicle.doors,
                                          photoUrl: activeVehicle.photoUrl,
                                          height: 58,
                                          showMetaBadge: false,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${activeVehicle.brand} ${activeVehicle.model}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              '${activeVehicle.year} • ${activeVehicle.color}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: OmniTheme.slate400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: p.toggleOnlineStatus,
                                      icon: const Icon(
                                          Icons.power_settings_new_rounded,
                                          size: 18),
                                      label: const Text('ATIVAR MODO ONLINE'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              decoration: OmniTheme.neonCardDecoration(
                                color: OmniTheme.alpha(OmniTheme.slate950, 0.96),
                                active: true,
                              ),
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      const OmniPillBadge(
                                        text: 'RADAR ONLINE ATIVO',
                                        color: OmniTheme.neonEmerald,
                                        icon: Icons.sensors_rounded,
                                      ),
                                      const Spacer(),
                                      InkWell(
                                        onTap: p.toggleOnlineStatus,
                                        child: const Text(
                                          'Ficar Offline',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: OmniTheme.rose500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _QuickStatTile(
                                          label: 'Ganhos Hoje',
                                          value:
                                              'R\$ ${driver.todayEarnings.toStringAsFixed(2)}',
                                          color: OmniTheme.neonEmerald,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _QuickStatTile(
                                          label: 'Corridas',
                                          value: '${driver.todayTripsCount}',
                                          color: OmniTheme.neonCyan,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _QuickStatTile(
                                          label: 'Nota',
                                          value:
                                              '★ ${driver.rating.toStringAsFixed(2)}',
                                          color: OmniTheme.amber400,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              p.triggerSimulatedTrip(
                                                  type: 'PASSENGER'),
                                          icon: const Icon(
                                              Icons.directions_car_rounded,
                                              size: 16),
                                          label: const Text(
                                            'Receber Corrida',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              p.triggerSimulatedTrip(
                                                  type: 'DELIVERY'),
                                          icon: const Icon(
                                              Icons.inventory_2_rounded,
                                              size: 16,
                                              color: OmniTheme.amber400),
                                          label: const Text(
                                            'Receber Entrega',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                color: OmniTheme.amber400,
                                                fontWeight: FontWeight.w800),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12),
                                            side: BorderSide(
                                                color: OmniTheme.alpha(
                                                    OmniTheme.amber400, 0.5)),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FloatingMapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _FloatingMapButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OmniTheme.alpha(OmniTheme.slate950, 0.92),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: OmniTheme.alpha(OmniTheme.neonCyan, 0.35)),
          ),
          child: Icon(icon, size: 20, color: OmniTheme.neonCyan),
        ),
      ),
    );
  }
}

class _PinBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _PinBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: OmniTheme.alpha(color, 0.65), blurRadius: 10),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF05080F),
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _QuickStatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _QuickStatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: OmniTheme.slate900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OmniTheme.slate800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9.5, color: OmniTheme.slate400),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OmniTheme.monoStyle(
              fontSize: 12.5,
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
