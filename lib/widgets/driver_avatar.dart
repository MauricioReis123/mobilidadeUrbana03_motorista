import 'dart:io';
import 'package:flutter/material.dart';
import '../config/omni_theme.dart';
import '../models/omni_models.dart';

/// Avatar reativo do motorista: prioriza foto real capturada no oval (`avatarBytes` / `avatarFilePath`)
class DriverAvatar extends StatelessWidget {
  final OmniDriver driver;
  final double radius;
  final Color borderColor;
  final double borderWidth;

  const DriverAvatar({
    super.key,
    required this.driver,
    this.radius = 28,
    this.borderColor = OmniTheme.neonCyan,
    this.borderWidth = 2,
  });

  ImageProvider? _resolveImage() {
    if (driver.avatarBytes != null && driver.avatarBytes!.isNotEmpty) {
      return MemoryImage(driver.avatarBytes!);
    }
    if (driver.capturedOvalFaceBytes != null &&
        driver.capturedOvalFaceBytes!.isNotEmpty) {
      return MemoryImage(driver.capturedOvalFaceBytes!);
    }
    final localPath = driver.avatarFilePath ?? driver.capturedOvalFacePath;
    if (localPath != null &&
        localPath.isNotEmpty &&
        File(localPath).existsSync()) {
      return FileImage(File(localPath));
    }
    if (driver.avatarUrl.startsWith('http')) {
      return NetworkImage(driver.avatarUrl);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = _resolveImage();
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: borderWidth),
        color: OmniTheme.slate900,
      ),
      clipBehavior: Clip.antiAlias,
      child: provider != null
          ? Image(
              image: ResizeImage.resizeIfNeeded(240, null, provider),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.person_rounded,
                size: radius,
                color: OmniTheme.slate400,
              ),
            )
          : Icon(
              Icons.person_rounded,
              size: radius,
              color: OmniTheme.slate400,
            ),
    );
  }
}
