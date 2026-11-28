import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../config/omni_theme.dart';
import '../models/omni_models.dart';
import '../providers/omni_driver_provider.dart';
import '../services/sound_service.dart';
import '../widgets/active_trip_panel.dart';
import '../widgets/onboarding_gatekeeper_panel.dart';
import '../widgets/owner_test_hired_driver_checkbox.dart';
import '../widgets/vehicle_image.dart';
import 'owner_admin_dashboard_screen.dart';

/// Cockpit de Mapa Interativo + Radar Online + Ajuste Fino de Pino & GPS Preciso — 1:1 com MapCanvas.tsx
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
  bool _hasCenteredRealFix = false;

  bool _adjustPinMode = false;
  bool _recenteringGps = false;
  bool _resolvingPinAddress = false;
  LatLng? _pinCenter;
  ReverseGeocodedAddress? _pinAddressPreview;
  Timer? _pinDebounceTimer;

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
    _pinDebounceTimer?.cancel();
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Color _fixQualityColor(GpsFixQuality q) {
    switch (q) {
      case GpsFixQuality.precise:
        return OmniTheme.neonEmerald;
      case GpsFixQuality.approximate:
        return OmniTheme.amber400;
      case GpsFixQuality.searching:
        return OmniTheme.neonCyan;
      case GpsFixQuality.unavailable:
        return OmniTheme.rose500;
    }
  }

  String _fixQualityLabel(OmniDriverProvider p) {
    final locSvc = p.locationService;
    if (!locSvc.hasRealFix && locSvc.fixQuality == GpsFixQuality.searching) {
      return 'Buscando GPS...';
    }
    if (locSvc.fixQuality == GpsFixQuality.unavailable) {
      return 'GPS Indisponível';
    }
    final acc = locSvc.lastAccuracyMeters;
    final meters = acc > 0 ? '${acc.toStringAsFixed(0)}m' : '--';
    return locSvc.isApproximateLocationWarning
        ? 'Aprox.: $meters'
        : 'Precisão: $meters';
  }

  Future<void> _handleFineRecenter(OmniDriverProvider p) async {
    if (_recenteringGps) return;
    setState(() => _recenteringGps = true);
    try {
      await p.locationService.recenterHighPrecision();
      p.triggerRecenter();
      final pos = p.driverLocation;
      _mapController.move(LatLng(pos.latitude, pos.longitude), 16.4);
    } finally {
      if (mounted) setState(() => _recenteringGps = false);
    }
  }

  void _togglePinAdjustmentMode(OmniDriverProvider p) {
    final next = !_adjustPinMode;
    final current = LatLng(p.driverLocation.latitude, p.driverLocation.longitude);
    setState(() {
      _adjustPinMode = next;
      _pinCenter = next ? current : null;
      _pinAddressPreview = next ? p.locationService.lastReverseGeocodedAddress : null;
    });
    if (next) {
      _mapController.move(current, 17.2);
      _schedulePinReverseGeocode(p, current, immediate: true);
    } else {
      _pinDebounceTimer?.cancel();
    }
  }

  void _schedulePinReverseGeocode(
    OmniDriverProvider p,
    LatLng center, {
    bool immediate = false,
  }) {
    _pinDebounceTimer?.cancel();
    _pinDebounceTimer = Timer(
      Duration(milliseconds: immediate ? 50 : 800),
      () async {
        if (!mounted || !_adjustPinMode) return;
        setState(() => _resolvingPinAddress = true);
        try {
          final addr = await p.locationService.reverseGeocodeFree(
            center.latitude,
            center.longitude,
            immediate: immediate,
          );
          if (mounted && _adjustPinMode && addr != null) {
            setState(() => _pinAddressPreview = addr);
          }
        } finally {
          if (mounted) setState(() => _resolvingPinAddress = false);
        }
      },
    );
  }

  Future<void> _confirmAdjustedPin(OmniDriverProvider p) async {
    final center = _pinCenter;
    if (center == null) return;
    final resolved = _pinAddressPreview ??
        await p.locationService.reverseGeocodeFree(
          center.latitude,
          center.longitude,
          immediate: true,
        );

    p.locationService.setManualAdjustedPosition(
      OmniCoordinate(
        latitude: center.latitude,
        longitude: center.longitude,
        accuracyMeters: 5.0,
        isApproximateOnly: false,
      ),
    );

    if (resolved != null) {
      final currAddr = p.driver.address;
      final nextAddress = DriverAddress(
        cep: resolved.cep.isNotEmpty ? resolved.cep : (currAddr?.cep ?? ''),
        street: resolved.street.isNotEmpty
            ? resolved.street
            : (currAddr?.street ?? ''),
        number: resolved.number.isNotEmpty
            ? resolved.number
            : (currAddr?.number ?? 'S/N'),
        complement: currAddr?.complement,
        neighborhood: resolved.neighborhood.isNotEmpty
            ? resolved.neighborhood
            : (currAddr?.neighborhood ?? ''),
        city: resolved.city.isNotEmpty ? resolved.city : (currAddr?.city ?? ''),
        state:
            resolved.state.isNotEmpty ? resolved.state : (currAddr?.state ?? ''),
      );
      await p.updateDriverProfile(
        p.driver.copyWith(
          operationalCity: (nextAddress.city.isNotEmpty && nextAddress.state.isNotEmpty)
              ? '${nextAddress.city} - ${nextAddress.state}'
              : p.driver.operationalCity,
          address: nextAddress,
        ),
        silent: true,
      );
      await OmniSoundService.playSuccess();
      p.addAlert(
        'Pino Ajustado com Precisão',
        '${resolved.formattedStreetLine} (${resolved.city}/${resolved.state})',
        'success',
      );
    }

    if (mounted) {
      setState(() {
        _adjustPinMode = false;
        _pinCenter = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();
    final driver = p.driver;
    final loc = p.driverLocation;
    final trip = p.activeTrip;
    final approved = p.isDriverFullyApproved;
    final activeVehicle = p.activeVehicle;
    final locSvc = p.locationService;

    final hasRealFix = locSvc.hasRealFix &&
        (loc.latitude.abs() > 0.0001 || loc.longitude.abs() > 0.0001);
    final driverLatLng = hasRealFix
        ? LatLng(loc.latitude, loc.longitude)
        : const LatLng(-15.793889, -47.882778);

    if (hasRealFix && !_hasCenteredRealFix) {
      _hasCenteredRealFix = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(driverLatLng, 16.0);
      });
    }

    if (p.recenterTick != _lastRecenterTick) {
      _lastRecenterTick = p.recenterTick;
      if (hasRealFix) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _mapController.move(driverLatLng, 15.6);
        });
      }
    }

    final fixColor = _fixQualityColor(locSvc.fixQuality);

    return Stack(
      children: [
        // 1. Mapa OpenStreetMap (Gratuito, sem token)
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: driverLatLng,
            initialZoom: hasRealFix ? 15.6 : 4.2,
            minZoom: 3.0,
            maxZoom: 18.8,
            onPositionChanged: (MapPosition position, bool hasGesture) {
              if (!_adjustPinMode || position.center == null) return;
              _pinCenter = position.center;
              if (hasGesture) {
                _schedulePinReverseGeocode(p, position.center!);
              }
            },
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

            // Polilinha da Rota Ativa (OSRM gratuita)
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
                if (hasRealFix)
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

        // Mira central do Pino Arrastável para ajuste fino de Rua + Número
        if (_adjustPinMode)
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 34),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 46,
                      color: OmniTheme.amber400,
                    ),
                    SizedBox(height: 2),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: OmniTheme.slate950,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(width: 8, height: 8),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 2a. HUD Superior Esquerdo: Selo de Precisão GPS + Aviso de Localização Aproximada
        Positioned(
          top: 12,
          left: 12,
          right: 68,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: OmniTheme.alpha(OmniTheme.slate950, 0.92),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: OmniTheme.alpha(fixColor, 0.65),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.gps_fixed_rounded,
                            size: 13, color: fixColor),
                        const SizedBox(width: 5),
                        Text(
                          _fixQualityLabel(p),
                          style: OmniTheme.monoStyle(
                            fontSize: 10.5,
                            color: fixColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: OmniTheme.alpha(OmniTheme.slate950, 0.92),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: OmniTheme.alpha(OmniTheme.neonCyan, 0.35),
                      ),
                    ),
                    child: const Text(
                      'OSRM • OSM 100% Gratuito',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: OmniTheme.neonCyan,
                      ),
                    ),
                  ),
                ],
              ),
              if (locSvc.isApproximateLocationWarning) ...[
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final opened = await Geolocator.openLocationSettings();
                    if (!opened) {
                      await Geolocator.openAppSettings();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: OmniTheme.alpha(OmniTheme.slate950, 0.95),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: OmniTheme.amber400),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 15, color: OmniTheme.amber400),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Localização Aproximada ativa. Toque para ativar Localização Exata.',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: OmniTheme.amber400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_adjustPinMode) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: OmniTheme.neonCardDecoration(
                    color: OmniTheme.alpha(OmniTheme.slate950, 0.96),
                    borderColor: OmniTheme.amber400,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.edit_location_alt_rounded,
                              size: 15, color: OmniTheme.amber400),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Arraste o mapa para ajustar o pino (Rua + Nº)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: OmniTheme.amber400,
                              ),
                            ),
                          ),
                          if (_resolvingPinAddress)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: OmniTheme.neonCyan,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _pinAddressPreview?.formattedStreetLine.isNotEmpty ==
                                true
                            ? '${_pinAddressPreview!.formattedStreetLine} • ${_pinAddressPreview!.neighborhood} (${_pinAddressPreview!.city}/${_pinAddressPreview!.state})'
                            : 'Movimente o pino sobre a via desejada...',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _togglePinAdjustmentMode(p),
                              child: const Text(
                                'Cancelar',
                                style: TextStyle(
                                    fontSize: 11, color: OmniTheme.slate300),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () => _confirmAdjustedPin(p),
                              child: const Text(
                                'Confirmar Pino',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // 2b. Controles Flutuantes do Mapa (Modo Noturno + Centralizar GPS + Pino Manual)
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
                icon: _recenteringGps
                    ? Icons.gps_not_fixed_rounded
                    : Icons.my_location_rounded,
                tooltip: 'Recalibrar GPS de Alta Precisão',
                onTap: () => _handleFineRecenter(p),
              ),
              const SizedBox(height: 8),
              _FloatingMapButton(
                icon: _adjustPinMode
                    ? Icons.close_rounded
                    : Icons.edit_location_alt_rounded,
                tooltip: 'Ajustar Pino Manualmente',
                onTap: () => _togglePinAdjustmentMode(p),
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
                                  const OwnerTestHiredDriverCheckbox(compact: true),
                                  if (OwnerTestConfig.isAuthorizedOwner(
                                    driver,
                                    backendVerifiedOwner: p.backendVerifiedOwner,
                                    backendOwnerEmail: p.backend.ownerEmail,
                                  )) ...[
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const OwnerAdminDashboardScreen(),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.admin_panel_settings_rounded,
                                          size: 16,
                                          color: OmniTheme.amber400,
                                        ),
                                        label: const Text(
                                          'Painel Admin do Dono (Push & Frota)',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: OmniTheme.amber400,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
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
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          p.refreshPassengerDispatchQueueNow(),
                                      icon: const Icon(
                                          Icons.wifi_tethering_rounded,
                                          size: 16),
                                      label: const Text(
                                        'Escutar Fila Real (Firebase RTDB)',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                      ),
                                    ),
                                  ),
                                  const OwnerTestHiredDriverCheckbox(compact: true),
                                  if (OwnerTestConfig.isAuthorizedOwner(
                                    driver,
                                    backendVerifiedOwner: p.backendVerifiedOwner,
                                    backendOwnerEmail: p.backend.ownerEmail,
                                  )) ...[
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const OwnerAdminDashboardScreen(),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.admin_panel_settings_rounded,
                                          size: 16,
                                          color: OmniTheme.amber400,
                                        ),
                                        label: const Text(
                                          'Painel Admin do Dono (Push & Frota)',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: OmniTheme.amber400,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
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
