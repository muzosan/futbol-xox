import 'package:flutter/material.dart';

import '../game/engine/common.dart';
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

  @override
  Widget build(BuildContext context) {
    final lowTime = secondsLeft <= 10;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _chip(Mark.x)),
            const SizedBox(width: 12),
            Expanded(child: _chip(Mark.o)),
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

  Widget _chip(Mark mark) {
    final active = !isOver && showTimer && current == mark;
    final won = winner == mark;
    final color = markColor(mark);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: active || won ? color.withValues(alpha: 0.14) : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active || won ? color : AppColors.border,
          width: active || won ? 2 : 1,
        ),
        boxShadow: active
            ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12)]
            : null,
      ),
      child: Row(
        children: [
          Text(
            mark.symbol,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              names[mark] ?? mark.symbol,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: AppColors.text),
            ),
          ),
          Text(
            values[mark] ?? '',
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}
