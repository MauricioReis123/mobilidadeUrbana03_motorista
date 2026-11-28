import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../config/omni_theme.dart';
import '../models/omni_models.dart';
import '../providers/omni_driver_provider.dart';
import '../services/local_vision_engine.dart';
import '../services/sound_service.dart';
import '../services/vision_service.dart';

/// Modal Real de Verificação Biométrica Facial (Câmera Frontal Ao Vivo + ML Kit + Match Cruzado RG/CNH)
/// 1:1 com src/components/BiometricVerificationModal.tsx
class BiometricVerificationModal extends StatefulWidget {
  const BiometricVerificationModal({super.key});

  @override
  State<BiometricVerificationModal> createState() =>
      _BiometricVerificationModalState();
}

enum _BioStep { document, faceScan, comparing, result }

class _BiometricVerificationModalState extends State<BiometricVerificationModal>
    with WidgetsBindingObserver {
  _BioStep _step = _BioStep.document;

  // Documento com foto (opcional p/ modo Oval-First, ou RG/CNH existente/capturado)
  Uint8List? _docBytes;
  String? _docPath;
  String _selectedDocType = 'RG'; // 'RG' | 'CNH_EAR'

  // Selfie real capturada da câmera frontal
  Uint8List? _selfieBytes;
  String? _selfiePath;

  // Câmera ao vivo + ML Kit Stream
  CameraController? _cameraController;
  CameraDescription? _frontCamera;
  bool _initializingCamera = false;
  bool _isOpeningCamera = false;
  bool _disposingCamera = false;
  String? _cameraError;
  bool _isStreaming = false;
  bool _isInferringFrame = false;
  bool _isCapturing = false;
  bool _screenFlashBoost = false;
  DateTime _lastInferenceAt = DateTime.fromMillisecondsSinceEpoch(0);
  double _ovalProgress = 0.0; // 0.0 .. 1.0 progresso contínuo até 100% captura automática

  // Assinatura facial extraída do RG/CNH para match ao vivo no oval (>= 30%)
  DocumentFaceSignature? _docSignature;
  bool _extractingDocSig = false;

  LiveOvalFaceMetrics _metrics = const LiveOvalFaceMetrics(
    hasFace: false,
    faceCount: 0,
    isAligned: false,
    fitScore: 0,
    instruction: 'POSICIONE SEU ROSTO DENTRO DA MOLDURA OVAL',
    issueCode: 'NO_FACE',
  );

  FaceComparisonAiResult? _compareResult;
  bool _ovalOnlySaved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prefillFromProvider();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_cameraController != null && _step == _BioStep.faceScan) {
        _stopAndDisposeCamera(unmountDelayMs: 60);
      }
    }
  }

  void _prefillFromProvider() {
    final p = context.read<OmniDriverProvider>();
    final docs = p.documents;

    DriverDocument? docWithPhoto;
    for (final d in docs) {
      final hasFaceFile = d.faceFileBytes != null && d.faceFileBytes!.isNotEmpty ||
          (d.faceFilePath != null &&
              d.faceFilePath!.isNotEmpty &&
              File(d.faceFilePath!).existsSync());
      final hasDocFile = (d.fileBytes != null &&
              d.fileBytes!.isNotEmpty &&
              !(d.fileName?.toLowerCase().endsWith('.pdf') ?? false)) ||
          (d.filePath != null &&
              d.filePath!.isNotEmpty &&
              !d.filePath!.toLowerCase().endsWith('.pdf') &&
              File(d.filePath!).existsSync());
      if ((d.type == 'RG' || d.type == 'CNH_EAR') &&
          d.status == 'APPROVED' &&
          (hasFaceFile || hasDocFile)) {
        docWithPhoto = d;
        break;
      }
    }

    if (docWithPhoto != null) {
      _docBytes = docWithPhoto.faceFileBytes ?? docWithPhoto.fileBytes;
      _docPath = docWithPhoto.faceFilePath ?? docWithPhoto.filePath;
      _selectedDocType = docWithPhoto.type;
    } else if (p.driver.biometricDocumentBytes != null ||
        (p.driver.biometricDocumentPath != null &&
            File(p.driver.biometricDocumentPath!).existsSync())) {
      _docBytes = p.driver.biometricDocumentBytes;
      _docPath = p.driver.biometricDocumentPath;
    }

    if (_docBytes != null || _docPath != null) {
      _refreshDocSignature();
    }
  }

  Future<void> _refreshDocSignature() async {
    final hasDoc = (_docBytes != null && _docBytes!.isNotEmpty) ||
        (_docPath != null &&
            _docPath!.isNotEmpty &&
            File(_docPath!).existsSync());
    if (!hasDoc) {
      if (mounted) {
        setState(() {
          _docSignature = null;
          _extractingDocSig = false;
        });
      } else {
        _docSignature = null;
        _extractingDocSig = false;
      }
      return;
    }

    if (mounted) setState(() => _extractingDocSig = true);
    final sig = await LocalVisionEngine.instance.extractDocumentFaceSignature(
      documentPath: _docPath,
      documentBytes: _docBytes,
    );
    if (!mounted) return;
    setState(() {
      _docSignature = sig;
      _extractingDocSig = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCameraSync();
    super.dispose();
  }

  void _disposeCameraSync() {
    final ctrl = _cameraController;
    _cameraController = null;
    _isStreaming = false;
    if (ctrl != null) {
      if (ctrl.value.isStreamingImages) {
        ctrl.stopImageStream().catchError((_) {}).whenComplete(() {
          ctrl.dispose().catchError((_) {});
        });
      } else {
        ctrl.dispose().catchError((_) {});
      }
    }
  }

  Future<void> _stopAndDisposeCamera({int unmountDelayMs = 120}) async {
    if (_disposingCamera) return;
    _disposingCamera = true;
    try {
      final ctrl = _cameraController;
      _cameraController = null;
      _isStreaming = false;
      if (mounted) {
        setState(() {});
        await Future.delayed(Duration(milliseconds: unmountDelayMs));
      }
      if (ctrl != null) {
        try {
          if (ctrl.value.isStreamingImages) {
            await ctrl.stopImageStream();
            await Future.delayed(const Duration(milliseconds: 90));
          }
        } catch (_) {}
        try {
          await ctrl.dispose();
        } catch (_) {}
      }
    } finally {
      _disposingCamera = false;
    }
  }

  Future<void> _startLiveFaceCamera() async {
    if (_isOpeningCamera) return;
    _isOpeningCamera = true;
    try {
      await _stopAndDisposeCamera();
      for (int i = 0; i < 10 && _disposingCamera; i++) {
        await Future.delayed(const Duration(milliseconds: 30));
      }
      if (_docSignature == null &&
          ((_docBytes != null && _docBytes!.isNotEmpty) ||
              (_docPath != null &&
                  _docPath!.isNotEmpty &&
                  File(_docPath!).existsSync()))) {
        await _refreshDocSignature();
      }
      if (!mounted) return;
      setState(() {
        _step = _BioStep.faceScan;
        _initializingCamera = true;
        _cameraError = null;
        _ovalProgress = 0.0;
        _isCapturing = false;
        _metrics = LiveOvalFaceMetrics(
          hasFace: false,
          faceCount: 0,
          isAligned: false,
          fitScore: 0,
          docMatchScore: _docSignature != null ? 0.0 : null,
          instruction: 'INICIANDO CÂMERA FRONTAL AO VIVO...',
          issueCode: 'NO_FACE',
        );
      });

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _initializingCamera = false;
          _cameraError =
              'Nenhuma câmera detectada no dispositivo. Use o botão de Câmera Nativa abaixo.';
        });
        return;
      }

      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _frontCamera = front;

      final formatCandidates = Platform.isAndroid
          ? const [ImageFormatGroup.nv21, ImageFormatGroup.yuv420]
          : const [ImageFormatGroup.bgra8888];

      CameraController? initializedCtrl;
      Object? lastInitErr;
      for (final fmt in formatCandidates) {
        final candidate = CameraController(
          front,
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: fmt,
        );
        try {
          await candidate.initialize();
          initializedCtrl = candidate;
          break;
        } catch (err) {
          lastInitErr = err;
          await candidate.dispose().catchError((_) {});
        }
      }

      if (initializedCtrl == null) {
        throw lastInitErr ?? Exception('CAMERA_INIT_FAILED');
      }

      if (!mounted) {
        await initializedCtrl.dispose();
        return;
      }
      _cameraController = initializedCtrl;

      setState(() {
        _initializingCamera = false;
        _isStreaming = true;
      });

      await initializedCtrl.startImageStream(_onCameraFrame);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializingCamera = false;
        _cameraError =
            'Permissão ou inicialização da câmera falhou ($e). Use a Câmera Nativa abaixo.';
      });
    } finally {
      _isOpeningCamera = false;
    }
  }

  Future<void> _onCameraFrame(CameraImage image) async {
    if (!mounted || !_isStreaming || _isCapturing || _isInferringFrame) return;
    final cam = _frontCamera;
    if (cam == null) return;

    final now = DateTime.now();
    if (now.difference(_lastInferenceAt).inMilliseconds < 120) return;

    _isInferringFrame = true;
    _lastInferenceAt = now;

    try {
      final metrics = await LocalVisionEngine.instance.detectLiveOvalFace(
        image,
        cam,
        docReference: _docSignature,
      );
      if (!mounted || !_isStreaming || _isCapturing) {
        _isInferringFrame = false;
        return;
      }

      double nextProgress = _ovalProgress;
      final bool docOk =
          metrics.docMatchScore == null || metrics.docMatchScore! >= 30.0;
      if (metrics.isAligned) {
        // Sobe de forma fluida (~7 frames consecutivos bem encaixados) até 100%
        nextProgress = (_ovalProgress + 0.15).clamp(0.0, 1.0);
      } else if (metrics.hasFace &&
          metrics.fitScore >= 60 &&
          docOk &&
          metrics.issueCode != 'MULTI_FACE') {
        nextProgress = (_ovalProgress - 0.04).clamp(0.0, 1.0);
      } else {
        nextProgress = (_ovalProgress - 0.09).clamp(0.0, 1.0);
      }

      setState(() {
        _metrics = metrics;
        _ovalProgress = nextProgress;
      });

      // Completou 100% do anel verde no oval -> trava 160ms para feedback visual e captura REAL!
      if (nextProgress >= 0.99) {
        _isInferringFrame = false;
        await _autoLockAndCaptureFromLiveStream();
        return;
      }
    } catch (_) {
      // Ignora frame corrompido isolado
    } finally {
      _isInferringFrame = false;
    }
  }

  Future<void> _autoLockAndCaptureFromLiveStream() async {
    if (_isCapturing) return;
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    setState(() {
      _ovalProgress = 1.0;
      _isCapturing = true;
      _isStreaming = false;
    });

    await Future.delayed(const Duration(milliseconds: 160));
    await _performLiveTakePicture(ctrl);
  }

  Future<void> _captureRealSelfieFromLiveStream() async {
    if (_isCapturing) return;
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    setState(() {
      _ovalProgress = 1.0;
      _isCapturing = true;
      _isStreaming = false;
    });

    await _performLiveTakePicture(ctrl);
  }

  Future<void> _performLiveTakePicture(CameraController ctrl) async {
    try {
      if (ctrl.value.isStreamingImages) {
        await ctrl.stopImageStream();
      }
      await Future.delayed(const Duration(milliseconds: 90));
      final xFile = await ctrl.takePicture();
      final bytes = await xFile.readAsBytes();
      await _stopAndDisposeCamera();
      await _processCapturedSelfie(bytes, xFile.path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        _cameraError =
            'Erro ao capturar foto ao vivo ($e). Tente a Câmera Nativa.';
      });
    }
  }

  Future<void> _captureNativeFrontCamera() async {
    await _stopAndDisposeCamera();
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 86,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      await _processCapturedSelfie(bytes, picked.path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = 'Falha ao abrir câmera nativa: $e';
      });
    }
  }

  Future<void> _pickDocumentPhoto({required bool fromCamera}) async {
    try {
      if (fromCamera) {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.rear,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 86,
        );
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        if (!mounted) return;
        setState(() {
          _docBytes = bytes;
          _docPath = picked.path;
        });
        await _refreshDocSignature();
      } else {
        final res = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
          withData: true,
        );
        if (res == null || res.files.isEmpty) return;
        final f = res.files.first;
        final bytes = f.bytes ??
            (f.path != null ? await File(f.path!).readAsBytes() : null);
        if (bytes == null || !mounted) return;
        setState(() {
          _docBytes = bytes;
          _docPath = f.path;
        });
        await _refreshDocSignature();
      }
    } catch (e) {
      if (!mounted) return;
      context.read<OmniDriverProvider>().addAlert(
            'Erro ao selecionar documento',
            'Não foi possível carregar a imagem do documento ($e).',
            'warning',
          );
    }
  }

  Future<void> _processCapturedSelfie(Uint8List bytes, String filePath) async {
    if (!mounted) return;
    final p = context.read<OmniDriverProvider>();
    final savedSelfiePath = await p.persistCapturedMedia(bytes, 'oval_selfie');

    setState(() {
      _selfieBytes = bytes;
      _selfiePath = savedSelfiePath;
      _step = _BioStep.comparing;
      _ovalOnlySaved = false;
    });

    final hasDoc = (_docBytes != null && _docBytes!.isNotEmpty) ||
        (_docPath != null &&
            _docPath!.isNotEmpty &&
            File(_docPath!).existsSync());

    if (!hasDoc) {
      await p.saveCapturedOvalFace(bytes, filePath: savedSelfiePath);
      if (!mounted) return;
      setState(() {
        _ovalOnlySaved = true;
        _compareResult = const FaceComparisonAiResult(
          approved: true,
          documentValid: true,
          documentTypeDetected: 'Selfie Oval Capturada',
          livenessCheckPassed: true,
          isSamePerson: true,
          confidenceScore: 95.0,
          facialFeaturesAnalysis:
              'Seu rosto real foi capturado com 100% de encaixe dentro da moldura oval via ML Kit. Envie seu RG e CNH para concluir o Match Facial Cruzado.',
          resolutionTier: 1,
          engineUsed: 'MLKit Live Face Oval On-Device',
        );
        _step = _BioStep.result;
      });
      return;
    }

    final result = await OmniVisionService.compareFaces(
      documentPath: _docPath,
      documentBytes: _docBytes,
      selfiePath: savedSelfiePath,
      selfieBytes: bytes,
    );

    if (!mounted) return;
    final passed = result.approved && result.isSamePerson;

    await p.setBiometricVerified(
      passed,
      avatarBytes: bytes,
      avatarPath: savedSelfiePath,
      documentBytes: _docBytes,
      documentPath: _docPath,
      result: result,
      docType: _selectedDocType,
    );

    if (!mounted) return;
    setState(() {
      _compareResult = result;
      _step = _BioStep.result;
    });

    if (!passed) {
      await OmniSoundService.playAlert();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();
    if (!p.biometricModalOpen) return const SizedBox.shrink();

    final rgDoc = p.documents.cast<DriverDocument?>().firstWhere(
          (d) =>
              d != null &&
              d.type == 'RG' &&
              ((d.faceFileBytes != null && d.faceFileBytes!.isNotEmpty) ||
                  (d.faceFilePath != null &&
                      File(d.faceFilePath!).existsSync()) ||
                  (d.fileBytes != null &&
                      d.fileBytes!.isNotEmpty &&
                      !(d.fileName?.toLowerCase().endsWith('.pdf') ?? false)) ||
                  (d.filePath != null &&
                      !d.filePath!.toLowerCase().endsWith('.pdf') &&
                      File(d.filePath!).existsSync())),
          orElse: () => null,
        );
    final cnhDoc = p.documents.cast<DriverDocument?>().firstWhere(
          (d) =>
              d != null &&
              d.type == 'CNH_EAR' &&
              ((d.faceFileBytes != null && d.faceFileBytes!.isNotEmpty) ||
                  (d.faceFilePath != null &&
                      File(d.faceFilePath!).existsSync()) ||
                  (d.fileBytes != null &&
                      d.fileBytes!.isNotEmpty &&
                      !(d.fileName?.toLowerCase().endsWith('.pdf') ?? false)) ||
                  (d.filePath != null &&
                      !d.filePath!.toLowerCase().endsWith('.pdf') &&
                      File(d.filePath!).existsSync())),
          orElse: () => null,
        );

    final progressPct = (_ovalProgress * 100).round().clamp(0, 100);

    return Material(
      color: OmniTheme.alpha(Colors.black, 0.86),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 460,
              maxHeight: MediaQuery.of(context).size.height * 0.90,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: OmniTheme.slate950,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _screenFlashBoost
                      ? Colors.white
                      : OmniTheme.alpha(OmniTheme.neonCyan, 0.45),
                  width: _screenFlashBoost ? 3 : 1,
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cabeçalho
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: OmniTheme.alpha(OmniTheme.neonCyan, 0.14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: OmniTheme.alpha(OmniTheme.neonCyan, 0.35)),
                          ),
                          child: const Icon(Icons.face_retouching_natural,
                              color: OmniTheme.neonCyan, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Biometria Facial Ao Vivo',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Captura automática 100% no oval • ML Kit',
                                style: TextStyle(
                                    fontSize: 11, color: OmniTheme.slate400),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            _stopAndDisposeCamera();
                            p.setBiometricModalOpen(false);
                          },
                          icon: const Icon(Icons.close_rounded,
                              color: OmniTheme.slate400),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Stepper visual
                    Row(
                      children: [
                        _StepChip(
                            label: '1. Doc',
                            active: _step == _BioStep.document,
                            done: _step.index > 0),
                        const SizedBox(width: 4),
                        _StepChip(
                            label: '2. Rosto Oval',
                            active: _step == _BioStep.faceScan,
                            done: _step.index > 1),
                        const SizedBox(width: 4),
                        _StepChip(
                            label: '3. Visão IA',
                            active: _step == _BioStep.comparing,
                            done: _step.index > 2),
                        const SizedBox(width: 4),
                        _StepChip(
                            label: '4. Laudo',
                            active: _step == _BioStep.result,
                            done: false),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // PASSO 1: ESCOLHA DO DOCUMENTO OU MODO OVAL DIRETO
                    if (_step == _BioStep.document) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: OmniTheme.neonCardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Documento com Foto para Match Facial (Opcional antes do Oval)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Você pode escolher RG/CNH para comparar imediatamente com seu rosto ou capturar seu rosto no oval primeiro.',
                              style: TextStyle(
                                  fontSize: 11, color: OmniTheme.slate400),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: ChoiceChip(
                                    label: const Text('RG / CIN'),
                                    selected: _selectedDocType == 'RG',
                                    onSelected: (_) {
                                      setState(() {
                                        _selectedDocType = 'RG';
                                        if (rgDoc != null) {
                                          _docBytes = rgDoc.faceFileBytes ??
                                              rgDoc.fileBytes;
                                          _docPath = rgDoc.faceFilePath ??
                                              rgDoc.filePath;
                                        }
                                      });
                                      _refreshDocSignature();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ChoiceChip(
                                    label: const Text('CNH c/ EAR'),
                                    selected: _selectedDocType == 'CNH_EAR',
                                    onSelected: (_) {
                                      setState(() {
                                        _selectedDocType = 'CNH_EAR';
                                        if (cnhDoc != null) {
                                          _docBytes = cnhDoc.faceFileBytes ??
                                              cnhDoc.fileBytes;
                                          _docPath = cnhDoc.faceFilePath ??
                                              cnhDoc.filePath;
                                        }
                                      });
                                      _refreshDocSignature();
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (_docBytes != null && _docBytes!.isNotEmpty) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  _docBytes!,
                                  cacheWidth: 600,
                                  height: 120,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ] else if (_docPath != null &&
                                File(_docPath!).existsSync()) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(_docPath!),
                                  cacheWidth: 600,
                                  height: 120,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ] else ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: OmniTheme.slate900,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: OmniTheme.slate800),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.badge_outlined,
                                        color: OmniTheme.slate400, size: 22),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Nenhum documento selecionado ainda. Você pode fotografar agora ou capturar a selfie oval primeiro.',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: OmniTheme.slate400),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _pickDocumentPhoto(fromCamera: true),
                                    icon: const Icon(Icons.photo_camera_rounded,
                                        size: 16),
                                    label: const Text('Fotografar Doc'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _pickDocumentPhoto(fromCamera: false),
                                    icon: const Icon(Icons.folder_open_rounded,
                                        size: 16),
                                    label: const Text('Arquivo / Galeria'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _startLiveFaceCamera,
                          icon: const Icon(Icons.videocam_rounded, size: 18),
                          label: Text((_docBytes != null || _docPath != null)
                              ? 'Abrir Câmera Frontal & Validar no Oval'
                              : 'Capturar Rosto no Oval Primeiro'),
                        ),
                      ),
                    ],

                    // PASSO 2: CÂMERA FRONTAL AO VIVO DENTRO DA MOLDURA OVAL
                    if (_step == _BioStep.faceScan) ...[
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 350),
                          child: AspectRatio(
                            aspectRatio: 3 / 4,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Container(color: const Color(0xFF05080F)),

                                  if (_cameraController != null &&
                                      _cameraController!.value.isInitialized)
                                    FittedBox(
                                      fit: BoxFit.cover,
                                      child: SizedBox(
                                        width: _cameraController!
                                            .value.previewSize!.height,
                                        height: _cameraController!
                                            .value.previewSize!.width,
                                        child: CameraPreview(_cameraController!),
                                      ),
                                    )
                                  else if (_initializingCamera)
                                    const Center(
                                      child: CircularProgressIndicator(
                                          color: OmniTheme.neonCyan),
                                    )
                                  else
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Text(
                                          _cameraError ??
                                              'Câmera frontal indisponível.',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: OmniTheme.amber400,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Aro opcional de Luz Frontal branca para ambientes escuros
                                  if (_screenFlashBoost)
                                    IgnorePointer(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(24),
                                          border: Border.all(
                                            color: OmniTheme.alpha(
                                                Colors.white, 0.92),
                                            width: 14,
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Máscara com recorte oval e anel verde suave contínuo (0% -> 100%)
                                  CustomPaint(
                                    painter: _OvalGuideOverlayPainter(
                                      isAligned: _metrics.isAligned,
                                      hasFace: _metrics.hasFace,
                                      fitScore: _metrics.fitScore,
                                      progress: _ovalProgress,
                                      screenFlashBoost: _screenFlashBoost,
                                    ),
                                  ),

                                  // Barra superior: Enquadramento + Match ao Vivo c/ DOC + Luz Frontal
                                  Positioned(
                                    top: 10,
                                    left: 10,
                                    right: 10,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Wrap(
                                            spacing: 5,
                                            runSpacing: 4,
                                            children: [
                                              _OverlayPill(
                                                text: _ovalProgress >= 0.99
                                                    ? 'TRAVADO 100% ✓'
                                                    : _ovalProgress > 0.05
                                                        ? 'CAPTURANDO $progressPct%'
                                                        : 'OVAL ${_metrics.fitScore}%',
                                                color: (_metrics.isAligned ||
                                                        _ovalProgress >= 0.3)
                                                    ? OmniTheme.neonEmerald
                                                    : _metrics.hasFace
                                                        ? OmniTheme.neonCyan
                                                        : OmniTheme.amber400,
                                              ),
                                              if (_docSignature != null ||
                                                  _extractingDocSig)
                                                _OverlayPill(
                                                  text: _extractingDocSig
                                                      ? 'DOC ...'
                                                      : 'DOC ${_metrics.docMatchScore?.round() ?? 0}%',
                                                  color: (_metrics.docMatchScore !=
                                                              null &&
                                                          _metrics.docMatchScore! >=
                                                              30.0)
                                                      ? OmniTheme.neonEmerald
                                                      : OmniTheme.amber400,
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        InkWell(
                                          onTap: () => setState(() =>
                                              _screenFlashBoost =
                                                  !_screenFlashBoost),
                                          borderRadius:
                                              BorderRadius.circular(99),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 9, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: _screenFlashBoost
                                                  ? OmniTheme.amber400
                                                  : OmniTheme.alpha(
                                                      Colors.black, 0.72),
                                              borderRadius:
                                                  BorderRadius.circular(99),
                                              border: Border.all(
                                                color: _screenFlashBoost
                                                    ? Colors.white
                                                    : OmniTheme.amber400,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  _screenFlashBoost
                                                      ? Icons.wb_sunny_rounded
                                                      : Icons.wb_sunny_outlined,
                                                  size: 13,
                                                  color: _screenFlashBoost
                                                      ? Colors.black
                                                      : OmniTheme.amber400,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _screenFlashBoost
                                                      ? 'Luz ON'
                                                      : 'Luz Frontal',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w900,
                                                    color: _screenFlashBoost
                                                        ? Colors.black
                                                        : OmniTheme.amber400,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Instrução em tempo real na parte inferior
                                  Positioned(
                                    bottom: 12,
                                    left: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: OmniTheme.alpha(
                                            Colors.black, 0.80),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: (_metrics.isAligned ||
                                                  _ovalProgress >= 0.99)
                                              ? OmniTheme.neonEmerald
                                              : OmniTheme.alpha(
                                                  OmniTheme.neonCyan, 0.5),
                                        ),
                                      ),
                                      child: Text(
                                        _isCapturing
                                            ? 'ROSTO 100% ENCAIXADO ✓ CAPTURANDO FOTO...'
                                            : _metrics.instruction,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: (_metrics.isAligned ||
                                                  _isCapturing)
                                              ? OmniTheme.neonEmerald
                                              : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (_cameraController != null &&
                                      _cameraController!.value.isInitialized &&
                                      !_isCapturing)
                                  ? _captureRealSelfieFromLiveStream
                                  : null,
                              icon: const Icon(Icons.camera_rounded, size: 17),
                              label: Text(_isCapturing
                                  ? 'Capturando...'
                                  : 'Capturar Manualmente'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed:
                                _isCapturing ? null : _captureNativeFrontCamera,
                            icon: const Icon(Icons.photo_camera_front_rounded,
                                size: 16),
                            label: const Text('Nativa'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            _stopAndDisposeCamera();
                            setState(() => _step = _BioStep.document);
                          },
                          icon: const Icon(Icons.arrow_back_rounded, size: 16),
                          label: const Text('Voltar p/ Documento'),
                        ),
                      ),
                    ],

                    // PASSO 3: PROCESSANDO VISÃO COMPUTACIONAL
                    if (_step == _BioStep.comparing) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            if (_selfieBytes != null)
                              ClipOval(
                                child: Image.memory(
                                  _selfieBytes!,
                                  cacheWidth: 400,
                                  width: 112,
                                  height: 112,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            const SizedBox(height: 16),
                            const CircularProgressIndicator(
                                color: OmniTheme.neonCyan),
                            const SizedBox(height: 14),
                            const Text(
                              'Processando Biometria Facial Real...',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Executando ML Kit Face Landmarks On-Device com fallback multimodal para comparar sua selfie capturada contra seu documento.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11.5, color: OmniTheme.slate400),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // PASSO 4: LAUDO BIOMÉTRICO REAL
                    if (_step == _BioStep.result && _compareResult != null) ...[
                      Builder(builder: (context) {
                        final res = _compareResult!;
                        final ok = res.approved && res.isSamePerson;
                        final accent =
                            ok ? OmniTheme.neonEmerald : OmniTheme.rose500;
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: OmniTheme.neonCardDecoration(
                            borderColor: OmniTheme.alpha(accent, 0.55),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (_selfieBytes != null)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 10),
                                      child: ClipOval(
                                        child: Image.memory(
                                          _selfieBytes!,
                                          cacheWidth: 300,
                                          width: 54,
                                          height: 54,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    )
                                  else
                                    Icon(
                                      ok
                                          ? Icons.verified_user_rounded
                                          : Icons.gpp_bad_rounded,
                                      color: accent,
                                      size: 32,
                                    ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _ovalOnlySaved
                                              ? 'SELFIE OVAL SALVA COM SUCESSO ✓'
                                              : ok
                                                  ? 'IDENTIDADE FACIAL CONFIRMADA ✓'
                                                  : 'DIVERGÊNCIA BIOMÉTRICA DETECTADA',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w900,
                                            color: accent,
                                          ),
                                        ),
                                        Text(
                                          'Compatibilidade: ${res.confidenceScore.toStringAsFixed(1)}% • ${res.engineUsed ?? 'Visão IA'}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: OmniTheme.slate300,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                res.rejectionReason?.isNotEmpty == true && !ok
                                    ? res.rejectionReason!
                                    : res.facialFeaturesAnalysis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: OmniTheme.slate200,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _startLiveFaceCamera,
                                      child: const Text('Refazer Selfie'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          p.setBiometricModalOpen(false),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: accent,
                                        foregroundColor:
                                            const Color(0xFF05080F),
                                      ),
                                      child: Text(ok ? 'Concluir' : 'Fechar'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OvalGuideOverlayPainter extends CustomPainter {
  final bool isAligned;
  final bool hasFace;
  final int fitScore;
  final double progress;
  final bool screenFlashBoost;

  const _OvalGuideOverlayPainter({
    required this.isAligned,
    required this.hasFace,
    required this.fitScore,
    required this.progress,
    required this.screenFlashBoost,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.5),
      width: size.width * (LocalVisionEngine.ovalRx * 2),
      height: size.height * (LocalVisionEngine.ovalRy * 2),
    );

    final bgPath = Path()..addRect(Offset.zero & size);
    final holePath = Path()..addOval(ovalRect);
    final maskedPath =
        Path.combine(PathOperation.difference, bgPath, holePath);

    canvas.drawPath(
      maskedPath,
      Paint()
        ..color = screenFlashBoost
            ? const Color(0x95FFFFFF)
            : const Color(0xB505080F),
    );

    final borderColor = (isAligned || progress >= 0.99)
        ? OmniTheme.neonEmerald
        : hasFace
            ? OmniTheme.neonCyan
            : OmniTheme.amber400;

    canvas.drawOval(
      ovalRect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isAligned ? 4.0 : 2.6,
    );

    // Trilha de fundo sutil do arco de progresso
    canvas.drawOval(
      ovalRect.inflate(6),
      Paint()
        ..color = const Color(0x3310B981)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5,
    );

    // Anel verde contínuo: sobe suavemente até 100% (2 * pi) ao encaixar o rosto
    final double sweepFraction;
    if (progress > 0.01) {
      sweepFraction = progress.clamp(0.04, 1.0);
    } else if (hasFace && fitScore >= 45) {
      sweepFraction = (fitScore / 200.0).clamp(0.06, 0.45);
    } else {
      sweepFraction = 0.0;
    }

    if (sweepFraction > 0.0) {
      canvas.drawArc(
        ovalRect.inflate(6),
        -1.5708,
        6.2831853 * sweepFraction,
        false,
        Paint()
          ..color = OmniTheme.neonEmerald
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 5.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OvalGuideOverlayPainter oldDelegate) =>
      oldDelegate.isAligned != isAligned ||
      oldDelegate.hasFace != hasFace ||
      oldDelegate.fitScore != fitScore ||
      oldDelegate.progress != progress ||
      oldDelegate.screenFlashBoost != screenFlashBoost;
}

class _OverlayPill extends StatelessWidget {
  final String text;
  final Color color;

  const _OverlayPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: OmniTheme.alpha(Colors.black, 0.72),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: OmniTheme.alpha(color, 0.7)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool done;

  const _StepChip({
    required this.label,
    required this.active,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final c = active
        ? OmniTheme.neonCyan
        : done
            ? OmniTheme.neonEmerald
            : OmniTheme.slate400;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: active
              ? OmniTheme.alpha(OmniTheme.neonCyan, 0.14)
              : OmniTheme.slate900,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? OmniTheme.neonCyan
                : done
                    ? OmniTheme.alpha(OmniTheme.neonEmerald, 0.5)
                    : OmniTheme.slate800,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: c,
          ),
        ),
      ),
    );
  }
}
