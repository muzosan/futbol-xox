import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../game/game_controller.dart';

Color markColor(Mark mark) =>
    mark == Mark.x ? const Color(0xFF42A5F5) : const Color(0xFFEF5350);

const List<Color> _clubPalette = [
  Color(0xFF8E24AA), Color(0xFF3949AB), Color(0xFF00897B), Color(0xFFF4511E),
  Color(0xFF6D4C41), Color(0xFF546E7A), Color(0xFFC0CA33), Color(0xFFD81B60),
  Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFFFB8C00), Color(0xFF5E35B1),
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
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: _Cell(
                        filled: game.cells[r * 3 + c],
                        highlighted:
                            game.winningLine?.contains(r * 3 + c) ?? false,
                        example: game.isOver && game.cells[r * 3 + c] == null
                            ? repo.exampleAnswer(
                                game.grid.rows[r], game.grid.cols[c])
                            : null,
                        onTap: game.isOver || game.cells[r * 3 + c] != null
                            ? null
                            : () => onCellTap(r * 3 + c),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
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
          width: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: clubColor(club.id),
                child: Text(
                  club.initials,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                club.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, height: 1.1),
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
      return Center(
        child: Icon(
          game.winner != null ? Icons.emoji_events : Icons.handshake,
          size: 36,
          color: game.winner != null ? markColor(game.winner!) : Colors.grey,
        ),
      );
    }
    return Center(
      child: Text(
        game.current.symbol,
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w900,
          color: markColor(game.current),
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
    final scheme = Theme.of(context).colorScheme;
    final Color background;
    final Widget child;

    if (filled != null) {
      final color = markColor(filled!.owner);
      background = color.withValues(alpha: highlighted ? 0.6 : 0.25);
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
            style: const TextStyle(fontSize: 11, height: 1.1),
          ),
        ],
      );
    } else if (example != null) {
      background = scheme.surfaceContainerHighest.withValues(alpha: 0.4);
      child = Text(
        'Örn:\n${example!.name}',
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontStyle: FontStyle.italic,
          color: scheme.onSurfaceVariant,
        ),
      );
    } else {
      background = scheme.surfaceContainerHighest;
      child = Icon(Icons.add, color: scheme.onSurfaceVariant);
    }

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Üstteki oyuncu kutuları ve süre çubuğu.
class TurnBar extends StatelessWidget {
  const TurnBar({super.key, required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _PlayerChip(game: game, mark: Mark.x)),
            const SizedBox(width: 12),
            Expanded(child: _PlayerChip(game: game, mark: Mark.o)),
          ],
        ),
        const SizedBox(height: 12),
        if (!game.isOver) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: game.secondsLeft / game.turnSeconds,
              minHeight: 6,
              color: markColor(game.current),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${game.current.playerName} düşünüyor · ${game.secondsLeft} sn',
            style: Theme.of(context).textTheme.bodySmall,
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
    final color = markColor(mark);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? color : color.withValues(alpha: 0.3),
          width: 2,
        ),
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
            child: Text(mark.playerName,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text('${game.cellCount(mark)}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
