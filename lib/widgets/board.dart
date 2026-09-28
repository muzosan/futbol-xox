import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../game/game_controller.dart';
import '../theme.dart';
import 'kit_icon.dart';
import 'players_header.dart';

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
              KitIcon(club: club, size: 46),
              const SizedBox(height: 5),
              Text(
                club.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
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
        style: displayStyle(48, color: color, spacing: 0).copyWith(
          shadows: [Shadow(color: color.withValues(alpha: 0.8), blurRadius: 18)],
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
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: highlighted ? 0.45 : 0.22),
            color.withValues(alpha: highlighted ? 0.22 : 0.06),
          ],
        ),
        border: Border.all(
          color: color.withValues(alpha: highlighted ? 1 : 0.6),
          width: highlighted ? 2.5 : 1.5,
        ),
        boxShadow: [
          ...AppShadows.card,
          if (highlighted) ...AppShadows.glow(color, 0.55),
        ],
      );
      child = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            filled!.owner.symbol,
            style: displayStyle(28, color: color, spacing: 0).copyWith(
              shadows: [Shadow(color: color.withValues(alpha: 0.8), blurRadius: 14)],
            ),
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
        color: AppColors.surface.withValues(alpha: 0.8),
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
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1D2948), Color(0xFF111A2D)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: AppShadows.card,
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

/// XOX için üst bilgi: oyuncu kutuları (dolu hücre sayısı) ve süre.
class TurnBar extends StatelessWidget {
  const TurnBar({
    super.key,
    required this.game,
    this.botThinking = false,
    this.bubbles = const {},
  });

  final GameController game;
  final bool botThinking;
  final Map<Mark, String?> bubbles;

  @override
  Widget build(BuildContext context) {
    return PlayersHeader(
      names: {Mark.x: game.nameOf(Mark.x), Mark.o: game.nameOf(Mark.o)},
      values: {
        Mark.x: '${game.cellCount(Mark.x)}',
        Mark.o: '${game.cellCount(Mark.o)}',
      },
      current: game.current,
      winner: game.winner,
      isOver: game.isOver,
      secondsLeft: game.secondsLeft,
      turnSeconds: game.turnSeconds,
      status: botThinking
          ? '${game.nameOf(game.current)} düşünüyor…'
          : 'Sıra: ${game.nameOf(game.current)} · ${game.secondsLeft} sn',
      bubbles: bubbles,
    );
  }
}
