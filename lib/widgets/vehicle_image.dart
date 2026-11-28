import 'package:flutter/material.dart';
import '../config/omni_theme.dart';
import '../models/omni_models.dart';
import '../utils/vehicle_catalog.dart';

/// Renderizador de Foto Real & Silhueta Vetorial Exata de Veículos OMNI (1:1 com VehicleImage.tsx)
class VehicleImage extends StatefulWidget {
  final VehicleType type;
  final String brand;
  final String model;
  final String? color;
  final String? bodyStyle;
  final int? doors;
  final String? photoUrl;
  final double height;
  final double? width;
  final bool showMetaBadge;

  const VehicleImage({
    super.key,
    required this.type,
    required this.brand,
    required this.model,
    this.color,
    this.bodyStyle,
    this.doors,
    this.photoUrl,
    this.height = 100,
    this.width,
    this.showMetaBadge = true,
  });

  @override
  State<VehicleImage> createState() => _VehicleImageState();
}

class _VehicleImageState extends State<VehicleImage> {
  String? _resolvedPhoto;
  bool _photoFailed = false;

  @override
  void initState() {
    super.initState();
    _resolvePhoto();
  }

  @override
  void didUpdateWidget(covariant VehicleImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brand != widget.brand ||
        oldWidget.model != widget.model ||
        oldWidget.type != widget.type ||
        oldWidget.photoUrl != widget.photoUrl) {
      _photoFailed = false;
      _resolvePhoto();
    }
  }

  Future<void> _resolvePhoto() async {
    final direct = (widget.photoUrl ?? '').trim();
    if (direct.isNotEmpty) {
      setState(() => _resolvedPhoto = direct);
      return;
    }
    final curated = resolveCuratedVehiclePhoto(widget.brand, widget.model);
    if (curated != null) {
      setState(() => _resolvedPhoto = curated);
      return;
    }
    setState(() => _resolvedPhoto = null);
    final fetched =
        await lookupRealVehiclePhotoOnline(widget.brand, widget.model, widget.type);
    if (mounted && fetched != null) {
      setState(() => _resolvedPhoto = fetched);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = resolveVehiclePaintPalette(widget.color);
    final style = inferVehicleBodyStyle(
      type: widget.type,
      brand: widget.brand,
      model: widget.model,
      explicitBodyStyle: widget.bodyStyle,
      doors: widget.doors,
    );
    final showNetworkImage =
        _resolvedPhoto != null && _resolvedPhoto!.isNotEmpty && !_photoFailed;

    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: OmniTheme.slate950,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OmniTheme.slate800),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showNetworkImage)
            Image.network(
              _resolvedPhoto!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_photoFailed) {
                    setState(() => _photoFailed = true);
                  }
                });
                return _VectorVehicleFallback(style: style, palette: palette);
              },
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _VectorVehicleFallback(style: style, palette: palette);
              },
            )
          else
            _VectorVehicleFallback(style: style, palette: palette),

          // Gradiente sutil de contraste na base
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    OmniTheme.alpha(OmniTheme.slate950, 0.72),
                  ],
                  stops: const [0.45, 1.0],
                ),
              ),
            ),
          ),

          if (widget.showMetaBadge)
            Positioned(
              left: 8,
              right: 8,
              bottom: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: OmniTheme.alpha(OmniTheme.slate950, 0.85),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: OmniTheme.alpha(OmniTheme.neonCyan, 0.3)),
                      ),
                      child: Text(
                        formatBodyStyleLabel(style),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: OmniTheme.neonCyan,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: palette.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white70, width: 1),
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

class _VectorVehicleFallback extends StatelessWidget {
  final String style;
  final VehiclePaintPalette palette;

  const _VectorVehicleFallback({
    required this.style,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1422), Color(0xFF06090F)],
        ),
      ),
      child: CustomPaint(
        painter: _VehicleSilhouettePainter(style: style, palette: palette),
      ),
    );
  }
}

class _VehicleSilhouettePainter extends CustomPainter {
  final String style;
  final VehiclePaintPalette palette;

  const _VehicleSilhouettePainter({
    required this.style,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.highlight, palette.primary, palette.shadow],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final strokePaint = Paint()
      ..color = OmniTheme.alpha(Colors.white, 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final glassPaint = Paint()..color = const Color(0xFF1E293B);
    final tirePaint = Paint()..color = const Color(0xFF020617);
    final rimPaint = Paint()..color = const Color(0xFF94A3B8);

    if (style.startsWith('MOTO')) {
      // Silhueta de Moto (Street / Scooter / Trail)
      final wheelRadius = h * 0.22;
      final rearCenter = Offset(w * 0.27, h * 0.68);
      final frontCenter = Offset(w * 0.74, h * 0.68);

      for (final c in [rearCenter, frontCenter]) {
        canvas.drawCircle(c, wheelRadius, tirePaint);
        canvas.drawCircle(c, wheelRadius * 0.55, rimPaint);
        canvas.drawCircle(c, wheelRadius, strokePaint);
      }

      final frame = Path()
        ..moveTo(w * 0.24, h * 0.52)
        ..lineTo(w * 0.44, h * 0.42)
        ..quadraticBezierTo(w * 0.56, h * 0.30, w * 0.67, h * 0.38)
        ..lineTo(w * 0.75, h * 0.65)
        ..lineTo(w * 0.64, h * 0.60)
        ..lineTo(w * 0.45, h * 0.60)
        ..close();

      canvas.drawPath(frame, bodyPaint);
      canvas.drawPath(frame, strokePaint);
      return;
    }

    // Carro (Sedan 4P / Hatch 4P / SUV / Coupé 2P / Picape)
    final isSuv = style == 'SUV' || style == 'PICKUP_CARGO';
    final isHatch = style == 'HATCH_4P';
    final isCoupe = style == 'COUPE_2P';

    final roofTop = isSuv ? h * 0.20 : h * 0.24;
    final bodyTop = isSuv ? h * 0.42 : h * 0.45;
    final bodyBottom = h * 0.70;

    final carPath = Path()
      ..moveTo(w * 0.14, bodyBottom)
      ..lineTo(w * 0.14, bodyTop + h * 0.05)
      ..lineTo(w * 0.22, bodyTop)
      ..lineTo(w * 0.32, roofTop)
      ..lineTo(isHatch ? w * 0.68 : w * 0.62, roofTop)
      ..lineTo(isHatch ? w * 0.78 : w * 0.74, bodyTop)
      ..lineTo(w * 0.87, bodyTop + h * 0.06)
      ..lineTo(w * 0.87, bodyBottom)
      ..close();

    canvas.drawPath(carPath, bodyPaint);
    canvas.drawPath(carPath, strokePaint);

    // Janelas (divisão 2P vs 4P)
    final winPath = Path()
      ..moveTo(w * 0.26, bodyTop - h * 0.02)
      ..lineTo(w * 0.34, roofTop + h * 0.04)
      ..lineTo(isHatch ? w * 0.66 : w * 0.60, roofTop + h * 0.04)
      ..lineTo(isHatch ? w * 0.74 : w * 0.70, bodyTop - h * 0.02)
      ..close();
    canvas.drawPath(winPath, glassPaint);

    // Coluna B / divisória de portas
    canvas.drawLine(
      Offset(w * 0.48, roofTop + h * 0.04),
      Offset(w * 0.48, bodyBottom - h * 0.04),
      strokePaint,
    );

    // Maçanetas (2 ou 4 portas)
    final handlePaint = Paint()..color = Colors.white70;
    canvas.drawRect(
      Rect.fromLTWH(w * 0.41, bodyTop + h * 0.07, w * 0.04, 2.5),
      handlePaint,
    );
    if (!isCoupe) {
      canvas.drawRect(
        Rect.fromLTWH(w * 0.59, bodyTop + h * 0.07, w * 0.04, 2.5),
        handlePaint,
      );
    }

    // Rodas
    final wheelRadius = h * 0.13;
    for (final cx in [w * 0.27, w * 0.73]) {
      final center = Offset(cx, bodyBottom + h * 0.01);
      canvas.drawCircle(center, wheelRadius, tirePaint);
      canvas.drawCircle(center, wheelRadius * 0.55, rimPaint);
      canvas.drawCircle(center, wheelRadius, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _VehicleSilhouettePainter oldDelegate) {
    return oldDelegate.style != style ||
        oldDelegate.palette.primary != palette.primary;
  }
}
