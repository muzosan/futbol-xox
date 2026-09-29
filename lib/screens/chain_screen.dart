import 'dart:async';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../game/ai_player.dart';
import '../game/chain_controller.dart';
import '../game/engine/common.dart';
import '../reactions/reactions.dart';
import '../report/report.dart';
import '../theme.dart';
import '../widgets/kit_icon.dart';
import '../widgets/player_search_sheet.dart';
import '../widgets/players_header.dart';
import 'game_screen.dart' show difficultyLabels;
import '../l10n/l10n.dart';

class ChainScreen extends StatefulWidget {
  const ChainScreen({
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
  State<ChainScreen> createState() => _ChainScreenState();
}

class _ChainScreenState extends State<ChainScreen> {
  late ChainController _game;
  ChainBot? _bot;
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
    _bot = widget.botLevel == null
        ? null
        : ChainBot(widget.botLevel!, widget.repo);
    _botReactor?.dispose();
    _botReactor = _bot == null ? null : BotReactor(_reactions);
    _game = ChainController(
      repo: widget.repo,
      engine: ChainEngine(
        startPlayerId: pickChainStart(widget.repo, widget.difficulty),
        clubsOf: widget.repo.clubsOf,
        lives: chainRules(widget.difficulty).lives,
        maxClubUses: chainRules(widget.difficulty).maxClubUses,
      ),
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
    final player = _bot!.decide(_game);
    if (player == null) {
      _game.pass();
      _toast(t('chain.bot_passed'));
      return;
    }
    final result = _game.answer(player);
    if (result.outcome == GuessResult.correct) {
      final via = widget.repo.club(result.link!.viaClub!).name;
      _toast(t('chain.bot_link', {'name': player.name, 'via': via}),
          color: AppColors.o.withValues(alpha: 0.9));
      _botReactor?.onBotScored();
    } else if (result.outcome == GuessResult.wrong) {
      _toast(t('chain.bot_wrong', {'name': player.name}));
    }
  }

  // ---------- Oyuncu hamlesi ----------

  void _onTimeout(Mark who) {
    if (!mounted || _game.isOver) return;
    _toast(t('chain.time_up', {'name': _game.nameOf(who)}));
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
    if (_game.isOver || _sheetOpen || _botTurn) return;
    final last = _game.lastPlayer;
    _sheetOpen = true;
    _sheetTurn = _game.turnNumber;
    final player = await showModalBottomSheet<Player>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PlayerSearchSheet(
        repo: widget.repo,
        title: t('chain.search_title', {'name': last.name}),
        hint: t('chain.search_hint', {'name': last.name}),
        usedIds: _game.usedPlayerIds,
      ),
    );
    _sheetOpen = false;
    if (player == null || !mounted) return;

    final result = _game.answer(player);
    switch (result.outcome) {
      case GuessResult.correct:
        final via = widget.repo.club(result.link!.viaClub!).name;
        _toast(t('chain.correct', {'via': via}), color: AppColors.success);
        _botReactor?.onPlayerScored();
      case GuessResult.wrong:
        _toast(
          result.fail == ChainFail.clubLimit
              ? t('chain.limit')
              : t('chain.wrong', {'name': player.name, 'last': last.name}),
          color: AppColors.danger,
          action: result.fail == ChainFail.clubLimit
              ? null
              : reportAction(
                  context,
                  DataReport(
                    mode: t('mode.chain.title'),
                    player: player,
                    clubs: last.clubs.map(widget.repo.club).toList(),
                    claim: t('chain.claim', {'last': last.name}),
                  ),
                ),
        );
        _botReactor?.onPlayerMissed();
      case GuessResult.alreadyUsed:
        _toast(t('chain.already'));
      case GuessResult.invalid:
        break;
    }
  }

  // ---------- Sonuç ----------

  Future<void> _showResult() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final winner = _game.winner!;
    _botReactor?.onGameEnd(botWon: winner == Mark.o);
    final title = _vsBot
        ? (winner == Mark.x ? t('common.you_won') : t('common.bot_won'))
        : t('common.x_won', {'name': _game.nameOf(winner)});

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(Icons.emoji_events, size: 40, color: markColor(winner)),
        title: Text(title),
        content: Text(
          '${t('chain.out_of_lives', {'name': _game.nameOf(winner.other)})}\n'
          '${t('chain.length', {'n': _game.length})}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
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
        String hearts(Mark m) => '♥' * _game.livesOf(m);
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
            title: Text(
              t('chain.title', {'mode': modeLabel, 'diff': diffLabel}),
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
                    values: {Mark.x: hearts(Mark.x), Mark.o: hearts(Mark.o)},
                    current: current,
                    winner: _game.winner,
                    isOver: _game.isOver,
                    secondsLeft: _game.secondsLeft,
                    turnSeconds: _game.turnSeconds,
                    status: _botTurn
                        ? t('common.bot_thinking')
                        : t('common.turn_of', {'name': _game.nameOf(current), 's': _game.secondsLeft}),
                    bubbles: _reactions.bubbles,
                  ),
                  const SizedBox(height: 14),
                  _LastPlayerCard(game: _game),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        t('chain.count', {'n': _game.length}),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary),
                      ),
                      const Spacer(),
                      Text(
                        t('chain.max_uses', {'n': _game.engine.maxClubUses}),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(child: _ChainList(game: _game)),
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
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _botTurn ? null : _game.pass,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.text,
                side: const BorderSide(color: AppColors.border),
                shape: shape,
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(t('chain.pass')),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _botTurn ? null : _openSearch,
              icon: const Icon(Icons.link),
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

/// Zincirdeki son futbolcu ve onun kulüpleri (bağlantı kurulabilecekler).
class _LastPlayerCard extends StatelessWidget {
  const _LastPlayerCard({required this.game});

  final ChainController game;

  @override
  Widget build(BuildContext context) {
    final player = game.lastPlayer;
    final max = game.engine.maxClubUses;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('chain.last'),
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(upper(player.name), style: displayStyle(32)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in game.lastPlayerClubs)
                _ClubChip(club: c.club, uses: c.uses, max: max),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClubChip extends StatelessWidget {
  const _ClubChip({required this.club, required this.uses, required this.max});

  final Club club;
  final int uses;
  final int max;

  @override
  Widget build(BuildContext context) {
    final full = uses >= max;
    return Opacity(
      opacity: full ? 0.4 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KitIcon(club: club, size: 18),
            const SizedBox(width: 6),
            Text(
              club.name,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.text,
                decoration: full ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(width: 6),
            Text('$uses/$max',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

/// Zincirin geçmişi (en yeni üstte).
class _ChainList extends StatelessWidget {
  const _ChainList({required this.game});

  final ChainController game;

  @override
  Widget build(BuildContext context) {
    final links = game.links.reversed.toList();
    return ListView.builder(
      itemCount: links.length,
      itemBuilder: (context, i) {
        final link = links[i];
        final player = game.repo.playerById(link.playerId)!;
        final isStart = link.mark == null;
        final color = isStart ? AppColors.primary : markColor(link.mark!);
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: isStart
                    ? const Icon(Icons.flag, size: 18, color: AppColors.primary)
                    : Text(
                        link.mark!.symbol,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.w900, color: color),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  player.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.text),
                ),
              ),
              Text(
                isStart
                    ? t('chain.start')
                    : t('chain.via', {'club': game.repo.club(link.viaClub!).name}),
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        );
      },
    );
  }
}
