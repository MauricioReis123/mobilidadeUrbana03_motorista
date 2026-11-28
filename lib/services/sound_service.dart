import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Feedback Sonoro & Tátil OMNI — 1:1 com src/services/soundService.ts
/// Sintetiza bipes e acordes PCM WAV 16-bit em memória via audioplayers
/// para tocar de forma audível e confiável no APK Android mesmo sem arquivos de áudio externos.
class OmniSoundService {
  static bool muted = false;

  static final AudioPlayer _player = AudioPlayer();
  static Uint8List? _dispatchWav;
  static Uint8List? _successWav;
  static Uint8List? _alertWav;
  static Uint8List? _chatWav;

  /// Gera um arquivo WAV PCM 16-bit mono em memória com sequência de notas senoidais suaves
  static Uint8List _synthesizeWav(List<({double freq, int ms, double vol})> notes) {
    const int sampleRate = 22050;
    final List<int> pcmSamples = <int>[];

    for (final note in notes) {
      final int totalSamples = (sampleRate * note.ms / 1000).round();
      final int fadeSamples = math.max(1, (sampleRate * 0.012).round());
      for (int i = 0; i < totalSamples; i++) {
        double env = 1.0;
        if (i < fadeSamples) {
          env = i / fadeSamples;
        } else if (i > totalSamples - fadeSamples) {
          env = (totalSamples - i) / fadeSamples;
        }
        final double t = i / sampleRate;
        final double wave = note.freq <= 0
            ? 0.0
            : math.sin(2 * math.pi * note.freq * t) * 0.8 +
                math.sin(4 * math.pi * note.freq * t) * 0.2;
        final int sample = (wave * env * note.vol * 32767).round().clamp(-32767, 32767);
        pcmSamples.add(sample);
      }
    }

    final int dataSize = pcmSamples.length * 2;
    final ByteData header = ByteData(44 + dataSize);

    void writeAscii(int offset, String s) {
      for (int i = 0; i < s.length; i++) {
        header.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeAscii(0, 'RIFF');
    header.setUint32(4, 36 + dataSize, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little); // Subchunk1Size (PCM)
    header.setUint16(20, 1, Endian.little); // AudioFormat = 1 (PCM)
    header.setUint16(22, 1, Endian.little); // NumChannels = 1
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little); // ByteRate
    header.setUint16(32, 2, Endian.little); // BlockAlign
    header.setUint16(34, 16, Endian.little); // BitsPerSample
    writeAscii(36, 'data');
    header.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < pcmSamples.length; i++) {
      header.setInt16(44 + i * 2, pcmSamples[i], Endian.little);
    }

    return header.buffer.asUint8List();
  }

  static Future<void> _playBytes(Uint8List bytes) async {
    try {
      await _player.stop();
      await _player.setVolume(1.0);
      await _player.play(BytesSource(bytes));
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  static Future<void> playDispatchPing() async {
    if (muted) return;
    HapticFeedback.heavyImpact();
    _dispatchWav ??= _synthesizeWav(const [
      (freq: 880.0, ms: 130, vol: 0.72),
      (freq: 0.0, ms: 55, vol: 0.0),
      (freq: 1174.66, ms: 200, vol: 0.8),
    ]);
    await _playBytes(_dispatchWav!);
  }

  static Future<void> playSuccess() async {
    if (muted) return;
    HapticFeedback.mediumImpact();
    _successWav ??= _synthesizeWav(const [
      (freq: 523.25, ms: 90, vol: 0.65),
      (freq: 659.25, ms: 95, vol: 0.70),
      (freq: 783.99, ms: 170, vol: 0.78),
    ]);
    await _playBytes(_successWav!);
  }

  static Future<void> playAlert() async {
    if (muted) return;
    HapticFeedback.vibrate();
    _alertWav ??= _synthesizeWav(const [
      (freq: 660.0, ms: 120, vol: 0.72),
      (freq: 0.0, ms: 60, vol: 0.0),
      (freq: 440.0, ms: 160, vol: 0.72),
    ]);
    await _playBytes(_alertWav!);
  }

  static Future<void> playChatBeep() async {
    if (muted) return;
    HapticFeedback.selectionClick();
    _chatWav ??= _synthesizeWav(const [
      (freq: 740.0, ms: 110, vol: 0.60),
    ]);
    await _playBytes(_chatWav!);
  }
}
