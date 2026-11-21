import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/omni_models.dart';

/// Base Integrada de Marcas e Modelos de Veículos (Brasil / FIPE Brasil API + Dataset Local)
/// 1:1 com src/utils/vehicleModelsDataset.ts

class CatalogVehicleModelEntry {
  final String model;
  final String bodyStyle;
  final int doors;
  final String categoryHint; // 'CAR' | 'MOTO'

  const CatalogVehicleModelEntry({
    required this.model,
    required this.bodyStyle,
    required this.doors,
    required this.categoryHint,
  });
}

class FipeBrand {
  final String codigo;
  final String nome;

  const FipeBrand({required this.codigo, required this.nome});
}

class FipeModel {
  final int codigo;
  final String nome;

  const FipeModel({required this.codigo, required this.nome});
}

const Map<String, List<CatalogVehicleModelEntry>> _builtinCarModelsByBrand = {
  'Toyota': [
    CatalogVehicleModelEntry(model: 'Corolla XEi 2.0', bodyStyle: 'SEDAN_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Corolla Altis Hybrid', bodyStyle: 'SEDAN_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Corolla Cross XRE', bodyStyle: 'SUV', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Yaris Sedan XLS', bodyStyle: 'SEDAN_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Yaris Hatch XL', bodyStyle: 'HATCH_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Etios Sedan X', bodyStyle: 'SEDAN_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Hilux SRX 4x4', bodyStyle: 'PICKUP_CARGO', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'SW4 Diamond', bodyStyle: 'SUV', doors: 4, categoryHint: 'CAR'),
  ],
  'Chevrolet': [
    CatalogVehicleModelEntry(model: 'Onix Plus Premier', bodyStyle: 'SEDAN_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Onix LT 1.0', bodyStyle: 'HATCH_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Tracker Premier 1.2 Turbo', bodyStyle: 'SUV', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Cruze LTZ', bodyStyle: 'SEDAN_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Spin Premier', bodyStyle: 'SUV', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Montana Premier', bodyStyle: 'PICKUP_CARGO', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'S10 High Country', bodyStyle: 'PICKUP_CARGO', doors: 4, categoryHint: 'CAR'),
  ],
  'Volkswagen': [
    CatalogVehicleModelEntry(model: 'Virtus Highline 200 TSI', bodyStyle: 'SEDAN_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Polo Track 1.0', bodyStyle: 'HATCH_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Polo Highline 200 TSI', bodyStyle: 'HATCH_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'T-Cross Highline', bodyStyle: 'SUV', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Nivus Highline', bodyStyle: 'SUV', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Voyage 1.6 MSI', bodyStyle: 'SEDAN_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Jetta GLI', bodyStyle: 'SEDAN_4P', doors: 4, categoryHint: 'CAR'),
  ],
  'Hyundai': [
    CatalogVehicleModelEntry(model: 'HB20S Platinum Plus', bodyStyle: 'SEDAN_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'HB20 Comfort 1.0', bodyStyle: 'HATCH_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Creta Ultimate 2.0', bodyStyle: 'SUV', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Tucson GLS', bodyStyle: 'SUV', doors: 4, categoryHint: 'CAR'),
  ],
  'Fiat': [
    CatalogVehicleModelEntry(model: 'Cronos Precision 1.3', bodyStyle: 'SEDAN_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Argo Drive 1.0', bodyStyle: 'HATCH_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Mobi Like 1.0', bodyStyle: 'HATCH_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Pulse Audace Turbo', bodyStyle: 'SUV', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Fastback Impetus', bodyStyle: 'SUV', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Strada Volcano', bodyStyle: 'PICKUP_CARGO', doors: 4, categoryHint: 'CAR'),
  ],
  'Honda': [
    CatalogVehicleModelEntry(model: 'Civic Touring', bodyStyle: 'SEDAN_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'City Touring Sedan', bodyStyle: 'SEDAN_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'HR-V EXL', bodyStyle: 'SUV', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Fit EX', bodyStyle: 'HATCH_4P', doors: 4, categoryHint: 'CAR'),
  ],
  'Renault': [
    CatalogVehicleModelEntry(model: 'Logan Zen 1.6', bodyStyle: 'SEDAN_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Sandero Stepway', bodyStyle: 'HATCH_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Kwid Zen 1.0', bodyStyle: 'HATCH_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Duster Iconic', bodyStyle: 'SUV', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Kardian Premiere', bodyStyle: 'SUV', doors: 4, categoryHint: 'CAR'),
  ],
  'Nissan': [
    CatalogVehicleModelEntry(model: 'Versa Exclusive', bodyStyle: 'SEDAN_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Sentra Exclusive', bodyStyle: 'SEDAN_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Kicks Exclusive', bodyStyle: 'SUV', doors: 4, categoryHint: 'CAR'),
  ],
  'BYD': [
    CatalogVehicleModelEntry(model: 'Dolphin Plus EV', bodyStyle: 'HATCH_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Dolphin Mini EV', bodyStyle: 'HATCH_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'King GS Hybrid', bodyStyle: 'SEDAN_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Song Plus DM-i', bodyStyle: 'SUV', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Yuan Plus EV', bodyStyle: 'SUV', doors: 4, categoryHint: 'CAR'),
  ],
  'Jeep': [
    CatalogVehicleModelEntry(model: 'Compass Longitude', bodyStyle: 'SUV', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Renegade Longitude', bodyStyle: 'SUV', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Commander Overland', bodyStyle: 'SUV', doors: 4, categoryHint: 'CAR'),
  ],
  'Caoa Chery': [
    CatalogVehicleModelEntry(model: 'Tiggo 5X Pro', bodyStyle: 'SUV', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Tiggo 7 Pro', bodyStyle: 'SUV', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Arrizo 6 Pro', bodyStyle: 'SEDAN_4P', doors: 4, categoryHint: 'CAR'),
  ],
  'BMW': [
    CatalogVehicleModelEntry(model: '320i M Sport', bodyStyle: 'SEDAN_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'X1 sDrive20i', bodyStyle: 'SUV', doors: 4, categoryHint: 'CAR'),
  ],
  'Audi': [
    CatalogVehicleModelEntry(model: 'A3 Sedan S Line', bodyStyle: 'SEDAN_4P', doors: 4, categoryHint: 'CAR'),
    CatalogVehicleModelEntry(model: 'Q3 Performance', bodyStyle: 'SUV', doors: 4, categoryHint: 'CAR'),
  ],
};

const Map<String, List<CatalogVehicleModelEntry>> _builtinMotoModelsByBrand = {
  'Honda': [
    CatalogVehicleModelEntry(model: 'CG 160 Titan', bodyStyle: 'MOTO_STREET', doors: 0, categoryHint: 'MOTO'),
    CatalogVehicleModelEntry(model: 'CG 160 Fan', bodyStyle: 'MOTO_STREET', doors: 0, categoryHint: 'MOTO'),
    CatalogVehicleModelEntry(model: 'CG 160 Start', bodyStyle: 'MOTO_STREET', doors: 0, categoryHint: 'MOTO'),
    CatalogVehicleModelEntry(model: 'PCX 160 DLX', bodyStyle: 'MOTO_SCOOTER', doors: 0, categoryHint: 'MOTO'),
    CatalogVehicleModelEntry(model: 'Biz 125 EX', bodyStyle: 'MOTO_SCOOTER', doors: 0, categoryHint: 'MOTO'),
    CatalogVehicleModelEntry(model: 'NXR 160 Bros', bodyStyle: 'MOTO_TRAIL', doors: 0, categoryHint: 'MOTO'),
    CatalogVehicleModelEntry(model: 'XRE 300 Sahara', bodyStyle: 'MOTO_TRAIL', doors: 0, categoryHint: 'MOTO'),
    CatalogVehicleModelEntry(model: 'CB 300F Twister', bodyStyle: 'MOTO_STREET', doors: 0, categoryHint: 'MOTO'),
  ],
  'Yamaha': [
    CatalogVehicleModelEntry(model: 'Fazer FZ25 ABS', bodyStyle: 'MOTO_STREET', doors: 0, categoryHint: 'MOTO'),
    CatalogVehicleModelEntry(model: 'Factor 150 ED', bodyStyle: 'MOTO_STREET', doors: 0, categoryHint: 'MOTO'),
    CatalogVehicleModelEntry(model: 'Fazer FZ15 ABS', bodyStyle: 'MOTO_STREET', doors: 0, categoryHint: 'MOTO'),
    CatalogVehicleModelEntry(model: 'NMAX 160 ABS', bodyStyle: 'MOTO_SCOOTER', doors: 0, categoryHint: 'MOTO'),
    CatalogVehicleModelEntry(model: 'Lander 250 ABS', bodyStyle: 'MOTO_TRAIL', doors: 0, categoryHint: 'MOTO'),
    CatalogVehicleModelEntry(model: 'Crosser 150 Z', bodyStyle: 'MOTO_TRAIL', doors: 0, categoryHint: 'MOTO'),
  ],
  'Bajaj': [
    CatalogVehicleModelEntry(model: 'Dominar 400', bodyStyle: 'MOTO_STREET', doors: 0, categoryHint: 'MOTO'),
    CatalogVehicleModelEntry(model: 'Dominar 200', bodyStyle: 'MOTO_STREET', doors: 0, categoryHint: 'MOTO'),
    CatalogVehicleModelEntry(model: 'Dominar 160', bodyStyle: 'MOTO_STREET', doors: 0, categoryHint: 'MOTO'),
  ],
  'Mottu': [
    CatalogVehicleModelEntry(model: 'Sport 110i', bodyStyle: 'MOTO_STREET', doors: 0, categoryHint: 'MOTO'),
  ],
  'Royal Enfield': [
    CatalogVehicleModelEntry(model: 'Meteor 350', bodyStyle: 'MOTO_STREET', doors: 0, categoryHint: 'MOTO'),
    CatalogVehicleModelEntry(model: 'Himalayan 450', bodyStyle: 'MOTO_TRAIL', doors: 0, categoryHint: 'MOTO'),
  ],
};

final Map<String, List<FipeBrand>> _fipeBrandsCache = {};
final Map<String, List<FipeModel>> _fipeModelsCache = {};

String _normText(String input) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  var out = input.toLowerCase().trim();
  for (int i = 0; i < from.length; i++) {
    out = out.replaceAll(from[i], to[i]);
  }
  return out;
}

String cleanFipeBrandName(String raw) {
  final trimmed = raw.trim();
  final lower = trimmed.toLowerCase();
  if (lower == 'vw - volkswagen') return 'Volkswagen';
  if (lower == 'gm - chevrolet') return 'Chevrolet';
  if (lower == 'caoachery' || lower == 'caoa chery') return 'Caoa Chery';
  return trimmed;
}

List<String> getBuiltinBrandsForType(VehicleType type) {
  return type == VehicleType.moto
      ? _builtinMotoModelsByBrand.keys.toList()
      : _builtinCarModelsByBrand.keys.toList();
}

List<CatalogVehicleModelEntry> getBuiltinModelsForBrand(
  String brand,
  VehicleType type,
) {
  final dict =
      type == VehicleType.moto ? _builtinMotoModelsByBrand : _builtinCarModelsByBrand;
  final nb = _normText(brand);
  for (final entry in dict.entries) {
    final ke = _normText(entry.key);
    if (ke == nb || nb.contains(ke) || ke.contains(nb)) {
      return entry.value;
    }
  }
  return const [];
}

class CrossBrandMatch {
  final String brand;
  final CatalogVehicleModelEntry entry;

  const CrossBrandMatch({required this.brand, required this.entry});
}

List<CrossBrandMatch> searchCrossBrandModels(
  String query,
  VehicleType type, {
  int limit = 25,
}) {
  final nq = _normText(query);
  final dict =
      type == VehicleType.moto ? _builtinMotoModelsByBrand : _builtinCarModelsByBrand;
  final results = <CrossBrandMatch>[];
  for (final entry in dict.entries) {
    for (final item in entry.value) {
      if (nq.isEmpty ||
          _normText(item.model).contains(nq) ||
          _normText(entry.key).contains(nq)) {
        results.add(CrossBrandMatch(brand: entry.key, entry: item));
        if (results.length >= limit) return results;
      }
    }
  }
  return results;
}

Future<List<FipeBrand>> fetchFipeBrands(VehicleType type) async {
  final key = type == VehicleType.moto ? 'motos' : 'carros';
  if (_fipeBrandsCache.containsKey(key)) return _fipeBrandsCache[key]!;
  try {
    final uri = Uri.parse('https://parallelum.com.br/fipe/api/v1/$key/marcas');
    final resp = await http.get(uri).timeout(const Duration(seconds: 6));
    if (resp.statusCode == 200) {
      final list = jsonDecode(resp.body) as List<dynamic>;
      final parsed = list
          .whereType<Map<String, dynamic>>()
          .map((e) => FipeBrand(
                codigo: e['codigo']?.toString() ?? '',
                nome: cleanFipeBrandName(e['nome']?.toString() ?? ''),
              ))
          .where((b) => b.codigo.isNotEmpty && b.nome.isNotEmpty)
          .toList();
      _fipeBrandsCache[key] = parsed;
      return parsed;
    }
  } catch (_) {}
  return const [];
}

Future<List<FipeModel>> fetchFipeModelsForBrand(
  VehicleType type,
  String brandCode,
) async {
  final kind = type == VehicleType.moto ? 'motos' : 'carros';
  final cacheKey = '$kind::$brandCode';
  if (_fipeModelsCache.containsKey(cacheKey)) return _fipeModelsCache[cacheKey]!;
  try {
    final uri = Uri.parse(
        'https://parallelum.com.br/fipe/api/v1/$kind/marcas/$brandCode/modelos');
    final resp = await http.get(uri).timeout(const Duration(seconds: 6));
    if (resp.statusCode == 200) {
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = decoded['modelos'] as List<dynamic>? ?? const [];
      final parsed = list
          .whereType<Map<String, dynamic>>()
          .map((e) => FipeModel(
                codigo: (e['codigo'] as num?)?.toInt() ?? 0,
                nome: e['nome']?.toString() ?? '',
              ))
          .where((m) => m.nome.isNotEmpty)
          .toList();
      _fipeModelsCache[cacheKey] = parsed;
      return parsed;
    }
  } catch (_) {}
  return const [];
}
