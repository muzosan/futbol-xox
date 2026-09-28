import 'dart:math';

import 'package:flutter/material.dart';

import '../data/models.dart';

/// Kulübün renkleriyle çizilmiş küçük forma ikonu (logo değil, sadece renk ve desen).
class KitIcon extends StatelessWidget {
  const KitIcon({super.key, required this.club, this.size = 44});

  final Club club;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = club.kitColors.isNotEmpty
        ? club.kitColors.map(Color.new).toList()
        : [_fallbackColor(club.id), Colors.white];
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _KitPainter(club.kitPattern, colors)),
    );
  }

  /// Rengi bilinmeyen kulüpler için ID'den her seferinde aynı çıkan bir renk
  static Color _fallbackColor(String id) {
    const palette = [
      Color(0xFF546E7A), Color(0xFF3F51B5), Color(0xFF00897B),
      Color(0xFF6D4C41), Color(0xFF7E57C2), Color(0xFF455A64),
    ];
    final sum = id.codeUnits.fold<int>(0, (a, b) => a + b);
    return palette[sum % palette.length];
  }
}

class _KitPainter extends CustomPainter {
  _KitPainter(this.pattern, this.colors);

  final String pattern;
  final List<Color> colors;

  /// 100x100'lük bir alanda tişört şekli
  Path _shirt(double w, double h) => Path()
    ..moveTo(36 * w, 6 * h)
    ..quadraticBezierTo(50 * w, 16 * h, 64 * w, 6 * h) // yaka
    ..lineTo(82 * w, 11 * h) // sağ omuz
    ..lineTo(99 * w, 30 * h) // sağ kol
    ..lineTo(88 * w, 43 * h)
    ..lineTo(79 * w, 36 * h) // koltuk altı
    ..lineTo(79 * w, 95 * h)
    ..lineTo(21 * w, 95 * h)
    ..lineTo(21 * w, 36 * h)
    ..lineTo(12 * w, 43 * h) // sol kol
    ..lineTo(1 * w, 30 * h)
    ..lineTo(18 * w, 11 * h) // sol omuz
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / 100, h = size.height / 100;
    final shirt = _shirt(w, h);
    final c0 = colors[0];
    final c1 = colors.length > 1 ? colors[1] : colors[0];
    final paint = Paint()..isAntiAlias = true;

    void rect(double x1, double y1, double x2, double y2, Color color) {
      canvas.drawRect(Rect.fromLTRB(x1 * w, y1 * h, x2 * w, y2 * h),
          paint..color = color);
    }

    void poly(List<Offset> points, Color color) {
      canvas.drawPath(
          Path()
            ..addPolygon(
                points.map((p) => Offset(p.dx * w, p.dy * h)).toList(), true),
          paint..color = color);
    }

    canvas.save();
    canvas.clipPath(shirt);
    rect(0, 0, 100, 100, c0);
    switch (pattern) {
      case 'stripes': // dikey çubuklar (gövdede)
        const stripe = 58 / 9;
        for (var i = 1; i < 9; i += 2) {
          rect(21 + i * stripe, 0, 21 + (i + 1) * stripe, 100, c1);
        }
      case 'hoops': // yatay çizgiler
        for (var y = 10.0; y < 100; y += 20) {
          rect(0, y, 100, y + 10, c1);
        }
      case 'halves': // iki yarım
        rect(50, 0, 100, 100, c1);
      case 'sleeves': // farklı renk kollar
        rect(0, 0, 21, 100, c1);
        rect(79, 0, 100, 100, c1);
      case 'center': // ortadan şerit (3. renk varsa şeridin kenarı)
        if (colors.length > 2) rect(37, 0, 63, 100, colors[2]);
        rect(41, 0, 59, 100, c1);
      case 'band': // göğüste yatay bant
        rect(0, 34, 100, 50, c1);
      case 'sash': // çapraz şerit
        poly(const [Offset(14, 4), Offset(32, 4), Offset(88, 96), Offset(70, 96)], c1);
      case 'diagonal': // çapraz ikiye bölünmüş
        poly(const [Offset(100, 0), Offset(100, 100), Offset(0, 100)], c1);
      default:
        break;
    }
    canvas.restore();

    // Yaka ve (düz formalarda) kol ucu detayı
    final trim = pattern == 'center' || pattern == 'band' || pattern == 'sash'
        ? c0
        : c1;
    final trimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * w
      ..strokeCap = StrokeCap.round
      ..color = trim;
    if (trim != c0 || pattern != 'solid') {
      canvas.drawPath(
          Path()
            ..moveTo(36 * w, 6 * h)
            ..quadraticBezierTo(50 * w, 16 * h, 64 * w, 6 * h),
          trimPaint);
    }
    if (pattern == 'solid' && colors.length > 1) {
      canvas.drawLine(Offset(97 * w, 32 * h), Offset(88.5 * w, 42 * h), trimPaint);
      canvas.drawLine(Offset(3 * w, 32 * h), Offset(11.5 * w, 42 * h), trimPaint);
    }

    // Koyu zeminde de görünsün diye ince açık kenar çizgisi
    canvas.drawPath(
      shirt,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = max(1.0, 2.2 * w)
        ..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_KitPainter old) =>
      old.pattern != pattern || !_sameColors(old.colors, colors);

  static bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
