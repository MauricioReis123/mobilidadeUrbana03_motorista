import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/omni_models.dart';

/// Catálogo Visual Real & Vetorial de Veículos OMNI (Wikimedia + Wikipedia + Vetor por carroceria/cor)
/// 1:1 com src/utils/vehicleCatalog.ts

class VehiclePaintPalette {
  final Color primary;
  final Color highlight;
  final Color shadow;
  final String label;

  const VehiclePaintPalette({
    required this.primary,
    required this.highlight,
    required this.shadow,
    required this.label,
  });
}

VehiclePaintPalette resolveVehiclePaintPalette(String? colorName) {
  final c = (colorName ?? '').toLowerCase();
  if (c.contains('prata') || c.contains('silver') || c.contains('cinza')) {
    return const VehiclePaintPalette(
      primary: Color(0xFFCBD5E1),
      highlight: Color(0xFFF8FAFC),
      shadow: Color(0xFF475569),
      label: 'Prata Metálico',
    );
  }
  if (c.contains('branc') || c.contains('white')) {
    return const VehiclePaintPalette(
      primary: Color(0xFFF1F5F9),
      highlight: Color(0xFFFFFFFF),
      shadow: Color(0xFF94A3B8),
      label: 'Branco Pérola',
    );
  }
  if (c.contains('pret') || c.contains('black') || c.contains('grafite')) {
    return const VehiclePaintPalette(
      primary: Color(0xFF1E293B),
      highlight: Color(0xFF475569),
      shadow: Color(0xFF020617),
      label: 'Preto Ônix',
    );
  }
  if (c.contains('vermelh') || c.contains('red') || c.contains('vinho')) {
    return const VehiclePaintPalette(
      primary: Color(0xFFEF4444),
      highlight: Color(0xFFFCA5A5),
      shadow: Color(0xFF7F1D1D),
      label: 'Vermelho',
    );
  }
  if (c.contains('azul') || c.contains('blue')) {
    return const VehiclePaintPalette(
      primary: Color(0xFF3B82F6),
      highlight: Color(0xFF93C5FD),
      shadow: Color(0xFF1E3A8A),
      label: 'Azul',
    );
  }
  if (c.contains('verde') || c.contains('green')) {
    return const VehiclePaintPalette(
      primary: Color(0xFF10B981),
      highlight: Color(0xFF6EE7B7),
      shadow: Color(0xFF064E3B),
      label: 'Verde',
    );
  }
  return const VehiclePaintPalette(
    primary: Color(0xFF00FFCC),
    highlight: Color(0xFF99FFE8),
    shadow: Color(0xFF0F766E),
    label: 'OMNI Cyan',
  );
}

String inferVehicleBodyStyle({
  required VehicleType type,
  String? brand,
  String? model,
  String? explicitBodyStyle,
  int? doors,
}) {
  if (explicitBodyStyle != null && explicitBodyStyle.isNotEmpty) {
    return explicitBodyStyle;
  }
  final m = '${brand ?? ''} ${model ?? ''}'.toLowerCase();
  if (type == VehicleType.moto) {
    if (m.contains('pcx') || m.contains('nmax') || m.contains('biz') || m.contains('scooter')) {
      return 'MOTO_SCOOTER';
    }
    if (m.contains('bros') || m.contains('xre') || m.contains('lander') || m.contains('crosser') || m.contains('himalayan')) {
      return 'MOTO_TRAIL';
    }
    return 'MOTO_STREET';
  }
  if (doors == 2) return 'COUPE_2P';
  if (m.contains('hilux') || m.contains('strada') || m.contains('s10') || m.contains('montana') || m.contains('toro')) {
    return 'PICKUP_CARGO';
  }
  if (m.contains('tracker') || m.contains('creta') || m.contains('t-cross') || m.contains('nivus') ||
      m.contains('compass') || m.contains('renegade') || m.contains('kicks') || m.contains('hr-v') ||
      m.contains('corolla cross') || m.contains('song') || m.contains('pulse') || m.contains('fastback') ||
      m.contains('duster') || m.contains('tiggo') || m.contains('spin') || m.contains('sw4')) {
    return 'SUV';
  }
  if (m.contains('onix') && !m.contains('plus')) return 'HATCH_4P';
  if (m.contains('polo') || m.contains('argo') || m.contains('mobi') || m.contains('kwid') ||
      m.contains('hb20 ') || m.contains('sandero') || m.contains('fit') || m.contains('dolphin')) {
    return 'HATCH_4P';
  }
  return 'SEDAN_4P';
}

String formatBodyStyleLabel(String bodyStyle) {
  switch (bodyStyle) {
    case 'SEDAN_4P':
      return 'Sedan 4 Portas';
    case 'HATCH_4P':
      return 'Hatch 4 Portas';
    case 'SUV':
      return 'SUV / Crossover';
    case 'COUPE_2P':
      return 'Coupé 2 Portas';
    case 'PICKUP_CARGO':
      return 'Picape Cabine Dupla';
    case 'MOTO_SCOOTER':
      return 'Scooter Urbana';
    case 'MOTO_TRAIL':
      return 'Moto Trail';
    case 'MOTO_STREET':
      return 'Moto Street';
    default:
      return 'Veículo OMNI';
  }
}

String formatVehicleCategoryLabel(VehicleCategory category) {
  switch (category) {
    case VehicleCategory.omniX:
      return 'OMNI X';
    case VehicleCategory.omniComfort:
      return 'OMNI Comfort';
    case VehicleCategory.omniBlack:
      return 'OMNI Black';
    case VehicleCategory.omniMoto:
      return 'OMNI Moto';
    case VehicleCategory.omniFlashDelivery:
      return 'OMNI Flash';
  }
}

/// Dicionário curado de fotos reais gratuitas via Wikimedia Commons (sem tokens)
const Map<String, String> verifiedVehiclePhotos = {
  'corolla': 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/2020_Toyota_Corolla_Hybrid_Icon_Tech_1.8_Front.jpg/640px-2020_Toyota_Corolla_Hybrid_Icon_Tech_1.8_Front.jpg',
  'onix plus': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/03/Chevrolet_Onix_Plus_Premier_2020_%28cropped%29.jpg/640px-Chevrolet_Onix_Plus_Premier_2020_%28cropped%29.jpg',
  'onix': 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/be/2020_Chevrolet_Onix_Premier_hatchback_%28front%29.jpg/640px-2020_Chevrolet_Onix_Premier_hatchback_%28front%29.jpg',
  'virtus': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a7/VW_Virtus_1.0_TSI_Highline_2019_%28cropped%29.jpg/640px-VW_Virtus_1.0_TSI_Highline_2019_%28cropped%29.jpg',
  'polo': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/41/2018_Volkswagen_Polo_SE_TSi_1.0_Front.jpg/640px-2018_Volkswagen_Polo_SE_TSi_1.0_Front.jpg',
  'hb20': 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dc/Hyundai_HB20_Diamond_2020.jpg/640px-Hyundai_HB20_Diamond_2020.jpg',
  'civic': 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/64/2022_Honda_Civic_Touring_Sedan_in_Lunar_Silver_Metallic%2C_Front_Left.jpg/640px-2022_Honda_Civic_Touring_Sedan_in_Lunar_Silver_Metallic%2C_Front_Left.jpg',
  'tracker': 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d6/Chevrolet_Tracker_Premier_2021.jpg/640px-Chevrolet_Tracker_Premier_2021.jpg',
  't-cross': 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/ea/Volkswagen_T-Cross_IMG_2447.jpg/640px-Volkswagen_T-Cross_IMG_2447.jpg',
  'compass': 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/2022_Jeep_Compass_Limited_front_NYIAS.jpg/640px-2022_Jeep_Compass_Limited_front_NYIAS.jpg',
  'dolphin': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/22/BYD_Dolphin_IAA_2023_1X7A0416.jpg/640px-BYD_Dolphin_IAA_2023_1X7A0416.jpg',
  'cg 160': 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/89/Honda_CG_160_Titan_EX.jpg/640px-Honda_CG_160_Titan_EX.jpg',
  'pcx': 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/55/Honda_PCX_160_%282021%29.jpg/640px-Honda_PCX_160_%282021%29.jpg',
  'fazer': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9f/Yamaha_Fazer_250_ABS_2018.jpg/640px-Yamaha_Fazer_250_ABS_2018.jpg',
  'nmax': 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/bb/Yamaha_NMAX_155_%282021%29.jpg/640px-Yamaha_NMAX_155_%282021%29.jpg',
};

String? resolveCuratedVehiclePhoto(String brand, String model) {
  final full = '${brand.toLowerCase()} ${model.toLowerCase()}';
  for (final entry in verifiedVehiclePhotos.entries) {
    if (full.contains(entry.key)) return entry.value;
  }
  return null;
}

final Map<String, String?> _wikiPhotoCache = {};

Future<String?> lookupRealVehiclePhotoOnline(
  String brand,
  String model,
  VehicleType type,
) async {
  final key = '${type.code}::${brand.trim()}::${model.trim()}'.toLowerCase();
  if (_wikiPhotoCache.containsKey(key)) return _wikiPhotoCache[key];

  final curated = resolveCuratedVehiclePhoto(brand, model);
  if (curated != null) {
    _wikiPhotoCache[key] = curated;
    return curated;
  }

  if (brand.trim().isEmpty || model.trim().isEmpty) return null;

  final cleanModel = model.split(RegExp(r'\s+')).take(2).join(' ');
  final queries = ['${brand.trim()} $cleanModel', '${brand.trim()} ${model.trim()}'];

  for (final lang in ['pt', 'en']) {
    for (final q in queries) {
      try {
        final uri = Uri.parse(
          'https://$lang.wikipedia.org/w/api.php?action=query&generator=search&gsrsearch=${Uri.encodeComponent(q)}&gsrlimit=1&prop=pageimages&pithumbsize=640&format=json&origin=*',
        );
        final resp = await http.get(uri).timeout(const Duration(seconds: 4));
        if (resp.statusCode == 200) {
          final json = jsonDecode(resp.body) as Map<String, dynamic>;
          final pages = (json['query'] as Map<String, dynamic>?)?['pages']
              as Map<String, dynamic>?;
          if (pages != null) {
            for (final page in pages.values) {
              final thumb = (page as Map<String, dynamic>?)?['thumbnail']
                  as Map<String, dynamic>?;
              final src = thumb?['source'] as String?;
              if (src != null && src.isNotEmpty) {
                _wikiPhotoCache[key] = src;
                return src;
              }
            }
          }
        }
      } catch (_) {}
    }
  }
  _wikiPhotoCache[key] = null;
  return null;
}
