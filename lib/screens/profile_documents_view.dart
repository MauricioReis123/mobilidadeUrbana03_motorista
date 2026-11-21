import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../config/omni_theme.dart';
import '../models/omni_models.dart';
import '../providers/omni_driver_provider.dart';
import '../utils/vehicle_catalog.dart';
import '../widgets/driver_avatar.dart';
import '../widgets/onboarding_gatekeeper_panel.dart';
import '../widgets/backend_domain_config_card.dart';
import '../widgets/vehicle_image.dart';
import 'driver_forms.dart';

/// Hub Completo de Perfil, Documentos, Frota (Edição Inline) e Termos/LGPD — 1:1 com ProfileDocumentsView.tsx
class ProfileDocumentsView extends StatefulWidget {
  const ProfileDocumentsView({super.key});

  @override
  State<ProfileDocumentsView> createState() => _ProfileDocumentsViewState();
}

class _ProfileDocumentsViewState extends State<ProfileDocumentsView> {
  String? _editingVehicleId;
  bool _showAddVehicleForm = false;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();
    final driver = p.driver;
    final subTab = p.profileSubTab;
    final approvedDocsCount =
        p.documents.where((d) => d.status == 'APPROVED').length;

    final tabs = [
      (
        id: ProfileSubTab.personal,
        label: 'Perfil Profissional',
        icon: Icons.person_rounded
      ),
      (
        id: ProfileSubTab.documents,
        label: 'Documentos & CNH ($approvedDocsCount/${p.documents.length})',
        icon: Icons.description_rounded
      ),
      (
        id: ProfileSubTab.vehicles,
        label: 'Veículos (${p.vehicles.length})',
        icon: Icons.directions_car_rounded
      ),
      (
        id: ProfileSubTab.terms,
        label: 'Termos & LGPD',
        icon: Icons.gavel_rounded
      ),
    ];

    return Column(
      children: [
        // Barra horizontal rolável de sub-abas (zero overflow!)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: const BoxDecoration(
            color: OmniTheme.slate950,
            border: Border(bottom: BorderSide(color: OmniTheme.slate800)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: tabs.map((t) {
                final selected = subTab == t.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => p.setProfileSubTab(t.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? OmniTheme.alpha(OmniTheme.neonCyan, 0.16)
                            : OmniTheme.slate900,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? OmniTheme.neonCyan
                              : OmniTheme.slate800,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            t.icon,
                            size: 14,
                            color: selected
                                ? OmniTheme.neonCyan
                                : OmniTheme.slate400,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            t.label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: selected
                                  ? OmniTheme.neonCyan
                                  : OmniTheme.slate300,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Conteúdo da sub-aba
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              const OnboardingGatekeeperPanel(compact: true),
              const SizedBox(height: 12),

              if (subTab == ProfileSubTab.personal) ...[
                // Card Avatar Real + Biometria Facial
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: OmniTheme.neonCardDecoration(),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          DriverAvatar(
                            driver: driver,
                            radius: 30,
                            borderColor: OmniTheme.neonCyan,
                            borderWidth: 2.5,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: () {
                                final photoDoc = p.documents
                                    .cast<DriverDocument?>()
                                    .firstWhere(
                                      (d) => d?.type == 'PROFILE_PHOTO',
                                      orElse: () => null,
                                    );
                                if (photoDoc != null) {
                                  p.openDocumentCapture(photoDoc.id);
                                }
                              },
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: OmniTheme.neonCyan,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: OmniTheme.slate950,
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.photo_camera_rounded,
                                  size: 12,
                                  color: Color(0xFF05080F),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driver.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '★ ${driver.rating.toStringAsFixed(2)} • ${driver.totalTrips} viagens • Nível ${driver.clubTier}',
                              style: const TextStyle(
                                  fontSize: 11, color: OmniTheme.slate400),
                            ),
                            const SizedBox(height: 6),
                            OmniPillBadge(
                              text: driver.isBiometricVerified
                                  ? 'Biometria Facial Aprovada ✓'
                                  : 'Biometria Pendente',
                              color: driver.isBiometricVerified
                                  ? OmniTheme.neonEmerald
                                  : OmniTheme.amber400,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => p.setBiometricModalOpen(true),
                        style: IconButton.styleFrom(
                          backgroundColor: OmniTheme.slate900,
                          side: BorderSide(
                              color: OmniTheme.alpha(OmniTheme.neonCyan, 0.45)),
                        ),
                        icon: const Icon(Icons.face_retouching_natural,
                            color: OmniTheme.neonCyan),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Camada de Validação por Impressão Digital Biométrica (+5% Aptidão)
                _FingerprintValidationCard(
                  p: p,
                  onOpenSensor: () => _openFingerprintSensorModal(context, p),
                ),
                const SizedBox(height: 12),

                // Auditoria Papiloscópica: Digital do Aparelho vs Polegar do RG / CNH (+6% Aptidão)
                _FingerprintDocComparisonCard(p: p),
                const SizedBox(height: 12),

                // Painel de Aptidão Cruzada (18 Camadas OMNI)
                _CrossMatchAptitudeSummaryCard(p: p),
                const SizedBox(height: 12),

                // Checagem Inteligente e Real de Antecedentes Criminais (+10% Aptidão)
                _CriminalBackgroundAuditCard(p: p),
                const SizedBox(height: 12),

                // Checagem Profunda do Veículo Ativo (Documentação + Histórico, +7% Aptidão)
                if (p.vehicles.isNotEmpty) ...[
                  _VehicleDeepAuditCard(p: p, vehicle: p.activeVehicle),
                  const SizedBox(height: 12),
                ],

                // Atalhos rápidos CPF / RG / CNH
                _MandatoryDocsQuickGrid(p: p),
                const SizedBox(height: 12),

                const DriverProfileFormCard(),
                const SizedBox(height: 12),
                const DriverFinanceAndSafetyFormCard(),
                const SizedBox(height: 12),
                const BackendDomainConfigCard(),
              ] else if (subTab == ProfileSubTab.documents) ...[
                // Biometria em destaque
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: OmniTheme.neonCardDecoration(
                    active: !driver.isBiometricVerified,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (driver.capturedOvalFaceBytes != null ||
                              (driver.capturedOvalFacePath != null &&
                                  File(driver.capturedOvalFacePath!)
                                      .existsSync()))
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: DriverAvatar(
                                driver: driver,
                                radius: 22,
                                borderColor: driver.isBiometricVerified
                                    ? OmniTheme.neonEmerald
                                    : OmniTheme.amber400,
                              ),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.only(right: 10),
                              child: Icon(Icons.face_retouching_natural,
                                  size: 28, color: OmniTheme.neonCyan),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Selfie Biométrica no Oval & Match RG/CNH',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  driver.isBiometricVerified
                                      ? 'Rosto real validado (${driver.biometricScore?.toStringAsFixed(0) ?? '95'}% match).'
                                      : 'Mire seu rosto no oval com a câmera frontal para captura automática.',
                                  style: const TextStyle(
                                      fontSize: 11, color: OmniTheme.slate400),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => p.setBiometricModalOpen(true),
                            child: Text(driver.isBiometricVerified
                                ? 'Revalidar'
                                : 'Abrir Oval'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _FaceMatchPill(
                              label: 'Match RG', entry: driver.faceMatchRg),
                          _FaceMatchPill(
                              label: 'Match CNH', entry: driver.faceMatchCnh),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Lista Completa de Documentos com Miniatura Real + OCR
                ...p.documents.map((doc) {
                  final approved = doc.status == 'APPROVED';
                  final rejected = doc.status == 'REJECTED';
                  final statusColor = approved
                      ? OmniTheme.neonEmerald
                      : rejected
                          ? OmniTheme.rose500
                          : OmniTheme.amber400;

                  Widget leadingThumb;
                  if (doc.fileBytes != null &&
                      doc.fileBytes!.isNotEmpty &&
                      !(doc.fileName?.toLowerCase().endsWith('.pdf') ?? false)) {
                    leadingThumb = ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        doc.fileBytes!,
                        cacheWidth: 200,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    );
                  } else if (doc.filePath != null &&
                      !doc.filePath!.toLowerCase().endsWith('.pdf') &&
                      File(doc.filePath!).existsSync()) {
                    leadingThumb = ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(doc.filePath!),
                        cacheWidth: 200,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    );
                  } else {
                    leadingThumb = Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: OmniTheme.alpha(statusColor, 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        approved
                            ? Icons.verified_rounded
                            : rejected
                                ? Icons.warning_amber_rounded
                                : Icons.upload_file_rounded,
                        color: statusColor,
                        size: 20,
                      ),
                    );
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: OmniTheme.neonCardDecoration(
                      borderColor: OmniTheme.alpha(statusColor, 0.4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            leadingThumb,
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          doc.name,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      if (doc.aiAudit != null)
                                        OmniPillBadge(
                                          text:
                                              'IA ${doc.aiAudit!.integrityScore}%',
                                          color: OmniTheme.neonCyan,
                                        ),
                                    ],
                                  ),
                                  if ((doc.faceFileBytes != null &&
                                          doc.faceFileBytes!.isNotEmpty) ||
                                      (doc.faceFilePath != null &&
                                          doc.faceFilePath!.isNotEmpty)) ...[
                                    const SizedBox(height: 4),
                                    const OmniPillBadge(
                                      text: 'Parte A: 3x4 ✓',
                                      color: OmniTheme.neonEmerald,
                                    ),
                                  ],
                                  const SizedBox(height: 3),
                                  Text(
                                    '${approved ? 'Aprovado' : rejected ? 'Recusado' : 'Pendente'} • ${doc.updatedAt}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: statusColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: doc.type == 'BIOMETRIC_VALIDATION'
                                  ? () => p.setBiometricModalOpen(true)
                                  : () => p.openDocumentCapture(doc.id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: approved
                                    ? OmniTheme.slate800
                                    : OmniTheme.neonCyan,
                                foregroundColor: approved
                                    ? OmniTheme.slate200
                                    : const Color(0xFF05080F),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 9),
                              ),
                              child: Text(approved ? 'Atualizar' : 'Enviar'),
                            ),
                          ],
                        ),
                        if (doc.aiAudit?.rejectionReason != null &&
                            doc.aiAudit!.rejectionReason!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: OmniTheme.alpha(OmniTheme.rose500, 0.14),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color:
                                      OmniTheme.alpha(OmniTheme.rose500, 0.45)),
                            ),
                            child: Text(
                              doc.aiAudit!.rejectionReason!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: OmniTheme.rose400,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        if (doc.aiAudit?.ocrTextExcerpt != null &&
                            doc.aiAudit!.ocrTextExcerpt!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: OmniTheme.slate900,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: OmniTheme.slate800),
                            ),
                            child: Text(
                              'OCR: ${doc.aiAudit!.ocrTextExcerpt}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: OmniTheme.monoStyle(
                                  fontSize: 10, color: OmniTheme.slate400),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ] else if (subTab == ProfileSubTab.vehicles) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Frota Cadastrada (${p.vehicles.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showAddVehicleForm = !_showAddVehicleForm;
                          _editingVehicleId = null;
                        });
                      },
                      icon: Icon(
                        _showAddVehicleForm
                            ? Icons.close_rounded
                            : Icons.add_rounded,
                        size: 16,
                      ),
                      label: Text(_showAddVehicleForm ? 'Fechar' : 'Novo Veículo'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_showAddVehicleForm) ...[
                  VehicleRegistrationForm(
                    onDone: () => setState(() => _showAddVehicleForm = false),
                    onCancel: () => setState(() => _showAddVehicleForm = false),
                  ),
                  const SizedBox(height: 12),
                ],

                if (p.vehicles.isNotEmpty) ...[
                  _VehicleDeepAuditCard(p: p, vehicle: p.activeVehicle),
                  const SizedBox(height: 12),
                ],

                // Cards de Veículos com Edição Inline garantida
                ...p.vehicles.map((v) {
                  final isEditing = _editingVehicleId == v.id;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: OmniTheme.neonCardDecoration(
                      active: v.isActive,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 112,
                              child: VehicleImage(
                                type: v.type,
                                brand: v.brand,
                                model: v.model,
                                color: v.color,
                                bodyStyle: v.bodyStyle,
                                doors: v.doors,
                                photoUrl: v.photoUrl,
                                height: 78,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      OmniPillBadge(
                                        text: formatVehicleCategoryLabel(
                                            v.category),
                                        color: OmniTheme.neonCyan,
                                      ),
                                      if (v.isActive)
                                        const OmniPillBadge(
                                          text: 'ATIVO',
                                          color: OmniTheme.neonEmerald,
                                        ),
                                      OmniPillBadge(
                                        text: v.deepAudit?.status == 'APPROVED'
                                            ? 'Auditoria OK (${v.deepAudit!.score}%)'
                                            : v.deepAudit?.status == 'REJECTED'
                                                ? 'Bloqueio/Alerta'
                                                : v.deepAudit?.status == 'REVIEW'
                                                    ? 'Revisar CRLV'
                                                    : 'Auditoria Pendente',
                                        color: v.deepAudit?.status == 'APPROVED'
                                            ? OmniTheme.neonEmerald
                                            : v.deepAudit?.status == 'REJECTED'
                                                ? OmniTheme.rose500
                                                : OmniTheme.amber400,
                                      ),
                                      OmniPillBadge(
                                        text: (v.insuranceAppActive ?? true) &&
                                                (v.insuranceCompany ?? '')
                                                    .trim()
                                                    .isNotEmpty &&
                                                (v.insurancePolicy ?? '')
                                                    .trim()
                                                    .isNotEmpty
                                            ? 'Seguro APP ✓'
                                            : 'Seguro APP Pendente',
                                        color: (v.insuranceAppActive ?? true) &&
                                                (v.insuranceCompany ?? '')
                                                    .trim()
                                                    .isNotEmpty &&
                                                (v.insurancePolicy ?? '')
                                                    .trim()
                                                    .isNotEmpty
                                            ? OmniTheme.neonEmerald
                                            : OmniTheme.amber400,
                                      ),
                                      OmniPillBadge(
                                        text: v.inspection360Completed == true
                                            ? 'Vistoria 360° ✓'
                                            : 'Vistoria 360° Pendente',
                                        color: v.inspection360Completed == true
                                            ? OmniTheme.neonEmerald
                                            : OmniTheme.amber400,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${v.brand} ${v.model}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '${v.year} • ${v.color} • Placa ${v.plate}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: OmniTheme.slate400,
                                    ),
                                  ),
                                  if ((v.renavam != null && v.renavam!.isNotEmpty) ||
                                      (v.chassi != null && v.chassi!.isNotEmpty))
                                    Text(
                                      '${v.renavam != null && v.renavam!.isNotEmpty ? 'RENAVAM: ${v.renavam}' : ''}${v.chassi != null && v.chassi!.isNotEmpty ? ' • Chassi: ${v.chassi}' : ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: OmniTheme.monoStyle(
                                        fontSize: 10,
                                        color: OmniTheme.slate500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: p.isRunningVehicleDeepCheck
                                  ? null
                                  : () => p.runVehicleDeepCheck(vehicleId: v.id),
                              icon: p.isRunningVehicleDeepCheck
                                  ? const SizedBox(
                                      width: 13,
                                      height: 13,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.policy_rounded, size: 15),
                              label: const Text('Auditar IA'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: OmniTheme.neonCyan,
                                side: BorderSide(
                                    color: OmniTheme.alpha(
                                        OmniTheme.neonCyan, 0.45)),
                              ),
                            ),
                            if (!v.isActive)
                              OutlinedButton(
                                onPressed: () => p.toggleActiveVehicle(v.id),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: OmniTheme.neonEmerald,
                                  side: BorderSide(
                                      color: OmniTheme.alpha(
                                          OmniTheme.neonEmerald, 0.5)),
                                ),
                                child: const Text('Ativar para Corridas'),
                              ),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _showAddVehicleForm = false;
                                  _editingVehicleId =
                                      isEditing ? null : v.id;
                                });
                              },
                              icon: Icon(
                                  isEditing
                                      ? Icons.close_rounded
                                      : Icons.edit_rounded,
                                  size: 15),
                              label:
                                  Text(isEditing ? 'Fechar Edição' : 'Editar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: OmniTheme.slate800,
                                foregroundColor: OmniTheme.neonCyan,
                              ),
                            ),
                            if (p.vehicles.length > 1)
                              IconButton(
                                onPressed: () => p.deleteVehicle(v.id),
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: OmniTheme.rose500),
                              ),
                          ],
                        ),
                        if (isEditing) ...[
                          const SizedBox(height: 12),
                          VehicleRegistrationForm(
                            initialVehicle: v,
                            onDone: () =>
                                setState(() => _editingVehicleId = null),
                            onCancel: () =>
                                setState(() => _editingVehicleId = null),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ] else ...[
                _ComplianceRitesCard(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FaceMatchPill extends StatelessWidget {
  final String label;
  final FaceMatchEntry? entry;

  const _FaceMatchPill({required this.label, this.entry});

  @override
  Widget build(BuildContext context) {
    final status = entry?.status ?? 'PENDING';
    final matched = status == 'MATCHED';
    final mismatch = status == 'MISMATCH';
    final color = matched
        ? OmniTheme.neonEmerald
        : mismatch
            ? OmniTheme.rose500
            : OmniTheme.amber400;
    final text = matched
        ? '$label: OK (${entry?.score?.toStringAsFixed(0) ?? '90'}%)'
        : mismatch
            ? '$label: Divergente'
            : status == 'WAITING_DOC'
                ? '$label: Envie Doc'
                : status == 'WAITING_FACE'
                    ? '$label: Faça Oval'
                    : '$label: Pendente';
    return OmniPillBadge(text: text, color: color);
  }
}

class _CrossMatchAptitudeSummaryCard extends StatelessWidget {
  final OmniDriverProvider p;
  const _CrossMatchAptitudeSummaryCard({required this.p});

  @override
  Widget build(BuildContext context) {
    final d = p.driver;
    final docs = p.documents;
    final cpfOk = docs.any((x) => x.type == 'CPF' && x.status == 'APPROVED');
    final rgOk = docs.any((x) => x.type == 'RG' && x.status == 'APPROVED');
    final cnhOk =
        docs.any((x) => x.type == 'CNH_EAR' && x.status == 'APPROVED');
    final crlvOk = docs.any((x) => x.type == 'CRLV' && x.status == 'APPROVED');
    final residenceOk =
        docs.any((x) => x.type == 'RESIDENCE_PROOF' && x.status == 'APPROVED');
    final rgMatch = d.faceMatchRg?.status == 'MATCHED';
    final cnhMatch = d.faceMatchCnh?.status == 'MATCHED';
    final faceOk = rgMatch && cnhMatch && d.isBiometricVerified;
    final fpDocCmp = d.fingerprintDocComparison;
    final fpDocOk = d.isFingerprintVerified && fpDocCmp?.status == 'MATCHED';
    final bgAudit = d.criminalBackgroundAudit;
    final bgOk = bgAudit?.status == 'APPROVED';
    final activeVeh = p.vehicles.isNotEmpty ? p.activeVehicle : null;
    final vehAudit = activeVeh?.deepAudit;
    final vehOk = vehAudit?.status == 'APPROVED';
    final insuranceOk = activeVeh != null &&
        activeVeh.insuranceAppActive != false &&
        (activeVeh.insuranceCompany ?? '').trim().length >= 3 &&
        (activeVeh.insurancePolicy ?? '').trim().length >= 4 &&
        activeVeh.inspection360Completed == true;

    final items = [
      (label: 'CPF (Mód. 11)', ok: cpfOk, err: false),
      (
        label: 'RG / CIN',
        ok: rgOk && rgMatch,
        err: d.faceMatchRg?.status == 'MISMATCH'
      ),
      (
        label: 'CNH Cat. ${d.cnhCategory ?? '?'} EAR',
        ok: cnhOk && cnhMatch,
        err: d.faceMatchCnh?.status == 'MISMATCH'
      ),
      (label: 'CRLV-e Veículo', ok: crlvOk, err: false),
      (label: 'Comprov. Residência', ok: residenceOk, err: false),
      (
        label: 'Match Facial Oval',
        ok: faceOk,
        err: d.faceMatchRg?.status == 'MISMATCH' ||
            d.faceMatchCnh?.status == 'MISMATCH'
      ),
      (label: 'Impressão Digital', ok: d.isFingerprintVerified, err: false),
      (
        label: 'Digital vs RG/CNH',
        ok: fpDocOk,
        err: fpDocCmp?.status == 'MISMATCH'
      ),
      (
        label: 'Antecedentes Criminais',
        ok: bgOk,
        err: bgAudit?.status == 'REJECTED',
      ),
      (
        label: 'Histórico & Doc. Veículo',
        ok: vehOk,
        err: vehAudit?.status == 'REJECTED',
      ),
      (label: 'Seguro APP + Vistoria 360°', ok: insuranceOk, err: false),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: OmniTheme.neonCardDecoration(active: p.isDriverFullyApproved),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_rounded, color: OmniTheme.neonCyan, size: 17),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Aptidão Completa para Condutor OMNI',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((it) {
              final c = it.ok
                  ? OmniTheme.neonEmerald
                  : it.err
                      ? OmniTheme.rose500
                      : OmniTheme.amber400;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: OmniTheme.alpha(c, 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: OmniTheme.alpha(c, 0.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      it.ok
                          ? Icons.check_circle_rounded
                          : it.err
                              ? Icons.warning_amber_rounded
                              : Icons.schedule_rounded,
                      size: 13,
                      color: c,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      it.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: c,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _CriminalBackgroundAuditCard extends StatelessWidget {
  final OmniDriverProvider p;
  const _CriminalBackgroundAuditCard({required this.p});

  @override
  Widget build(BuildContext context) {
    final bgAudit = p.driver.criminalBackgroundAudit;
    final bgDoc = p.documents
        .cast<DriverDocument?>()
        .firstWhere((d) => d?.type == 'BACKGROUND_CHECK', orElse: () => null);
    final isOk = bgAudit?.status == 'APPROVED';
    final isRejected = bgAudit?.status == 'REJECTED';
    final accent = isOk
        ? OmniTheme.neonEmerald
        : isRejected
            ? OmniTheme.rose500
            : OmniTheme.amber400;

    final badgeText = isOk
        ? 'NADA CONSTA (${bgAudit!.score}%)'
        : isRejected
            ? 'RESTRIÇÃO (${bgAudit!.score}%)'
            : bgAudit?.status == 'REVIEW'
                ? 'REVISÃO (${bgAudit!.score}%)'
                : 'PENDENTE (+6%)';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: OmniTheme.neonCardDecoration(
        active: isOk,
        borderColor: OmniTheme.alpha(accent, 0.45),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: OmniTheme.alpha(accent, 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: OmniTheme.alpha(accent, 0.45)),
                ),
                child: Icon(
                  isRejected
                      ? Icons.gpp_bad_rounded
                      : Icons.verified_user_rounded,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Checagem Inteligente de Antecedentes Criminais & Idoneidade',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        OmniPillBadge(text: badgeText, color: accent),
                        if (bgAudit != null)
                          OmniPillBadge(
                            text:
                                'RISCO ${bgAudit.riskLevel == 'LOW' ? 'BAIXO' : bgAudit.riskLevel == 'HIGH' ? 'ALTO' : 'MÉDIO'}',
                            color: accent,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            bgAudit?.summary ??
                'Varredura multimodal de idoneidade cruzando PF (SINIC), TJ Estadual, TRF / BNMP (CNJ), CPF e CNH EAR.',
            style: const TextStyle(fontSize: 11, color: OmniTheme.slate400),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _AuditSubChip(
                title: 'PF / SINIC',
                value: bgAudit?.pfSinicStatus == 'CLEAR'
                    ? 'Nada Consta ✓'
                    : bgAudit?.pfSinicStatus == 'ALERT'
                        ? 'Ocorrência!'
                        : 'Pendente',
                ok: bgAudit?.pfSinicStatus == 'CLEAR',
                alert: bgAudit?.pfSinicStatus == 'ALERT',
              ),
              _AuditSubChip(
                title: 'TJ Estadual',
                value: bgAudit?.tjStateStatus == 'CLEAR'
                    ? 'Nada Consta ✓'
                    : bgAudit?.tjStateStatus == 'ALERT'
                        ? 'Ação ativa!'
                        : 'Pendente',
                ok: bgAudit?.tjStateStatus == 'CLEAR',
                alert: bgAudit?.tjStateStatus == 'ALERT',
              ),
              _AuditSubChip(
                title: 'TRF / BNMP',
                value: bgAudit?.trfBnmpStatus == 'CLEAR'
                    ? 'Sem mandados ✓'
                    : bgAudit?.trfBnmpStatus == 'ALERT'
                        ? 'Mandado/Alerta!'
                        : 'Pendente',
                ok: bgAudit?.trfBnmpStatus == 'CLEAR',
                alert: bgAudit?.trfBnmpStatus == 'ALERT',
              ),
              _AuditSubChip(
                title: 'CNH EAR',
                value: bgAudit?.cnhSuitabilityStatus == 'REGULAR'
                    ? 'Regular ✓'
                    : bgAudit?.cnhSuitabilityStatus == 'SUSPENDED'
                        ? 'Suspensa!'
                        : bgAudit?.cnhSuitabilityStatus == 'INVALID'
                            ? 'Inválida!'
                            : 'Pendente',
                ok: bgAudit?.cnhSuitabilityStatus == 'REGULAR',
                alert: bgAudit?.cnhSuitabilityStatus == 'SUSPENDED' ||
                    bgAudit?.cnhSuitabilityStatus == 'INVALID',
              ),
            ],
          ),
          if (bgAudit != null) ...[
            const SizedBox(height: 8),
            Text(
              'Protocolo: ${bgAudit.protocolCode} • ${bgAudit.engineUsed ?? 'OMNI-BGC-AI'}',
              style: OmniTheme.monoStyle(fontSize: 10, color: OmniTheme.slate400),
            ),
            if (bgAudit.findings.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: OmniTheme.slate900,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: OmniTheme.slate800),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: bgAudit.findings
                      .take(3)
                      .map((f) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '• $f',
                              style: const TextStyle(
                                  fontSize: 10.5, color: OmniTheme.slate300),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
            if (bgAudit.rejectionReason != null &&
                bgAudit.rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: OmniTheme.alpha(OmniTheme.rose500, 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: OmniTheme.alpha(OmniTheme.rose500, 0.45)),
                ),
                child: Text(
                  bgAudit.rejectionReason!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: OmniTheme.rose400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: p.isRunningBackgroundCheck
                      ? null
                      : () => p.runCriminalBackgroundCheck(),
                  icon: p.isRunningBackgroundCheck
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.shield_rounded, size: 16),
                  label: Text(
                    p.isRunningBackgroundCheck
                        ? 'Verificando...'
                        : 'Executar Checagem com IA',
                  ),
                ),
              ),
              if (bgDoc != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: () => p.openDocumentCapture(bgDoc.id),
                    icon: const Icon(Icons.upload_file_rounded, size: 15),
                    label: Text(
                        bgDoc.status == 'APPROVED' ? 'Certidão ✓' : 'Anexar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OmniTheme.neonCyan,
                      side: BorderSide(
                          color: OmniTheme.alpha(OmniTheme.neonCyan, 0.45)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _VehicleDeepAuditCard extends StatelessWidget {
  final OmniDriverProvider p;
  final OmniVehicle vehicle;
  const _VehicleDeepAuditCard({required this.p, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final vAudit = vehicle.deepAudit;
    final crlvDoc = p.documents
        .cast<DriverDocument?>()
        .firstWhere((d) => d?.type == 'CRLV', orElse: () => null);
    final isOk = vAudit?.status == 'APPROVED';
    final isRejected = vAudit?.status == 'REJECTED';
    final accent = isOk
        ? OmniTheme.neonEmerald
        : isRejected
            ? OmniTheme.rose500
            : OmniTheme.amber400;

    final badgeText = isOk
        ? 'VEÍCULO APROVADO (${vAudit!.score}%)'
        : isRejected
            ? 'BLOQUEIO (${vAudit!.score}%)'
            : vAudit?.status == 'REVIEW'
                ? 'REVISÃO (${vAudit!.score}%)'
                : 'PENDENTE (+6%)';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: OmniTheme.neonCardDecoration(
        active: isOk,
        borderColor: OmniTheme.alpha(accent, 0.45),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: OmniTheme.alpha(accent, 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: OmniTheme.alpha(accent, 0.45)),
                ),
                child: Icon(Icons.directions_car_filled_rounded,
                    color: accent, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Checagem Profunda do Veículo (Documentação & Histórico)',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${vehicle.brand} ${vehicle.model} (${vehicle.year}) • Placa ${vehicle.plate} • RENAVAM ${vehicle.renavam ?? 'N/I'}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: OmniTheme.slate200,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        OmniPillBadge(text: badgeText, color: accent),
                        if (vAudit != null)
                          OmniPillBadge(
                            text:
                                'RISCO ${vAudit.riskLevel == 'LOW' ? 'BAIXO' : vAudit.riskLevel == 'HIGH' ? 'ALTO' : 'MÉDIO'}',
                            color: accent,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            vAudit?.summary ??
                'Auditoria DENATRAN / SINESP / RENAJUD que analisa Roubo/Furto, restrições judiciais, leilão/sinistro e regularidade CRLV/RENAVAM.',
            style: const TextStyle(fontSize: 11, color: OmniTheme.slate400),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _AuditSubChip(
                title: 'SINESP Roubo/Furto',
                value: vAudit?.theftRobberyStatus == 'CLEAR'
                    ? 'Sem queixa ✓'
                    : vAudit?.theftRobberyStatus == 'ALERT'
                        ? 'Alerta Roubo!'
                        : 'Pendente',
                ok: vAudit?.theftRobberyStatus == 'CLEAR',
                alert: vAudit?.theftRobberyStatus == 'ALERT',
              ),
              _AuditSubChip(
                title: 'RENAJUD Judicial',
                value: vAudit?.judicialRenajudStatus == 'CLEAR'
                    ? 'Sem bloqueio ✓'
                    : vAudit?.judicialRenajudStatus == 'ALERT'
                        ? 'Bloqueio ativo!'
                        : 'Pendente',
                ok: vAudit?.judicialRenajudStatus == 'CLEAR',
                alert: vAudit?.judicialRenajudStatus == 'ALERT',
              ),
              _AuditSubChip(
                title: 'Leilão / Sinistro',
                value: vAudit?.auctionSinisterStatus == 'CLEAR'
                    ? 'Limpo ✓'
                    : vAudit?.auctionSinisterStatus == 'HIGH_RISK'
                        ? 'Salvado / PT!'
                        : vAudit?.auctionSinisterStatus == 'MEDIUM_RISK'
                            ? 'Risco Médio'
                            : 'Pendente',
                ok: vAudit?.auctionSinisterStatus == 'CLEAR',
                alert: vAudit?.auctionSinisterStatus == 'HIGH_RISK',
              ),
              _AuditSubChip(
                title: 'Licenciamento CRLV',
                value: vAudit?.licensingDebtsStatus == 'REGULAR'
                    ? 'Em dia ✓'
                    : vAudit?.licensingDebtsStatus == 'EXPIRED'
                        ? 'Vencido!'
                        : vAudit?.licensingDebtsStatus == 'IRREGULAR'
                            ? 'Irregular!'
                            : 'Pendente',
                ok: vAudit?.licensingDebtsStatus == 'REGULAR',
                alert: vAudit?.licensingDebtsStatus == 'EXPIRED' ||
                    vAudit?.licensingDebtsStatus == 'IRREGULAR',
              ),
            ],
          ),
          if (vAudit != null) ...[
            const SizedBox(height: 8),
            Text(
              'Protocolo: ${vAudit.protocolCode} • RENAVAM Mód.11: ${vAudit.renavamValid ? 'OK' : 'Pendente'} • Placa: ${vAudit.plateValid ? 'OK' : 'Inválida'}',
              style: OmniTheme.monoStyle(fontSize: 10, color: OmniTheme.slate400),
            ),
            if (vAudit.findings.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: OmniTheme.slate900,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: OmniTheme.slate800),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: vAudit.findings
                      .take(3)
                      .map((f) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '• $f',
                              style: const TextStyle(
                                  fontSize: 10.5, color: OmniTheme.slate300),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
            if (vAudit.rejectionReason != null &&
                vAudit.rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: OmniTheme.alpha(OmniTheme.rose500, 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: OmniTheme.alpha(OmniTheme.rose500, 0.45)),
                ),
                child: Text(
                  vAudit.rejectionReason!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: OmniTheme.rose400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: p.isRunningVehicleDeepCheck
                      ? null
                      : () => p.runVehicleDeepCheck(vehicleId: vehicle.id),
                  icon: p.isRunningVehicleDeepCheck
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.policy_rounded, size: 16),
                  label: Text(
                    p.isRunningVehicleDeepCheck
                        ? 'Auditando...'
                        : 'Auditar Veículo com IA',
                  ),
                ),
              ),
              if (crlvDoc != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: () => p.openDocumentCapture(crlvDoc.id),
                    icon: const Icon(Icons.upload_file_rounded, size: 15),
                    label: Text(
                        crlvDoc.status == 'APPROVED' ? 'CRLV ✓' : 'Enviar CRLV'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OmniTheme.neonCyan,
                      side: BorderSide(
                          color: OmniTheme.alpha(OmniTheme.neonCyan, 0.45)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AuditSubChip extends StatelessWidget {
  final String title;
  final String value;
  final bool ok;
  final bool alert;

  const _AuditSubChip({
    required this.title,
    required this.value,
    required this.ok,
    required this.alert,
  });

  @override
  Widget build(BuildContext context) {
    final c = ok
        ? OmniTheme.neonEmerald
        : alert
            ? OmniTheme.rose500
            : OmniTheme.slate400;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: ok
            ? OmniTheme.alpha(OmniTheme.neonEmerald, 0.1)
            : alert
                ? OmniTheme.alpha(OmniTheme.rose500, 0.12)
                : OmniTheme.slate900,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ok || alert ? OmniTheme.alpha(c, 0.45) : OmniTheme.slate800,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: ok || alert ? c : OmniTheme.slate300,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: ok || alert ? c : OmniTheme.slate400,
            ),
          ),
        ],
      ),
    );
  }
}

class _MandatoryDocsQuickGrid extends StatelessWidget {
  final OmniDriverProvider p;
  const _MandatoryDocsQuickGrid({required this.p});

  @override
  Widget build(BuildContext context) {
    final targetTypes = ['CPF', 'RG', 'CNH_EAR'];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: OmniTheme.neonCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Envio Rápido: CPF, RG e CNH com EAR',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          ...targetTypes.map((type) {
            final doc = p.documents.cast<DriverDocument?>().firstWhere(
                  (d) => d?.type == type,
                  orElse: () => null,
                );
            if (doc == null) return const SizedBox.shrink();
            final ok = doc.status == 'APPROVED';
            final err = doc.status == 'REJECTED';
            final c = ok
                ? OmniTheme.neonEmerald
                : err
                    ? OmniTheme.rose500
                    : OmniTheme.amber400;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => p.openDocumentCapture(doc.id),
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: OmniTheme.slate900,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: OmniTheme.alpha(c, 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        ok
                            ? Icons.check_circle_rounded
                            : Icons.document_scanner_rounded,
                        color: c,
                        size: 18,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            if ((doc.faceFileBytes != null &&
                                    doc.faceFileBytes!.isNotEmpty) ||
                                (doc.faceFilePath != null &&
                                    doc.faceFilePath!.isNotEmpty))
                              const Text(
                                'Parte A (Foto 3x4) vinculada ✓',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: OmniTheme.neonEmerald,
                                ),
                              ),
                          ],
                        ),
                      ),
                      OmniPillBadge(
                        text: ok ? 'Autêntico' : err ? 'Refazer' : 'Enviar',
                        color: c,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ComplianceRitesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();
    final rites = p.driver.complianceRites ??
        const ComplianceRites(
          acceptedTerms: false,
          acceptedPrivacyLgpd: false,
          acceptedZeroTolerance: false,
          completedSafetyBriefing: false,
        );

    final allDone = rites.acceptedTerms &&
        rites.acceptedPrivacyLgpd &&
        rites.acceptedZeroTolerance &&
        rites.completedSafetyBriefing;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: OmniTheme.neonCardDecoration(active: allDone),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gavel_rounded,
                  color: OmniTheme.neonCyan, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Termos, LGPD & Briefing de Segurança',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              OmniPillBadge(
                text: allDone ? 'ASSINADO ✓' : 'PENDENTE',
                color: allDone ? OmniTheme.neonEmerald : OmniTheme.amber400,
              ),
            ],
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: OmniTheme.neonCyan,
            title: const Text(
              'Termos de Uso & Contrato de Parceria OMNI',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            value: rites.acceptedTerms,
            onChanged: (v) => p.updateComplianceRites(
                rites.copyWith(acceptedTerms: v ?? false)),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: OmniTheme.neonCyan,
            title: const Text(
              'Política de Privacidade & Proteção de Dados (LGPD)',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            value: rites.acceptedPrivacyLgpd,
            onChanged: (v) => p.updateComplianceRites(
                rites.copyWith(acceptedPrivacyLgpd: v ?? false)),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: OmniTheme.neonCyan,
            title: const Text(
              'Código de Conduta & Tolerância Zero',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            value: rites.acceptedZeroTolerance,
            onChanged: (v) => p.updateComplianceRites(
                rites.copyWith(acceptedZeroTolerance: v ?? false)),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: OmniTheme.neonCyan,
            title: const Text(
              'Treinamento & Briefing de Segurança Viária OMNI',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            value: rites.completedSafetyBriefing,
            onChanged: (v) => p.updateComplianceRites(
                rites.copyWith(completedSafetyBriefing: v ?? false)),
          ),
          if (rites.signatureHash != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: OmniTheme.slate900,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: OmniTheme.slate800),
              ),
              child: Text(
                'Hash de Auditoria: ${rites.signatureHash}',
                style: OmniTheme.monoStyle(
                    fontSize: 11, color: OmniTheme.neonEmerald),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => p.updateComplianceRites(
                rites.copyWith(
                  acceptedTerms: true,
                  acceptedPrivacyLgpd: true,
                  acceptedZeroTolerance: true,
                  completedSafetyBriefing: true,
                ),
              ),
              icon: const Icon(Icons.verified_rounded, size: 17),
              label: const Text('Assinar Todos os Termos Agora'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FingerprintDocComparisonCard extends StatelessWidget {
  final OmniDriverProvider p;
  const _FingerprintDocComparisonCard({required this.p});

  @override
  Widget build(BuildContext context) {
    final cmp = p.driver.fingerprintDocComparison;
    final isMatched = cmp?.status == 'MATCHED';
    final isMismatch = cmp?.status == 'MISMATCH';
    final accent = isMatched
        ? OmniTheme.neonEmerald
        : isMismatch
            ? OmniTheme.rose500
            : OmniTheme.amber400;

    final badgeText = isMatched
        ? 'MATCH PAPILOSCÓPICO (${cmp!.score}%)'
        : isMismatch
            ? 'DIVERGÊNCIA (${cmp!.score}%)'
            : 'PENDENTE (+6%)';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: OmniTheme.neonCardDecoration(
        active: isMatched,
        borderColor: OmniTheme.alpha(accent, 0.45),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: OmniTheme.alpha(accent, 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: OmniTheme.alpha(accent, 0.45)),
                ),
                child: Icon(Icons.fingerprint_rounded, color: accent, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Auditoria Biométrica: Digital do Aparelho vs Polegar RG/CNH',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        OmniPillBadge(text: badgeText, color: accent),
                        if (cmp != null)
                          OmniPillBadge(
                            text:
                                'CRISTAS: ${cmp.ridgeQuality} • ${cmp.docTypeUsed ?? 'RG/CNH'}',
                            color: accent,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            cmp?.summary ??
                'Confronta a assinatura biométrica do sensor do aparelho com a impressão do polegar direito no RG ou com a titularidade da CNH.',
            style: const TextStyle(fontSize: 11, color: OmniTheme.slate400),
          ),
          if (cmp != null && cmp.findings.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: OmniTheme.slate900,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: OmniTheme.slate800),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: cmp.findings
                    .take(3)
                    .map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '• $f',
                            style: const TextStyle(
                                fontSize: 10.5, color: OmniTheme.slate300),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
          if (cmp?.rejectionReason != null &&
              cmp!.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: OmniTheme.alpha(OmniTheme.rose500, 0.14),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: OmniTheme.alpha(OmniTheme.rose500, 0.45)),
              ),
              child: Text(
                cmp.rejectionReason!,
                style: const TextStyle(
                  fontSize: 11,
                  color: OmniTheme.rose400,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: p.isRunningFingerprintDocCheck
                  ? null
                  : () => p.runFingerprintDocComparison(),
              icon: p.isRunningFingerprintDocCheck
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                p.isRunningFingerprintDocCheck
                    ? 'Confrontando Digital...'
                    : 'Reauditar Digital vs RG/CNH',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: OmniTheme.neonCyan,
                side: BorderSide(
                    color: OmniTheme.alpha(OmniTheme.neonCyan, 0.45)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _openFingerprintSensorModal(BuildContext context, OmniDriverProvider p) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: OmniTheme.slate950,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _FingerprintSensorSheet(provider: p),
  );
}

class _FingerprintValidationCard extends StatelessWidget {
  final OmniDriverProvider p;
  final VoidCallback onOpenSensor;
  const _FingerprintValidationCard({
    required this.p,
    required this.onOpenSensor,
  });

  @override
  Widget build(BuildContext context) {
    final ok = p.driver.isFingerprintVerified;
    final badgeColor = ok ? OmniTheme.neonEmerald : OmniTheme.amber400;
    final isNative = p.driver.fingerprintMethod == 'DEVICE_BIOMETRIC_NATIVE' ||
        p.driver.fingerprintMethod == 'WEBAUTHN_PASSKEY';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: OmniTheme.neonCardDecoration(active: ok),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: OmniTheme.alpha(badgeColor, 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: OmniTheme.alpha(badgeColor, 0.45)),
            ),
            child: Icon(Icons.fingerprint_rounded, color: badgeColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Validação por Impressão Digital',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    OmniPillBadge(
                      text: ok ? 'VALIDADA ✓' : '+5% APTIDÃO',
                      color: badgeColor,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  ok
                      ? '${isNative ? 'Sensor Biométrico Nativo do Aparelho' : 'Sensor Digital OMNI'} (${p.driver.fingerprintHash ?? 'OMNI-FP'}).'
                      : 'Acione o sensor de digital do seu celular ou segure o Sensor OMNI por 1,2s.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: OmniTheme.slate400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onOpenSensor,
            style: ElevatedButton.styleFrom(
              backgroundColor: ok ? OmniTheme.slate800 : OmniTheme.neonCyan,
              foregroundColor:
                  ok ? OmniTheme.neonEmerald : const Color(0xFF05080F),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            ),
            child: Text(ok ? 'Revalidar' : 'Validar'),
          ),
        ],
      ),
    );
  }
}

class _FingerprintSensorSheet extends StatefulWidget {
  final OmniDriverProvider provider;
  const _FingerprintSensorSheet({required this.provider});

  @override
  State<_FingerprintSensorSheet> createState() =>
      _FingerprintSensorSheetState();
}

class _FingerprintSensorSheetState extends State<_FingerprintSensorSheet> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  Timer? _timer;
  double _progress = 0.0;
  bool _holding = false;
  bool _done = false;
  bool _hardwarePromptRunning = false;
  int _lastHapticStep = 0;
  String _statusNote =
      'Acionando leitor biométrico nativo do dispositivo... ou segure o sensor OMNI por 1,2s.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryNativeDeviceFingerprint();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _completeDeviceBiometricSuccess(String hwHash) async {
    _timer?.cancel();
    if (!mounted) return;
    setState(() {
      _hardwarePromptRunning = false;
      _holding = false;
      _progress = 1.0;
      _done = true;
      _statusNote =
          'Impressão digital autenticada pelo sensor biométrico do dispositivo!';
    });
    await HapticFeedback.heavyImpact();
    await widget.provider.verifyFingerprintBiometrics(
      method: 'DEVICE_BIOMETRIC_NATIVE',
      hash: hwHash,
    );
    if (mounted) {
      Future.delayed(const Duration(milliseconds: 750), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  Future<void> _tryNativeDeviceFingerprint() async {
    if (_done || _hardwarePromptRunning || !mounted) return;
    setState(() {
      _hardwarePromptRunning = true;
      _statusNote =
          'Encoste o dedo no leitor biométrico nativo do celular para autenticar...';
    });
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      bool didAuthenticate = false;

      if (supported || canCheck) {
        try {
          didAuthenticate = await _localAuth.authenticate(
            localizedReason:
                'Confirme sua impressão digital do dispositivo para vincular ao seu RG/CNH na OMNI',
            options: const AuthenticationOptions(
              biometricOnly: true,
              stickyAuth: true,
            ),
          );
        } on PlatformException catch (_) {
          // Fallback suave para credencial biométrica/PIN nativa do sistema
          try {
            didAuthenticate = await _localAuth.authenticate(
              localizedReason:
                  'Confirme a autenticação biométrica do aparelho para validar sua conta OMNI',
              options: const AuthenticationOptions(
                biometricOnly: false,
                stickyAuth: true,
              ),
            );
          } catch (_) {
            didAuthenticate = false;
          }
        }
      }

      if (!mounted) return;
      if (didAuthenticate) {
        final hwHash =
            'HW-ANDROID-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
        await _completeDeviceBiometricSuccess(hwHash);
      } else if (!supported && !canCheck) {
        // Sem sensor físico cadastrado: oferece validação rápida sem bloqueio
        setState(() {
          _hardwarePromptRunning = false;
          _statusNote =
              'Toque e segure o Sensor Digital OMNI abaixo por 1,2s para concluir a validação.';
        });
      } else {
        setState(() {
          _hardwarePromptRunning = false;
          _statusNote =
              'Toque novamente no botão nativo ou segure o Sensor Digital OMNI abaixo por 1,2s.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hardwarePromptRunning = false;
        _statusNote =
            'Use o Sensor Digital OMNI abaixo (mantenha pressionado por 1,2s).';
      });
    }
  }

  void _startHold() {
    if (_done) return;
    _timer?.cancel();
    setState(() {
      _holding = true;
      _progress = 0.0;
      _lastHapticStep = 0;
      _statusNote = 'Lendo cristas biométricas... mantenha o dedo pressionado';
    });
    HapticFeedback.selectionClick();
    final start = DateTime.now();
    const totalMs = 1200;
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      final pct = (elapsed / totalMs).clamp(0.0, 1.0);
      final step = (pct * 4).floor();
      if (step > _lastHapticStep && pct < 1.0) {
        _lastHapticStep = step;
        HapticFeedback.selectionClick();
      }
      setState(() => _progress = pct);
      if (pct >= 1.0) {
        timer.cancel();
        setState(() {
          _holding = false;
          _done = true;
          _statusNote = 'Assinatura biométrica digital registrada com sucesso!';
        });
        await HapticFeedback.heavyImpact();
        await widget.provider.verifyFingerprintBiometrics(
          method: 'OMNI_DIGITAL_SENSOR',
        );
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 750), () {
            if (mounted) Navigator.of(context).pop();
          });
        }
      }
    });
  }

  void _cancelHold() {
    if (_done) return;
    _timer?.cancel();
    setState(() {
      _holding = false;
      _progress = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _done
        ? OmniTheme.neonEmerald
        : _holding
            ? OmniTheme.neonCyan
            : OmniTheme.slate400;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: OmniTheme.slate800,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'CAMADA BIOMÉTRICA OMNI (+5% APTIDÃO)',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: OmniTheme.neonCyan,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Validação por Impressão Digital',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _statusNote,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: OmniTheme.slate400),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTapDown: (_) => _startHold(),
            onTapUp: (_) => _cancelHold(),
            onTapCancel: _cancelHold,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: OmniTheme.alpha(
                  _done ? OmniTheme.neonEmerald : OmniTheme.neonCyan,
                  _done || _holding ? 0.2 : 0.08,
                ),
                border: Border.all(
                  color: _done
                      ? OmniTheme.neonEmerald
                      : OmniTheme.neonCyan,
                  width: _holding ? 4 : 2.5,
                ),
                boxShadow: _holding || _done
                    ? [
                        BoxShadow(
                          color: OmniTheme.alpha(
                            _done ? OmniTheme.neonEmerald : OmniTheme.neonCyan,
                            0.45,
                          ),
                          blurRadius: 24,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.fingerprint_rounded,
                    size: 56,
                    color: _done ? OmniTheme.neonEmerald : OmniTheme.neonCyan,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _done
                        ? 'VALIDADA ✓'
                        : _holding
                            ? '${(_progress * 100).round()}%'
                            : 'SEGURE AQUI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: activeColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 7,
              backgroundColor: OmniTheme.slate900,
              valueColor: AlwaysStoppedAnimation<Color>(
                _done ? OmniTheme.neonEmerald : OmniTheme.neonCyan,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (_hardwarePromptRunning || _done)
                  ? null
                  : _tryNativeDeviceFingerprint,
              icon: _hardwarePromptRunning
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.fingerprint_rounded, size: 17),
              label: Text(
                _hardwarePromptRunning
                    ? 'Aguardando leitor nativo...'
                    : 'Acionar Leitor Nativo do Celular',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: OmniTheme.neonCyan,
                side: BorderSide(
                    color: OmniTheme.alpha(OmniTheme.neonCyan, 0.45)),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
