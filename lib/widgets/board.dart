import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../game/game_controller.dart';
import '../theme.dart';

Color markColor(Mark mark) => mark == Mark.x ? AppColors.x : AppColors.o;

const List<Color> _clubPalette = [
  Color(0xFF7E57C2), Color(0xFF3F51B5), Color(0xFF00897B), Color(0xFFE64A19),
  Color(0xFF6D4C41), Color(0xFF546E7A), Color(0xFF9E9D24), Color(0xFFC2185B),
  Color(0xFF1976D2), Color(0xFF388E3C), Color(0xFFF57C00), Color(0xFF5E35B1),
];

/// Kulüp ID'sinden her seferinde aynı rengi üretir (şimdilik logo yerine).
Color clubColor(String id) {
  final sum = id.codeUnits.fold<int>(0, (a, b) => a + b);
  return _clubPalette[sum % _clubPalette.length];
}

/// 4x4 düzen: sol üst köşe + 3 sütun başlığı, altında 3 satır başlığı + 9 hücre.
class GameBoard extends StatelessWidget {
  const GameBoard({
    super.key,
    required this.game,
    required this.repo,
    required this.onCellTap,
  });

  final GameController game;
  final Repository repo;
  final void Function(int cell) onCellTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _Corner(game: game)),
              for (final id in game.grid.cols)
                Expanded(child: ClubHeader(club: repo.club(id))),
            ],
          ),
        ),
        for (var r = 0; r < 3; r++)
          Expanded(
            child: Row(
              children: [
                Expanded(child: ClubHeader(club: repo.club(game.grid.rows[r]))),
                for (var c = 0; c < 3; c++)
                  Expanded(child: _buildCell(r * 3 + c)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCell(int index) {
    final filled = game.cells[index];
    return Padding(
      padding: const EdgeInsets.all(4),
      child: _Cell(
        filled: filled,
        highlighted: game.winningLine?.contains(index) ?? false,
        example: game.isOver && filled == null
            ? repo.exampleAnswer(game.rowClubId(index), game.colClubId(index))
            : null,
        onTap: game.isOver || filled != null ? null : () => onCellTap(index),
      ),
    );
  }
}

class ClubHeader extends StatelessWidget {
  const ClubHeader({super.key, required this.club});

  final Club club;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 84,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: clubColor(club.id),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: clubColor(club.id).withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Text(
                  club.initials,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                club.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    if (game.isOver) {
      final color =
          game.winner != null ? markColor(game.winner!) : AppColors.textMuted;
      return Center(
        child: Icon(
          game.winner != null ? Icons.emoji_events : Icons.handshake,
          size: 36,
          color: color,
        ),
      );
    }
    final color = markColor(game.current);
    return Center(
      child: Text(
        game.current.symbol,
        style: TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w900,
          color: color,
          shadows: [Shadow(color: color.withValues(alpha: 0.6), blurRadius: 16)],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.filled,
    required this.highlighted,
    required this.example,
    required this.onTap,
  });

  final FilledCell? filled;
  final bool highlighted;
  final Player? example;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    final BoxDecoration decoration;
    final Widget child;

    if (filled != null) {
      final color = markColor(filled!.owner);
      decoration = BoxDecoration(
        borderRadius: radius,
        color: color.withValues(alpha: highlighted ? 0.32 : 0.12),
        border: Border.all(
          color: color.withValues(alpha: highlighted ? 1 : 0.55),
          width: highlighted ? 2.5 : 1.5,
        ),
        boxShadow: highlighted
            ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 16)]
            : null,
      );
      child = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            filled!.owner.symbol,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            filled!.player.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 11, height: 1.1, color: AppColors.text),
          ),
        ],
      );
    } else if (example != null) {
      decoration = BoxDecoration(
        borderRadius: radius,
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
      );
      child = Text(
        'Örn:\n${example!.name}',
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10,
          fontStyle: FontStyle.italic,
          color: AppColors.textMuted,
        ),
      );
    } else {
      decoration = BoxDecoration(
        borderRadius: radius,
        color: AppColors.surfaceHigh,
        border: Border.all(color: AppColors.border),
      );
      child = Icon(Icons.add,
          color: onTap == null
              ? AppColors.border
              : AppColors.textMuted.withValues(alpha: 0.7));
    }

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

/// Üstteki oyuncu kutuları ve süre çubuğu.
class TurnBar extends StatelessWidget {
  const TurnBar({super.key, required this.game, this.botThinking = false});

  final GameController game;
  final bool botThinking;

  @override
  Widget build(BuildContext context) {
    final lowTime = game.secondsLeft <= 10;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _PlayerChip(game: game, mark: Mark.x)),
            const SizedBox(width: 12),
            Expanded(child: _PlayerChip(game: game, mark: Mark.o)),
          ],
        ),
        const SizedBox(height: 14),
        if (!game.isOver) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: game.secondsLeft / game.turnSeconds,
              minHeight: 6,
              backgroundColor: AppColors.surfaceHigh,
              color: lowTime ? AppColors.danger : markColor(game.current),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            botThinking
                ? '${game.nameOf(game.current)} düşünüyor…'
                : 'Sıra: ${game.nameOf(game.current)} · ${game.secondsLeft} sn',
            style: TextStyle(
              fontSize: 13,
              color: lowTime ? AppColors.danger : AppColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({required this.game, required this.mark});

  final GameController game;
  final Mark mark;

  @override
  Widget build(BuildContext context) {
    final active = !game.isOver && game.current == mark;
    final won = game.winner == mark;
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
              game.nameOf(mark),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: AppColors.text),
            ),
          ),
          Text(
            '${game.cellCount(mark)}',
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}
