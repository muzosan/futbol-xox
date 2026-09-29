import 'dart:math';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../data/text_utils.dart';
import '../game/engine/duel_engine.dart';
import '../l10n/translate.dart' show upper;
import '../theme.dart';
import 'kit_icon.dart';

/// Kart çerçevesi: yıldız puanına göre
class _CardTier {
  const _CardTier(this.name, this.colors, this.textColor, this.border);

  final String name;
  final List<Color> colors;
  final Color textColor;
  final Color border;
}

const _ikon = _CardTier(
  'İKON',
  [Color(0xFF26324F), Color(0xFF111827), Color(0xFF05070C)],
  AppColors.gold,
  AppColors.gold,
);
const _altin = _CardTier(
  'ALTIN',
  [Color(0xFFFCE9AE), Color(0xFFE3B955), Color(0xFFA9781F)],
  Color(0xFF2A1F05),
  Color(0xFFFFF1C1),
);
const _gumus = _CardTier(
  'GÜMÜŞ',
  [Color(0xFFF4F6F9), Color(0xFFC9CFD7), Color(0xFF8A939E)],
  Color(0xFF1B222B),
  Color(0xFFFFFFFF),
);
const _bronz = _CardTier(
  'BRONZ',
  [Color(0xFFEBC199), Color(0xFFC4814F), Color(0xFF7A4727)],
  Color(0xFF2A160A),
  Color(0xFFF6D9BD),
);

_CardTier _tierFor(int rating) {
  if (rating >= 88) return _ikon;
  if (rating >= 78) return _altin;
  if (rating >= 68) return _gumus;
  return _bronz;
}

/// FIFA tarzı futbolcu kartı. [onPickStat] verilirse istatistik satırları seçilebilir.
class PlayerCard extends StatelessWidget {
  const PlayerCard({
    super.key,
    required this.player,
    required this.repo,
    required this.width,
    required this.stats,
    this.highlightStat,
    this.onPickStat,
    this.glow,
  });

  final Player player;
  final Repository repo;
  final double width;

  /// Kartta gösterilecek istatistikler (sırasıyla)
  final List<CardStat> stats;
  final String? highlightStat;
  final ValueChanged<String>? onPickStat;

  /// Turu kazanan kartın etrafında parlama rengi
  final Color? glow;

  static double heightFor(double width) => width * 1.62;

  @override
  Widget build(BuildContext context) {
    final rating = repo.starRating(player);
    final tier = _tierFor(rating);
    final club = repo.mainClub(player);
    final w = width;
    final ink = tier.textColor;

    return Container(
      width: w,
      height: heightFor(w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(w * 0.09),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tier.colors,
        ),
        border: Border.all(color: tier.border.withValues(alpha: 0.9), width: 2),
        boxShadow: [
          ...AppShadows.card,
          if (glow != null) ...AppShadows.glow(glow!, 0.75),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(w * 0.09),
        child: Stack(
          children: [
            // Parlak yüzey yansıması
            Positioned(
              top: -w * 0.5,
              left: -w * 0.3,
              child: Transform.rotate(
                angle: -0.5,
                child: Container(
                  width: w * 0.5,
                  height: w * 1.6,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(w * 0.07, w * 0.05, w * 0.07, w * 0.05),
              child: Column(
                children: [
                  // Puan, mevki, bayrak
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Text('$rating',
                              style: displayStyle(w * 0.25, color: ink, spacing: 0)
                                  .copyWith(shadows: const [])),
                          Text(
                            player.positions.isEmpty ? '' : player.positions.first,
                            style: displayStyle(w * 0.1, color: ink, spacing: 1)
                                .copyWith(shadows: const []),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Padding(
                        padding: EdgeInsets.only(top: w * 0.03),
                        child: Text(flagEmoji(player.nationality),
                            style: TextStyle(fontSize: w * 0.13)),
                      ),
                    ],
                  ),
                  if (club != null) KitIcon(club: club, size: w * 0.3),
                  SizedBox(height: w * 0.02),
                  Text(
                    upper(player.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: displayStyle(w * 0.12, color: ink, spacing: 0.5)
                        .copyWith(shadows: const []),
                  ),
                  Container(
                    height: 1.2,
                    margin: EdgeInsets.symmetric(vertical: w * 0.025),
                    color: ink.withValues(alpha: 0.35),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final s in stats) _statRow(s, ink, w),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(CardStat s, Color ink, double w) {
    final selected = highlightStat == s.key;
    final row = Container(
      padding: EdgeInsets.symmetric(horizontal: w * 0.03),
      decoration: BoxDecoration(
        color: selected ? ink.withValues(alpha: 0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: onPickStat != null
            ? Border.all(color: ink.withValues(alpha: 0.18))
            : null,
      ),
      child: Row(
        children: [
          Text(s.short,
              style: TextStyle(
                  fontSize: w * 0.068,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: ink.withValues(alpha: 0.8))),
          const Spacer(),
          Text(s.format(player.stat(s.key)),
              style: displayStyle(w * 0.095, color: ink, spacing: 0.5)
                  .copyWith(shadows: const [])),
        ],
      ),
    );
    if (onPickStat == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => onPickStat!(s.key),
        child: row,
      ),
    );
  }
}

/// Kartın arkası
class CardBack extends StatelessWidget {
  const CardBack({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final w = width;
    return Container(
      width: w,
      height: PlayerCard.heightFor(w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(w * 0.09),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C2A4F), Color(0xFF0A1022)],
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.8), width: 2),
        boxShadow: AppShadows.card,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Çapraz ince desen
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(w * 0.09),
              child: CustomPaint(painter: _BackPatternPainter()),
            ),
          ),
          Container(
            width: w * 0.5,
            height: w * 0.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 2),
              boxShadow: AppShadows.glow(AppColors.gold, 0.3),
            ),
            alignment: Alignment.center,
            child: GoldText('V', size: w * 0.26, spacing: 0),
          ),
        ],
      ),
    );
  }
}

class _BackPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width; x += 12) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_BackPatternPainter old) => false;
}

/// Kartı yüzü açık / kapalı arasında 3B çevirme animasyonu
class FlipCard extends StatelessWidget {
  const FlipCard({
    super.key,
    required this.faceUp,
    required this.front,
    required this.back,
  });

  final bool faceUp;
  final Widget front;
  final Widget back;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: faceUp ? 1 : 0),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeInOutCubic,
      builder: (context, v, _) {
        final angle = (1 - v) * pi;
        final showFront = angle <= pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(showFront ? angle : angle - pi),
          child: showFront ? front : back,
        );
      },
    );
  }
}
