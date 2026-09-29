import 'dart:async';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../game/ai_player.dart';
import '../game/game_controller.dart';
import '../reactions/reactions.dart';
import '../report/report.dart';
import '../theme.dart';
import '../widgets/board.dart';
import '../widgets/player_search_sheet.dart';
import '../l10n/l10n.dart';

/// Zorluk adları geçerli dilde (her okunuşta yeniden çevrilir)
Map<String, String> get difficultyLabels => {
      'kolay': t('diff.kolay'),
      'orta': t('diff.orta'),
      'zor': t('diff.zor'),
    };

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.repo,
    required this.difficulty,
    this.botLevel,
  });

  final Repository repo;
  final String difficulty;

  /// null ise aynı telefonda 2 kişilik oyun
  final BotLevel? botLevel;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController _game;
  Bot? _bot;
  Timer? _botTimer;
  int _botScheduledTurn = -1;

  bool _sheetOpen = false;
  int _sheetTurn = -1;
  bool _resultShown = false;
  final _reactions = ReactionController();
  BotReactor? _botReactor;

  bool get _vsBot => _bot != null;
  bool get _botTurn => _vsBot && !_game.isOver && _game.current == Mark.o;

  @override
  void initState() {
    super.initState();
    _createGame();
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    _game.removeListener(_onGameChanged);
    _game.dispose();
    _botReactor?.dispose();
    _reactions.dispose();
    super.dispose();
  }

  void _createGame() {
    _bot = widget.botLevel == null ? null : Bot(widget.botLevel!, widget.repo);
    _botReactor?.dispose();
    _botReactor = _bot == null ? null : BotReactor(_reactions);
    _game = GameController(
      repo: widget.repo,
      grid: widget.repo.randomGrid(widget.difficulty),
      onTimeout: _onTimeout,
      names: _vsBot
          ? {Mark.x: t('common.you'), Mark.o: t('common.bot')}
          : {Mark.x: t('common.player_n', {'n': 1}), Mark.o: t('common.player_n', {'n': 2})},
    );
    _game.addListener(_onGameChanged);
    _resultShown = false;
    _botScheduledTurn = -1;
    _maybeScheduleBot();
  }

  void _restart() {
    _botTimer?.cancel();
    _game.removeListener(_onGameChanged);
    _game.dispose();
    setState(_createGame);
  }

  void _onGameChanged() {
    // Arama paneli açıkken sıra değişirse (süre doldu) paneli kapat
    if (_sheetOpen && (_game.turnNumber != _sheetTurn || _game.isOver)) {
      _sheetOpen = false;
      Navigator.of(context).pop();
    }
    if (_game.isOver && !_resultShown) {
      _resultShown = true;
      _botTimer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) => _showResult());
    }
    _maybeScheduleBot();
  }

  // ---------- Bot ----------

  void _maybeScheduleBot() {
    if (!_botTurn || _botScheduledTurn == _game.turnNumber) return;
    _botScheduledTurn = _game.turnNumber;
    _botTimer?.cancel();
    _botTimer = Timer(_bot!.thinkingTime(), _playBot);
  }

  void _playBot() {
    if (!mounted || !_botTurn || _game.turnNumber != _botScheduledTurn) return;
    final move = _bot!.decide(_game);

    if (move.isPass) {
      _game.pass();
      _toast(t('common.bot_passed_you'));
      return;
    }
    final cell = move.cell!;
    final player = move.player!;
    final result = _game.guess(cell, player);
    if (result == GuessResult.correct) {
      _toast(t('xox.bot_played', {'name': player.name}), color: AppColors.o.withValues(alpha: 0.9));
      _botReactor?.onBotScored();
    } else if (result == GuessResult.wrong) {
      final row = widget.repo.club(_game.rowClubId(cell)).name;
      final col = widget.repo.club(_game.colClubId(cell)).name;
      _toast(t('xox.bot_wrong', {'name': player.name, 'row': row, 'col': col}));
    }
  }

  // ---------- Oyuncu hamlesi ----------

  void _onTimeout(Mark who) {
    if (!mounted || _game.isOver) return;
    _toast(t('common.time_up_turn', {'name': _game.nameOf(who.other)}));
  }

  void _toast(String message, {Color? color, SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color ?? AppColors.surfaceHigh,
        duration: Duration(seconds: action == null ? 2 : 5),
        action: action,
      ));
  }

  Future<void> _onCellTap(int cell) async {
    if (_game.isOver || _game.cells[cell] != null || _sheetOpen || _botTurn) {
      return;
    }

    final rowClub = widget.repo.club(_game.rowClubId(cell));
    final colClub = widget.repo.club(_game.colClubId(cell));

    _sheetOpen = true;
    _sheetTurn = _game.turnNumber;
    final player = await showModalBottomSheet<Player>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PlayerSearchSheet(
        repo: widget.repo,
        title: '${rowClub.name}  ×  ${colClub.name}',
        hint: t('xox.search_hint'),
        usedIds: _game.usedPlayerIds,
      ),
    );
    _sheetOpen = false;
    if (player == null || !mounted) return;

    final result = _game.guess(cell, player);
    switch (result) {
      case GuessResult.correct:
        _toast(t('common.correct_name', {'name': player.name}), color: AppColors.success);
        _botReactor?.onPlayerScored();
      case GuessResult.wrong:
        _toast(
          t('xox.wrong', {'name': player.name, 'row': rowClub.name, 'col': colClub.name}),
          color: AppColors.danger,
          action: reportAction(
            context,
            DataReport(
              mode: t('mode.xox.title'),
              player: player,
              clubs: [rowClub, colClub],
              claim: t('xox.claim'),
            ),
          ),
        );
        _botReactor?.onPlayerMissed();
      case GuessResult.alreadyUsed:
        _toast(t('common.already_used'));
      case GuessResult.invalid:
        break;
    }
  }

  // ---------- Sonuç ----------

  Future<void> _showResult() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final String title;
    final String message;
    final winner = _game.winner;
    if (winner != null) _botReactor?.onGameEnd(botWon: winner == Mark.o);
    if (winner != null) {
      if (_vsBot) {
        title = winner == Mark.x ? t('common.you_won') : t('common.bot_won');
        message = winner == Mark.x
            ? t('xox.you_line')
            : t('xox.bot_line');
      } else {
        title = t('common.x_won', {'name': _game.nameOf(winner)});
        message = t('xox.other_line');
      }
    } else if (_game.endReason == EndReason.stalemate) {
      title = t('common.draw_plain');
      message = t('xox.stalemate', {'n': GameController.maxTurnsWithoutProgress});
    } else {
      title = t('common.draw_plain');
      message = t('xox.full');
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(
          winner != null ? Icons.emoji_events : Icons.handshake,
          size: 40,
          color: winner != null ? markColor(winner) : AppColors.textMuted,
        ),
        title: Text(title),
        content: Text(
          '$message\n\n${t('xox.see_examples')}',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('common.see_board')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _restart();
            },
            child: Text(_vsBot ? t('common.rematch') : t('common.new_game')),
          ),
        ],
      ),
    );
  }

  // ---------- Arayüz ----------

  @override
  Widget build(BuildContext context) {
    final modeLabel = _vsBot ? t('common.vs_bot') : t('common.two_players');
    final diffLabel =
        difficultyLabels[widget.difficulty] ?? widget.difficulty;

    return ListenableBuilder(
      listenable: Listenable.merge([_game, _reactions]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
            title: Text(
              '$modeLabel · $diffLabel',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800),
            ),
            actions: [if (_vsBot) ReactionButton(controller: _reactions)],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  TurnBar(
                    game: _game,
                    botThinking: _botTurn,
                    bubbles: _reactions.bubbles,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: GameBoard(
                          game: _game,
                          repo: widget.repo,
                          onCellTap: _onCellTap,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: _game.isOver
                        ? FilledButton.icon(
                            onPressed: _restart,
                            icon: const Icon(Icons.refresh),
                            label: Text(_vsBot ? t('common.rematch') : t('common.new_game')),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: _botTurn ? null : _game.pass,
                            icon: const Icon(Icons.skip_next),
                            label: Text(t('common.pass_turn')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.text,
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
