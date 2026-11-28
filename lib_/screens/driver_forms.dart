import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../config/omni_theme.dart';
import '../models/omni_models.dart';
import '../providers/omni_driver_provider.dart';
import '../services/behavioral_antifraud_engine.dart';
import '../services/sound_service.dart';
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
  String _cnhCategory = '';
  bool _loadingCep = false;
  bool _loadingGps = false;
  bool _gpsPrefilled = false;
  bool _saving = false;
  String? _feedbackMsg;
  bool _feedbackIsError = false;
  String? _gpsStatusMsg;
  bool _gpsStatusIsError = false;
  Timer? _feedbackTimer;

  late String _lastSyncedName;
  late String _lastSyncedCpf;
  late String _lastSyncedRg;
  late String _lastSyncedBirth;
  late String _lastSyncedCnh;
  late String _lastSyncedCnhExpiry;
  late String _lastSyncedCnhCat;
  late String _lastSyncedEmail;
  late String _lastSyncedPhone;
  late String _lastSyncedCnhUf;
  late String _lastSyncedBio;
  late String _lastSyncedAddrSig;

  String _addrSignature(DriverAddress? addr) {
    if (addr == null) return '';
    return '${addr.cep}|${addr.street}|${addr.number}|${addr.complement ?? ''}|${addr.neighborhood}|${addr.city}|${addr.state}';
  }

  String _normalizeDateInputToIso(String raw) {
    final trimmed = raw.trim();
    final brMatch = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
    if (brMatch != null) {
      return '${brMatch.group(3)}-${brMatch.group(2)}-${brMatch.group(1)}';
    }
    return trimmed;
  }

  @override
  void initState() {
    super.initState();
    final d = context.read<OmniDriverProvider>().driver;
    _lastSyncedName = d.name;
    _lastSyncedCpf = d.cpf;
    _lastSyncedRg = d.rg ?? '';
    _lastSyncedBirth = d.birthDate ?? '';
    _lastSyncedCnh = d.cnhNumber;
    _lastSyncedCnhExpiry = d.cnhExpiry;
    _lastSyncedCnhCat = d.cnhCategory ?? '';
    _lastSyncedEmail = d.email ?? '';
    _lastSyncedPhone = d.phone;
    _lastSyncedCnhUf = d.cnhIssueState ?? '';
    _lastSyncedBio = d.bio ?? '';
    _lastSyncedAddrSig = _addrSignature(d.address);

    _nameCtrl = TextEditingController(text: _lastSyncedName);
    _cpfCtrl = TextEditingController(text: _lastSyncedCpf);
    _rgCtrl = TextEditingController(text: _lastSyncedRg);
    _birthCtrl = TextEditingController(text: _lastSyncedBirth);
    _emailCtrl = TextEditingController(text: _lastSyncedEmail);
    _phoneCtrl = TextEditingController(text: _lastSyncedPhone);
    _cnhCtrl = TextEditingController(text: _lastSyncedCnh);
    _cnhExpiryCtrl = TextEditingController(text: _lastSyncedCnhExpiry);
    _bioCtrl = TextEditingController(text: _lastSyncedBio);
    _cnhCategory = _lastSyncedCnhCat;
    _cnhUfCtrl = TextEditingController(text: _lastSyncedCnhUf);

    _cepCtrl = TextEditingController(text: d.address?.cep ?? '');
    _streetCtrl = TextEditingController(text: d.address?.street ?? '');
    _numberCtrl = TextEditingController(text: d.address?.number ?? '');
    _compCtrl = TextEditingController(text: d.address?.complement ?? '');
    _neighCtrl = TextEditingController(text: d.address?.neighborhood ?? '');
    _cityCtrl = TextEditingController(text: d.address?.city ?? '');
    _stateCtrl = TextEditingController(text: d.address?.state ?? '');

    final isAddressEmpty =
        _streetCtrl.text.trim().isEmpty && _cepCtrl.text.trim().isEmpty;
    if (isAddressEmpty) {
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
    final emailNext = d.email ?? '';
    if (emailNext.isNotEmpty && emailNext != _lastSyncedEmail) {
      _lastSyncedEmail = emailNext;
      _emailCtrl.text = emailNext;
    }
    if (d.phone.isNotEmpty && d.phone != _lastSyncedPhone) {
      _lastSyncedPhone = d.phone;
      _phoneCtrl.text = d.phone;
    }
    final ufNext = d.cnhIssueState ?? '';
    if (ufNext.isNotEmpty && ufNext != _lastSyncedCnhUf) {
      _lastSyncedCnhUf = ufNext;
      _cnhUfCtrl.text = ufNext;
    }
    final bioNext = d.bio ?? '';
    if (bioNext.isNotEmpty && bioNext != _lastSyncedBio) {
      _lastSyncedBio = bioNext;
      _bioCtrl.text = bioNext;
    }

    final addrSig = _addrSignature(d.address);
    if (addrSig != _lastSyncedAddrSig && d.address != null) {
      _lastSyncedAddrSig = addrSig;
      _cepCtrl.text = d.address!.cep;
      _streetCtrl.text = d.address!.street;
      _numberCtrl.text = d.address!.number;
      _compCtrl.text = d.address!.complement ?? '';
      _neighCtrl.text = d.address!.neighborhood;
      _cityCtrl.text = d.address!.city;
      _stateCtrl.text = d.address!.state;
    }
  }

  void _showFormFeedback(String msg, {bool isError = false}) {
    _feedbackTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _feedbackMsg = msg;
      _feedbackIsError = isError;
    });

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              isError ? OmniTheme.rose500 : OmniTheme.neonEmerald,
          content: Text(
            msg,
            style: TextStyle(
              color: isError ? Colors.white : const Color(0xFF05080F),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }

    if (!isError) {
      _feedbackTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _feedbackMsg = null);
      });
    }
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
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
    FocusScope.of(context).unfocus();
    final clean = _cepCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (clean.length != 8) {
      const msg = 'Informe um CEP válido com 8 dígitos para buscar o endereço.';
      setState(() {
        _gpsStatusMsg = msg;
        _gpsStatusIsError = true;
      });
      _showFormFeedback(msg, isError: true);
      p.addAlert('CEP Inválido', msg, 'warning');
      return;
    }

    setState(() {
      _loadingCep = true;
      _gpsStatusMsg = null;
    });
    final res = await p.backend.lookupViaCep(clean);
    if (!mounted) return;

    setState(() {
      _loadingCep = false;
      if (res != null) {
        final logradouro = (res['logradouro'] ?? '').toString().trim();
        final bairro = (res['bairro'] ?? '').toString().trim();
        final localidade = (res['localidade'] ?? '').toString().trim();
        final uf = (res['uf'] ?? '').toString().trim().toUpperCase();
        final cepFormatted = (res['cep'] ?? formatCepInput(clean)).toString();

        _cepCtrl.text = cepFormatted;
        if (logradouro.isNotEmpty) _streetCtrl.text = logradouro;
        if (bairro.isNotEmpty) _neighCtrl.text = bairro;
        if (localidade.isNotEmpty) _cityCtrl.text = localidade;
        if (uf.isNotEmpty) _stateCtrl.text = uf;
        _gpsStatusMsg =
            'CEP localizado ($localidade/$uf)! Confira o número e salve o formulário.';
        _gpsStatusIsError = false;
      } else {
        _gpsStatusMsg =
            'CEP não encontrado no ViaCEP. Confira os 8 dígitos ou preencha manualmente.';
        _gpsStatusIsError = true;
      }
    });

    if (res != null) {
      await OmniSoundService.playSuccess();
      p.addAlert('CEP Encontrado', 'Endereço preenchido via ViaCEP.', 'success');
      _showFormFeedback('Endereço preenchido pelo CEP!', isError: false);
    } else {
      OmniSoundService.playAlert();
      p.addAlert(
          'CEP não encontrado', 'Verifique os 8 dígitos do CEP.', 'warning');
      _showFormFeedback('CEP não encontrado. Preencha manualmente.',
          isError: true);
    }
  }

  Future<void> _prefillAddressFromGps(
    OmniDriverProvider p, {
    bool silent = false,
  }) async {
    if (_loadingGps) return;
    if (!silent && mounted) {
      FocusScope.of(context).unfocus();
    }

    setState(() {
      _loadingGps = true;
      if (!silent) {
        _gpsStatusMsg =
            'Estabilizando GPS de alta precisão (calibrando coordenadas reais de rua e número)...';
        _gpsStatusIsError = false;
      }
    });

    double? lat;
    double? lng;
    double? accMeters;
    String sourceLabel = 'GPS de alta precisão';

    final fresh = await p.locationService.fetchHighPrecisionLocation(
      snapToRoad: false,
      forceFresh: !silent,
    );
    if (fresh != null) {
      lat = fresh.latitude;
      lng = fresh.longitude;
      accMeters = fresh.accuracyMeters ?? p.locationService.lastAccuracyMeters;
      if (p.locationService.isApproximateLocationWarning) {
        sourceLabel =
            'GPS aproximado (ative Localização Exata nas configurações para precisão de número)';
      } else if (accMeters > 0) {
        sourceLabel = 'GPS ±${accMeters.toStringAsFixed(0)}m';
      }
    } else if (p.locationService.hasRealFix) {
      lat = p.driverLocation.latitude;
      lng = p.driverLocation.longitude;
      sourceLabel = 'última leitura GPS do aparelho';
    }

    if (lat == null || lng == null) {
      if (!mounted) return;
      setState(() {
        _loadingGps = false;
        if (!silent) {
          _gpsStatusMsg =
              'Ative o GPS com Localização Exata do aparelho ou informe seu CEP manualmente.';
          _gpsStatusIsError = true;
        }
      });
      if (!silent) {
        OmniSoundService.playAlert();
        p.addAlert(
          'GPS Indisponível',
          'Ative a localização exata do dispositivo ou busque pelo CEP.',
          'warning',
        );
        _showFormFeedback(
          'Não foi possível obter o GPS exato. Ative a localização do celular ou use Buscar CEP.',
          isError: true,
        );
      }
      return;
    }

    final freeGeo = await p.locationService.reverseGeocodeFree(
      lat,
      lng,
      immediate: true,
    );
    Map<String, String>? res;
    if (freeGeo == null ||
        freeGeo.cep.isEmpty ||
        freeGeo.street.isEmpty ||
        freeGeo.number.isEmpty ||
        freeGeo.city.isEmpty) {
      res = await p.backend.reverseGeocode(lat, lng);
    }
    if (!mounted) return;

    final resolvedCep = (freeGeo?.cep.isNotEmpty == true
            ? freeGeo!.cep
            : (res?['cep'] ?? ''))
        .toString()
        .trim();
    final resolvedStreet = (freeGeo?.street.isNotEmpty == true
            ? freeGeo!.street
            : (res?['street'] ?? ''))
        .toString()
        .trim();
    final resolvedNumber = (freeGeo?.number.isNotEmpty == true
            ? freeGeo!.number
            : (res?['number'] ?? ''))
        .toString()
        .trim();
    final resolvedNeigh = (freeGeo?.neighborhood.isNotEmpty == true
            ? freeGeo!.neighborhood
            : (res?['neighborhood'] ?? ''))
        .toString()
        .trim();
    final resolvedCity = (freeGeo?.city.isNotEmpty == true
            ? freeGeo!.city
            : (res?['city'] ?? ''))
        .toString()
        .trim();
    final resolvedState = (freeGeo?.state.isNotEmpty == true
            ? freeGeo!.state
            : (res?['state'] ?? ''))
        .toString()
        .trim()
        .toUpperCase();

    final hasUsefulAddress = resolvedStreet.isNotEmpty ||
        resolvedCity.isNotEmpty ||
        resolvedCep.isNotEmpty;

    if (hasUsefulAddress) {
      setState(() {
        _loadingGps = false;
        if (resolvedCep.isNotEmpty) {
          _cepCtrl.text = formatCepInput(resolvedCep);
        }
        if (resolvedStreet.isNotEmpty) {
          _streetCtrl.text = resolvedStreet;
        }
        if (resolvedNumber.isNotEmpty) {
          _numberCtrl.text = resolvedNumber;
        } else if (_numberCtrl.text.trim().isEmpty) {
          _numberCtrl.text = '';
        }
        if (resolvedNeigh.isNotEmpty) {
          _neighCtrl.text = resolvedNeigh;
        }
        if (resolvedCity.isNotEmpty) _cityCtrl.text = resolvedCity;
        if (resolvedState.isNotEmpty) _stateCtrl.text = resolvedState;

        _gpsPrefilled = true;
        _gpsStatusMsg = resolvedNumber.isNotEmpty
            ? 'Endereço localizado via $sourceLabel: $resolvedStreet, $resolvedNumber (${_cityCtrl.text}/${_stateCtrl.text})'
            : 'Rua localizada via $sourceLabel (${_cityCtrl.text}/${_stateCtrl.text}) — confira o número exato.';
        _gpsStatusIsError = p.locationService.isApproximateLocationWarning;
      });

      final nextAddr = DriverAddress(
        cep: _cepCtrl.text.trim(),
        street: _streetCtrl.text.trim(),
        number: _numberCtrl.text.trim(),
        complement: _compCtrl.text.trim(),
        neighborhood: _neighCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        state: _stateCtrl.text.trim().toUpperCase(),
      );
      _lastSyncedAddrSig = _addrSignature(nextAddr);

      await p.updateDriverProfile(
        p.driver.copyWith(
          operationalCity: (_cityCtrl.text.trim().isNotEmpty &&
                  _stateCtrl.text.trim().isNotEmpty)
              ? '${_cityCtrl.text.trim()} - ${_stateCtrl.text.trim().toUpperCase()}'
              : p.driver.operationalCity,
          address: nextAddr,
        ),
        silent: true,
      );

      if (!silent && mounted) {
        await OmniSoundService.playSuccess();
        final summaryCity = _cityCtrl.text.trim().isNotEmpty
            ? '${_cityCtrl.text.trim()}/${_stateCtrl.text.trim().toUpperCase()}'
            : 'localização atual';
        p.addAlert(
          'Endereço via GPS',
          'Endereço atualizado pela sua $sourceLabel ($summaryCity)! Confira rua e número antes de salvar.',
          'success',
        );
        _showFormFeedback(
          'Endereço preenchido via $sourceLabel ($summaryCity)!',
          isError: false,
        );
      }
    } else {
      setState(() {
        _loadingGps = false;
        if (!silent) {
          _gpsStatusMsg =
              'Serviço de mapa indisponível no momento. Use o CEP ou preencha manualmente.';
          _gpsStatusIsError = true;
        }
      });
      if (!silent) {
        OmniSoundService.playAlert();
        p.addAlert(
          'GPS Indisponível',
          'Não foi possível converter sua localização em endereço agora. Use Buscar CEP.',
          'warning',
        );
        _showFormFeedback(
          'Não foi possível obter o endereço pelo GPS agora. Use Buscar CEP ou preencha manualmente.',
          isError: true,
        );
      }
    }
  }

  Future<void> _save(OmniDriverProvider p) async {
    if (_saving) return;
    FocusScope.of(context).unfocus();

    final cleanName = _nameCtrl.text.trim();
    if (cleanName.length < 3) {
      const msg = 'Informe o nome completo do motorista.';
      OmniSoundService.playAlert();
      p.addAlert('Nome Obrigatório', msg, 'danger');
      _showFormFeedback(msg, isError: true);
      return;
    }

    final rawCpf = _cpfCtrl.text.trim();
    final cpfDigits = rawCpf.replaceAll(RegExp(r'\D'), '');
    final isMaskedCpf = rawCpf.contains('*');
    if (!isMaskedCpf && cpfDigits.isNotEmpty && !isValidBrazilianCpf(cpfDigits)) {
      const msg =
          'O CPF informado não passou no dígito verificador Módulo 11. Confira os 11 dígitos.';
      OmniSoundService.playAlert();
      p.addAlert('CPF Inválido', msg, 'danger');
      _showFormFeedback(msg, isError: true);
      return;
    }

    final cnhDigits = _cnhCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (cnhDigits.isNotEmpty && !isValidBrazilianCnhNumber(cnhDigits)) {
      const msg =
          'O registro CNH deve ter 11 dígitos válidos pelo algoritmo oficial SENATRAN.';
      OmniSoundService.playAlert();
      p.addAlert('CNH Inválida', msg, 'danger');
      _showFormFeedback(msg, isError: true);
      return;
    }

    final birthIso = _normalizeDateInputToIso(_birthCtrl.text);
    final age = calculateAgeFromIso(birthIso);
    if (age != null && age < 21) {
      const msg = 'Motoristas OMNI devem possuir 21 anos completos ou mais.';
      OmniSoundService.playAlert();
      p.addAlert('Idade Mínima', msg, 'danger');
      _showFormFeedback(msg, isError: true);
      return;
    }

    final cleanEmail = _emailCtrl.text.trim();
    if (cleanEmail.isNotEmpty && !cleanEmail.contains('@')) {
      const msg = 'Informe um endereço de e-mail válido.';
      OmniSoundService.playAlert();
      p.addAlert('E-mail Inválido', msg, 'danger');
      _showFormFeedback(msg, isError: true);
      return;
    }

    final cleanStreet = _streetCtrl.text.trim();
    final cleanNeigh = _neighCtrl.text.trim();
    final cleanCity = _cityCtrl.text.trim();
    final cleanState = _stateCtrl.text.trim().toUpperCase();
    final cleanNumber =
        _numberCtrl.text.trim().isEmpty ? 'S/N' : _numberCtrl.text.trim();
    if (cleanStreet.isEmpty || cleanCity.isEmpty || cleanState.length < 2) {
      const msg =
          'Preencha ao menos Logradouro / Rua, Cidade e UF do endereço (ou clique em Usar GPS Atual).';
      OmniSoundService.playAlert();
      p.addAlert('Endereço Incompleto', msg, 'warning');
      _showFormFeedback(msg, isError: true);
      return;
    }

    setState(() {
      _saving = true;
      _feedbackMsg = null;
    });

    final formattedCep = formatCepInput(_cepCtrl.text);
    final resolvedCpf =
        (!isMaskedCpf && cpfDigits.length == 11)
            ? formatCpfInput(cpfDigits)
            : p.driver.cpf;
    final resolvedCnh =
        cnhDigits.isNotEmpty ? cnhDigits : p.driver.cnhNumber;
    final cnhExpiryIso = _normalizeDateInputToIso(_cnhExpiryCtrl.text);
    final nextAddress = DriverAddress(
      cep: formattedCep,
      street: cleanStreet,
      number: cleanNumber,
      complement: _compCtrl.text.trim(),
      neighborhood: cleanNeigh,
      city: cleanCity,
      state: cleanState,
    );

    _lastSyncedName = cleanName;
    _lastSyncedCpf = resolvedCpf;
    _lastSyncedRg = _rgCtrl.text.trim();
    _lastSyncedBirth = birthIso;
    _lastSyncedCnh = resolvedCnh;
    _lastSyncedCnhExpiry = cnhExpiryIso;
    _lastSyncedCnhCat = _cnhCategory;
    _lastSyncedEmail = cleanEmail;
    _lastSyncedPhone = _phoneCtrl.text.trim();
    _lastSyncedCnhUf = _cnhUfCtrl.text.trim().toUpperCase();
    _lastSyncedBio = _bioCtrl.text.trim();
    _lastSyncedAddrSig = _addrSignature(nextAddress);
    _cepCtrl.text = formattedCep;
    _numberCtrl.text = cleanNumber;
    _birthCtrl.text = birthIso;
    _cnhExpiryCtrl.text = cnhExpiryIso;

    final updated = p.driver.copyWith(
      name: cleanName,
      cpf: resolvedCpf,
      rg: _rgCtrl.text.trim(),
      birthDate: birthIso,
      email: cleanEmail,
      phone: _phoneCtrl.text.trim(),
      cnhNumber: resolvedCnh,
      cnhCategory: _cnhCategory,
      cnhExpiry: cnhExpiryIso,
      cnhIssueState: _cnhUfCtrl.text.trim().toUpperCase(),
      operationalCity: '$cleanCity - $cleanState',
      bio: _bioCtrl.text.trim(),
      address: nextAddress,
    );

    try {
      await p.updateDriverProfile(updated);
      if (!mounted) return;
      setState(() => _saving = false);
      _showFormFeedback(
        'Dados pessoais, CNH e endereço salvos com sucesso!',
        isError: false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showFormFeedback(
        'Erro ao salvar os dados localmente. Tente novamente.',
        isError: true,
      );
    }
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
    final rawCpf = _cpfCtrl.text.trim();
    final cpfDigits = rawCpf.replaceAll(RegExp(r'\D'), '');
    final cpfOk = rawCpf.contains('*')
        ? p.driver.cpf.isNotEmpty
        : (cpfDigits.isEmpty || isValidBrazilianCpf(cpfDigits));
    final cnhDigits = _cnhCtrl.text.replaceAll(RegExp(r'\D'), '');
    final cnhOk =
        cnhDigits.isEmpty ? true : isValidBrazilianCnhNumber(cnhDigits);
    final age = calculateAgeFromIso(_normalizeDateInputToIso(_birthCtrl.text));

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
                  label: cpfOk
                      ? (cpfDigits.length == 11 ? 'CPF (Módulo 11 ✓)' : 'CPF')
                      : 'CPF (Inválido)',
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
                  label: cnhOk
                      ? (cnhDigits.length == 11
                          ? 'Registro CNH (11 dig ✓)'
                          : 'Registro CNH (11 dígitos)')
                      : 'Registro CNH (Inválido)',
                  controller: _cnhCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: const [
                    'A',
                    'B',
                    'AB',
                    'AC',
                    'AD',
                    'AE',
                    'C',
                    'D',
                    'E'
                  ].contains(_cnhCategory)
                      ? _cnhCategory
                      : null,
                  dropdownColor: OmniTheme.slate900,
                  decoration: const InputDecoration(
                    labelText: 'Cat.',
                    hintText: 'Selecione',
                  ),
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
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: OmniTheme.neonCyan,
                        ),
                      )
                    : const Icon(Icons.gps_fixed_rounded, size: 14),
                label: Text(
                  _loadingGps ? 'Localizando...' : 'Usar GPS Atual',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: OmniTheme.neonCyan,
                  backgroundColor: OmniTheme.alpha(OmniTheme.neonCyan, 0.12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          if (_gpsStatusMsg != null) ...[
            const SizedBox(height: 6),
            _InlineBanner(
              message: _gpsStatusMsg!,
              isError: _gpsStatusIsError,
            ),
          ],
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
          const SizedBox(height: 12),

          if (_feedbackMsg != null) ...[
            _InlineBanner(
              message: _feedbackMsg!,
              isError: _feedbackIsError,
            ),
            const SizedBox(height: 10),
          ],

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : () => _save(p),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF05080F),
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 17),
              label: Text(
                _saving
                    ? 'Salvando Dados...'
                    : 'Salvar Dados Pessoais & Endereço',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: OmniTheme.neonCyan,
                foregroundColor: const Color(0xFF05080F),
                padding: const EdgeInsets.symmetric(vertical: 14),
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
  bool _saving = false;
  String? _feedbackMsg;
  bool _feedbackIsError = false;
  Timer? _feedbackTimer;
  late String _lastSyncedFinanceSig;

  String _financeSignature(OmniDriver d) {
    final bp = d.bankPayout;
    final ec = d.emergencyContact;
    final wp = d.workPreferences;
    return '${bp?.pixKeyType}|${bp?.pixKey}|${bp?.bankName}|${bp?.agency}|${bp?.account}|${bp?.accountType}|${ec?.name}|${ec?.relationship}|${ec?.phone}|${wp?.acceptsPassengers}|${wp?.acceptsDeliveries}|${wp?.acceptsPrivateTrips}|${wp?.acceptsCash}|${wp?.hasEar}|${wp?.maxRadiusKm}';
  }

  void _syncFromDriver(OmniDriver d) {
    final sig = _financeSignature(d);
    if (sig == _lastSyncedFinanceSig) return;
    _lastSyncedFinanceSig = sig;
    _pixType = d.bankPayout?.pixKeyType ?? 'CPF';
    _pixKeyCtrl.text = d.bankPayout?.pixKey ?? d.cpf;
    _bankCtrl.text = d.bankPayout?.bankName ?? '';
    _agencyCtrl.text = d.bankPayout?.agency ?? '';
    _accountCtrl.text = d.bankPayout?.account ?? '';
    _accountType = d.bankPayout?.accountType ?? 'CORRENTE';
    _sosNameCtrl.text = d.emergencyContact?.name ?? '';
    _sosRelCtrl.text = d.emergencyContact?.relationship ?? '';
    _sosPhoneCtrl.text = d.emergencyContact?.phone ?? '';
    _acceptPass = d.workPreferences?.acceptsPassengers ?? true;
    _acceptDeliv = d.workPreferences?.acceptsDeliveries ?? true;
    _acceptPriv = d.workPreferences?.acceptsPrivateTrips ?? true;
    _acceptCash = d.workPreferences?.acceptsCash ?? true;
    _hasEar = d.workPreferences?.hasEar ?? true;
    _maxRadius = (d.workPreferences?.maxRadiusKm ?? 18.0).clamp(3.0, 50.0);
  }

  @override
  void initState() {
    super.initState();
    final d = context.read<OmniDriverProvider>().driver;
    _lastSyncedFinanceSig = _financeSignature(d);
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
    _maxRadius = (d.workPreferences?.maxRadiusKm ?? 18.0).clamp(3.0, 50.0);
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
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

  void _showFinanceFeedback(String msg, {bool isError = false}) {
    _feedbackTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _feedbackMsg = msg;
      _feedbackIsError = isError;
    });

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              isError ? OmniTheme.rose500 : OmniTheme.neonEmerald,
          content: Text(
            msg,
            style: TextStyle(
              color: isError ? Colors.white : const Color(0xFF05080F),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }

    if (!isError) {
      _feedbackTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _feedbackMsg = null);
      });
    }
  }

  Future<void> _save(OmniDriverProvider p) async {
    if (_saving) return;
    FocusScope.of(context).unfocus();

    final cleanPix = _pixKeyCtrl.text.trim();
    if (cleanPix.length < 3) {
      const msg = 'Informe uma chave PIX válida (mínimo 3 caracteres) para repasses.';
      OmniSoundService.playAlert();
      p.addAlert('Chave PIX Obrigatória', msg, 'warning');
      _showFinanceFeedback(msg, isError: true);
      return;
    }

    final cleanSosPhone = _sosPhoneCtrl.text.trim();
    final sosPhoneDigits = cleanSosPhone.replaceAll(RegExp(r'\D'), '');
    if (cleanSosPhone.isNotEmpty && sosPhoneDigits.length < 10) {
      const msg = 'Informe um telefone SOS completo com DDD (10 ou 11 dígitos).';
      OmniSoundService.playAlert();
      p.addAlert('Telefone SOS Inválido', msg, 'warning');
      _showFinanceFeedback(msg, isError: true);
      return;
    }

    setState(() {
      _saving = true;
      _feedbackMsg = null;
    });

    try {
      final updatedDriver = p.driver.copyWith(
        cnhEar: _hasEar,
        bankPayout: DriverBankPayout(
          pixKeyType: _pixType,
          pixKey: cleanPix,
          bankName: _bankCtrl.text.trim(),
          agency: _agencyCtrl.text.trim(),
          account: _accountCtrl.text.trim(),
          accountType: _accountType,
        ),
        emergencyContact: DriverEmergencyContact(
          name: _sosNameCtrl.text.trim(),
          relationship: _sosRelCtrl.text.trim(),
          phone: cleanSosPhone,
        ),
        workPreferences: DriverWorkPreferences(
          acceptsPassengers: _acceptPass,
          acceptsDeliveries: _acceptDeliv,
          acceptsPrivateTrips: _acceptPriv,
          acceptsCash: _acceptCash,
          acceptsPets: p.driver.workPreferences?.acceptsPets ?? true,
          acceptsLargeLuggage:
              p.driver.workPreferences?.acceptsLargeLuggage ?? true,
          hasEar: _hasEar,
          maxRadiusKm: _maxRadius,
        ),
      );
      _lastSyncedFinanceSig = _financeSignature(updatedDriver);
      await p.updateDriverProfile(updatedDriver);
      if (!mounted) return;
      setState(() => _saving = false);
      _showFinanceFeedback(
        'Dados bancários/PIX, contato SOS e preferências salvos com sucesso!',
        isError: false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showFinanceFeedback(
        'Erro ao salvar financeiro e preferências. Tente novamente.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();
    _syncFromDriver(p.driver);
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

          Row(
            children: [
              Expanded(
                flex: 2,
                child: _FormTextField(
                    label: 'Banco (Código e Nome)', controller: _bankCtrl),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _accountType,
                  dropdownColor: OmniTheme.slate900,
                  decoration: const InputDecoration(labelText: 'Conta'),
                  items: const ['CORRENTE', 'POUPANCA']
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e == 'CORRENTE' ? 'Corrente' : 'Poupança',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _accountType = v);
                  },
                ),
              ),
            ],
          ),
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
                    label: 'Telefone SOS',
                    controller: _sosPhoneCtrl,
                    keyboardType: TextInputType.phone,
                  )),
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
            title: const Text('Receber Propostas de Viagens Particulares',
                style: TextStyle(fontSize: 12)),
            value: _acceptPriv,
            activeColor: OmniTheme.neonCyan,
            onChanged: (v) => setState(() => _acceptPriv = v),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Aceitar Pagamento em Dinheiro',
                style: TextStyle(fontSize: 12)),
            value: _acceptCash,
            activeColor: OmniTheme.neonCyan,
            onChanged: (v) => setState(() => _acceptCash = v),
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

          if (_feedbackMsg != null) ...[
            _InlineBanner(
              message: _feedbackMsg!,
              isError: _feedbackIsError,
            ),
            const SizedBox(height: 10),
          ],

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : () => _save(p),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF05080F),
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 17),
              label: Text(
                _saving
                    ? 'Salvando...'
                    : 'Salvar Financeiro, SOS & Preferências',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: OmniTheme.neonEmerald,
                foregroundColor: const Color(0xFF05080F),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const _InlineBanner({
    required this.message,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError ? OmniTheme.rose500 : OmniTheme.neonEmerald;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: OmniTheme.alpha(color, 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OmniTheme.alpha(color, 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isError ? OmniTheme.rose300 : OmniTheme.neonEmerald,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const List<String> _kBrazilianStates = [
  'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA',
  'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN',
  'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO',
];

/// Formulário Direto de Certidão de Antecedentes Criminais & Declaração (1:1 com CriminalCertificateFormCard em TSX)
class CriminalCertificateFormCard extends StatefulWidget {
  const CriminalCertificateFormCard({super.key});

  @override
  State<CriminalCertificateFormCard> createState() =>
      _CriminalCertificateFormCardState();
}

class _CriminalCertificateFormCardState
    extends State<CriminalCertificateFormCard> {
  String _portal = 'PF';
  late TextEditingController _codeCtrl;
  late TextEditingController _issueDateCtrl;
  String _uf = '';
  bool _selfDeclaredClean = false;
  bool _saving = false;
  String? _feedbackMsg;
  bool _feedbackIsError = false;
  String _lastSyncedSig = '';

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController();
    _issueDateCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _issueDateCtrl.dispose();
    super.dispose();
  }

  void _syncFromDriver(OmniDriver d) {
    final cert = d.criminalCertificate;
    final sig =
        '${cert?.issuingPortal ?? ''}|${cert?.validationCode ?? ''}|${cert?.issueDate ?? ''}|${cert?.ufJurisdiction ?? ''}|${cert?.selfDeclaredClean ?? false}';
    if (sig == _lastSyncedSig) return;
    _lastSyncedSig = sig;
    if (cert != null) {
      _portal = cert.issuingPortal;
      _codeCtrl.text = cert.validationCode;
      _issueDateCtrl.text = cert.issueDate;
      if (_kBrazilianStates.contains(cert.ufJurisdiction)) {
        _uf = cert.ufJurisdiction;
      }
      _selfDeclaredClean = cert.selfDeclaredClean;
    } else if (d.address != null &&
        _kBrazilianStates.contains(d.address!.state.toUpperCase())) {
      _uf = d.address!.state.toUpperCase();
    }
  }

  Future<void> _save(OmniDriverProvider p) async {
    setState(() {
      _saving = true;
      _feedbackMsg = null;
    });
    try {
      final sub = CriminalCertificateSubmission(
        issuingPortal: _portal,
        validationCode: _codeCtrl.text.trim().toUpperCase(),
        issueDate: _issueDateCtrl.text.trim(),
        ufJurisdiction: _uf,
        selfDeclaredClean: _selfDeclaredClean,
      );
      _lastSyncedSig =
          '${sub.issuingPortal}|${sub.validationCode}|${sub.issueDate}|${sub.ufJurisdiction}|${sub.selfDeclaredClean}';
      final res = await p.submitCriminalCertificate(sub);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _feedbackMsg = res.summary;
        _feedbackIsError =
            res.status != 'APPROVED' && res.status != 'IN_REVIEW';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _feedbackMsg = 'Erro ao salvar certidão. Tente novamente.';
        _feedbackIsError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();
    _syncFromDriver(p.driver);
    final bgDoc = p.documents.cast<DriverDocument?>().firstWhere(
          (d) => d?.type == 'BACKGROUND_CHECK',
          orElse: () => null,
        );
    final liveScreening = BehavioralAntifraudEngine.evaluateCriminalCertificate(
      CriminalCertificateSubmission(
        issuingPortal: _portal,
        validationCode: _codeCtrl.text.trim(),
        issueDate: _issueDateCtrl.text.trim(),
        ufJurisdiction: _uf,
        selfDeclaredClean: _selfDeclaredClean,
      ),
      bgDoc,
      driverName: p.driver.name,
    );

    final Color badgeColor = liveScreening.status == 'APPROVED'
        ? OmniTheme.neonEmerald
        : liveScreening.status == 'REJECTED'
            ? OmniTheme.rose500
            : liveScreening.status == 'IN_REVIEW'
                ? OmniTheme.sky400
                : OmniTheme.amber400;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: OmniTheme.neonCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded,
                  color: OmniTheme.neonCyan, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Certidão de Antecedentes Criminais & Declaração',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: OmniTheme.alpha(badgeColor, 0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: OmniTheme.alpha(badgeColor, 0.45)),
                ),
                child: Text(
                  '${BehavioralAntifraudEngine.statusLabel(liveScreening.status).toUpperCase()} (${liveScreening.score}%)',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Envio direto da certidão (PF / Justiça Estadual) e código de conferência pré-aprovação.',
            style: TextStyle(fontSize: 11, color: OmniTheme.slate400),
          ),
          const SizedBox(height: 10),

          // Anexo da Certidão
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: OmniTheme.slate950,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: OmniTheme.slate800),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.description_rounded,
                  size: 18,
                  color: bgDoc?.status == 'APPROVED'
                      ? OmniTheme.neonEmerald
                      : OmniTheme.amber400,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bgDoc?.status == 'APPROVED'
                            ? 'Arquivo da Certidão Anexado'
                            : 'Anexo da Certidão (PDF ou Foto Nítida)',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'Emitida na Polícia Federal ou TJ Estadual (até 90 dias).',
                        style: TextStyle(fontSize: 10, color: OmniTheme.slate400),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: bgDoc == null
                      ? null
                      : () => p.openDocumentCapture(bgDoc.id, autoOpenCamera: true),
                  child: Text(
                    bgDoc?.status == 'APPROVED' ? 'Atualizar' : 'Anexar',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: OmniTheme.neonCyan,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          DropdownButtonFormField<String>(
            value: _portal,
            dropdownColor: OmniTheme.slate900,
            decoration: const InputDecoration(labelText: 'Órgão Emissor *'),
            items: const [
              DropdownMenuItem(value: 'PF', child: Text('Polícia Federal (PF)')),
              DropdownMenuItem(
                  value: 'TJ_ESTADUAL', child: Text('Justiça Estadual (TJ)')),
              DropdownMenuItem(
                  value: 'AMBOS', child: Text('Ambas (PF + TJ Estadual)')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _portal = v);
            },
          ),
          const SizedBox(height: 10),

          _FormTextField(
            label: 'Código de Validação / Autenticação *',
            controller: _codeCtrl,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: _FormTextField(
                  label: 'Data Emissão (AAAA-MM-DD) *',
                  controller: _issueDateCtrl,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _kBrazilianStates.contains(_uf) ? _uf : null,
                  hint: const Text('UF'),
                  dropdownColor: OmniTheme.slate900,
                  decoration: const InputDecoration(labelText: 'UF *'),
                  items: _kBrazilianStates
                      .map((uf) => DropdownMenuItem(value: uf, child: Text(uf)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _uf = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: OmniTheme.neonCyan,
            value: _selfDeclaredClean,
            onChanged: (v) => setState(() => _selfDeclaredClean = v ?? false),
            title: const Text(
              'Declaro sob responsabilidade legal que a certidão anexada e seu código de autenticação são autênticos, emitidos há no máximo 90 dias, e sem impedimentos.',
              style: TextStyle(fontSize: 11, color: OmniTheme.slate200),
            ),
          ),
          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: OmniTheme.slate950,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: OmniTheme.slate800),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Itens de Triagem Inicial:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: OmniTheme.slate300,
                  ),
                ),
                const SizedBox(height: 4),
                ...liveScreening.findings.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '• $f',
                      style: const TextStyle(
                          fontSize: 10.5, color: OmniTheme.slate400),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: OmniTheme.slate950,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: OmniTheme.alpha(OmniTheme.amber400, 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: OmniTheme.amber400, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    BehavioralAntifraudEngine.legalDisclaimer,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: OmniTheme.slate300,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_feedbackMsg != null) ...[
            const SizedBox(height: 10),
            _InlineBanner(
              message: _feedbackMsg!,
              isError: _feedbackIsError,
            ),
          ],
          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : () => _save(p),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF05080F),
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 17),
              label: Text(
                _saving ? 'Salvando...' : 'Salvar Certidão & Declaração',
              ),
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

/// Formulário de Cadastro / Edição de Veículo (Carro ou Moto) com FIPE Autocompletar, CRLV, Vínculo e 5 Fotos
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
  final ImagePicker _picker = ImagePicker();

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
  late TextEditingController _ownerNameCtrl;
  late TextEditingController _ownerDocCtrl;
  late bool _insuranceAppActive;
  late bool _inspection360Completed;
  late bool _isActive;
  late int _doors;

  late String _ownershipType;
  String? _authDocPath;
  String? _authDocName;
  Uint8List? _authDocBytes;
  late VehicleVisualPhotos _visualPhotos;

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
    _yearCtrl = TextEditingController(
        text: (v?.year ?? DateTime.now().year).toString());
    _plateCtrl = TextEditingController(text: v?.plate ?? '');
    _colorCtrl = TextEditingController(text: v?.color ?? '');
    _renavamCtrl = TextEditingController(text: v?.renavam ?? '');
    _chassiCtrl = TextEditingController(text: v?.chassi ?? '');
    _crlvCtrl = TextEditingController(text: v?.crlvExpiry ?? '');
    _insuranceCompanyCtrl =
        TextEditingController(text: v?.insuranceCompany ?? '');
    _insurancePolicyCtrl =
        TextEditingController(text: v?.insurancePolicy ?? '');
    _ownerNameCtrl = TextEditingController(text: v?.ownerName ?? '');
    _ownerDocCtrl = TextEditingController(text: v?.ownerDocument ?? '');
    _ownershipType = v?.ownershipType ?? 'PROPRIO';
    _authDocPath = v?.authorizationDocPath;
    _authDocName = v?.authorizationDocName;
    _authDocBytes = v?.authorizationDocBytes;
    _visualPhotos = v?.visualPhotos ?? const VehicleVisualPhotos();
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
      _ownerNameCtrl,
      _ownerDocCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickVehicleAnglePhoto(
    OmniDriverProvider p,
    String slotKey,
    ImageSource source,
  ) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1280,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final savedPath = await p.persistCapturedMedia(bytes, 'veh_$slotKey');
      if (!mounted) return;
      setState(() {
        switch (slotKey) {
          case 'front':
            _visualPhotos = _visualPhotos.copyWith(front: savedPath);
            break;
          case 'rear':
            _visualPhotos = _visualPhotos.copyWith(rear: savedPath);
            break;
          case 'left_side':
            _visualPhotos = _visualPhotos.copyWith(leftSide: savedPath);
            break;
          case 'right_side':
            _visualPhotos = _visualPhotos.copyWith(rightSide: savedPath);
            break;
          case 'plate':
            _visualPhotos = _visualPhotos.copyWith(plate: savedPath);
            break;
        }
        if (BehavioralAntifraudEngine.countVehiclePhotos(_visualPhotos) >= 5) {
          _inspection360Completed = true;
        }
      });
    } catch (_) {
      p.addAlert('Câmera/Galeria', 'Não foi possível capturar a foto do veículo.', 'warning');
    }
  }

  void _showPhotoSourceSheet(OmniDriverProvider p, String slotKey, String label) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: OmniTheme.slate900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: OmniTheme.neonCyan),
              title: Text('Fotografar ($label)',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickVehicleAnglePhoto(p, slotKey, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: OmniTheme.neonEmerald),
              title: Text('Escolher da Galeria ($label)',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickVehicleAnglePhoto(p, slotKey, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAuthDocument(OmniDriverProvider p) async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;
      final file = res.files.first;
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null && File(file.path!).existsSync()) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (!mounted) return;
      setState(() {
        _authDocPath = file.path ?? 'picked://${file.name}';
        _authDocName = file.name;
        _authDocBytes = bytes;
      });
    } catch (_) {
      p.addAlert('Arquivo', 'Não foi possível selecionar o termo de autorização.', 'warning');
    }
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
    if (_ownershipType != 'PROPRIO') {
      if (_ownerNameCtrl.text.trim().length < 3) {
        p.addAlert('Proprietário',
            'Informe o nome completo / razão social do proprietário.', 'warning');
        return;
      }
      if (!BehavioralAntifraudEngine.isValidCpfOrCnpjDigits(_ownerDocCtrl.text)) {
        p.addAlert('Documento Proprietário',
            'Informe um CPF ou CNPJ válido do proprietário/locadora.', 'danger');
        return;
      }
      final hasAuthDoc = (_authDocPath ?? '').trim().isNotEmpty ||
          (_authDocName ?? '').trim().isNotEmpty ||
          (_authDocBytes != null && _authDocBytes!.isNotEmpty);
      if (!hasAuthDoc) {
        p.addAlert('Autorização',
            'Anexe o termo de autorização de uso ou contrato de locação.', 'warning');
        return;
      }
    }

    final photosCount = BehavioralAntifraudEngine.countVehiclePhotos(_visualPhotos);
    final effectiveInspection = _inspection360Completed || photosCount >= 5;

    final vehicle = OmniVehicle(
      id: widget.initialVehicle?.id ??
          'veh_${DateTime.now().millisecondsSinceEpoch}',
      type: _type,
      category: _category,
      brand: _brandCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      year: int.tryParse(_yearCtrl.text.trim()) ?? 2024,
      color: _colorCtrl.text.trim(),
      plate: cleanPlate,
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
      inspection360Completed: effectiveInspection,
      inspection360Date: effectiveInspection
          ? (widget.initialVehicle?.inspection360Date ??
              DateTime.now().toIso8601String())
          : null,
      status: 'APPROVED',
      isActive: _isActive,
      ownershipType: _ownershipType,
      ownerName:
          _ownershipType == 'PROPRIO' ? null : _ownerNameCtrl.text.trim(),
      ownerDocument:
          _ownershipType == 'PROPRIO' ? null : _ownerDocCtrl.text.trim(),
      authorizationDocPath:
          _ownershipType == 'PROPRIO' ? null : _authDocPath,
      authorizationDocName:
          _ownershipType == 'PROPRIO' ? null : _authDocName,
      authorizationDocBytes:
          _ownershipType == 'PROPRIO' ? null : _authDocBytes,
      visualPhotos: _visualPhotos,
      vehicleScreening: widget.initialVehicle?.vehicleScreening,
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
    final crlvDoc = p.documents.cast<DriverDocument?>().firstWhere(
          (d) => d?.type == 'CRLV',
          orElse: () => null,
        );
    final photosCount = BehavioralAntifraudEngine.countVehiclePhotos(_visualPhotos);

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
          const SizedBox(height: 12),

          // CRLV INTEGRADO + VÍNCULO DE POSSE
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: OmniTheme.slate900,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: OmniTheme.slate800),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.assignment_turned_in_rounded,
                        color: OmniTheme.neonCyan, size: 16),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'CRLV-e & Vínculo / Autorização de Uso',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: crlvDoc == null
                          ? null
                          : () => p.openDocumentCapture(crlvDoc.id,
                              autoOpenCamera: true),
                      child: Text(
                        crlvDoc?.status == 'APPROVED'
                            ? 'CRLV ✓'
                            : 'Anexar CRLV',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: crlvDoc?.status == 'APPROVED'
                              ? OmniTheme.neonEmerald
                              : OmniTheme.neonCyan,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _ownershipType,
                  dropdownColor: OmniTheme.slate900,
                  decoration: const InputDecoration(labelText: 'Posse do Veículo'),
                  items: const [
                    DropdownMenuItem(value: 'PROPRIO', child: Text('Veículo Próprio')),
                    DropdownMenuItem(value: 'FAMILIAR', child: Text('De Familiar')),
                    DropdownMenuItem(
                        value: 'TERCEIRO_AUTORIZADO',
                        child: Text('Terceiro Autorizado')),
                    DropdownMenuItem(value: 'LOCADORA', child: Text('Locadora / Frota')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _ownershipType = v);
                  },
                ),
                if (_ownershipType != 'PROPRIO') ...[
                  const SizedBox(height: 8),
                  _FormTextField(
                    label: 'Nome / Razão Social Proprietário *',
                    controller: _ownerNameCtrl,
                  ),
                  const SizedBox(height: 8),
                  _FormTextField(
                    label: 'CPF ou CNPJ do Proprietário *',
                    controller: _ownerDocCtrl,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _pickAuthDocument(p),
                    icon: const Icon(Icons.upload_file_rounded, size: 16),
                    label: Text(
                      _authDocName ??
                          ((_authDocPath ?? '').isNotEmpty
                              ? 'Autorização Anexada ✓'
                              : 'Anexar Termo / Contrato de Locação'),
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OmniTheme.neonCyan,
                      side: BorderSide(
                          color: OmniTheme.alpha(OmniTheme.neonCyan, 0.5)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 5 FOTOS NÍTIDAS DO VEÍCULO
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: OmniTheme.slate900,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: OmniTheme.slate800),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.photo_camera_rounded,
                        color: OmniTheme.neonCyan, size: 16),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        '5 Fotos Nítidas do Veículo',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      '$photosCount/5 fotos',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: photosCount >= 5
                            ? OmniTheme.neonEmerald
                            : OmniTheme.amber400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ('front', 'Frente', _visualPhotos.front),
                    ('rear', 'Traseira', _visualPhotos.rear),
                    ('left_side', 'Lat. Esq.', _visualPhotos.leftSide),
                    ('right_side', 'Lat. Dir.', _visualPhotos.rightSide),
                    ('plate', 'Placa Nítida', _visualPhotos.plate),
                  ].map((slot) {
                    final path = slot.$3;
                    final hasPhoto = (path ?? '').isNotEmpty;
                    final isLocalFile = hasPhoto &&
                        !path!.startsWith('owner_test://') &&
                        !path.startsWith('http') &&
                        File(path).existsSync();
                    return InkWell(
                      onTap: () => _showPhotoSourceSheet(p, slot.$1, slot.$2),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 96,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: hasPhoto
                              ? OmniTheme.alpha(OmniTheme.neonEmerald, 0.12)
                              : OmniTheme.slate950,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: hasPhoto
                                ? OmniTheme.alpha(OmniTheme.neonEmerald, 0.55)
                                : OmniTheme.slate700,
                          ),
                        ),
                        child: Column(
                          children: [
                            if (isLocalFile)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(
                                  File(path),
                                  width: 80,
                                  height: 44,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else
                              Icon(
                                hasPhoto
                                    ? Icons.check_circle_rounded
                                    : Icons.add_a_photo_rounded,
                                size: 22,
                                color: hasPhoto
                                    ? OmniTheme.neonEmerald
                                    : OmniTheme.slate400,
                              ),
                            const SizedBox(height: 4),
                            Text(
                              slot.$2,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
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
