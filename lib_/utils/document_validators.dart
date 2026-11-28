/// Validadores Matemáticos e Estruturais de Documentos Brasileiros
/// CPF (Módulo 11 Receita Federal), RG/CIN (Composição & Módulo 11) e CNH (11 dígitos SENATRAN + Categoria B+/A + EAR)
/// 1:1 com src/utils/documentValidators.ts

class CpfValidationResult {
  final bool found;
  final bool valid;
  final String? maskedValue;
  final String? reason;

  const CpfValidationResult({
    required this.found,
    required this.valid,
    this.maskedValue,
    this.reason,
  });
}

class RgValidationResult {
  final bool found;
  final bool valid;
  final String kind; // 'CIN_CPF' | 'RG_ESTADUAL' | 'UNKNOWN'
  final String? maskedValue;
  final int digitsCount;
  final String? reason;

  const RgValidationResult({
    required this.found,
    required this.valid,
    required this.kind,
    this.maskedValue,
    required this.digitsCount,
    this.reason,
  });
}

class CnhValidationResult {
  final bool registryFound;
  final bool registryValid;
  final String? maskedRegistry;
  final bool categoryFound;
  final String? categoryDetected;
  final bool categoryQualified;
  final bool carQualified;
  final bool motoQualified;
  final bool hasEar;
  final String? reason;

  const CnhValidationResult({
    required this.registryFound,
    required this.registryValid,
    this.maskedRegistry,
    required this.categoryFound,
    this.categoryDetected,
    required this.categoryQualified,
    required this.carQualified,
    required this.motoQualified,
    required this.hasEar,
    this.reason,
  });
}

/// Valida CPF brasileiro usando o algoritmo oficial Módulo 11 da Receita Federal (11 dígitos + 2 DVs).
bool isValidBrazilianCpf(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 11) return false;
  if (RegExp(r'^(\d)\1{10}$').hasMatch(digits)) return false;

  int sum = 0;
  for (int i = 0; i < 9; i++) {
    sum += int.parse(digits[i]) * (10 - i);
  }
  int check1 = (sum * 10) % 11;
  if (check1 == 10) check1 = 0;
  if (check1 != int.parse(digits[9])) return false;

  sum = 0;
  for (int i = 0; i < 10; i++) {
    sum += int.parse(digits[i]) * (11 - i);
  }
  int check2 = (sum * 10) % 11;
  if (check2 == 10) check2 = 0;
  return check2 == int.parse(digits[10]);
}

String maskCpf(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 11) return '***.***.***-**';
  return '${digits.substring(0, 3)}.***.***-${digits.substring(9, 11)}';
}

String maskGenericDigits(String raw) {
  final clean = raw.replaceAll(RegExp(r'[^0-9X]', caseSensitive: false), '').toUpperCase();
  if (clean.length == 11) {
    return '${clean.substring(0, 3)}.***.***-${clean.substring(9, 11)}';
  }
  if (clean.length >= 7) {
    return '${clean.substring(0, 2)}.***.***-${clean[clean.length - 1]}';
  }
  return '***';
}

/// Normaliza pequenos ruídos de OCR em grupos numéricos (ex: O->0 em sequências com dígitos)
String _normalizeNumericOcrArtifacts(String textNorm) {
  return textNorm.replaceAllMapped(
    RegExp(r'\b[\dO]{3}[\s.,:\-]?[\dO]{3}[\s.,:\-]?[\dO]{3}[\s.,:\-\/]?[\dO]{2}\b'),
    (m) => m.group(0)!.replaceAll('O', '0'),
  );
}

CpfValidationResult validateCpfInText(String textNorm) {
  final normalized = _normalizeNumericOcrArtifacts(textNorm.toUpperCase());
  final candMatches = RegExp(
    r'\d{3}[\s.,:\-]?\d{3}[\s.,:\-]?\d{3}[\s.,:\-\/]?\d{2}',
  ).allMatches(normalized);
  final candidates = candMatches.map((m) => m.group(0)!).toList();

  if (candidates.isEmpty) {
    final raw11 = RegExp(r'\b\d{11}\b')
        .allMatches(normalized)
        .map((m) => m.group(0)!)
        .toList();
    for (final seq in raw11) {
      if (isValidBrazilianCpf(seq)) {
        return CpfValidationResult(
          found: true,
          valid: true,
          maskedValue: maskCpf(seq),
        );
      }
    }
    if (raw11.isNotEmpty) {
      return CpfValidationResult(
        found: true,
        valid: false,
        maskedValue: maskCpf(raw11.first),
        reason:
            'Número de 11 dígitos encontrado não passa no cálculo de dígitos verificadores do CPF (Módulo 11).',
      );
    }
    return const CpfValidationResult(found: false, valid: false);
  }

  for (final cand in candidates) {
    if (isValidBrazilianCpf(cand)) {
      return CpfValidationResult(
        found: true,
        valid: true,
        maskedValue: maskCpf(cand),
      );
    }
  }

  return CpfValidationResult(
    found: true,
    valid: false,
    maskedValue: maskCpf(candidates.first),
    reason:
        'O CPF identificado no documento possui dígitos verificadores inválidos pelo cálculo oficial Módulo 11.',
  );
}

/// Valida composição numérica de RG estadual (7 a 10 dígitos) ou CIN (11 dígitos CPF Mod-11).
RgValidationResult validateRgInText(String textNorm) {
  final upper = textNorm.toUpperCase();
  final isCinContext =
      RegExp(r'IDENTIDADE\s+NACIONAL|\bCIN\b|CPF').hasMatch(upper);
  if (isCinContext) {
    final cpfCheck = validateCpfInText(upper);
    if (cpfCheck.found && cpfCheck.valid) {
      return RgValidationResult(
        found: true,
        valid: true,
        kind: 'CIN_CPF',
        maskedValue: cpfCheck.maskedValue,
        digitsCount: 11,
      );
    }
  }

  final formattedRgMatches = [
    ...RegExp(r'\b\d{1,2}\.\d{3}\.\d{3}(?:[\-\s]?[\dX])?\b')
        .allMatches(upper)
        .map((m) => m.group(0)!),
    ...RegExp(r'\b\d{1,2}[.,]?\d{3}[.,]?\d{3}[\-\s]?[\dX]\b')
        .allMatches(upper)
        .map((m) => m.group(0)!),
    ...RegExp(r'\b(?:RG|REGISTRO\s+GERAL|IDENTIDADE)[:\s#]*([\d.\-X]{7,13})\b')
        .allMatches(upper)
        .map((m) => m.group(1) ?? m.group(0)!),
  ];

  final genericDigits = RegExp(r'\b\d{7,10}\b')
      .allMatches(upper)
      .map((m) => m.group(0)!)
      .toList();

  final allCandidates = [...formattedRgMatches, ...genericDigits];

  for (final cand in allCandidates) {
    final clean = cand.replaceAll(RegExp(r'[^0-9X]'), '');
    if (clean.length < 7 || clean.length > 11) continue;
    if (RegExp(r'^(\d)\1+$').hasMatch(clean) ||
        clean == '12345678' ||
        clean == '123456789' ||
        clean == '1234567') {
      continue;
    }

    if (clean.length == 11 &&
        RegExp(r'^\d{11}$').hasMatch(clean) &&
        isValidBrazilianCpf(clean)) {
      return RgValidationResult(
        found: true,
        valid: true,
        kind: 'CIN_CPF',
        maskedValue: maskCpf(clean),
        digitsCount: 11,
      );
    }

    if (clean.length >= 7 && clean.length <= 10) {
      final masked = clean.length == 7
          ? '${clean.substring(0, 1)}.***.${clean.substring(clean.length - 3)}'
          : '${clean.substring(0, 2)}.***.***-${clean[clean.length - 1]}';
      return RgValidationResult(
        found: true,
        valid: true,
        kind: 'RG_ESTADUAL',
        maskedValue: masked,
        digitsCount: clean.length,
      );
    }
  }

  if (formattedRgMatches.isNotEmpty || genericDigits.isNotEmpty) {
    return const RgValidationResult(
      found: true,
      valid: false,
      kind: 'RG_ESTADUAL',
      digitsCount: 0,
      reason:
          'A numeração identificada para o RG não corresponde a um padrão válido brasileiro (7 a 10 dígitos ou CIN 11 dígitos).',
    );
  }

  return const RgValidationResult(
    found: false,
    valid: false,
    kind: 'UNKNOWN',
    digitsCount: 0,
  );
}

/// Valida Número de Registro da CNH brasileira usando o algoritmo oficial SENATRAN/DENATRAN (11 dígitos + 2 DVs).
bool isValidBrazilianCnhNumber(String raw) {
  final cnh = raw.replaceAll(RegExp(r'\D'), '');
  if (cnh.length != 11) return false;
  if (RegExp(r'^(\d)\1{10}$').hasMatch(cnh)) return false;

  int dsc = 0;
  int sum1 = 0;
  for (int i = 0, weight = 9; i < 9; i++, weight--) {
    sum1 += int.parse(cnh[i]) * weight;
  }
  int vl1 = sum1 % 11;
  if (vl1 >= 10) {
    vl1 = 0;
    dsc = 2;
  }

  int sum2 = 0;
  for (int i = 0, weight = 1; i < 9; i++, weight++) {
    sum2 += int.parse(cnh[i]) * weight;
  }
  int vl2 = (sum2 % 11) - dsc;
  if (vl2 < 0) vl2 += 11;
  if (vl2 >= 10) vl2 = 0;

  return vl1 == int.parse(cnh[9]) && vl2 == int.parse(cnh[10]);
}

/// Extrai e valida Número de Registro CNH (11 dígitos), Categoria de Habilitação (B+ / A / AB) e EAR.
CnhValidationResult validateCnhInText(String textNorm) {
  final upper = textNorm.toUpperCase();
  final digit11Candidates = RegExp(r'\b\d{11}\b')
      .allMatches(upper)
      .map((m) => m.group(0)!)
      .toList();

  String? validRegistry;
  bool invalid11Found = false;

  for (final seq in digit11Candidates) {
    if (isValidBrazilianCnhNumber(seq)) {
      validRegistry = '${seq.substring(0, 3)}*****${seq.substring(8, 11)}';
      break;
    }
    if (!isValidBrazilianCpf(seq)) {
      invalid11Found = true;
    }
  }

  final catMatch1 = RegExp(
    r'(?:CAT\.?\s*HAB\.?|CATEGORIA)[:\s\-]*([ABCDE]{1,2})\b',
  ).firstMatch(upper);
  final catMatch2 = RegExp(
    r'\b([ABCDE]{1,2})\b(?=\s+(?:\d{2}\/\d{2}\/\d{4}|VALIDADE|PERM|EAR))',
  ).firstMatch(upper);
  final catMatch3 = RegExp(
    r'(?:CAT\.?\s*HAB\.?|CATEGORIA)[\s\S]{0,40}\b(AB|AC|AD|AE|[ABCDE])\b',
  ).firstMatch(upper);

  String? categoryDetected =
      catMatch1?.group(1) ?? catMatch2?.group(1) ?? catMatch3?.group(1);
  if (categoryDetected == null) {
    final explicit = RegExp(r'\b(AB|AC|AD|AE)\b').firstMatch(upper);
    if (explicit != null) categoryDetected = explicit.group(1);
  }
  // CNH nova tem linha "A B" separada por espaço ou letra isolada antes de "EAR"
  if (categoryDetected == null && RegExp(r'\bA\s+B\b').hasMatch(upper)) {
    categoryDetected = 'AB';
  }

  const carCategories = {'B', 'AB', 'AC', 'AD', 'AE', 'C', 'D', 'E'};
  const motoCategories = {'A', 'AB', 'AC', 'AD', 'AE'};
  final carQualified =
      categoryDetected != null && carCategories.contains(categoryDetected);
  final motoQualified =
      categoryDetected != null && motoCategories.contains(categoryDetected);
  final categoryQualified = carQualified || motoQualified;

  final hasEar = RegExp(
    r'\b(?:EAR|E\.A\.R)\b|EXERCE\s+ATIVIDADE\s+REMUNERADA|ATIVIDADE\s+REMUNERADA',
  ).hasMatch(upper);

  String? reason;
  if (digit11Candidates.isNotEmpty && validRegistry == null && invalid11Found) {
    reason =
        'O número de registro de 11 dígitos encontrado não passou na validação matemática oficial da CNH brasileira.';
  } else if (categoryDetected != null && !categoryQualified) {
    reason =
        'Categoria detectada ($categoryDetected) não habilita transporte ou entregas no aplicativo (exige Categoria A para Moto, B+ para Carro ou AB para ambos).';
  } else if (categoryQualified && !hasEar) {
    reason =
        'Não foi encontrada a observação obrigatória "EAR" (Exerce Atividade Remunerada) exigida pelos aplicativos de mobilidade urbana.';
  }

  return CnhValidationResult(
    registryFound: digit11Candidates.isNotEmpty,
    registryValid: validRegistry != null,
    maskedRegistry: validRegistry,
    categoryFound: categoryDetected != null,
    categoryDetected: categoryDetected,
    categoryQualified: categoryQualified,
    carQualified: carQualified,
    motoQualified: motoQualified,
    hasEar: hasEar,
    reason: reason,
  );
}

String formatCpfInput(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  final d = digits.length > 11 ? digits.substring(0, 11) : digits;
  if (d.length <= 3) return d;
  if (d.length <= 6) return '${d.substring(0, 3)}.${d.substring(3)}';
  if (d.length <= 9) {
    return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6)}';
  }
  return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-${d.substring(9)}';
}

String formatCepInput(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  final d = digits.length > 8 ? digits.substring(0, 8) : digits;
  if (d.length <= 5) return d;
  return '${d.substring(0, 5)}-${d.substring(5)}';
}

int? calculateAgeFromIso(String? isoDate) {
  if (isoDate == null || isoDate.trim().isEmpty) return null;
  final parsed = DateTime.tryParse(isoDate.trim());
  if (parsed == null) return null;
  final now = DateTime.now();
  int age = now.year - parsed.year;
  if (now.month < parsed.month ||
      (now.month == parsed.month && now.day < parsed.day)) {
    age--;
  }
  return (age >= 0 && age <= 115) ? age : null;
}

class ExtractedOcrIdentity {
  final String? fullName;
  final String? birthDateIso;
  final String? birthDateBr;
  final String? cpfDigits;
  final String? cpfFormatted;
  final String? cpfMasked;
  final String? rgRaw;
  final String? rgMasked;
  final String? rgIssuer;
  final String? cnhRegistryDigits;
  final String? cnhRegistryMasked;
  final String? cnhCategory;
  final bool? cnhHasEar;
  final String? cnhExpiryIso;

  const ExtractedOcrIdentity({
    this.fullName,
    this.birthDateIso,
    this.birthDateBr,
    this.cpfDigits,
    this.cpfFormatted,
    this.cpfMasked,
    this.rgRaw,
    this.rgMasked,
    this.rgIssuer,
    this.cnhRegistryDigits,
    this.cnhRegistryMasked,
    this.cnhCategory,
    this.cnhHasEar,
    this.cnhExpiryIso,
  });
}

class DocumentIdentityBaseline {
  final String docType;
  final String docTitle;
  final String? fullName;
  final String? birthDateIso;
  final String? birthDateBr;
  final String? cpfDigits;
  final String? rgNumber;

  const DocumentIdentityBaseline({
    required this.docType,
    required this.docTitle,
    this.fullName,
    this.birthDateIso,
    this.birthDateBr,
    this.cpfDigits,
    this.rgNumber,
  });
}

class CrossDocumentMatchResult {
  final String status; // 'FIRST_DOC' | 'MATCHED' | 'MISMATCH'
  final List<String> matchedFields;
  final List<String> mismatchedReasons;
  final String summary;

  const CrossDocumentMatchResult({
    required this.status,
    required this.matchedFields,
    required this.mismatchedReasons,
    required this.summary,
  });
}

String _stripAccentsUpper(String input) {
  const src = 'ÁÀÃÂÄÉÈÊËÍÌÎÏÓÒÕÔÖÚÙÛÜÇÑáàãâäéèêëíìîïóòõôöúùûüçñ';
  const dst = 'AAAAAEEEEIIIIOOOOOUUUUCNAAAAAEEEEIIIIOOOOOUUUUCN';
  final buf = StringBuffer();
  for (int i = 0; i < input.length; i++) {
    final ch = input[i];
    final idx = src.indexOf(ch);
    buf.write(idx >= 0 ? dst[idx] : ch.toUpperCase());
  }
  return buf.toString();
}

String _toTitleCasePtBr(String raw) {
  const lowerWords = {'DA', 'DE', 'DO', 'DAS', 'DOS', 'E'};
  final words = raw.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final out = <String>[];
  for (int i = 0; i < words.length; i++) {
    final up = words[i].toUpperCase();
    if (i > 0 && lowerWords.contains(up)) {
      out.add(up.toLowerCase());
    } else if (up.length == 1) {
      out.add(up);
    } else {
      out.add('${up[0]}${up.substring(1).toLowerCase()}');
    }
  }
  return out.join(' ');
}

final RegExp _nameStopKeywords = RegExp(
  r'\b(REPUBLICA|FEDERATIVA|BRASIL|MINISTERIO|SECRETARIA|RECEITA|FEDERAL|FAZENDA|ECONOMIA|CARTEIRA|NACIONAL|HABILITACAO|REGISTRO|GERAL|IDENTIDADE|IDENTIFICACAO|DETRAN|SENATRAN|DENATRAN|POLICIA|CIVIL|SEGURANCA|PUBLICA|INSTITUTO|POUPATEMPO|NATURALIDADE|NASCIMENTO|EXPEDICAO|EXPEDIDOR|ASSINATURA|FILIACAO|VALIDADE|VALIDO|VALIDA|SOMENTE|PERMISSAO|CATEGORIA|ATIVIDADE|REMUNERADA|OBSERVACOES|COMPROVANTE|INSCRICAO|SITUACAO|CADASTRAL|REGULAR|TERRITORIO|PROIBIDO|VINCULAR|DOBRAR|PLASTIFICAR|ESTADO|GOVERNO|CERTIDAO|LICENCIAMENTO|CONDUZIR|HABILITADO|PORTADOR|TITULAR|MOTORISTA|CONDUTOR|SOCIAL|DOCUMENTO|ORIGEM|DIGITAL|OFICIAL|AUTENTICIDADE|PASSAPORTE|ORGAO|UF|DATA|MAE|PAI|DIRETOR|DELEGADO|PERITO|SECRETARIO|DATILOSCOPIA|MUNICIPIO|COMARCA|CARTORIO)\b',
);

String? _cleanCandidateNameLine(String line) {
  final rawUpper = _stripAccentsUpper(line).trim();
  if (RegExp(r'\s[-–—]\s*[A-Z]{2}\b\s*$').hasMatch(rawUpper)) return null;

  var cleaned = rawUpper
      .replaceFirst(
        RegExp(
          r'^(?:NOME(?:\s+(?:COMPLETO|CIVIL|DO\s+TITULAR|E\s+SOBRENOME))?|NAME|SURNAME|TITULAR|PORTADOR)[:\s\/\-]*',
        ),
        '',
      )
      .replaceAll(
        RegExp(r'\b(?:CPF|RG|CNH|DATA|NASC|NASCIMENTO|DOC|SEXO|MAE|PAI|FILIACAO)\b.*$'),
        '',
      )
      .replaceAll(RegExp(r'[^A-Z\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (cleaned.length < 6 || cleaned.length > 62) return null;
  if (_nameStopKeywords.hasMatch(cleaned)) return null;

  final words = cleaned.split(' ').where((w) => w.length >= 2 || w == 'E').toList();
  final sigWords = words
      .where((w) => w.length >= 2 && !const {'DA', 'DE', 'DO', 'DAS', 'DOS'}.contains(w))
      .toList();
  if (sigWords.length < 2 || words.length > 7) return null;
  if (sigWords.first.length < 2 || sigWords.last.length < 2) return null;

  return _toTitleCasePtBr(cleaned);
}

bool isValidAutoFillName(String? raw) {
  if (raw == null) return false;
  return _cleanCandidateNameLine(raw) != null;
}

({String iso, String br, int year})? _parsePlausibleDate(
  String dStr,
  String mStr,
  String yStr,
) {
  final d = int.tryParse(dStr);
  final m = int.tryParse(mStr);
  final y = int.tryParse(yStr);
  if (d == null || m == null || y == null) return null;
  if (d < 1 || d > 31 || m < 1 || m > 12 || y < 1925 || y > 2050) return null;
  final iso =
      '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
  final br =
      '${d.toString().padLeft(2, '0')}/${m.toString().padLeft(2, '0')}/${y.toString().padLeft(4, '0')}';
  return (iso: iso, br: br, year: y);
}

/// Extrai Nome Completo, Data de Nascimento, CPF, RG, Órgão, CNH e Validade via OCR preservando linhas.
ExtractedOcrIdentity extractBrazilianDocumentIdentity(String rawText) {
  if (rawText.trim().length < 4) return const ExtractedOcrIdentity();

  final lines = rawText
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final rawUpper = _stripAccentsUpper(rawText);
  final upperFull = rawUpper.replaceAll(RegExp(r'\s+'), ' ');
  final currentYear = DateTime.now().year;

  String? cpfDigits;
  String? cpfFormatted;
  String? cpfMasked;
  final cpfMatches = RegExp(
    r'\d{3}[\s.,:\-]*\d{3}[\s.,:\-]*\d{3}[\s.,:\-\/]*\d{2}|\b\d{11}\b',
  ).allMatches(upperFull);
  for (final m in cpfMatches) {
    final clean11 = m.group(0)!.replaceAll(RegExp(r'\D'), '');
    if (clean11.length == 11 && isValidBrazilianCpf(clean11)) {
      cpfDigits = clean11;
      cpfFormatted = formatCpfInput(clean11);
      cpfMasked = maskCpf(clean11);
      break;
    }
  }

  String? cnhRegistryDigits;
  String? cnhRegistryMasked;
  final cnhCheck = validateCnhInText(upperFull);
  if (cnhCheck.registryValid) {
    for (final m in RegExp(r'\b\d{11}\b').allMatches(upperFull)) {
      final seq = m.group(0)!;
      if (isValidBrazilianCnhNumber(seq)) {
        cnhRegistryDigits = seq;
        cnhRegistryMasked = cnhCheck.maskedRegistry;
        break;
      }
    }
  }

  String? rgRaw;
  String? rgMasked;
  final rgCheck = validateRgInText(upperFull);
  if (rgCheck.valid) {
    rgMasked = rgCheck.maskedValue;
    if (rgCheck.kind == 'CIN_CPF' && cpfFormatted != null) {
      rgRaw = cpfFormatted;
    } else {
      final rgCands = [
        ...RegExp(r'\b\d{1,2}\.\d{3}\.\d{3}(?:[\-\s]?[\dX])?\b')
            .allMatches(upperFull)
            .map((m) => m.group(0)!),
        ...RegExp(r'\b\d{1,2}\.?\d{3}\.?\d{3}[\-\s]?[\dX]\b')
            .allMatches(upperFull)
            .map((m) => m.group(0)!),
        ...RegExp(r'\b(?:RG|REGISTRO\s+GERAL|IDENTIDADE)[:\s#]*([\d.\-X]{7,13})\b')
            .allMatches(upperFull)
            .map((m) => m.group(1) ?? m.group(0)!),
        ...RegExp(r'\b\d{7,10}\b').allMatches(upperFull).map((m) => m.group(0)!),
      ];
      for (final cand in rgCands) {
        final clean = cand.replaceAll(RegExp(r'[^0-9X]'), '');
        if (clean.length >= 7 &&
            clean.length <= 10 &&
            !RegExp(r'^(\d)\1+$').hasMatch(clean)) {
          rgRaw = cand.trim();
          break;
        }
      }
    }
  }

  String? rgIssuer;
  final issuerMatch = RegExp(
    r'\b(SSP|DETRAN|PC|SDS|IGP|IFP|SEJSP|SESP|SJS)[\s\-\/]*([A-Z]{2})?\b',
  ).firstMatch(upperFull);
  if (issuerMatch != null) {
    final uf = issuerMatch.group(2);
    rgIssuer = uf != null ? '${issuerMatch.group(1)}-$uf' : issuerMatch.group(1);
  }

  String? birthDateIso;
  String? birthDateBr;
  final labeledBirth = RegExp(
    r'(?:DATA\s+DE\s+NASCIMENTO|DT\.?\s*NASC|NASCIMENTO|NASC\.?|2A\s+DATA|D\.N\.)[^\d]{0,40}(\d{2})[\/.\-\s](\d{2})[\/.\-\s](\d{4})',
  ).firstMatch(rawUpper);
  if (labeledBirth != null) {
    final parsed = _parsePlausibleDate(
      labeledBirth.group(1)!,
      labeledBirth.group(2)!,
      labeledBirth.group(3)!,
    );
    if (parsed != null && parsed.year >= 1925 && parsed.year <= currentYear - 16) {
      birthDateIso = parsed.iso;
      birthDateBr = parsed.br;
    }
  }

  String? cnhExpiryIso;
  final expiryMatch = RegExp(
    r'(?:VALIDADE|VAL\.?|4B\s+VALIDADE)[^\d]{0,36}(\d{2})[\/.\-\s](\d{2})[\/.\-\s](\d{4})',
  ).firstMatch(rawUpper);
  if (expiryMatch != null) {
    final parsed = _parsePlausibleDate(
      expiryMatch.group(1)!,
      expiryMatch.group(2)!,
      expiryMatch.group(3)!,
    );
    if (parsed != null &&
        parsed.year >= currentYear - 2 &&
        parsed.year <= currentYear + 15) {
      cnhExpiryIso = parsed.iso;
    }
  }

  if (birthDateIso == null) {
    ({String iso, String br, int year})? bestBirth;
    for (final m in RegExp(r'(\d{2})[\/.\-](\d{2})[\/.\-](\d{4})').allMatches(upperFull)) {
      final start = m.start;
      final beforeStart = start - 26 < 0 ? 0 : start - 26;
      final before = upperFull.substring(beforeStart, start);
      if (RegExp(r'EMISSAO|EXPEDICAO|EXP\.|VALIDADE|VAL\.|1A\s*HAB|HABILITACAO|EMITID')
          .hasMatch(before)) {
        continue;
      }
      final parsed = _parsePlausibleDate(m.group(1)!, m.group(2)!, m.group(3)!);
      if (parsed != null &&
          parsed.year >= 1930 &&
          parsed.year <= currentYear - 18) {
        if (bestBirth == null || parsed.year < bestBirth.year) {
          bestBirth = parsed;
        }
      }
    }
    if (bestBirth != null) {
      birthDateIso = bestBirth.iso;
      birthDateBr = bestBirth.br;
    }
  }

  String? fullName;
  for (int i = 0; i < lines.length; i++) {
    final lineUp = _stripAccentsUpper(lines[i]);
    if (RegExp(r'\b(FILIACAO|MAE|PAI|SOCIAL)\b').hasMatch(lineUp)) continue;
    if (RegExp(
      r'\b(?:NOME(?:\s+(?:COMPLETO|CIVIL|DO\s+TITULAR|E\s+SOBRENOME))?|NAME(?:\s+AND\s+SURNAME)?|TITULAR)\b',
    ).hasMatch(lineUp)) {
      final inlineCand = _cleanCandidateNameLine(lines[i]);
      if (inlineCand != null) {
        fullName = inlineCand;
        break;
      }
      if (i + 1 < lines.length) {
        final nextUp = _stripAccentsUpper(lines[i + 1]);
        if (!RegExp(r'\b(FILIACAO|MAE|PAI)\b').hasMatch(nextUp)) {
          final nextCand = _cleanCandidateNameLine(lines[i + 1]);
          if (nextCand != null) {
            fullName = nextCand;
            break;
          }
        }
      }
    }
  }

  if (fullName == null) {
    for (final rawLine in lines) {
      final lineUp = _stripAccentsUpper(rawLine);
      if (RegExp(r'\bFILIACAO\b').hasMatch(lineUp)) break;
      if (RegExp(r'\d').hasMatch(lineUp) || lineUp.contains('/') || lineUp.contains('@')) {
        continue;
      }
      final cand = _cleanCandidateNameLine(rawLine);
      if (cand != null) {
        fullName = cand;
        break;
      }
    }
  }

  return ExtractedOcrIdentity(
    fullName: fullName,
    birthDateIso: birthDateIso,
    birthDateBr: birthDateBr,
    cpfDigits: cpfDigits,
    cpfFormatted: cpfFormatted,
    cpfMasked: cpfMasked,
    rgRaw: rgRaw,
    rgMasked: rgMasked,
    rgIssuer: rgIssuer,
    cnhRegistryDigits: cnhRegistryDigits,
    cnhRegistryMasked: cnhRegistryMasked,
    cnhCategory: cnhCheck.categoryDetected,
    cnhHasEar: cnhCheck.hasEar ? true : null,
    cnhExpiryIso: cnhExpiryIso,
  );
}

int _levenshtein(String a, String b) {
  final m = a.length;
  final n = b.length;
  final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
  for (int i = 0; i <= m; i++) {
    dp[i][0] = i;
  }
  for (int j = 0; j <= n; j++) {
    dp[0][j] = j;
  }
  for (int i = 1; i <= m; i++) {
    for (int j = 1; j <= n; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var best = dp[i - 1][j] + 1;
      if (dp[i][j - 1] + 1 < best) best = dp[i][j - 1] + 1;
      if (dp[i - 1][j - 1] + cost < best) best = dp[i - 1][j - 1] + cost;
      dp[i][j] = best;
    }
  }
  return dp[m][n];
}

bool namesRoughlyMatch(String? nameA, String? nameB) {
  if (nameA == null || nameB == null) return true;
  const connectors = {'DA', 'DE', 'DO', 'DAS', 'DOS', 'E'};
  final tokensA = _stripAccentsUpper(nameA)
      .replaceAll(RegExp(r'[^A-Z\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.length >= 2 && !connectors.contains(t))
      .toList();
  final tokensB = _stripAccentsUpper(nameB)
      .replaceAll(RegExp(r'[^A-Z\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.length >= 2 && !connectors.contains(t))
      .toList();

  if (tokensA.isEmpty || tokensB.isEmpty) return true;
  if (tokensA.join(' ') == tokensB.join(' ')) return true;

  int matches = 0;
  for (final ta in tokensA) {
    final ok = tokensB.any((tb) {
      if (ta == tb) return true;
      final maxLen = ta.length > tb.length ? ta.length : tb.length;
      return maxLen >= 4 && _levenshtein(ta, tb) <= 1;
    });
    if (ok) matches++;
  }

  final firstLen = tokensA.first.length > tokensB.first.length
      ? tokensA.first.length
      : tokensB.first.length;
  final firstMatch = tokensA.first == tokensB.first ||
      (firstLen >= 4 && _levenshtein(tokensA.first, tokensB.first) <= 1);
  final lastLen = tokensA.last.length > tokensB.last.length
      ? tokensA.last.length
      : tokensB.last.length;
  final lastMatch = tokensA.last == tokensB.last ||
      (lastLen >= 4 && _levenshtein(tokensA.last, tokensB.last) <= 1);
  final denom = tokensA.length > tokensB.length ? tokensA.length : tokensB.length;

  return firstMatch && (lastMatch || matches >= 2) && (matches / denom) >= 0.5;
}

CrossDocumentMatchResult compareIdentityAgainstBaseline(
  ExtractedOcrIdentity current,
  List<DocumentIdentityBaseline> baselines,
) {
  final validBaselines = baselines
      .where((b) =>
          (b.fullName?.isNotEmpty == true) ||
          (b.birthDateIso?.isNotEmpty == true) ||
          (b.cpfDigits?.isNotEmpty == true) ||
          (b.rgNumber?.isNotEmpty == true))
      .toList();

  if (validBaselines.isEmpty) {
    final captured = <String>[
      if (current.fullName != null) 'Nome: ${current.fullName}',
      if (current.birthDateBr != null) 'Nasc.: ${current.birthDateBr}',
      if (current.cpfMasked != null) 'CPF: ${current.cpfMasked}',
    ];
    return CrossDocumentMatchResult(
      status: 'FIRST_DOC',
      matchedFields: captured,
      mismatchedReasons: const [],
      summary: captured.isNotEmpty
          ? 'Dados-base salvos (${captured.join(' • ')}) para comparar com os próximos documentos e preencher seu cadastro.'
          : 'Primeiro documento registrado para verificação cruzada.',
    );
  }

  final matchedFields = <String>[];
  final mismatchedReasons = <String>[];

  for (final base in validBaselines) {
    if (current.fullName != null && base.fullName != null) {
      if (namesRoughlyMatch(current.fullName, base.fullName)) {
        if (!matchedFields.any((f) => f.startsWith('Nome'))) {
          matchedFields.add('Nome (${current.fullName})');
        }
      } else {
        mismatchedReasons.add(
          'Nome lido "${current.fullName}" diverge de "${base.fullName}" (${base.docTitle}).',
        );
      }
    }

    if (current.birthDateIso != null && base.birthDateIso != null) {
      if (current.birthDateIso == base.birthDateIso) {
        if (!matchedFields.any((f) => f.startsWith('Nascimento'))) {
          matchedFields.add('Nascimento (${current.birthDateBr ?? current.birthDateIso})');
        }
      } else {
        mismatchedReasons.add(
          'Data de nascimento (${current.birthDateBr ?? current.birthDateIso}) diverge de ${base.birthDateBr ?? base.birthDateIso} (${base.docTitle}).',
        );
      }
    }

    if (current.cpfDigits != null && base.cpfDigits != null) {
      if (current.cpfDigits == base.cpfDigits) {
        if (!matchedFields.any((f) => f.startsWith('CPF'))) {
          matchedFields.add('CPF (${current.cpfMasked ?? formatCpfInput(current.cpfDigits!)})');
        }
      } else {
        mismatchedReasons.add(
          'CPF (${current.cpfMasked}) diferente do documento anterior (${base.docTitle}).',
        );
      }
    }

    if (current.rgRaw != null && base.rgNumber != null) {
      final aRg = current.rgRaw!.replaceAll(RegExp(r'[^0-9X]'), '').toUpperCase();
      final bRg = base.rgNumber!.replaceAll(RegExp(r'[^0-9X]'), '').toUpperCase();
      if (aRg.length >= 7 && bRg.length >= 7) {
        if (aRg == bRg) {
          if (!matchedFields.any((f) => f.startsWith('RG'))) {
            matchedFields.add('RG (${current.rgMasked ?? current.rgRaw})');
          }
        } else {
          mismatchedReasons.add(
            'Número do RG diverge do registro salvo em ${base.docTitle}.',
          );
        }
      }
    }
  }

  if (mismatchedReasons.isNotEmpty) {
    return CrossDocumentMatchResult(
      status: 'MISMATCH',
      matchedFields: matchedFields,
      mismatchedReasons: mismatchedReasons,
      summary: 'Divergência cadastral: ${mismatchedReasons.first}',
    );
  }

  return CrossDocumentMatchResult(
    status: 'MATCHED',
    matchedFields: matchedFields,
    mismatchedReasons: const [],
    summary: matchedFields.isNotEmpty
        ? 'Match de dados confirmado com documentos anteriores: ${matchedFields.join(' • ')}'
        : 'Documento compatível com o perfil cadastrado.',
  );
}

/// Valida código RENAVAM brasileiro usando o algoritmo oficial Módulo 11 do DENATRAN (9 a 11 dígitos).
bool isValidBrazilianRenavam(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 9 || digits.length > 11) return false;
  if (RegExp(r'^(\d)\1+$').hasMatch(digits) ||
      digits == '12345678901' ||
      digits == '01234567890') {
    return false;
  }
  final padded = digits.padLeft(11, '0');
  final rev = padded.substring(0, 10).split('').reversed.join('');
  const weights = [2, 3, 4, 5, 6, 7, 8, 9, 2, 3];
  int sum = 0;
  for (int i = 0; i < 10; i++) {
    sum += int.parse(rev[i]) * weights[i];
  }
  final mod = sum % 11;
  final dv = (11 - mod >= 10) ? 0 : 11 - mod;
  return dv == int.parse(padded[10]);
}

/// Valida placa brasileira padrão antigo (ABC-1234) ou Mercosul (ABC1D23).
bool isValidBrazilianPlate(String raw) {
  final clean = raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  return RegExp(r'^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$').hasMatch(clean);
}

/// Valida número de Chassi / VIN padrão ISO 3779 (17 caracteres alfanuméricos, sem I/O/Q).
bool isValidBrazilianChassi(String raw) {
  final clean = raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (clean.length != 17) return false;
  if (RegExp(r'^([A-Z0-9])\1{16}$').hasMatch(clean)) return false;
  return RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch(clean);
}


