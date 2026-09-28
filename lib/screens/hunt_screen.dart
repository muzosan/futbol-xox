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
          ? const {Mark.x: 'Sen', Mark.o: 'Bot'}
          : const {Mark.x: 'Oyuncu 1', Mark.o: 'Oyuncu 2'},
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
      _toast('Bot pas geçti.');
      return;
    }
    final result = _game.answer(player);
    final move = result.move;
    if (move == null) return;
    if (result.outcome == GuessResult.correct) {
      _toast('Bot: ${player.name} · ${move.clubs.length} kulüp, +${move.points}',
          color: AppColors.o.withValues(alpha: 0.9));
      _botReactor?.onBotScored();
    } else {
      _toast('Bot yanıldı: ${player.name} (${move.clubs.length} kulüp)');
    }
  }

  // ---------- Oyuncu hamlesi ----------

  void _onTimeout(Mark who) {
    if (!mounted || _game.awaitingNextRound) return;
    _toast('Süre doldu! Sıra: ${_game.nameOf(who.other)}');
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
        hint: 'Bu kulüplerin en az ikisinde oynamış bir futbolcu yaz',
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
          'Doğru! ${player.name} · ${move!.clubs.length} kulüp, +${move.points} puan',
          color: AppColors.success,
        );
        _botReactor?.onPlayerScored();
      case GuessResult.wrong:
        final n = move?.clubs.length ?? 0;
        _toast(
          n == 1
              ? '${player.name} bu kulüplerden sadece birinde oynamış. 0 puan.'
              : '${player.name} bu kulüplerin hiçbirinde oynamamış. 0 puan.',
          color: AppColors.danger,
          action: reportAction(
            context,
            DataReport(
              mode: 'Kulüp Avı',
              player: player,
              clubs: _game.clubs,
              claim: n == 1
                  ? 'Oyun: bu kulüplerden sadece birinde oynamış'
                  : 'Oyun: bu kulüplerin hiçbirinde oynamamış',
            ),
          ),
        );
        _botReactor?.onPlayerMissed();
      case GuessResult.alreadyUsed:
        _toast('Bu oyuncu bu maçta zaten kullanıldı.');
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
      title = 'Tur ${_game.round + 1} bitti';
    } else if (_game.winner == null) {
      title = 'Berabere!';
    } else if (_vsBot) {
      title = _game.winner == Mark.x ? 'Kazandın!' : 'Bot kazandı';
    } else {
      title = '${_game.nameOf(_game.winner!)} kazandı!';
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
                const Text(
                  'Bu turda kaçırılanlar',
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
                          '${m.count} kulüp · +${HuntEngine.pointsFor(m.count)}',
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
                  child: const Text('Ana Menü'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _restart();
                  },
                  child: Text(_vsBot ? 'Rövanş' : 'Yeni Oyun'),
                ),
              ]
            : [
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _game.nextRound();
                  },
                  child: const Text('Sonraki Tur'),
                ),
              ],
      ),
    );
  }

  // ---------- Arayüz ----------

  @override
  Widget build(BuildContext context) {
    final modeLabel = _vsBot ? 'Bota Karşı' : '2 Kişilik';
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
              'Kulüp Avı · $modeLabel · $diffLabel',
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
                      Mark.x: '${_game.score(Mark.x)} p',
                      Mark.o: '${_game.score(Mark.o)} p',
                    },
                    current: current,
                    winner: _game.winner,
                    isOver: _game.isOver,
                    showTimer: !_game.awaitingNextRound,
                    secondsLeft: _game.secondsLeft,
                    turnSeconds: _game.turnSeconds,
                    status: _botTurn
                        ? 'Bot düşünüyor…'
                        : 'Sıra: ${_game.nameOf(current)} · ${_game.secondsLeft} sn',
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
          label: Text(_vsBot ? 'Rövanş' : 'Yeni Oyun'),
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
              label: const Text('Pas'),
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
              label: const Text('Futbolcu Yaz'),
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
            'Tur ${game.round + 1}/${game.totalRounds}',
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.primary),
          ),
        ),
        const Spacer(),
        Text(
          'Kalan hamle: ${game.nameOf(Mark.x)} ${game.movesLeft(Mark.x)} · '
          '${game.nameOf(Mark.o)} ${game.movesLeft(Mark.o)}',
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
        .map((e) => '${e.key} kulüp = ${e.value}')
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
      return const Center(
        child: Text(
          'Bu 5 kulübün en çoğunda oynamış futbolcuyu bul!',
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
                      player?.name ?? 'Pas geçti',
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
                            ? 'Bu kulüplerde oynamamış'
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
