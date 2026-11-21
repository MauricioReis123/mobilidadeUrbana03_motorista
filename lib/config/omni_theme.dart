import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta oficial "Neon Luxuoso" da OMNI Mobilidade Urbana (1:1 com Web TSX)
class OmniTheme {
  static const Color neonCyan = Color(0xFF00FFCC);
  static const Color neonTeal = Color(0xFF00B894);
  static const Color neonCyanGlow = Color(0x7300FFCC);
  static const Color neonAmber = Color(0xFFFFB800);
  static const Color amber400 = Color(0xFFFBBF24);
  static const Color neonEmerald = Color(0xFF10B981);
  static const Color neonRose = Color(0xFFFF3366);
  static const Color rose300 = Color(0xFFFDA4AF);
  static const Color rose400 = Color(0xFFFB7185);
  static const Color rose500 = Color(0xFFF43F5E);
  static const Color sky400 = Color(0xFF38BDF8);
  static const Color indigo400 = Color(0xFF818CF8);

  static const Color bgDark = Color(0xFF080A0F);
  static const Color bgCard = Color(0xFF0F141C);
  static const Color bgCardHover = Color(0xFF161D28);
  static const Color slate950 = Color(0xFF020617);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color borderDark = Color(0xFF1E293B);

  static Color alpha(Color color, double opacity) {
    final clamped = opacity.clamp(0.0, 1.0);
    return color.withAlpha((clamped * 255).round());
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: neonCyan,
      colorScheme: const ColorScheme.dark(
        primary: neonCyan,
        secondary: neonEmerald,
        surface: bgCard,
        error: neonRose,
        onPrimary: Color(0xFF05080F),
        onSecondary: Color(0xFF05080F),
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: alpha(neonCyan, 0.25)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: slate900,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: const TextStyle(color: slate500, fontSize: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: slate700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: slate700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: neonCyan, width: 1.3),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonCyan,
          foregroundColor: const Color(0xFF05080F),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  /// Borda & sombra neon padrão (.neon-border)
  static BoxDecoration neonCardDecoration({
    Color? color,
    Color? borderColor,
    double radius = 20,
    bool active = false,
  }) {
    final effectiveBorder = borderColor ??
        (active ? alpha(neonCyan, 0.78) : alpha(neonCyan, 0.30));
    return BoxDecoration(
      color: color ?? bgCard,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: effectiveBorder, width: active ? 1.3 : 1.0),
      boxShadow: [
        BoxShadow(
          color: alpha(neonCyan, active ? 0.28 : 0.12),
          blurRadius: active ? 24 : 14,
          spreadRadius: 0,
        ),
      ],
    );
  }

  /// Botão gradiente neon padrão (.neon-glow-btn)
  static BoxDecoration neonButtonDecoration({double radius = 14}) {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [neonCyan, neonTeal],
      ),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: alpha(neonCyan, 0.35),
          blurRadius: 18,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static TextStyle monoStyle({
    double fontSize = 13,
    Color color = textPrimary,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
    );
  }
}

/// Badge compacto sem overflow horizontal
class OmniPillBadge extends StatelessWidget {
  final String text;
  final Color color;
  final Color? backgroundColor;
  final Color? borderColor;
  final IconData? icon;
  final double fontSize;

  const OmniPillBadge({
    super.key,
    required this.text,
    required this.color,
    this.backgroundColor,
    this.borderColor,
    this.icon,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: backgroundColor ?? OmniTheme.alpha(color, 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor ?? OmniTheme.alpha(color, 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
