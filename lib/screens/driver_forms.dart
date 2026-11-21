import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../config/omni_theme.dart';
import '../models/omni_models.dart';
import '../providers/omni_driver_provider.dart';
import '../utils/document_validators.dart';
import '../utils/vehicle_catalog.dart';
import '../utils/vehicle_models_dataset.dart';
import '../widgets/vehicle_autocomplete_field.dart';
import '../widgets/vehicle_image.dart';

/// Formulários Profissionais do Motorista & Veículo — 1:1 com src/components/DriverForms.tsx
class DriverProfileFormCard extends StatefulWidget {
  const DriverProfileFormCard({super.key});

  @override
  State<DriverProfileFormCard> createState() => _DriverProfileFormCardState();
}

class _DriverProfileFormCardState extends State<DriverProfileFormCard> {
  late TextEditingController _nameCtrl;
  late TextEditingController _cpfCtrl;
  late TextEditingController _rgCtrl;
  late TextEditingController _birthCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _cnhCtrl;
  late TextEditingController _cnhExpiryCtrl;
  late TextEditingController _bioCtrl;

  late TextEditingController _cepCtrl;
  late TextEditingController _streetCtrl;
  late TextEditingController _numberCtrl;
  late TextEditingController _compCtrl;
  late TextEditingController _neighCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _stateCtrl;

  late TextEditingController _cnhUfCtrl;
  String _cnhCategory = 'AB';
  bool _loadingCep = false;
  bool _loadingGps = false;
  bool _gpsPrefilled = false;

  late String _lastSyncedName;
  late String _lastSyncedCpf;
  late String _lastSyncedRg;
  late String _lastSyncedBirth;
  late String _lastSyncedCnh;
  late String _lastSyncedCnhExpiry;
  late String _lastSyncedCnhCat;

  @override
  void initState() {
    super.initState();
    final d = context.read<OmniDriverProvider>().driver;
    _lastSyncedName = d.name;
    _lastSyncedCpf = d.cpf;
    _lastSyncedRg = d.rg ?? '';
    _lastSyncedBirth = d.birthDate ?? '1989-07-14';
    _lastSyncedCnh = d.cnhNumber;
    _lastSyncedCnhExpiry = d.cnhExpiry;
    _lastSyncedCnhCat = d.cnhCategory ?? 'AB';

    _nameCtrl = TextEditingController(text: _lastSyncedName);
    _cpfCtrl = TextEditingController(text: _lastSyncedCpf);
    _rgCtrl = TextEditingController(text: _lastSyncedRg);
    _birthCtrl = TextEditingController(text: _lastSyncedBirth);
    _emailCtrl = TextEditingController(text: d.email ?? '');
    _phoneCtrl = TextEditingController(text: d.phone);
    _cnhCtrl = TextEditingController(text: _lastSyncedCnh);
    _cnhExpiryCtrl = TextEditingController(text: _lastSyncedCnhExpiry);
    _bioCtrl = TextEditingController(text: d.bio ?? '');
    _cnhCategory = _lastSyncedCnhCat;
    _cnhUfCtrl = TextEditingController(text: d.cnhIssueState ?? 'SP');

    _cepCtrl = TextEditingController(text: d.address?.cep ?? '');
    _streetCtrl = TextEditingController(text: d.address?.street ?? '');
    _numberCtrl = TextEditingController(text: d.address?.number ?? '');
    _compCtrl = TextEditingController(text: d.address?.complement ?? '');
    _neighCtrl = TextEditingController(text: d.address?.neighborhood ?? '');
    _cityCtrl = TextEditingController(text: d.address?.city ?? '');
    _stateCtrl = TextEditingController(text: d.address?.state ?? 'SP');

    final isDefaultOrEmpty =
        (_streetCtrl.text.trim().isEmpty && _cepCtrl.text.trim().isEmpty) ||
            _streetCtrl.text.toLowerCase().contains('paulista') ||
            _cepCtrl.text.replaceAll(RegExp(r'\D'), '') == '01310100';
    if (isDefaultOrEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _prefillAddressFromGps(context.read<OmniDriverProvider>(),
              silent: true);
        }
      });
    }
  }

  void _syncFromOcrUpdates(OmniDriver d) {
    if (d.name != _lastSyncedName && d.name.isNotEmpty) {
      _lastSyncedName = d.name;
      _nameCtrl.text = d.name;
    }
    if (d.cpf != _lastSyncedCpf && d.cpf.isNotEmpty && !d.cpf.contains('*')) {
      _lastSyncedCpf = d.cpf;
      _cpfCtrl.text = d.cpf;
    }
    final rgNext = d.rg ?? '';
    if (rgNext != _lastSyncedRg && rgNext.isNotEmpty) {
      _lastSyncedRg = rgNext;
      _rgCtrl.text = rgNext;
    }
    final birthNext = d.birthDate ?? '';
    if (birthNext != _lastSyncedBirth && birthNext.isNotEmpty) {
      _lastSyncedBirth = birthNext;
      _birthCtrl.text = birthNext;
    }
    if (d.cnhNumber != _lastSyncedCnh && d.cnhNumber.isNotEmpty) {
      _lastSyncedCnh = d.cnhNumber;
      _cnhCtrl.text = d.cnhNumber;
    }
    if (d.cnhExpiry != _lastSyncedCnhExpiry && d.cnhExpiry.isNotEmpty) {
      _lastSyncedCnhExpiry = d.cnhExpiry;
      _cnhExpiryCtrl.text = d.cnhExpiry;
    }
    final catNext = d.cnhCategory ?? '';
    if (catNext.isNotEmpty && catNext != _lastSyncedCnhCat) {
      _lastSyncedCnhCat = catNext;
      _cnhCategory = catNext;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _cpfCtrl,
      _rgCtrl,
      _birthCtrl,
      _emailCtrl,
      _phoneCtrl,
      _cnhCtrl,
      _cnhExpiryCtrl,
      _cnhUfCtrl,
      _bioCtrl,
      _cepCtrl,
      _streetCtrl,
      _numberCtrl,
      _compCtrl,
      _neighCtrl,
      _cityCtrl,
      _stateCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _lookupCep(OmniDriverProvider p) async {
    setState(() => _loadingCep = true);
    final res = await p.backend.lookupViaCep(_cepCtrl.text);
    if (mounted) {
      setState(() => _loadingCep = false);
      if (res != null) {
        _streetCtrl.text = (res['logradouro'] ?? _streetCtrl.text).toString();
        _neighCtrl.text = (res['bairro'] ?? _neighCtrl.text).toString();
        _cityCtrl.text = (res['localidade'] ?? _cityCtrl.text).toString();
        _stateCtrl.text = (res['uf'] ?? _stateCtrl.text).toString();
        p.addAlert('CEP Encontrado', 'Endereço preenchido via ViaCEP.', 'success');
      } else {
        p.addAlert('CEP não encontrado', 'Verifique os 8 dígitos do CEP.', 'warning');
      }
    }
  }

  Future<void> _prefillAddressFromGps(
    OmniDriverProvider p, {
    bool silent = false,
  }) async {
    setState(() => _loadingGps = true);
    double lat = p.driverLocation.latitude;
    double lng = p.driverLocation.longitude;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.always ||
            perm == LocationPermission.whileInUse) {
          try {
            final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 8),
            );
            lat = pos.latitude;
            lng = pos.longitude;
          } catch (_) {
            final last = await Geolocator.getLastKnownPosition();
            if (last != null) {
              lat = last.latitude;
              lng = last.longitude;
            }
          }
        }
      }
    } catch (_) {
      // mantém fallback p.driver.currentLocation
    }

    final res = await p.backend.reverseGeocode(lat, lng);
    if (!mounted) return;
    setState(() => _loadingGps = false);
    if (res != null) {
      if ((res['cep'] ?? '').isNotEmpty) _cepCtrl.text = res['cep']!;
      if ((res['street'] ?? '').isNotEmpty) _streetCtrl.text = res['street']!;
      if ((res['number'] ?? '').isNotEmpty) {
        _numberCtrl.text = res['number']!;
      } else if (_numberCtrl.text.trim().isEmpty) {
        _numberCtrl.text = 'S/N';
      }
      if ((res['neighborhood'] ?? '').isNotEmpty) {
        _neighCtrl.text = res['neighborhood']!;
      }
      if ((res['city'] ?? '').isNotEmpty) _cityCtrl.text = res['city']!;
      if ((res['state'] ?? '').isNotEmpty) _stateCtrl.text = res['state']!;

      // Persiste imediatamente o endereço atualizado via GPS no perfil
      p.updateDriverProfile(
        p.driver.copyWith(
          address: DriverAddress(
            cep: _cepCtrl.text.trim(),
            street: _streetCtrl.text.trim(),
            number: _numberCtrl.text.trim().isEmpty
                ? 'S/N'
                : _numberCtrl.text.trim(),
            complement: _compCtrl.text.trim(),
            neighborhood: _neighCtrl.text.trim(),
            city: _cityCtrl.text.trim(),
            state: _stateCtrl.text.trim().toUpperCase(),
          ),
        ),
      );

      setState(() => _gpsPrefilled = true);
      if (!silent) {
        p.addAlert(
          'Endereço via GPS',
          'Endereço atualizado pela sua localização atual (${_cityCtrl.text}/${_stateCtrl.text})! Você pode editar qualquer campo.',
          'success',
        );
      }
    } else if (!silent) {
      p.addAlert(
        'GPS Indisponível',
        'Não foi possível obter o endereço pelo GPS agora. Use o CEP ou preencha manualmente.',
        'warning',
      );
    }
  }

  void _save(OmniDriverProvider p) {
    if (!isValidBrazilianCpf(_cpfCtrl.text)) {
      p.addAlert('CPF Inválido', 'O CPF informado não passou no dígito verificador Módulo 11.', 'danger');
      return;
    }
    if (!isValidBrazilianCnhNumber(_cnhCtrl.text)) {
      p.addAlert('CNH Inválida', 'O registro CNH deve ter 11 dígitos válidos (SENATRAN).', 'danger');
      return;
    }
    final age = calculateAgeFromIso(_birthCtrl.text);
    if (age != null && age < 21) {
      p.addAlert('Idade Mínima', 'Motoristas OMNI devem possuir 21 anos ou mais.', 'danger');
      return;
    }

    final updated = p.driver.copyWith(
      name: _nameCtrl.text.trim(),
      cpf: formatCpfInput(_cpfCtrl.text),
      rg: _rgCtrl.text.trim(),
      birthDate: _birthCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      cnhNumber: _cnhCtrl.text.replaceAll(RegExp(r'\D'), ''),
      cnhCategory: _cnhCategory,
      cnhExpiry: _cnhExpiryCtrl.text.trim(),
      cnhIssueState: _cnhUfCtrl.text.trim().toUpperCase(),
      bio: _bioCtrl.text.trim(),
      address: DriverAddress(
        cep: formatCepInput(_cepCtrl.text),
        street: _streetCtrl.text.trim(),
        number: _numberCtrl.text.trim(),
        complement: _compCtrl.text.trim(),
        neighborhood: _neighCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        state: _stateCtrl.text.trim().toUpperCase(),
      ),
    );
    p.updateDriverProfile(updated);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();
    _syncFromOcrUpdates(p.driver);
    final hasOcrAutoFill = p.documents.any((d) {
      final v = d.aiAudit?.extractedValidation;
      return d.status == 'APPROVED' &&
          v != null &&
          ((v.fullName?.isNotEmpty == true) ||
              (v.birthDateIso?.isNotEmpty == true) ||
              (v.cpfDigits?.isNotEmpty == true) ||
              (v.rgNumber?.isNotEmpty == true));
    });
    final cpfOk = isValidBrazilianCpf(_cpfCtrl.text);
    final cnhOk = isValidBrazilianCnhNumber(_cnhCtrl.text);
    final age = calculateAgeFromIso(_birthCtrl.text);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: OmniTheme.neonCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_rounded, color: OmniTheme.neonCyan, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Dados Pessoais, CNH & Endereço',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              if (hasOcrAutoFill)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: OmniTheme.alpha(OmniTheme.neonEmerald, 0.16),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                        color: OmniTheme.alpha(OmniTheme.neonEmerald, 0.45)),
                  ),
                  child: const Text(
                    'Via OCR ✓',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: OmniTheme.neonEmerald,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          _FormTextField(label: 'Nome Completo', controller: _nameCtrl),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _FormTextField(
                  label: cpfOk ? 'CPF (Módulo 11 ✓)' : 'CPF (Inválido)',
                  controller: _cpfCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FormTextField(label: 'RG / Órgão', controller: _rgCtrl),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _FormTextField(
                  label: age != null ? 'Nascimento ($age anos)' : 'Nascimento (AAAA-MM-DD)',
                  controller: _birthCtrl,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FormTextField(
                  label: 'Celular / WhatsApp',
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          _FormTextField(
            label: 'E-mail Corporativo / Pessoal',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: _FormTextField(
                  label: cnhOk ? 'Registro CNH (11 dig ✓)' : 'Registro CNH (Inválido)',
                  controller: _cnhCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _cnhCategory,
                  dropdownColor: OmniTheme.slate900,
                  decoration: const InputDecoration(labelText: 'Cat.'),
                  items: const ['A', 'B', 'AB', 'AC', 'AD', 'AE', 'C', 'D', 'E']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _cnhCategory = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _FormTextField(
                    label: 'Validade CNH (AAAA-MM-DD)',
                    controller: _cnhExpiryCtrl),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FormTextField(
                  label: 'UF CNH',
                  controller: _cnhUfCtrl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Pré-preenchimento GPS editável + CEP + ViaCEP
          Row(
            children: [
              const Icon(Icons.my_location_rounded,
                  size: 14, color: OmniTheme.neonCyan),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _gpsPrefilled
                      ? 'Endereço via GPS ✓ (editável)'
                      : 'Endereço Residencial',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: OmniTheme.neonCyan,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _loadingGps
                    ? null
                    : () => _prefillAddressFromGps(p, silent: false),
                icon: _loadingGps
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.gps_fixed_rounded, size: 14),
                label: Text(
                  _loadingGps ? 'Localizando...' : 'Usar GPS Atual',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: OmniTheme.neonCyan,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _FormTextField(
                  label: 'CEP Residencial',
                  controller: _cepCtrl,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _loadingCep ? null : () => _lookupCep(p),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                child: _loadingCep
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Buscar CEP'),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                flex: 3,
                child: _FormTextField(label: 'Logradouro / Rua', controller: _streetCtrl),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FormTextField(label: 'Nº', controller: _numberCtrl),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _FormTextField(label: 'Bairro', controller: _neighCtrl),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FormTextField(label: 'Cidade', controller: _cityCtrl),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 64,
                child: _FormTextField(label: 'UF', controller: _stateCtrl),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _FormTextField(label: 'Complemento', controller: _compCtrl),
          const SizedBox(height: 10),
          _FormTextField(
            label: 'Bio Profissional (exibida ao passageiro)',
            controller: _bioCtrl,
            maxLines: 2,
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _save(p),
              icon: const Icon(Icons.save_rounded, size: 17),
              label: const Text('Salvar Dados Pessoais & Endereço'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DriverFinanceAndSafetyFormCard extends StatefulWidget {
  const DriverFinanceAndSafetyFormCard({super.key});

  @override
  State<DriverFinanceAndSafetyFormCard> createState() =>
      _DriverFinanceAndSafetyFormCardState();
}

class _DriverFinanceAndSafetyFormCardState
    extends State<DriverFinanceAndSafetyFormCard> {
  late TextEditingController _pixKeyCtrl;
  late TextEditingController _bankCtrl;
  late TextEditingController _agencyCtrl;
  late TextEditingController _accountCtrl;
  late TextEditingController _sosNameCtrl;
  late TextEditingController _sosRelCtrl;
  late TextEditingController _sosPhoneCtrl;

  String _pixType = 'CPF';
  String _accountType = 'CORRENTE';
  bool _acceptPass = true;
  bool _acceptDeliv = true;
  bool _acceptPriv = true;
  bool _acceptCash = true;
  bool _hasEar = true;
  double _maxRadius = 18;

  @override
  void initState() {
    super.initState();
    final d = context.read<OmniDriverProvider>().driver;
    _pixType = d.bankPayout?.pixKeyType ?? 'CPF';
    _pixKeyCtrl = TextEditingController(text: d.bankPayout?.pixKey ?? d.cpf);
    _bankCtrl = TextEditingController(text: d.bankPayout?.bankName ?? '');
    _agencyCtrl = TextEditingController(text: d.bankPayout?.agency ?? '');
    _accountCtrl = TextEditingController(text: d.bankPayout?.account ?? '');
    _accountType = d.bankPayout?.accountType ?? 'CORRENTE';

    _sosNameCtrl =
        TextEditingController(text: d.emergencyContact?.name ?? '');
    _sosRelCtrl =
        TextEditingController(text: d.emergencyContact?.relationship ?? '');
    _sosPhoneCtrl =
        TextEditingController(text: d.emergencyContact?.phone ?? '');

    _acceptPass = d.workPreferences?.acceptsPassengers ?? true;
    _acceptDeliv = d.workPreferences?.acceptsDeliveries ?? true;
    _acceptPriv = d.workPreferences?.acceptsPrivateTrips ?? true;
    _acceptCash = d.workPreferences?.acceptsCash ?? true;
    _hasEar = d.workPreferences?.hasEar ?? true;
    _maxRadius = d.workPreferences?.maxRadiusKm ?? 18.0;
  }

  @override
  void dispose() {
    for (final c in [
      _pixKeyCtrl,
      _bankCtrl,
      _agencyCtrl,
      _accountCtrl,
      _sosNameCtrl,
      _sosRelCtrl,
      _sosPhoneCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save(OmniDriverProvider p) {
    p.updateDriverProfile(
      p.driver.copyWith(
        bankPayout: DriverBankPayout(
          pixKeyType: _pixType,
          pixKey: _pixKeyCtrl.text.trim(),
          bankName: _bankCtrl.text.trim(),
          agency: _agencyCtrl.text.trim(),
          account: _accountCtrl.text.trim(),
          accountType: _accountType,
        ),
        emergencyContact: DriverEmergencyContact(
          name: _sosNameCtrl.text.trim(),
          relationship: _sosRelCtrl.text.trim(),
          phone: _sosPhoneCtrl.text.trim(),
        ),
        workPreferences: DriverWorkPreferences(
          acceptsPassengers: _acceptPass,
          acceptsDeliveries: _acceptDeliv,
          acceptsPrivateTrips: _acceptPriv,
          acceptsCash: _acceptCash,
          hasEar: _hasEar,
          maxRadiusKm: _maxRadius,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: OmniTheme.neonCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_rounded,
                  color: OmniTheme.neonEmerald, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dados Bancários PIX, SOS & Preferências',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _pixType,
                  dropdownColor: OmniTheme.slate900,
                  decoration: const InputDecoration(labelText: 'Tipo Chave PIX'),
                  items: const ['CPF', 'EMAIL', 'PHONE', 'RANDOM']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _pixType = v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _FormTextField(label: 'Chave PIX', controller: _pixKeyCtrl),
              ),
            ],
          ),
          const SizedBox(height: 10),

          _FormTextField(label: 'Banco (Código e Nome)', controller: _bankCtrl),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _FormTextField(label: 'Agência', controller: _agencyCtrl)),
              const SizedBox(width: 8),
              Expanded(
                  child: _FormTextField(label: 'Conta', controller: _accountCtrl)),
            ],
          ),
          const SizedBox(height: 14),

          const Text(
            'Contato de Emergência (Botão SOS)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: OmniTheme.neonRose,
            ),
          ),
          const SizedBox(height: 8),
          _FormTextField(label: 'Nome Completo Contato', controller: _sosNameCtrl),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _FormTextField(
                      label: 'Parentesco', controller: _sosRelCtrl)),
              const SizedBox(width: 8),
              Expanded(
                  child: _FormTextField(
                      label: 'Telefone SOS', controller: _sosPhoneCtrl)),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            'Raio Máximo de Chamadas: ${_maxRadius.round()} km',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: OmniTheme.neonCyan),
          ),
          Slider(
            value: _maxRadius,
            min: 3,
            max: 50,
            divisions: 47,
            activeColor: OmniTheme.neonCyan,
            onChanged: (v) => setState(() => _maxRadius = v),
          ),

          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Aceitar Corridas de Passageiros',
                style: TextStyle(fontSize: 12)),
            value: _acceptPass,
            activeColor: OmniTheme.neonCyan,
            onChanged: (v) => setState(() => _acceptPass = v),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Aceitar Entregas Expressas (Flash)',
                style: TextStyle(fontSize: 12)),
            value: _acceptDeliv,
            activeColor: OmniTheme.neonCyan,
            onChanged: (v) => setState(() => _acceptDeliv = v),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Observação EAR na CNH Ativa',
                style: TextStyle(fontSize: 12)),
            value: _hasEar,
            activeColor: OmniTheme.neonEmerald,
            onChanged: (v) => setState(() => _hasEar = v),
          ),
          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _save(p),
              icon: const Icon(Icons.save_rounded, size: 17),
              label: const Text('Salvar Financeiro, SOS & Preferências'),
              style: ElevatedButton.styleFrom(
                backgroundColor: OmniTheme.neonEmerald,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Formulário de Cadastro / Edição de Veículo (Carro ou Moto) com FIPE Autocompletar e Foto Real
class VehicleRegistrationForm extends StatefulWidget {
  final OmniVehicle? initialVehicle;
  final VoidCallback onDone;
  final VoidCallback? onCancel;

  const VehicleRegistrationForm({
    super.key,
    this.initialVehicle,
    required this.onDone,
    this.onCancel,
  });

  @override
  State<VehicleRegistrationForm> createState() =>
      _VehicleRegistrationFormState();
}

class _VehicleRegistrationFormState extends State<VehicleRegistrationForm> {
  late VehicleType _type;
  late VehicleCategory _category;
  late TextEditingController _brandCtrl;
  late TextEditingController _modelCtrl;
  late TextEditingController _yearCtrl;
  late TextEditingController _plateCtrl;
  late TextEditingController _colorCtrl;
  late TextEditingController _renavamCtrl;
  late TextEditingController _chassiCtrl;
  late TextEditingController _crlvCtrl;
  late TextEditingController _insuranceCompanyCtrl;
  late TextEditingController _insurancePolicyCtrl;
  late bool _insuranceAppActive;
  late bool _inspection360Completed;
  late bool _isActive;
  late int _doors;

  List<FipeBrand> _fipeBrands = const [];
  List<FipeModel> _fipeModels = const [];
  bool _loadingFipe = false;

  @override
  void initState() {
    super.initState();
    final v = widget.initialVehicle;
    _type = v?.type ?? VehicleType.car;
    _category = v?.category ?? VehicleCategory.omniX;
    _brandCtrl = TextEditingController(text: v?.brand ?? '');
    _modelCtrl = TextEditingController(text: v?.model ?? '');
    _yearCtrl = TextEditingController(text: (v?.year ?? 2024).toString());
    _plateCtrl = TextEditingController(text: v?.plate ?? '');
    _colorCtrl = TextEditingController(text: v?.color ?? 'Prata Metálico');
    _renavamCtrl = TextEditingController(text: v?.renavam ?? '');
    _chassiCtrl = TextEditingController(text: v?.chassi ?? '');
    _crlvCtrl = TextEditingController(text: v?.crlvExpiry ?? '2026-12-30');
    _insuranceCompanyCtrl =
        TextEditingController(text: v?.insuranceCompany ?? '');
    _insurancePolicyCtrl =
        TextEditingController(text: v?.insurancePolicy ?? '');
    _insuranceAppActive = v?.insuranceAppActive ?? true;
    _inspection360Completed = v?.inspection360Completed ?? false;
    _isActive = v?.isActive ?? true;
    _doors = v?.doors ?? (_type == VehicleType.moto ? 0 : 4);
    _loadFipeBrands();
  }

  @override
  void dispose() {
    for (final c in [
      _brandCtrl,
      _modelCtrl,
      _yearCtrl,
      _plateCtrl,
      _colorCtrl,
      _renavamCtrl,
      _chassiCtrl,
      _crlvCtrl,
      _insuranceCompanyCtrl,
      _insurancePolicyCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadFipeBrands() async {
    setState(() => _loadingFipe = true);
    final brands = await fetchFipeBrands(_type);
    if (mounted) {
      setState(() {
        _fipeBrands = brands;
        _loadingFipe = false;
      });
    }
  }

  Future<void> _loadFipeModelsForBrandName(String brandName) async {
    final match = _fipeBrands.cast<FipeBrand?>().firstWhere(
          (b) =>
              b != null &&
              b.nome.toLowerCase() == brandName.trim().toLowerCase(),
          orElse: () => null,
        );
    if (match == null) return;
    setState(() => _loadingFipe = true);
    final models = await fetchFipeModelsForBrand(_type, match.codigo);
    if (mounted) {
      setState(() {
        _fipeModels = models;
        _loadingFipe = false;
      });
    }
  }

  List<ComboboxOption> _brandOptions() {
    final seen = <String>{};
    final out = <ComboboxOption>[];
    for (final b in getBuiltinBrandsForType(_type)) {
      if (seen.add(b.toLowerCase())) {
        out.add(ComboboxOption(value: b, label: b, hint: 'Catálogo OMNI'));
      }
    }
    for (final b in _fipeBrands) {
      if (seen.add(b.nome.toLowerCase())) {
        out.add(ComboboxOption(value: b.nome, label: b.nome, hint: 'FIPE'));
      }
    }
    return out;
  }

  List<ComboboxOption> _modelOptions() {
    final seen = <String>{};
    final out = <ComboboxOption>[];
    for (final entry in getBuiltinModelsForBrand(_brandCtrl.text, _type)) {
      if (seen.add(entry.model.toLowerCase())) {
        out.add(ComboboxOption(
            value: entry.model, label: entry.model, hint: entry.bodyStyle));
      }
    }
    for (final m in _fipeModels) {
      if (seen.add(m.nome.toLowerCase())) {
        out.add(ComboboxOption(value: m.nome, label: m.nome, hint: 'FIPE'));
      }
    }
    if (_brandCtrl.text.trim().isEmpty) {
      for (final cross in searchCrossBrandModels(_modelCtrl.text, _type)) {
        if (seen.add(cross.entry.model.toLowerCase())) {
          out.add(ComboboxOption(
            value: cross.entry.model,
            label: cross.entry.model,
            hint: cross.brand,
          ));
        }
      }
    }
    return out;
  }

  Future<void> _submit(OmniDriverProvider p) async {
    final cleanPlate = _plateCtrl.text.trim().toUpperCase();
    final cleanRenavam = _renavamCtrl.text.replaceAll(RegExp(r'\D'), '');
    final cleanChassi = _chassiCtrl.text.trim().toUpperCase();

    if (_brandCtrl.text.trim().length < 2 ||
        _modelCtrl.text.trim().length < 2 ||
        !isValidBrazilianPlate(cleanPlate)) {
      p.addAlert('Campos Obrigatórios',
          'Informe Marca, Modelo e Placa válida (ABC1D23 ou ABC-1234).', 'warning');
      return;
    }
    if (cleanRenavam.isNotEmpty && !isValidBrazilianRenavam(cleanRenavam)) {
      p.addAlert(
          'RENAVAM Inválido',
          'O RENAVAM deve ter 9 a 11 dígitos válidos pelo Módulo 11 DENATRAN.',
          'danger');
      return;
    }
    if (cleanChassi.isNotEmpty && !isValidBrazilianChassi(cleanChassi)) {
      p.addAlert(
          'Chassi Inválido',
          'O Chassi deve conter 17 caracteres alfanuméricos sem I, O ou Q.',
          'danger');
      return;
    }

    final vehicle = OmniVehicle(
      id: widget.initialVehicle?.id ??
          'veh_${DateTime.now().millisecondsSinceEpoch}',
      type: _type,
      category: _category,
      brand: _brandCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      year: int.tryParse(_yearCtrl.text.trim()) ?? 2024,
      plate: cleanPlate,
      color: _colorCtrl.text.trim(),
      renavam: cleanRenavam,
      chassi: cleanChassi.isEmpty ? null : cleanChassi,
      crlvExpiry: _crlvCtrl.text.trim(),
      doors: _type == VehicleType.moto ? 0 : _doors,
      bodyStyle: inferVehicleBodyStyle(
        type: _type,
        brand: _brandCtrl.text,
        model: _modelCtrl.text,
        doors: _doors,
      ),
      photoUrl: resolveCuratedVehiclePhoto(_brandCtrl.text, _modelCtrl.text),
      insuranceCompany: _insuranceCompanyCtrl.text.trim().isEmpty
          ? null
          : _insuranceCompanyCtrl.text.trim(),
      insurancePolicy: _insurancePolicyCtrl.text.trim().isEmpty
          ? null
          : _insurancePolicyCtrl.text.trim(),
      insuranceAppActive: _insuranceAppActive,
      inspection360Completed: _inspection360Completed,
      inspection360Date: _inspection360Completed
          ? (widget.initialVehicle?.inspection360Date ??
              DateTime.now().toIso8601String())
          : null,
      status: 'APPROVED',
      isActive: _isActive,
      deepAudit: widget.initialVehicle?.deepAudit,
    );

    if (widget.initialVehicle != null) {
      await p.updateVehicle(vehicle);
    } else {
      await p.addVehicle(vehicle);
    }
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();
    final isEditing = widget.initialVehicle != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OmniTheme.slate950,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: OmniTheme.alpha(OmniTheme.neonCyan, 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEditing ? 'Editar Veículo Cadastrado' : 'Cadastrar Novo Veículo',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: OmniTheme.neonCyan,
            ),
          ),
          const SizedBox(height: 10),

          // Preview em tempo real do modelo digitado
          VehicleImage(
            type: _type,
            brand: _brandCtrl.text.isEmpty ? 'Toyota' : _brandCtrl.text,
            model: _modelCtrl.text.isEmpty ? 'Corolla' : _modelCtrl.text,
            color: _colorCtrl.text,
            doors: _doors,
            height: 92,
          ),
          const SizedBox(height: 10),

          // Toggle Carro / Moto
          Row(
            children: [
              Expanded(
                child: _TypeSelectBtn(
                  label: 'Carro (Passeio)',
                  icon: Icons.directions_car_rounded,
                  selected: _type == VehicleType.car,
                  onTap: () {
                    setState(() {
                      _type = VehicleType.car;
                      _doors = 4;
                      _category = VehicleCategory.omniX;
                      _fipeModels = const [];
                    });
                    _loadFipeBrands();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TypeSelectBtn(
                  label: 'Motocicleta',
                  icon: Icons.two_wheeler_rounded,
                  selected: _type == VehicleType.moto,
                  onTap: () {
                    setState(() {
                      _type = VehicleType.moto;
                      _doors = 0;
                      _category = VehicleCategory.omniMoto;
                      _fipeModels = const [];
                    });
                    _loadFipeBrands();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          VehicleAutocompleteField(
            label: 'Marca (FIPE + OMNI)',
            value: _brandCtrl.text,
            placeholder: 'Ex: Toyota, Honda, Chevrolet...',
            options: _brandOptions(),
            isLoading: _loadingFipe,
            onChanged: (v) => setState(() => _brandCtrl.text = v),
            onSelectOption: (opt) {
              setState(() => _brandCtrl.text = opt.value);
              _loadFipeModelsForBrandName(opt.value);
            },
          ),
          const SizedBox(height: 10),

          VehicleAutocompleteField(
            label: 'Modelo (FIPE + OMNI)',
            value: _modelCtrl.text,
            placeholder: 'Ex: Corolla XEi 2.0, CG 160 Titan...',
            options: _modelOptions(),
            isLoading: _loadingFipe,
            onChanged: (v) => setState(() => _modelCtrl.text = v),
            onSelectOption: (opt) {
              setState(() {
                _modelCtrl.text = opt.value;
                if (_brandCtrl.text.trim().isEmpty && opt.hint != null) {
                  _brandCtrl.text = opt.hint!;
                }
              });
            },
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _FormTextField(
                  label: 'Placa Mercosul',
                  controller: _plateCtrl,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 82,
                child: _FormTextField(
                  label: 'Ano',
                  controller: _yearCtrl,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _FormTextField(
                  label: 'Cor',
                  controller: _colorCtrl,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<VehicleCategory>(
                  value: _category,
                  dropdownColor: OmniTheme.slate900,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: VehicleCategory.values
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(formatVehicleCategoryLabel(c),
                                style: const TextStyle(fontSize: 12)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _category = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _FormTextField(
                  label: 'RENAVAM (9-11 dígitos)',
                  controller: _renavamCtrl,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FormTextField(
                  label: 'Validade CRLV',
                  controller: _crlvCtrl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          _FormTextField(
            label: 'Chassi (opcional — 17 caracteres)',
            controller: _chassiCtrl,
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                flex: 3,
                child: _FormTextField(
                  label: 'Seguradora (Seguro APP)',
                  controller: _insuranceCompanyCtrl,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _FormTextField(
                  label: 'Nº Apólice APP',
                  controller: _insurancePolicyCtrl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Seguro APP Passageiros Vigente',
                style: TextStyle(fontSize: 12)),
            value: _insuranceAppActive,
            activeColor: OmniTheme.neonEmerald,
            onChanged: (v) => setState(() => _insuranceAppActive = v),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text(
                'Vistoria Fotográfica 360° Concluída (Pneus, Luzes & Lataria)',
                style: TextStyle(fontSize: 12)),
            value: _inspection360Completed,
            activeColor: OmniTheme.neonEmerald,
            onChanged: (v) => setState(() => _inspection360Completed = v),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Definir como Veículo Ativo para Corridas',
                style: TextStyle(fontSize: 12)),
            value: _isActive,
            activeColor: OmniTheme.neonCyan,
            onChanged: (v) => setState(() => _isActive = v),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              if (widget.onCancel != null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OmniTheme.slate300,
                      side: const BorderSide(color: OmniTheme.slate700),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => _submit(p),
                  icon: const Icon(Icons.check_rounded, size: 17),
                  label: Text(
                      isEditing ? 'Salvar Alterações' : 'Cadastrar Veículo'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeSelectBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeSelectBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? OmniTheme.alpha(OmniTheme.neonCyan, 0.16)
              : OmniTheme.slate900,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? OmniTheme.neonCyan : OmniTheme.slate800,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? OmniTheme.neonCyan : OmniTheme.slate400),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? OmniTheme.neonCyan : OmniTheme.slate300,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _FormTextField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: OmniTheme.slate400,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 12.5, color: OmniTheme.textPrimary),
        ),
      ],
    );
  }
}
