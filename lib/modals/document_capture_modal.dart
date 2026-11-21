import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
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

/// Modal Real de Captura & Auditoria Documental (CPF, RG, CNH c/ EAR, CRLV, Antecedentes, Residência, Foto Perfil)
/// Usa Câmera Ampliada Ao Vivo (Foco ao Toque com Retículo Luminoso, Flash/Lanterna, Controle de Brilho/Exposição),
/// Câmera Nativa, Galeria, Seletor PDF/Arquivo + ML Kit OCR + Fallback Nuvem.
/// 1:1 com src/components/DocumentCaptureModal.tsx
class DocumentCaptureModal extends StatefulWidget {
  const DocumentCaptureModal({super.key});

  @override
  State<DocumentCaptureModal> createState() => _DocumentCaptureModalState();
}

enum _DocMode { choice, camera, analyzing, result }

enum _CapturePhase { partAFace, partBData }

class _DocumentCaptureModalState extends State<DocumentCaptureModal>
    with WidgetsBindingObserver {
  _DocMode _mode = _DocMode.choice;
  _CapturePhase _capturePhase = _CapturePhase.partBData;
  bool _useSingleDigitalMode = false;
  String? _trackedDocId;

  Uint8List? _partAFaceBytes;
  String? _partAFacePath;
  String? _partAFaceNote;
  String? _phaseErrorMsg;
  String _analyzingLabel = 'Executando Leitura OCR & Auditoria Antifraude...';

  CameraController? _cameraController;
  List<CameraDescription> _cameras = const [];
  int _selectedCameraIndex = 0;
  bool _initializingCamera = false;
  bool _isOpeningCamera = false;
  bool _disposingCamera = false;
  bool _isCapturing = false;
  bool _isStreaming = false;
  bool _isScanningFrame = false;
  bool _liveAutoLocked = false;
  String _liveScanStatus = 'LENDO DOCUMENTO AO VIVO PARA AUTO-CAPTURA...';
  DateTime _lastScanAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastCloudLiveScanAt = DateTime.fromMillisecondsSinceEpoch(0);
  DriverDocument? _activeLiveDoc;
  String? _cameraError;

  // Controles de Luz, Flash e Foco por Toque na Câmera
  bool _flashTorchOn = false;
  double _minExposure = -2.0;
  double _maxExposure = 2.0;
  double _exposureOffset = 0.0;
  Offset? _focusTapPos;
  int _focusAnimKey = 0;
  Timer? _focusHideTimer;

  Uint8List? _previewBytes;
  String? _previewPath;
  String? _fileName;
  bool _isPdf = false;

  DocumentAiAuditResult? _auditResult;
  DocumentUploadCrossResult? _crossResult;
  int _stableDocFrames = 0;

  bool _hasClearDocumentInYPlane(CameraImage image) {
    if (image.planes.isEmpty) return false;
    final yBytes = image.planes[0].bytes;
    if (yBytes.length < 200) return false;
    final step = math.max(1, yBytes.length ~/ 500);
    double sum = 0;
    double sumSq = 0;
    double edgeSum = 0;
    int prev = yBytes[0];
    int n = 0;
    for (int i = 0; i < yBytes.length; i += step) {
      final v = yBytes[i];
      sum += v;
      sumSq += v * v;
      if (n > 0) edgeSum += (v - prev).abs();
      prev = v;
      n++;
    }
    if (n < 20) return false;
    final mean = sum / n;
    final variance = math.max(0.0, (sumSq / n) - (mean * mean));
    final stdDev = math.sqrt(variance);
    final avgEdge = edgeSum / n;
    return mean >= 38 && mean <= 240 && stdDev >= 20 && avgEdge >= 6.0;
  }

  bool _supportsSplitForType(String type) => type == 'RG' || type == 'CNH_EAR';

  bool _isPortraitPhaseForType(String type) =>
      _supportsSplitForType(type) &&
      !_useSingleDigitalMode &&
      _capturePhase == _CapturePhase.partAFace;

  void _syncForDoc(DriverDocument doc) {
    if (_trackedDocId == doc.id) return;
    _trackedDocId = doc.id;
    _mode = _DocMode.choice;
    _useSingleDigitalMode = false;
    _capturePhase = _supportsSplitForType(doc.type)
        ? _CapturePhase.partAFace
        : _CapturePhase.partBData;
    _partAFaceBytes = null;
    _partAFacePath = null;
    _partAFaceNote = null;
    _phaseErrorMsg = null;
    _previewBytes = null;
    _previewPath = null;
    _fileName = null;
    _isPdf = false;
    _auditResult = null;
    _crossResult = null;
    _isCapturing = false;
    _liveAutoLocked = false;
    _isScanningFrame = false;
    _stableDocFrames = 0;
    _cameraError = null;
    final p = context.read<OmniDriverProvider>();
    if (p.documentCaptureAutoCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mode == _DocMode.choice && !_isOpeningCamera) {
          _openLiveCamera(doc);
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_cameraController != null && _mode == _DocMode.camera) {
        _stopAndDisposeCamera(unmountDelayMs: 60);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusHideTimer?.cancel();
    _disposeCameraSync();
    super.dispose();
  }

  void _disposeCameraSync() {
    final ctrl = _cameraController;
    _cameraController = null;
    _isStreaming = false;
    if (ctrl != null) {
      ctrl.setFlashMode(FlashMode.off).catchError((_) {});
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
      _focusHideTimer?.cancel();
      final ctrl = _cameraController;
      _cameraController = null;
      _isStreaming = false;
      _flashTorchOn = false;
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
          await ctrl.setFlashMode(FlashMode.off);
        } catch (_) {}
        try {
          await ctrl.dispose();
        } catch (_) {}
      }
    } finally {
      _disposingCamera = false;
    }
  }

  String _tipForDocType(String type) {
    switch (type) {
      case 'CPF':
        return 'Aproxime o Cartão CPF, Comprovante Receita ou verso do RG/CNH ocupando toda a área. Toque na tela sobre os números para focar!';
      case 'RG':
        return 'Enquadre o RG aberto (ou CIN) ocupando bem o visor. Toque na tela para focar o número e ative o brilho/flash se precisar.';
      case 'CNH_EAR':
      case 'CNH':
        return 'Fotografe sua CNH física aberta ou envie o PDF/print da CNH Digital com Categoria e EAR bem legíveis.';
      case 'CRLV':
        return 'Enquadre o CRLV-e mostrando Placa, RENAVAM, Marca/Modelo e exercício anual.';
      case 'BACKGROUND_CHECK':
      case 'ANTECEDENTES':
        return 'Envie a Certidão de Antecedentes Criminais (PF ou SSP) em PDF ou foto legível.';
      case 'RESIDENCE_PROOF':
        return 'Fotografe ou envie PDF de conta de luz, água ou internet recente em seu nome.';
      case 'PROFILE_PHOTO':
        return 'Tire uma foto frontal nítida do seu rosto em local iluminado e fundo neutro (sem óculos escuros).';
      default:
        return 'Centralize o documento ocupando toda a moldura e toque na tela para ativar o foco luminoso.';
    }
  }

  Future<void> _openLiveCamera(DriverDocument doc) async {
    if (_isOpeningCamera) return;
    _isOpeningCamera = true;
    try {
      await _stopAndDisposeCamera();
      if (!mounted) return;
      setState(() {
        _activeLiveDoc = doc;
        _mode = _DocMode.camera;
        _initializingCamera = true;
        _cameraError = null;
        _isCapturing = false;
        _liveAutoLocked = false;
        _isScanningFrame = false;
        _stableDocFrames = 0;
        _liveScanStatus = doc.type == 'PROFILE_PHOTO'
            ? 'CENTRALIZE SEU ROSTO PARA AUTO-CAPTURA...'
            : _isPortraitPhaseForType(doc.type)
                ? 'PARTE A: APONTE PARA O LADO COM A FOTO 3x4 DO ROSTO...'
                : 'PARTE B: APONTE PARA O DOCUMENTO (AUTO-OCR)...';
        _flashTorchOn = false;
        _exposureOffset = 0.0;
        _focusTapPos = null;
      });

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _initializingCamera = false;
          _cameraError =
              'Nenhuma câmera encontrada. Use "Câmera Nativa" ou "Selecionar Arquivo/PDF".';
        });
        return;
      }

      _cameras = cameras;
      final desiredDirection = doc.type == 'PROFILE_PHOTO'
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      final idx = cameras.indexWhere((c) => c.lensDirection == desiredDirection);
      _selectedCameraIndex = idx >= 0 ? idx : 0;

      await _initSelectedCamera();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializingCamera = false;
        _cameraError = 'Não foi possível iniciar a câmera ($e).';
      });
    } finally {
      _isOpeningCamera = false;
    }
  }

  Future<void> _initSelectedCamera() async {
    await _stopAndDisposeCamera();
    for (int i = 0; i < 10 && _disposingCamera; i++) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (_cameras.isEmpty || !mounted) return;
    setState(() {
      _initializingCamera = true;
      _cameraError = null;
      _liveAutoLocked = false;
      _isScanningFrame = false;
      _isCapturing = false;
    });

    try {
      final cam = _cameras[_selectedCameraIndex % _cameras.length];
      final formatCandidates = Platform.isAndroid
          ? const [ImageFormatGroup.nv21, ImageFormatGroup.yuv420]
          : const [ImageFormatGroup.bgra8888];

      CameraController? ctrl;
      Object? lastInitErr;
      for (final fmt in formatCandidates) {
        final candidate = CameraController(
          cam,
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: fmt,
        );
        try {
          await candidate.initialize();
          ctrl = candidate;
          break;
        } catch (err) {
          lastInitErr = err;
          await candidate.dispose().catchError((_) {});
        }
      }

      if (ctrl == null) {
        throw lastInitErr ?? Exception('CAMERA_INIT_FAILED');
      }

      double minExp = -2.0;
      double maxExp = 2.0;
      try {
        minExp = await ctrl.getMinExposureOffset();
        maxExp = await ctrl.getMaxExposureOffset();
      } catch (_) {}

      try {
        await ctrl.setFocusMode(FocusMode.auto);
        await ctrl.setExposureMode(ExposureMode.auto);
      } catch (_) {}

      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() {
        _cameraController = ctrl;
        _initializingCamera = false;
        _isStreaming = true;
        _minExposure = minExp;
        _maxExposure = maxExp > minExp ? maxExp : minExp + 2.0;
        _exposureOffset = 0.0.clamp(_minExposure, _maxExposure);
      });

      try {
        await ctrl.startImageStream(_onLiveCameraFrame);
      } catch (_) {
        // Fallback silencioso: captura manual permanece disponível
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializingCamera = false;
        _cameraError = 'Falha na câmera ($e). Tente a Câmera Nativa abaixo.';
      });
    }
  }

  /// Gera snapshot PNG em escala de cinza (<= 640px) diretamente do plano Y da câmera
  /// para leitura OCR assistida em nuvem caso o texto do documento físico esteja desgastado.
  Future<Uint8List?> _extractGrayscalePngFromYuv(CameraImage image) async {
    if (image.planes.isEmpty) return null;
    final yPlane = image.planes[0];
    final yBytes = yPlane.bytes;
    final srcW = image.width;
    final srcH = image.height;
    final stride = yPlane.bytesPerRow;
    if (srcW <= 0 || srcH <= 0 || yBytes.isEmpty) return null;

    final double scale = srcW > 640 ? 640.0 / srcW : 1.0;
    final dstW = math.max(120, (srcW * scale).round());
    final dstH = math.max(90, (srcH * scale).round());

    final rgba = Uint8List(dstW * dstH * 4);
    for (int y = 0; y < dstH; y++) {
      final sy = ((y * srcH) ~/ dstH).clamp(0, srcH - 1);
      final rowOff = sy * stride;
      for (int x = 0; x < dstW; x++) {
        final sx = ((x * srcW) ~/ dstW).clamp(0, srcW - 1);
        final srcIdx = rowOff + sx;
        final lum = srcIdx < yBytes.length ? yBytes[srcIdx] : 0;
        final outIdx = (y * dstW + x) * 4;
        rgba[outIdx] = lum;
        rgba[outIdx + 1] = lum;
        rgba[outIdx + 2] = lum;
        rgba[outIdx + 3] = 255;
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      dstW,
      dstH,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final img = await completer.future;
    try {
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } finally {
      img.dispose();
    }
  }

  Future<void> _onLiveCameraFrame(CameraImage image) async {
    final doc = _activeLiveDoc;
    if (!mounted ||
        doc == null ||
        !_isStreaming ||
        _liveAutoLocked ||
        _isCapturing ||
        _isScanningFrame) {
      return;
    }

    final int minIntervalMs = doc.type == 'PROFILE_PHOTO' ? 180 : 450;
    final now = DateTime.now();
    if (now.difference(_lastScanAt).inMilliseconds < minIntervalMs) return;

    final cam = _cameras.isNotEmpty
        ? _cameras[_selectedCameraIndex % _cameras.length]
        : null;
    if (cam == null) return;

    _isScanningFrame = true;
    _lastScanAt = now;

    try {
      if (doc.type == 'PROFILE_PHOTO') {
        final metrics =
            await LocalVisionEngine.instance.detectLiveOvalFace(image, cam);
        if (!mounted || !_isStreaming || _liveAutoLocked || _isCapturing) {
          return;
        }
        setState(() {
          _liveScanStatus = metrics.isAligned
              ? 'ROSTO ENQUADRADO (${metrics.fitScore}%) ✓ CAPTURANDO!'
              : metrics.instruction;
        });
        if (metrics.isAligned && metrics.fitScore >= 88) {
          _liveAutoLocked = true;
          _isStreaming = false;
          await OmniSoundService.playSuccess();
          await Future.delayed(const Duration(milliseconds: 220));
          if (mounted && !_isCapturing) {
            await _captureFromLiveCamera(doc);
          }
        }
        return;
      }

      final bool hasVisualDoc = _hasClearDocumentInYPlane(image);
      if (hasVisualDoc) {
        _stableDocFrames++;
      } else {
        _stableDocFrames = math.max(0, _stableDocFrames - 1);
      }

      if (_isPortraitPhaseForType(doc.type)) {
        final portraitScan = await LocalVisionEngine.instance.scanLivePortraitFrame(
          image,
          cam,
        );
        if (!mounted || !_isStreaming || _liveAutoLocked || _isCapturing) {
          return;
        }
        if (portraitScan.ready || _stableDocFrames >= 3) {
          _liveAutoLocked = true;
          _isStreaming = false;
          setState(() {
            _liveScanStatus =
                'FACE COM FOTO ENQUADRADA ✓ CAPTURANDO E ANALISANDO...';
          });
          await OmniSoundService.playSuccess();
          await Future.delayed(const Duration(milliseconds: 220));
          if (mounted && !_isCapturing) {
            await _captureFromLiveCamera(doc);
          }
          return;
        }
        setState(() {
          _liveScanStatus = _stableDocFrames >= 1
              ? 'FACE COM FOTO DETECTADA ($_stableDocFrames/3) • SEGURE FIRME...'
              : portraitScan.statusText;
        });
        return;
      }

      var scan = await LocalVisionEngine.instance.scanLiveDocumentFrame(
        image,
        cam,
        expectedDocType: doc.type,
      );
      if (!mounted || !_isStreaming || _liveAutoLocked || _isCapturing) {
        return;
      }

      // Assistência OCR em nuvem throttled (~1.65s) se o ML Kit local não fechou todos os dígitos ainda
      if (!scan.ready &&
          DateTime.now().difference(_lastCloudLiveScanAt).inMilliseconds >= 1650) {
        _lastCloudLiveScanAt = DateTime.now();
        try {
          final png = await _extractGrayscalePngFromYuv(image);
          if (png != null &&
              mounted &&
              _isStreaming &&
              !_liveAutoLocked &&
              !_isCapturing) {
            final cloudRaw = await OmniVisionService.liveScanDocumentFrame(
              framePngBytes: png,
              expectedDocType: doc.type,
            );
            if (cloudRaw.isNotEmpty) {
              scan = LocalVisionEngine.instance.evaluateRawOcrTextForLiveScan(
                cloudRaw,
                doc.type,
              );
            }
          }
        } catch (_) {}
      }

      if (!mounted || !_isStreaming || _liveAutoLocked || _isCapturing) {
        return;
      }

      if (scan.ready || _stableDocFrames >= 3) {
        _liveAutoLocked = true;
        _isStreaming = false;
        setState(() {
          _liveScanStatus = scan.ready
              ? scan.statusText
              : 'DOCUMENTO ENQUADRADO ✓ DISPARANDO CAPTURA & OCR AUTOMÁTICO!';
        });
        await OmniSoundService.playSuccess();
        await Future.delayed(const Duration(milliseconds: 220));
        if (mounted && !_isCapturing) {
          await _captureFromLiveCamera(doc);
        }
        return;
      }

      setState(() {
        _liveScanStatus = _stableDocFrames >= 1
            ? 'DOCUMENTO DETECTADO ($_stableDocFrames/3) • AUTO-CAPTURA EM INSTANTES...'
            : scan.statusText;
      });
    } catch (_) {
      // Ignora erro isolado de frame e continua leitura ao vivo
    } finally {
      _isScanningFrame = false;
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _isOpeningCamera) return;
    _isOpeningCamera = true;
    try {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
      await _initSelectedCamera();
    } finally {
      _isOpeningCamera = false;
    }
  }

  Future<void> _toggleFlashTorch() async {
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final next = !_flashTorchOn;
    try {
      await ctrl.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) {
        setState(() => _flashTorchOn = next);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _flashTorchOn = false);
      }
    }
  }

  Future<void> _updateExposureOffset(double value) async {
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    setState(() => _exposureOffset = value);
    try {
      await ctrl.setExposureOffset(value);
    } catch (_) {}
  }

  /// Foco e medição de luz ao tocar com o dedo na foto (exibe retículo luminoso)
  Future<void> _onTapFocus(TapUpDetails details, Size boxSize) async {
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    final local = details.localPosition;
    final nx = (local.dx / boxSize.width).clamp(0.05, 0.95);
    final ny = (local.dy / boxSize.height).clamp(0.05, 0.95);

    _focusHideTimer?.cancel();
    setState(() {
      _focusTapPos = local;
      _focusAnimKey++;
    });

    _focusHideTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _focusTapPos = null);
      }
    });

    try {
      await ctrl.setFocusMode(FocusMode.auto);
      await ctrl.setFocusPoint(Offset(nx, ny));
      await ctrl.setExposurePoint(Offset(nx, ny));
    } catch (_) {}
  }

  Future<void> _captureFromLiveCamera(DriverDocument doc) async {
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized || _isCapturing) return;
    setState(() {
      _isCapturing = true;
      _isStreaming = false;
    });
    try {
      if (ctrl.value.isStreamingImages) {
        await ctrl.stopImageStream();
        await Future.delayed(const Duration(milliseconds: 120));
      }
      final xFile = await ctrl.takePicture();
      final bytes = await xFile.readAsBytes();
      await _stopAndDisposeCamera();
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
      });
      if (_isPortraitPhaseForType(doc.type)) {
        await _runPartAFaceValidation(
          doc: doc,
          bytes: bytes,
          filePath: xFile.path,
        );
        return;
      }
      await _runDocumentAudit(
        doc: doc,
        bytes: bytes,
        filePath: xFile.path,
        fileName: '${doc.type}_camera.jpg',
        isPdf: false,
      );
    } catch (e) {
      await _stopAndDisposeCamera();
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        _liveAutoLocked = false;
        _cameraError = 'Erro ao fotografar: $e';
      });
    }
  }

  Future<void> _pickViaImagePicker(
    DriverDocument doc, {
    required ImageSource source,
  }) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        preferredCameraDevice: doc.type == 'PROFILE_PHOTO'
            ? CameraDevice.front
            : CameraDevice.rear,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 86,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (_isPortraitPhaseForType(doc.type)) {
        await _runPartAFaceValidation(
          doc: doc,
          bytes: bytes,
          filePath: picked.path,
        );
        return;
      }
      await _runDocumentAudit(
        doc: doc,
        bytes: bytes,
        filePath: picked.path,
        fileName: picked.name,
        isPdf: false,
      );
    } catch (e) {
      if (!mounted) return;
      context.read<OmniDriverProvider>().addAlert(
            'Erro na seleção',
            'Não foi possível acessar a mídia ($e).',
            'warning',
          );
    }
  }

  Future<void> _pickViaFilePicker(DriverDocument doc) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes ??
          (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        context.read<OmniDriverProvider>().addAlert(
              'Arquivo vazio',
              'Não foi possível ler o arquivo selecionado.',
              'danger',
            );
        return;
      }
      final name = file.name;
      final isPdf = name.toLowerCase().endsWith('.pdf') ||
          (file.extension?.toLowerCase() == 'pdf');
      if (_isPortraitPhaseForType(doc.type)) {
        if (isPdf) {
          setState(() {
            _useSingleDigitalMode = true;
            _capturePhase = _CapturePhase.partBData;
          });
        } else {
          await _runPartAFaceValidation(
            doc: doc,
            bytes: bytes,
            filePath: file.path,
          );
          return;
        }
      }
      await _runDocumentAudit(
        doc: doc,
        bytes: bytes,
        filePath: file.path,
        fileName: name,
        isPdf: isPdf,
      );
    } catch (e) {
      if (!mounted) return;
      context.read<OmniDriverProvider>().addAlert(
            'Erro ao abrir arquivo',
            'Verifique as permissões de armazenamento ($e).',
            'warning',
          );
    }
  }

  Future<void> _runPartAFaceValidation({
    required DriverDocument doc,
    required Uint8List bytes,
    String? filePath,
  }) async {
    if (!mounted) return;
    final p = context.read<OmniDriverProvider>();
    final persistedFacePath = await p.persistCapturedMedia(bytes, 'doc_${doc.type}_face');

    setState(() {
      _mode = _DocMode.analyzing;
      _analyzingLabel = 'Validando Retrato 3x4 do Titular (Parte A)...';
      _previewBytes = bytes;
      _previewPath = persistedFacePath;
      _phaseErrorMsg = null;
      _isPdf = false;
    });

    final check = await OmniVisionService.checkDocumentPortraitFace(
      expectedDocType: doc.type,
      filePath: persistedFacePath,
      fileBytes: bytes,
    );

    if (!mounted) return;
    if (check.hasFace) {
      await OmniSoundService.playSuccess();
      setState(() {
        _partAFaceBytes = bytes;
        _partAFacePath = persistedFacePath;
        _partAFaceNote = check.note;
        _capturePhase = _CapturePhase.partBData;
        _phaseErrorMsg = null;
        _liveScanStatus =
            'PARTE B: VIRE PARA A FACE COM IMPRESSÃO DIGITAL & DADOS (AUTO-OCR)...';
      });
      // Abre automaticamente a câmera ao vivo para a Parte B (impressão digital e OCR)
      await _openLiveCamera(doc);
    } else {
      await OmniSoundService.playAlert();
      setState(() {
        _mode = _DocMode.choice;
        _phaseErrorMsg = check.note.isNotEmpty
            ? check.note
            : 'Não foi detectado retrato 3x4 nítido nesta foto. Envie a face do documento que contenha sua foto para validar com o reconhecimento facial.';
      });
    }
  }

  Future<void> _runDocumentAudit({
    required DriverDocument doc,
    required Uint8List bytes,
    String? filePath,
    String? fileName,
    required bool isPdf,
  }) async {
    if (!mounted) return;
    final p = context.read<OmniDriverProvider>();
    String? persistedPath = filePath;
    if (!isPdf) {
      persistedPath = await p.persistCapturedMedia(bytes, 'doc_${doc.type}');
    }

    setState(() {
      _mode = _DocMode.analyzing;
      _analyzingLabel = 'Executando Leitura OCR & Auditoria Antifraude...';
      _previewBytes = bytes;
      _previewPath = persistedPath;
      _fileName = fileName;
      _isPdf = isPdf;
      _phaseErrorMsg = null;
    });

    var audit = await OmniVisionService.verifyDocument(
      expectedDocType: doc.type,
      expectedTitle: doc.name,
      filePath: persistedPath,
      fileBytes: bytes,
      fileName: fileName,
      isPdf: isPdf,
    );

    if (_partAFaceBytes != null || _partAFacePath != null) {
      final prefixDetail =
          'Parte A: Retrato 3x4 do titular validado (${_partAFaceNote ?? 'Foto frontal ok'})';
      final nextDetails = <String>[
        prefixDetail,
        ...audit.detectedDetails.where((d) => d != prefixDetail),
      ];
      audit = DocumentAiAuditResult(
        isAuthentic: audit.isAuthentic,
        matchesExpectedType: audit.matchesExpectedType,
        documentTypeDetected: audit.documentTypeDetected,
        integrityScore: audit.integrityScore,
        fraudRisk: audit.fraudRisk,
        hasHolderPhoto: true,
        detectedDetails: nextDetails,
        ocrTextExcerpt: audit.ocrTextExcerpt,
        rejectionReason: audit.rejectionReason,
        resolutionTier: audit.resolutionTier,
        engineUsed: audit.engineUsed,
        extractedValidation: audit.extractedValidation,
      );
    }

    final cross = await p.uploadDriverDocument(
      doc.id,
      audit: audit,
      fileBytes: bytes,
      filePath: persistedPath,
      fileName: fileName,
      faceBytes: _partAFaceBytes,
      facePath: _partAFacePath,
    );

    final persistedDoc = p.documents.cast<DriverDocument?>().firstWhere(
          (d) => d?.id == doc.id,
          orElse: () => null,
        );
    final finalAudit = persistedDoc?.aiAudit ?? audit;

    if (!mounted) return;
    setState(() {
      _auditResult = finalAudit;
      _crossResult = cross;
      _mode = _DocMode.result;
    });

    if (!finalAudit.isAuthentic) {
      await OmniSoundService.playAlert();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OmniDriverProvider>();
    final docId = p.documentCaptureDocId;
    if (docId == null) {
      _trackedDocId = null;
      return const SizedBox.shrink();
    }

    final doc = p.documents.firstWhere(
      (d) => d.id == docId,
      orElse: () => p.documents.first,
    );
    _syncForDoc(doc);

    final supportsSplit = _supportsSplitForType(doc.type);
    final isPortraitPhase = _isPortraitPhaseForType(doc.type);
    final screenSize = MediaQuery.of(context).size;
    final isCameraMode = _mode == _DocMode.camera;
    final viewfinderHeight =
        (screenSize.height * 0.56).clamp(320.0, 520.0);

    return Material(
      color: OmniTheme.alpha(Colors.black, 0.88),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCameraMode ? 8 : 14,
            vertical: isCameraMode ? 12 : 20,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isCameraMode ? 520 : 460,
              maxHeight: screenSize.height * 0.94,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: OmniTheme.slate950,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: OmniTheme.alpha(OmniTheme.neonCyan, 0.45)),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isCameraMode ? 12 : 18),
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
                          child: const Icon(Icons.document_scanner_rounded,
                              color: OmniTheme.neonCyan, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doc.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const Text(
                                'Auditoria Real ML Kit OCR + Matemática + Nuvem',
                                style: TextStyle(
                                    fontSize: 11, color: OmniTheme.slate400),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            _stopAndDisposeCamera();
                            p.openDocumentCapture(null);
                          },
                          icon: const Icon(Icons.close_rounded,
                              color: OmniTheme.slate400),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Barra 2 Etapas para RG & CNH Física (Parte A: Foto 3x4 | Parte B: Dados & OCR)
                    if (supportsSplit && _mode != _DocMode.camera) ...[
                      if (!_useSingleDigitalMode)
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => setState(() {
                                  _capturePhase = _CapturePhase.partAFace;
                                  if (_mode == _DocMode.result) {
                                    _mode = _DocMode.choice;
                                  }
                                }),
                                child: Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: _capturePhase ==
                                            _CapturePhase.partAFace
                                        ? OmniTheme.alpha(
                                            OmniTheme.neonCyan, 0.14)
                                        : _partAFaceBytes != null
                                            ? OmniTheme.alpha(
                                                OmniTheme.neonEmerald, 0.12)
                                            : OmniTheme.slate900,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _capturePhase ==
                                              _CapturePhase.partAFace
                                          ? OmniTheme.neonCyan
                                          : _partAFaceBytes != null
                                              ? OmniTheme.neonEmerald
                                              : OmniTheme.slate800,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _partAFaceBytes != null
                                            ? '1. Parte A ✓ (3x4)'
                                            : '1. Parte A • Foto 3x4',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          color: _capturePhase ==
                                                  _CapturePhase.partAFace
                                              ? OmniTheme.neonCyan
                                              : _partAFaceBytes != null
                                                  ? OmniTheme.neonEmerald
                                                  : OmniTheme.slate300,
                                        ),
                                      ),
                                      const Text(
                                        'Lado com seu rosto',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: OmniTheme.slate400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: _partAFaceBytes != null
                                    ? () => setState(() {
                                          _capturePhase =
                                              _CapturePhase.partBData;
                                          if (_mode == _DocMode.result) {
                                            _mode = _DocMode.choice;
                                          }
                                        })
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: _capturePhase ==
                                            _CapturePhase.partBData
                                        ? OmniTheme.alpha(
                                            OmniTheme.neonCyan, 0.14)
                                        : OmniTheme.slate900,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _capturePhase ==
                                              _CapturePhase.partBData
                                          ? OmniTheme.neonCyan
                                          : OmniTheme.slate800,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '2. Parte B • Dados OCR',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          color: _capturePhase ==
                                                  _CapturePhase.partBData
                                              ? OmniTheme.neonCyan
                                              : OmniTheme.slate300,
                                        ),
                                      ),
                                      const Text(
                                        'Face c/ digital e dados',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: OmniTheme.slate400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: OmniTheme.alpha(OmniTheme.neonCyan, 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    OmniTheme.alpha(OmniTheme.neonCyan, 0.35)),
                          ),
                          child: const Text(
                            'Modo 1 Etapa Ativo: Documento Aberto, Digital ou PDF (Foto + Digital + Dados juntos)',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: OmniTheme.neonCyan,
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => setState(() {
                          _useSingleDigitalMode = !_useSingleDigitalMode;
                          _phaseErrorMsg = null;
                          _capturePhase = (_useSingleDigitalMode ||
                                  _partAFaceBytes != null)
                              ? _CapturePhase.partBData
                              : _CapturePhase.partAFace;
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            _useSingleDigitalMode
                                ? '← Voltar para envio em 2 etapas (Parte A: Foto + Parte B: Digital/Dados)'
                                : 'Documento Aberto / Digital / PDF (1 Etapa — Foto + Dados juntos) →',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: OmniTheme.neonCyan,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Dica contextual
                    if (!isCameraMode) ...[
                      if (_partAFaceBytes != null && !_useSingleDigitalMode) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: OmniTheme.alpha(OmniTheme.neonEmerald, 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: OmniTheme.alpha(
                                    OmniTheme.neonEmerald, 0.45)),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  _partAFaceBytes!,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  cacheWidth: 160,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Parte A (Face com Foto 3x4) Validada ✓',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                        color: OmniTheme.neonEmerald,
                                      ),
                                    ),
                                    Text(
                                      'Envie a foto da face do documento que contenha sua impressão digital para validar com sua impressão digital coletada e dados OCR.',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: OmniTheme.slate300,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (_phaseErrorMsg != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: OmniTheme.alpha(OmniTheme.rose500, 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: OmniTheme.alpha(OmniTheme.rose500, 0.45)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: OmniTheme.rose400, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _phaseErrorMsg!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: OmniTheme.rose300,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: OmniTheme.slate900,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: OmniTheme.slate800),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.tips_and_updates_rounded,
                                color: OmniTheme.neonCyan, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isPortraitPhase
                                    ? 'Parte A (1 de 2): Fotografe o lado do ${doc.type == 'RG' ? 'RG' : 'CNH'} que mostra sua foto 3x4 para validarmos o Match Facial.'
                                    : _tipForDocType(doc.type),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: OmniTheme.slate300,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // MODO 1: ESCOLHA DE ENVIO REAL
                    if (_mode == _DocMode.choice) ...[
                      _ActionTile(
                        icon: Icons.photo_camera_rounded,
                        title: 'Fotografar Documento Agora (Auto-Captura Ao Vivo)',
                        subtitle:
                            'Lê CPF, RG ou CNH ao vivo e fotografa sozinho ao validar (com foco por toque)',
                        accent: OmniTheme.neonCyan,
                        onTap: () => _openLiveCamera(doc),
                      ),
                      const SizedBox(height: 8),
                      _ActionTile(
                        icon: Icons.camera_alt_outlined,
                        title: 'Câmera Nativa do Aparelho',
                        subtitle: 'Captura com foco e HDR nativo do Android',
                        accent: OmniTheme.neonEmerald,
                        onTap: () => _pickViaImagePicker(doc,
                            source: ImageSource.camera),
                      ),
                      const SizedBox(height: 8),
                      _ActionTile(
                        icon: Icons.photo_library_rounded,
                        title: 'Escolher Foto da Galeria',
                        subtitle: 'JPG, PNG ou print da CNH Digital / Gov.br',
                        accent: OmniTheme.slate300,
                        onTap: () => _pickViaImagePicker(doc,
                            source: ImageSource.gallery),
                      ),
                      const SizedBox(height: 8),
                      _ActionTile(
                        icon: Icons.picture_as_pdf_rounded,
                        title: 'Anexar PDF ou Arquivo do Celular',
                        subtitle:
                            'PDF oficial Gov.br, Receita Federal ou CNH-e',
                        accent: OmniTheme.amber400,
                        onTap: () => _pickViaFilePicker(doc),
                      ),
                    ],

                    // MODO 2: CÂMERA AMPLIADA COM TOQUE PARA FOCO LUMINOSO, FLASH & BRILHO
                    if (_mode == _DocMode.camera) ...[
                      SizedBox(
                        width: double.infinity,
                        height: viewfinderHeight,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final viewSize = Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );
                              final ctrl = _cameraController;
                              final previewSize = ctrl?.value.previewSize;
                              final pWidth = previewSize != null
                                  ? (previewSize.width > previewSize.height
                                      ? previewSize.height
                                      : previewSize.width)
                                  : viewSize.width;
                              final pHeight = previewSize != null
                                  ? (previewSize.width > previewSize.height
                                      ? previewSize.width
                                      : previewSize.height)
                                  : viewSize.height;

                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapUp: (details) =>
                                    _onTapFocus(details, viewSize),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Container(color: const Color(0xFF05080F)),

                                    if (ctrl != null &&
                                        ctrl.value.isInitialized)
                                      FittedBox(
                                        fit: BoxFit.cover,
                                        child: SizedBox(
                                          width: pWidth,
                                          height: pHeight,
                                          child: CameraPreview(ctrl),
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
                                          padding: const EdgeInsets.all(18),
                                          child: Text(
                                            _cameraError ??
                                                'Câmera indisponível.',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: OmniTheme.amber400,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),

                                    // Moldura ampla com cantoneiras ciano (ou verde esmeralda ao travar leitura ao vivo)
                                    IgnorePointer(
                                      child: CustomPaint(
                                        painter: _DocumentFramePainter(
                                            locked: _liveAutoLocked),
                                      ),
                                    ),

                                    // Luzinha animada de foco & exposição ao tocar na foto
                                    if (_focusTapPos != null)
                                      Positioned(
                                        left: _focusTapPos!.dx - 34,
                                        top: _focusTapPos!.dy - 34,
                                        child: IgnorePointer(
                                          child: TweenAnimationBuilder<double>(
                                            key: ValueKey(_focusAnimKey),
                                            tween:
                                                Tween(begin: 1.35, end: 1.0),
                                            duration: const Duration(
                                                milliseconds: 240),
                                            builder: (_, scale, child) =>
                                                Transform.scale(
                                              scale: scale,
                                              child: child,
                                            ),
                                            child: Container(
                                              width: 68,
                                              height: 68,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: OmniTheme.amber400,
                                                  width: 2.2,
                                                ),
                                                color: OmniTheme.alpha(
                                                    OmniTheme.amber400, 0.14),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: OmniTheme.alpha(
                                                        OmniTheme.amber400,
                                                        0.55),
                                                    blurRadius: 16,
                                                  ),
                                                ],
                                              ),
                                              child: const Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.wb_sunny_rounded,
                                                    color: OmniTheme.amber400,
                                                    size: 20,
                                                  ),
                                                  SizedBox(height: 1),
                                                  Text(
                                                    'FOCO',
                                                    style: TextStyle(
                                                      fontSize: 8.5,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                    // Barra superior: Dica de toque + Flash/Lanterna + Virar Câmera
                                    Positioned(
                                      top: 10,
                                      left: 10,
                                      right: 10,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                color: OmniTheme.alpha(
                                                    Colors.black, 0.76),
                                                borderRadius:
                                                    BorderRadius.circular(99),
                                                border: Border.all(
                                                  color: _liveAutoLocked
                                                      ? OmniTheme.neonEmerald
                                                      : OmniTheme.alpha(
                                                          OmniTheme.neonCyan,
                                                          0.55),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                      _liveAutoLocked
                                                          ? Icons
                                                              .verified_rounded
                                                          : Icons
                                                              .document_scanner_rounded,
                                                      size: 13,
                                                      color: _liveAutoLocked
                                                          ? OmniTheme
                                                              .neonEmerald
                                                          : OmniTheme.neonCyan),
                                                  const SizedBox(width: 5),
                                                  Expanded(
                                                    child: Text(
                                                      _liveScanStatus,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 9.8,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        color: _liveAutoLocked
                                                            ? OmniTheme
                                                                .neonEmerald
                                                            : Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          IconButton(
                                            onPressed: _toggleFlashTorch,
                                            tooltip: 'Flash / Lanterna',
                                            style: IconButton.styleFrom(
                                              backgroundColor: _flashTorchOn
                                                  ? OmniTheme.amber400
                                                  : OmniTheme.alpha(
                                                      Colors.black, 0.68),
                                            ),
                                            icon: Icon(
                                              _flashTorchOn
                                                  ? Icons.flashlight_on_rounded
                                                  : Icons
                                                      .flashlight_off_rounded,
                                              color: _flashTorchOn
                                                  ? Colors.black
                                                  : OmniTheme.amber400,
                                              size: 20,
                                            ),
                                          ),
                                          if (_cameras.length > 1) ...[
                                            const SizedBox(width: 4),
                                            IconButton(
                                              onPressed: _flipCamera,
                                              tooltip: 'Alternar Câmera',
                                              style: IconButton.styleFrom(
                                                backgroundColor:
                                                    OmniTheme.alpha(
                                                        Colors.black, 0.68),
                                              ),
                                              icon: const Icon(
                                                Icons
                                                    .flip_camera_android_rounded,
                                                color: OmniTheme.neonCyan,
                                                size: 20,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),

                                    // Controle de Brilho / Exposição sobre a câmera
                                    if (ctrl != null &&
                                        ctrl.value.isInitialized)
                                      Positioned(
                                        bottom: 8,
                                        left: 10,
                                        right: 10,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: OmniTheme.alpha(
                                                Colors.black, 0.72),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                              color: OmniTheme.alpha(
                                                  OmniTheme.amber400, 0.4),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.brightness_6_rounded,
                                                size: 16,
                                                color: OmniTheme.amber400,
                                              ),
                                              const SizedBox(width: 4),
                                              const Text(
                                                'Brilho',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              Expanded(
                                                child: SliderTheme(
                                                  data: SliderTheme.of(context)
                                                      .copyWith(
                                                    trackHeight: 2.5,
                                                    thumbShape:
                                                        const RoundSliderThumbShape(
                                                            enabledThumbRadius:
                                                                7),
                                                  ),
                                                  child: Slider(
                                                    value:
                                                        _exposureOffset.clamp(
                                                            _minExposure,
                                                            _maxExposure),
                                                    min: _minExposure,
                                                    max: _maxExposure,
                                                    activeColor:
                                                        OmniTheme.amber400,
                                                    inactiveColor:
                                                        OmniTheme.slate700,
                                                    onChanged:
                                                        _updateExposureOffset,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '${_exposureOffset >= 0 ? '+' : ''}${_exposureOffset.toStringAsFixed(1)}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: OmniTheme.amber400,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              _stopAndDisposeCamera();
                              setState(() => _mode = _DocMode.choice);
                            },
                            child: const Text('Voltar'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (_cameraController != null &&
                                      _cameraController!.value.isInitialized &&
                                      !_isCapturing)
                                  ? () => _captureFromLiveCamera(doc)
                                  : null,
                              icon: const Icon(Icons.camera_rounded, size: 18),
                              label: Text(_isCapturing
                                  ? 'Capturando...'
                                  : 'Tirar Foto & Auditar'),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // MODO 3: ANALISANDO COM OCR + VISÃO IA
                    if (_mode == _DocMode.analyzing) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            if (!_isPdf && _previewBytes != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.memory(
                                  _previewBytes!,
                                  cacheWidth: 720,
                                  height: 140,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                ),
                              )
                            else
                              const Icon(Icons.picture_as_pdf_rounded,
                                  color: OmniTheme.amber400, size: 54),
                            const SizedBox(height: 14),
                            const CircularProgressIndicator(
                                color: OmniTheme.neonCyan),
                            const SizedBox(height: 12),
                            Text(
                              _analyzingLabel,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Validando campos reais de ${_fileName ?? doc.name} (Módulo 11 / SENATRAN / Retrato)...',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 11, color: OmniTheme.slate400),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // MODO 4: RESULTADO DETALHADO
                    if (_mode == _DocMode.result && _auditResult != null) ...[
                      Builder(builder: (context) {
                        final audit = _auditResult!;
                        final ok = audit.isAuthentic;
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
                                  Icon(
                                    ok
                                        ? Icons.verified_rounded
                                        : Icons.warning_amber_rounded,
                                    color: accent,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ok
                                              ? 'DOCUMENTO AUTÊNTICO ✓'
                                              : 'AUDITORIA REPROVADA',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w900,
                                            color: accent,
                                          ),
                                        ),
                                        Text(
                                          '${audit.documentTypeDetected} • Integridade ${audit.integrityScore}%',
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
                              if (audit.engineUsed != null) ...[
                                const SizedBox(height: 6),
                                OmniPillBadge(
                                  text:
                                      'Camada ${audit.resolutionTier ?? 1}: ${audit.engineUsed}',
                                  color: OmniTheme.neonCyan,
                                ),
                              ],
                              if (audit.rejectionReason != null &&
                                  audit.rejectionReason!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  audit.rejectionReason!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: OmniTheme.rose400,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                              if (audit.detectedDetails.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                ...audit.detectedDetails.map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          ok
                                              ? Icons.check_rounded
                                              : Icons.info_outline_rounded,
                                          size: 14,
                                          color: accent,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            item,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: OmniTheme.slate300,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              if (audit.ocrTextExcerpt != null &&
                                  audit.ocrTextExcerpt!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: OmniTheme.slate900,
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: OmniTheme.slate800),
                                  ),
                                  child: Text(
                                    'OCR extraído: ${audit.ocrTextExcerpt}',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: OmniTheme.monoStyle(
                                      fontSize: 10,
                                      color: OmniTheme.slate400,
                                    ),
                                  ),
                                ),
                              ],
                              if (audit.extractedValidation?.fullName != null ||
                                  audit.extractedValidation?.birthDateBr != null) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    if (audit.extractedValidation?.fullName != null)
                                      OmniPillBadge(
                                        text:
                                            'Nome: ${audit.extractedValidation!.fullName}',
                                        color: OmniTheme.neonCyan,
                                      ),
                                    if (audit.extractedValidation?.birthDateBr != null)
                                      OmniPillBadge(
                                        text:
                                            'Nasc.: ${audit.extractedValidation!.birthDateBr}',
                                        color: OmniTheme.neonCyan,
                                      ),
                                  ],
                                ),
                              ],
                              if (_crossResult?.dataMatchMessage != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: _crossResult!.dataMatchStatus ==
                                            'MISMATCH'
                                        ? OmniTheme.alpha(
                                            OmniTheme.rose500, 0.14)
                                        : OmniTheme.alpha(
                                            OmniTheme.neonEmerald, 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _crossResult!.dataMatchStatus ==
                                              'MISMATCH'
                                          ? OmniTheme.rose500
                                          : OmniTheme.neonEmerald,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _crossResult!.dataMatchStatus ==
                                                'MISMATCH'
                                            ? 'DIVERGÊNCIA ENTRE DOCUMENTOS'
                                            : _crossResult!.dataMatchStatus ==
                                                    'MATCHED'
                                                ? 'MATCH DE DADOS ENTRE DOCUMENTOS ✓'
                                                : 'DADOS-BASE OCR SALVOS ✓',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          color: _crossResult!.dataMatchStatus ==
                                                  'MISMATCH'
                                              ? OmniTheme.rose400
                                              : OmniTheme.neonEmerald,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _crossResult!.dataMatchMessage!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _crossResult!.dataMatchStatus ==
                                                  'MISMATCH'
                                              ? OmniTheme.rose300
                                              : OmniTheme.slate200,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (_crossResult?.faceMatchMessage != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: _crossResult!.faceMatchStatus ==
                                            'MISMATCH'
                                        ? OmniTheme.alpha(
                                            OmniTheme.rose500, 0.14)
                                        : OmniTheme.alpha(
                                            OmniTheme.neonCyan, 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _crossResult!.faceMatchStatus ==
                                              'MISMATCH'
                                          ? OmniTheme.rose500
                                          : OmniTheme.neonCyan,
                                    ),
                                  ),
                                  child: Text(
                                    _crossResult!.faceMatchMessage!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _crossResult!.faceMatchStatus ==
                                              'MISMATCH'
                                          ? OmniTheme.rose400
                                          : OmniTheme.neonCyan,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => setState(
                                          () => _mode = _DocMode.choice),
                                      child: const Text('Enviar Outro'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          p.openDocumentCapture(null),
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

/// Moldura ampla de cantoneiras L para maximizar a área útil de captura do RG/CPF/CNH
class _DocumentFramePainter extends CustomPainter {
  final bool locked;

  const _DocumentFramePainter({this.locked = false});

  @override
  void paint(Canvas canvas, Size size) {
    const padX = 12.0;
    const padTop = 52.0;
    const padBottom = 60.0;
    final rect = Rect.fromLTRB(
      padX,
      padTop,
      size.width - padX,
      size.height - padBottom,
    );

    final accent = locked ? OmniTheme.neonEmerald : OmniTheme.neonCyan;

    final borderPaint = Paint()
      ..color = OmniTheme.alpha(accent, locked ? 0.85 : 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = locked ? 2.6 : 1.4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(14)),
      borderPaint,
    );

    final cornerPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = locked ? 4.2 : 3.2
      ..strokeCap = StrokeCap.round;

    const len = 24.0;
    // Top-left
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(len, 0), cornerPaint);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, len), cornerPaint);
    // Top-right
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(-len, 0), cornerPaint);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, len), cornerPaint);
    // Bottom-left
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(len, 0), cornerPaint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(0, -len), cornerPaint);
    // Bottom-right
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(-len, 0), cornerPaint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(0, -len), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _DocumentFramePainter oldDelegate) =>
      oldDelegate.locked != locked;
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: OmniTheme.slate900,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: OmniTheme.alpha(accent, 0.35)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: OmniTheme.alpha(accent, 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 10.5, color: OmniTheme.slate400),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: accent, size: 18),
          ],
        ),
      ),
    );
  }
}
