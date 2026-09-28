import 'package:flutter/material.dart';

import '../game/engine/common.dart';
import '../reactions/reactions.dart';
import '../theme.dart';

/// Bütün modların ortak üst bilgisi: iki oyuncu kutusu ve süre çubuğu.
class PlayersHeader extends StatelessWidget {
  const PlayersHeader({
    super.key,
    required this.names,
    required this.values,
    required this.current,
    required this.winner,
    required this.isOver,
    required this.secondsLeft,
    required this.turnSeconds,
    required this.status,
    this.showTimer = true,
    this.bubbles = const {},
  });

  final Map<Mark, String> names;

  /// Kutunun sağında yazan değer (XOX'ta hücre sayısı, Kulüp Avı'nda puan)
  final Map<Mark, String> values;
  final Mark current;
  final Mark? winner;
  final bool isOver;
  final int secondsLeft;
  final int turnSeconds;
  final String status;
  final bool showTimer;

  /// Oyuncu kutularının üstünde gösterilecek emojiler (maç içi tepkiler)
  final Map<Mark, String?> bubbles;

  @override
  Widget build(BuildContext context) {
    final lowTime = secondsLeft <= 10;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _withBubble(Mark.x)),
            const SizedBox(width: 12),
            Expanded(child: _withBubble(Mark.o)),
          ],
        ),
        const SizedBox(height: 14),
        if (!isOver && showTimer) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: secondsLeft / turnSeconds,
              minHeight: 6,
              backgroundColor: AppColors.surfaceHigh,
              color: lowTime ? AppColors.danger : markColor(current),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            status,
            style: TextStyle(
              fontSize: 13,
              color: lowTime ? AppColors.danger : AppColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }

  Widget _withBubble(Mark mark) => Stack(
        clipBehavior: Clip.none,
        children: [
          _chip(mark),
          Positioned(
            top: -22,
            right: 10,
            child: ReactionBubble(emoji: bubbles[mark]),
          ),
        ],
      );

  Widget _chip(Mark mark) {
    final active = !isOver && showTimer && current == mark;
    final won = winner == mark;
    final color = markColor(mark);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: AppDecor.card(
        radius: 14,
        accent: active || won ? color : null,
        active: active || won,
      ),
      child: Row(
        children: [
          Text(
            mark.symbol,
            style: displayStyle(26, color: color, spacing: 0).copyWith(
              shadows: [Shadow(color: color.withValues(alpha: 0.7), blurRadius: 12)],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              names[mark] ?? mark.symbol,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.text),
            ),
          ),
          Text(
            values[mark] ?? '',
            style: displayStyle(22, color: color, spacing: 0.5),
          ),
        ],
      ),
    );
  }
}
