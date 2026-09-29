import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'game/engine/common.dart';
import 'l10n/lang_state.dart';

/// Renk paleti: gece maçı + altın vurgular (premium his)
class AppColors {
  static const background = Color(0xFF060A12);
  static const backgroundTop = Color(0xFF0F1B36);
  static const surface = Color(0xFF111A2C);
  static const surfaceHigh = Color(0xFF1A2542);
  static const border = Color(0xFF27334F);
  static const primary = Color(0xFF2EE59D); // neon saha yeşili
  static const primaryDeep = Color(0xFF12B479);
  static const gold = Color(0xFFF5C451);
  static const goldDeep = Color(0xFFC48A22);
  static const x = Color(0xFF4DA3FF);
  static const o = Color(0xFFFF5C7A);
  static const amber = Color(0xFFFFC857);
  static const text = Color(0xFFF2F6FC);
  static const textMuted = Color(0xFF95A3BA);
  static const success = Color(0xFF1E9E6A);
  static const danger = Color(0xFFD64560);
}

Color markColor(Mark mark) => mark == Mark.x ? AppColors.x : AppColors.o;

/// Gölgeler: yazıya ve kartlara derinlik
class AppShadows {
  static const text = [
    Shadow(color: Color(0xAA000000), blurRadius: 10, offset: Offset(0, 3)),
  ];
  static const card = [
    BoxShadow(color: Color(0x99000000), blurRadius: 22, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
  ];

  static List<BoxShadow> glow(Color color, [double alpha = 0.35]) => [
        BoxShadow(
            color: color.withValues(alpha: alpha),
            blurRadius: 22,
            spreadRadius: -2),
      ];
}

/// Tekrar kullanılan yüzey tasarımları
class AppDecor {
  /// Üstten alta hafif koyulaşan, ince ışık kenarlı, gölgeli kart
  static BoxDecoration card({
    double radius = 18,
    Color? accent,
    bool raised = true,
    bool active = false,
  }) =>
      BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: accent != null && active
              ? [
                  Color.alphaBlend(accent.withValues(alpha: 0.22), AppColors.surfaceHigh),
                  Color.alphaBlend(accent.withValues(alpha: 0.08), AppColors.surface),
                ]
              : const [Color(0xFF1B2644), Color(0xFF0E1626)],
        ),
        border: Border.all(
          color: accent != null
              ? accent.withValues(alpha: active ? 0.9 : 0.35)
              : Colors.white.withValues(alpha: 0.07),
          width: active ? 1.6 : 1,
        ),
        boxShadow: [
          if (raised) ...AppShadows.card,
          if (accent != null && active) ...AppShadows.glow(accent, 0.3),
        ],
      );
}

/// Başlıklar için dar ve güçlü yazı (Bebas Neue)
/// Arapça seçiliyse Cairo (Montserrat ve Bebas Neue Arapça harf içermez)
bool get _arabic => currentLang == 'ar';

/// Arayüz yazı tipi: Montserrat, Arapçada Cairo
TextStyle uiFont({
  FontWeight? fontWeight,
  double? fontSize,
  double? letterSpacing,
  Color? color,
}) =>
    _arabic
        ? GoogleFonts.cairo(
            fontWeight: fontWeight, fontSize: fontSize, letterSpacing: 0, color: color)
        : GoogleFonts.montserrat(
            fontWeight: fontWeight,
            fontSize: fontSize,
            letterSpacing: letterSpacing,
            color: color);

/// Başlıklar için dar ve güçlü yazı (Bebas Neue; Arapçada kalın Cairo)
TextStyle displayStyle(double size, {Color color = AppColors.text, double spacing = 1.5}) =>
    _arabic
        ? GoogleFonts.cairo(
            fontSize: size * 0.78,
            fontWeight: FontWeight.w900,
            color: color,
            height: 1.25,
            shadows: AppShadows.text,
          )
        : GoogleFonts.bebasNeue(
            fontSize: size,
            color: color,
            letterSpacing: spacing,
            height: 1.0,
            shadows: AppShadows.text,
          );

/// Altın geçişli yazı (logo başlığı, rekorlar)
class GoldText extends StatelessWidget {
  const GoldText(this.text, {super.key, required this.size, this.spacing = 3});

  final String text;
  final double size;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFF1C1), AppColors.gold, AppColors.goldDeep],
        stops: [0.0, 0.5, 1.0],
      ).createShader(rect),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: displayStyle(size, color: Colors.white, spacing: spacing),
      ),
    );
  }
}

/// Her sayfanın arkasındaki katmanlı zemin: geçiş + ışık hüzmesi + soluk saha çizgileri
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.backgroundTop, AppColors.background],
          stops: [0.0, 0.65],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Üstten vuran stadyum ışığı
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -1.15),
                radius: 1.1,
                colors: [Color(0x332EE59D), Color(0x00000000)],
              ),
            ),
          ),
          const CustomPaint(painter: _PitchPainter()),
          child,
        ],
      ),
    );
  }
}

/// Çok soluk saha çizgileri (orta yuvarlak ve orta çizgi)
class _PitchPainter extends CustomPainter {
  const _PitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: 0.035);
    final center = Offset(size.width / 2, size.height * 0.62);
    final r = min(size.width, size.height) * 0.28;
    canvas.drawCircle(center, r, paint);
    canvas.drawCircle(center, 3, paint..style = PaintingStyle.fill);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy),
        paint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_PitchPainter oldDelegate) => false;
}

/// Sayfa geçişleri: her sayfa kendi zemini ile gelir (geçişte üst üste binme olmaz)
class _BackgroundPageTransitions extends PageTransitionsBuilder {
  const _BackgroundPageTransitions();

  static const _inner = ZoomPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      _inner.buildTransitions(route, context, animation, secondaryAnimation,
          AppBackground(child: child));
}

ThemeData buildAppTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: const Color(0xFF03130C),
    secondary: AppColors.gold,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    surfaceContainerHighest: AppColors.surfaceHigh,
    onSurfaceVariant: AppColors.textMuted,
    outline: AppColors.border,
  );

  // Bütün yazılar Montserrat; en ince yazı bile yarı kalın
  final t = (_arabic
          ? GoogleFonts.cairoTextTheme(base.textTheme)
          : GoogleFonts.montserratTextTheme(base.textTheme))
      .apply(bodyColor: AppColors.text, displayColor: AppColors.text);
  TextStyle? w(TextStyle? s, FontWeight weight) => s?.copyWith(fontWeight: weight);
  final textTheme = t.copyWith(
    displayLarge: w(t.displayLarge, FontWeight.w900),
    displayMedium: w(t.displayMedium, FontWeight.w900),
    displaySmall: w(t.displaySmall, FontWeight.w900),
    headlineLarge: w(t.headlineLarge, FontWeight.w900),
    headlineMedium: w(t.headlineMedium, FontWeight.w800),
    headlineSmall: w(t.headlineSmall, FontWeight.w800),
    titleLarge: w(t.titleLarge, FontWeight.w800),
    titleMedium: w(t.titleMedium, FontWeight.w800),
    titleSmall: w(t.titleSmall, FontWeight.w700),
    bodyLarge: w(t.bodyLarge, FontWeight.w600),
    bodyMedium: w(t.bodyMedium, FontWeight.w600),
    bodySmall: w(t.bodySmall, FontWeight.w600),
    labelLarge: w(t.labelLarge, FontWeight.w800),
    labelMedium: w(t.labelMedium, FontWeight.w700),
    labelSmall: w(t.labelSmall, FontWeight.w700),
  );
  final boldLabel = uiFont(
      fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.3);
  final radius14 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

  return base.copyWith(
    colorScheme: scheme,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    scaffoldBackgroundColor: Colors.transparent,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: _BackgroundPageTransitions(),
      TargetPlatform.iOS: _BackgroundPageTransitions(),
      TargetPlatform.windows: _BackgroundPageTransitions(),
      TargetPlatform.macOS: _BackgroundPageTransitions(),
      TargetPlatform.linux: _BackgroundPageTransitions(),
      TargetPlatform.fuchsia: _BackgroundPageTransitions(),
    }),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 8,
      shape: radius14,
      contentTextStyle: uiFont(
          fontWeight: FontWeight.w700, color: Colors.white),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: const Color(0xFF03130C),
        disabledBackgroundColor: AppColors.surfaceHigh,
        textStyle: boldLabel,
        elevation: 6,
        shadowColor: AppColors.primary.withValues(alpha: 0.6),
        shape: radius14,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        backgroundColor: AppColors.surface.withValues(alpha: 0.6),
        side: const BorderSide(color: AppColors.border, width: 1.4),
        textStyle: boldLabel,
        shape: radius14,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: uiFont(fontWeight: FontWeight.w800),
      ),
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: uiFont(
          fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.text),
      subtitleTextStyle: uiFont(
          fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textMuted),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(
            uiFont(fontWeight: FontWeight.w800)),
      ),
    ),
    dividerColor: AppColors.border,
  );
}
