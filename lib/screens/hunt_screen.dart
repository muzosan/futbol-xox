import 'dart:async';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../game/ai_player.dart';
import '../game/engine/common.dart';
import '../game/hunt_controller.dart';
import '../game/hunt_generator.dart';
import '../reactions/reactions.dart';
import '../report/report.dart';
import '../theme.dart';
import '../widgets/board.dart' show ClubHeader;
import '../widgets/player_search_sheet.dart';
import '../widgets/players_header.dart';
import 'game_screen.dart' show difficultyLabels;
import '../l10n/l10n.dart';

class HuntScreen extends StatefulWidget {
  const HuntScreen({
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
  State<HuntScreen> createState() => _HuntScreenState();
}

class _HuntScreenState extends State<HuntScreen> {
  late HuntController _game;
  HuntBot? _bot;
  Timer? _botTimer;
  int _botScheduledTurn = -1;

  bool _sheetOpen = false;
  int _sheetTurn = -1;
  int _summaryRound = -1;
  final _reactions = ReactionController();
  BotReactor? _botReactor;

  bool get _vsBot => _bot != null;
  bool get _botTurn =>
      _vsBot &&
      !_game.awaitingNextRound &&
      !_game.isOver &&
      _game.current == Mark.o;

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
    _bot = widget.botLevel == null
        ? null
        : HuntBot(widget.botLevel!, widget.repo);
    _botReactor?.dispose();
    _botReactor = _bot == null ? null : BotReactor(_reactions);
    final rounds = generateHuntRounds(widget.repo, widget.difficulty);
    _game = HuntController(
      repo: widget.repo,
      engine: HuntEngine(rounds: rounds, clubsOf: widget.repo.clubsOf),
      onTimeout: _onTimeout,
      names: _vsBot
          ? {Mark.x: t('common.you'), Mark.o: t('common.bot')}
          : {Mark.x: t('common.player_n', {'n': 1}), Mark.o: t('common.player_n', {'n': 2})},
    );
    _game.addListener(_onGameChanged);
    _summaryRound = -1;
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
    if (_sheetOpen &&
        (_game.turnNumber != _sheetTurn || _game.awaitingNextRound)) {
      _sheetOpen = false;
      Navigator.of(context).pop();
    }
    if (_game.awaitingNextRound && _summaryRound != _game.round) {
      _summaryRound = _game.round;
      _botTimer?.cancel();
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _showRoundSummary());
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
    final player = _bot!.decide(_game);
    if (player == null) {
      _game.pass();
      _toast(t('common.bot_passed'));
      return;
    }
    final result = _game.answer(player);
    final move = result.move;
    if (move == null) return;
    if (result.outcome == GuessResult.correct) {
      _toast(t('hunt.bot_scored', {'name': player.name, 'n': move.clubs.length, 'p': move.points}),
          color: AppColors.o.withValues(alpha: 0.9));
      _botReactor?.onBotScored();
    } else {
      _toast(t('hunt.bot_wrong', {'name': player.name, 'n': move.clubs.length}));
    }
  }

  // ---------- Oyuncu hamlesi ----------

  void _onTimeout(Mark who) {
    if (!mounted || _game.awaitingNextRound) return;
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

  Future<void> _openSearch() async {
    if (_game.awaitingNextRound || _game.isOver || _sheetOpen || _botTurn) {
      return;
    }
    _sheetOpen = true;
    _sheetTurn = _game.turnNumber;
    final player = await showModalBottomSheet<Player>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PlayerSearchSheet(
        repo: widget.repo,
        title: _game.clubs.map((c) => c.name).join(' · '),
        hint: t('hunt.search_hint'),
        usedIds: _game.usedPlayerIds,
      ),
    );
    _sheetOpen = false;
    if (player == null || !mounted) return;

    final result = _game.answer(player);
    final move = result.move;
    switch (result.outcome) {
      case GuessResult.correct:
        _toast(
          t('hunt.correct', {'name': player.name, 'n': move!.clubs.length, 'p': move.points}),
          color: AppColors.success,
        );
        _botReactor?.onPlayerScored();
      case GuessResult.wrong:
        final n = move?.clubs.length ?? 0;
        _toast(
          n == 1
              ? t('hunt.only_one', {'name': player.name})
              : t('hunt.none', {'name': player.name}),
          color: AppColors.danger,
          action: reportAction(
            context,
            DataReport(
              mode: t('mode.hunt.title'),
              player: player,
              clubs: _game.clubs,
              claim: n == 1
                  ? t('hunt.claim_one')
                  : t('hunt.claim_none'),
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

  // ---------- Tur sonu ----------

  Future<void> _showRoundSummary() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final over = _game.isOver;
    if (over && _game.winner != null) {
      _botReactor?.onGameEnd(botWon: _game.winner == Mark.o);
    }
    final you = _game.nameOf(Mark.x), rival = _game.nameOf(Mark.o);
    final String title;
    if (!over) {
      title = t('hunt.round_over', {'n': _game.round + 1});
    } else if (_game.winner == null) {
      title = t('common.draw');
    } else if (_vsBot) {
      title = _game.winner == Mark.x ? t('common.you_won') : t('common.bot_won');
    } else {
      title = t('common.x_won', {'name': _game.nameOf(_game.winner!)});
    }
    final missed = _game.missedAnswers();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: over
            ? Icon(
                _game.winner != null ? Icons.emoji_events : Icons.handshake,
                size: 40,
                color: _game.winner != null
                    ? markColor(_game.winner!)
                    : AppColors.textMuted,
              )
            : null,
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$you ${_game.score(Mark.x)}  –  ${_game.score(Mark.o)} $rival',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text),
              ),
              if (missed.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  t('hunt.missed'),
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),
                for (final m in missed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(m.player.name,
                              style: const TextStyle(color: AppColors.text)),
                        ),
                        Text(
                          t('hunt.clubs_points', {'n': m.count, 'p': HuntEngine.pointsFor(m.count)}),
                          style: const TextStyle(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: over
            ? [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  child: Text(t('common.main_menu')),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _restart();
                  },
                  child: Text(_vsBot ? t('common.rematch') : t('common.new_game')),
                ),
              ]
            : [
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _game.nextRound();
                  },
                  child: Text(t('common.next_round')),
                ),
              ],
      ),
    );
  }

  // ---------- Arayüz ----------

  @override
  Widget build(BuildContext context) {
    final modeLabel = _vsBot ? t('common.vs_bot') : t('common.two_players');
    final diffLabel = difficultyLabels[widget.difficulty] ?? widget.difficulty;

    return ListenableBuilder(
      listenable: Listenable.merge([_game, _reactions]),
      builder: (context, _) {
        final current = _game.current;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
            title: Text(
              t('hunt.title', {'mode': modeLabel, 'diff': diffLabel}),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            actions: [if (_vsBot) ReactionButton(controller: _reactions)],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  PlayersHeader(
                    names: {
                      Mark.x: _game.nameOf(Mark.x),
                      Mark.o: _game.nameOf(Mark.o),
                    },
                    values: {
                      Mark.x: t('hunt.points_short', {'n': _game.score(Mark.x)}),
                      Mark.o: t('hunt.points_short', {'n': _game.score(Mark.o)}),
                    },
                    current: current,
                    winner: _game.winner,
                    isOver: _game.isOver,
                    showTimer: !_game.awaitingNextRound,
                    secondsLeft: _game.secondsLeft,
                    turnSeconds: _game.turnSeconds,
                    status: _botTurn
                        ? t('common.bot_thinking')
                        : t('common.turn_of', {'name': _game.nameOf(current), 's': _game.secondsLeft}),
                    bubbles: _reactions.bubbles,
                  ),
                  const SizedBox(height: 14),
                  _RoundInfo(game: _game),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 96,
                    child: Row(
                      children: [
                        for (final club in _game.clubs)
                          Expanded(child: ClubHeader(club: club)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _PointsLegend(),
                  const SizedBox(height: 12),
                  Expanded(child: _MoveList(game: _game)),
                  const SizedBox(height: 12),
                  _buildButtons(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildButtons() {
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    if (_game.isOver) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: _restart,
          icon: const Icon(Icons.refresh),
          label: Text(_vsBot ? t('common.rematch') : t('common.new_game')),
          style: FilledButton.styleFrom(shape: shape),
        ),
      );
    }
    final disabled = _botTurn || _game.awaitingNextRound;
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: disabled ? null : _game.pass,
              icon: const Icon(Icons.skip_next),
              label: Text(t('common.pass')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.text,
                side: const BorderSide(color: AppColors.border),
                shape: shape,
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: disabled ? null : _openSearch,
              icon: const Icon(Icons.search),
              label: Text(t('common.write_player')),
              style: FilledButton.styleFrom(
                shape: shape,
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundInfo extends StatelessWidget {
  const _RoundInfo({required this.game});

  final HuntController game;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 13, color: AppColors.textMuted);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            t('common.round_of', {'n': game.round + 1, 'total': game.totalRounds}),
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.primary),
          ),
        ),
        const Spacer(),
        Text(
          t('hunt.moves_left', {
            'a': game.nameOf(Mark.x),
            'x': game.movesLeft(Mark.x),
            'b': game.nameOf(Mark.o),
            'o': game.movesLeft(Mark.o),
          }),
          style: style,
        ),
      ],
    );
  }
}

class _PointsLegend extends StatelessWidget {
  const _PointsLegend();

  @override
  Widget build(BuildContext context) {
    final parts = HuntEngine.pointTable.entries
        .map((e) => t('hunt.legend', {'n': e.key, 'p': e.value}))
        .join('  ·  ');
    return Text(
      parts,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
    );
  }
}

/// Bu turda yapılan hamlelerin listesi.
class _MoveList extends StatelessWidget {
  const _MoveList({required this.game});

  final HuntController game;

  @override
  Widget build(BuildContext context) {
    final moves = game.roundMoves.reversed.toList(); // en yeni üstte
    if (moves.isEmpty) {
      return Center(
        child: Text(
          t('hunt.empty'),
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return ListView.separated(
      itemCount: moves.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final m = moves[i];
        final color = markColor(m.mark);
        final player =
            m.playerId == null ? null : game.repo.playerById(m.playerId!);
        final clubNames = m.clubs.map((id) => game.repo.club(id).name);
        final scored = m.points > 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scored ? color.withValues(alpha: 0.5) : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Text(
                m.mark.symbol,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player?.name ?? t('hunt.passed'),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: player == null
                            ? AppColors.textMuted
                            : AppColors.text,
                      ),
                    ),
                    if (player != null)
                      Text(
                        m.clubs.isEmpty
                            ? t('hunt.not_here')
                            : clubNames.join(', '),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                  ],
                ),
              ),
              Text(
                scored ? '+${m.points}' : '0',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: scored ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
