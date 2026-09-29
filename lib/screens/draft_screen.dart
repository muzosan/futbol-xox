import 'dart:async';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../game/ai_player.dart' show BotLevel;
import '../game/draft_controller.dart';
import '../game/engine/common.dart';
import '../game/engine/duel_engine.dart' show CardStat;
import '../reactions/reactions.dart';
import '../report/report.dart';
import '../theme.dart';
import '../widgets/kit_icon.dart';
import '../widgets/player_search_sheet.dart';
import '../widgets/players_header.dart';
import 'game_screen.dart' show difficultyLabels;
import '../l10n/l10n.dart';

class DraftScreen extends StatefulWidget {
  const DraftScreen({
    super.key,
    required this.repo,
    required this.difficulty,
    this.botLevel,
  });

  final Repository repo;
  final String difficulty;
  final BotLevel? botLevel;

  @override
  State<DraftScreen> createState() => _DraftScreenState();
}

class _DraftScreenState extends State<DraftScreen> {
  late DraftController _game;
  DraftBot? _bot;
  Timer? _botTimer;
  int _botScheduledTurn = -1;
  bool _sheetOpen = false;
  int _sheetTurn = -1;
  bool _resultShown = false;
  final _reactions = ReactionController();
  BotReactor? _botReactor;

  bool get _vsBot => widget.botLevel != null;
  bool get _botTurn => _vsBot && !_game.isOver && _game.current == Mark.o;

  @override
  void initState() {
    super.initState();
    _createGame();
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    _game.removeListener(_onChanged);
    _game.dispose();
    _botReactor?.dispose();
    _reactions.dispose();
    super.dispose();
  }

  void _createGame() {
    final setup = draftSetup(widget.repo, widget.difficulty);
    _bot = _vsBot ? DraftBot(widget.botLevel!, widget.repo) : null;
    _botReactor?.dispose();
    _botReactor = _vsBot ? BotReactor(_reactions) : null;
    _game = DraftController(
      repo: widget.repo,
      engine: DraftEngine(
        criterion: setup.criterion,
        clubs: setup.clubs,
        clubsOf: widget.repo.clubsOf,
        statOf: (id, s) => widget.repo.playerById(id)!.stat(s),
      ),
      onTimeout: (who) {
        if (mounted) _toast(t('draft.time_up', {'name': _game.nameOf(who)}));
      },
      names: _vsBot
          ? {Mark.x: t('common.you'), Mark.o: t('common.bot')}
          : {Mark.x: t('common.player_n', {'n': 1}), Mark.o: t('common.player_n', {'n': 2})},
    );
    _game.addListener(_onChanged);
    _resultShown = false;
    _botScheduledTurn = -1;
    _maybeScheduleBot();
  }

  void _restart() {
    _botTimer?.cancel();
    _game.removeListener(_onChanged);
    _game.dispose();
    setState(_createGame);
  }

  void _onChanged() {
    if (_sheetOpen && (_game.turnNumber != _sheetTurn || _game.isOver)) {
      _sheetOpen = false;
      Navigator.of(context).pop();
    }
    if (_game.isOver && !_resultShown) {
      _resultShown = true;
      final w = _game.engine.winner;
      if (w != null) _botReactor?.onGameEnd(botWon: w == Mark.o);
      WidgetsBinding.instance.addPostFrameCallback((_) => _showResult());
    }
    _maybeScheduleBot();
  }

  void _maybeScheduleBot() {
    if (!_botTurn || _botScheduledTurn == _game.turnNumber) return;
    _botScheduledTurn = _game.turnNumber;
    _botTimer?.cancel();
    _botTimer = Timer(_bot!.thinkingTime(), () {
      if (!mounted || !_botTurn) return;
      final id = _bot!.pick(_game.engine);
      if (id == null) {
        _game.skip();
        return;
      }
      final p = widget.repo.playerById(id)!;
      final r = _game.pick(p);
      if (r.outcome == GuessResult.correct) {
        _toast(t('draft.bot_pick', {'name': p.name, 'v': _game.criterion.format(r.value)}),
            color: AppColors.o.withValues(alpha: 0.9));
        if (r.value > 0) _botReactor?.onBotScored();
      }
    });
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
    final club = _game.currentClub;
    _sheetOpen = true;
    _sheetTurn = _game.turnNumber;
    final player = await showModalBottomSheet<Player>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PlayerSearchSheet(
        repo: widget.repo,
        title: '${club.name} · ${criterionTitle(_game.criterion)}',
        hint: t('draft.search_hint', {'club': club.name}),
        usedIds: _game.engine.usedPlayerIds,
      ),
    );
    _sheetOpen = false;
    if (player == null || !mounted) return;
    final r = _game.pick(player);
    switch (r.outcome) {
      case GuessResult.correct:
        _toast(t('draft.picked', {'name': player.name, 'v': _game.criterion.format(r.value)}),
            color: AppColors.success);
        if (r.value > 0) _botReactor?.onPlayerScored();
      case GuessResult.wrong:
        _toast(
          t('draft.wrong', {'name': player.name, 'club': club.name}),
          color: AppColors.danger,
          action: reportAction(
            context,
            DataReport(
              mode: t('mode.draft.title'),
              player: player,
              clubs: [club],
              claim: t('draft.claim'),
            ),
          ),
        );
      case GuessResult.alreadyUsed:
        _toast(t('draft.already'));
      case GuessResult.invalid:
        break;
    }
  }

  Future<void> _showResult() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final e = _game.engine;
    final crit = _game.criterion;
    final w = e.winner;
    final title = w == null
        ? t('common.draw')
        : _vsBot
            ? (w == Mark.x ? t('common.you_won') : t('common.bot_won'))
            : t('common.x_won', {'name': _game.nameOf(w)});

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(w != null ? Icons.emoji_events : Icons.handshake,
            size: 44, color: w != null ? markColor(w) : AppColors.textMuted),
        title: Text(title, textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(criterionTitle(crit),
                  textAlign: TextAlign.center,
                  style: displayStyle(20, color: AppColors.gold)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(crit.format(e.total(Mark.x)),
                      style: displayStyle(44, color: AppColors.x)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text('–', style: displayStyle(32, color: AppColors.textMuted)),
                  ),
                  Text(crit.format(e.total(Mark.o)),
                      style: displayStyle(44, color: AppColors.o)),
                ],
              ),
              const SizedBox(height: 16),
              Text(t('draft.best'),
                  style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textMuted)),
              const SizedBox(height: 8),
              for (final clubId in e.clubs) ...[
                Row(
                  children: [
                    KitIcon(club: widget.repo.club(clubId), size: 20),
                    const SizedBox(width: 6),
                    Text(widget.repo.club(clubId).name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, color: AppColors.text)),
                  ],
                ),
                for (final p in bestOptions(widget.repo, clubId, e.criterion))
                  Padding(
                    padding: const EdgeInsets.only(left: 26, top: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(p.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textMuted)),
                        ),
                        Text(crit.format(p.stat(e.criterion)),
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, color: AppColors.primary)),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ],
          ),
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

  @override
  Widget build(BuildContext context) {
    final diffLabel = difficultyLabels[widget.difficulty] ?? widget.difficulty;
    return ListenableBuilder(
      listenable: Listenable.merge([_game, _reactions]),
      builder: (context, _) {
        final e = _game.engine;
        final crit = _game.criterion;
        final current = _game.current;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
            title: Text(t('draft.title', {'diff': diffLabel}),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            actions: [if (_vsBot) ReactionButton(controller: _reactions)],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  PlayersHeader(
                    names: {Mark.x: _game.nameOf(Mark.x), Mark.o: _game.nameOf(Mark.o)},
                    values: {
                      Mark.x: crit.format(e.total(Mark.x)),
                      Mark.o: crit.format(e.total(Mark.o)),
                    },
                    current: current,
                    winner: e.winner,
                    isOver: e.isOver,
                    secondsLeft: _game.secondsLeft,
                    turnSeconds: _game.turnSeconds,
                    status: _botTurn
                        ? t('draft.bot_thinking')
                        : t('common.turn_of', {'name': _game.nameOf(current), 's': _game.secondsLeft}),
                    bubbles: _reactions.bubbles,
                  ),
                  const SizedBox(height: 12),
                  _CriterionBanner(criterion: crit),
                  const SizedBox(height: 12),
                  if (!e.isOver) _RoundClub(game: _game),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _Lineup(game: _game, mark: Mark.x)),
                        const SizedBox(width: 10),
                        Expanded(child: _Lineup(game: _game, mark: Mark.o)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!e.isOver)
                    SizedBox(
                      height: 52,
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _botTurn ? null : _game.skip,
                              style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52)),
                              child: Text(t('draft.pass')),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: _botTurn ? null : _openSearch,
                              style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52)),
                              icon: const Icon(Icons.person_add_alt_1),
                              label: Text(t('draft.pick_btn')),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _restart,
                        icon: const Icon(Icons.refresh),
                        label: Text(_vsBot ? t('common.rematch') : t('common.new_game')),
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

/// Altın ölçüt bandı
class _CriterionBanner extends StatelessWidget {
  const _CriterionBanner({required this.criterion});

  final CardStat criterion;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF3A2C0A), Color(0xFF1A1405)],
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.8)),
        boxShadow: [...AppShadows.card, ...AppShadows.glow(AppColors.gold, 0.25)],
      ),
      child: Column(
        children: [
          Text(t('draft.criterion'),
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w900,
                  color: AppColors.gold)),
          GoldText(criterionTitle(criterion), size: 30, spacing: 2),
          if (criterion.since2012)
            Text(t('stat.scope'),
                style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

/// Turun kulübü
class _RoundClub extends StatelessWidget {
  const _RoundClub({required this.game});

  final DraftController game;

  @override
  Widget build(BuildContext context) {
    final club = game.currentClub;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppDecor.card(accent: AppColors.primary, active: true),
      child: Row(
        children: [
          KitIcon(club: club, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('common.round_of_caps', {'n': game.engine.round + 1, 'total': game.engine.rounds}),
                    style: displayStyle(18, color: AppColors.primary)),
                Text(upper(club.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: displayStyle(30)),
                Text(club.league,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bir oyuncunun 5 turluk kadrosu
class _Lineup extends StatelessWidget {
  const _Lineup({required this.game, required this.mark});

  final DraftController game;
  final Mark mark;

  @override
  Widget build(BuildContext context) {
    final e = game.engine;
    final color = markColor(mark);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: AppDecor.card(
          accent: color, active: !e.isOver && game.current == mark),
      child: Column(
        children: [
          Text(upper(game.nameOf(mark)), style: displayStyle(18, color: color)),
          const SizedBox(height: 6),
          for (var r = 0; r < e.rounds; r++)
            Expanded(child: _slot(e, r, color)),
        ],
      ),
    );
  }

  Widget _slot(DraftEngine e, int r, Color color) {
    final pick = e.picks[mark]![r];
    final club = game.repo.club(e.clubs[r]);
    final active = !e.isOver && e.round == r && game.current == mark;
    final future = r > e.round;
    final player = pick?.playerId == null ? null : game.repo.playerById(pick!.playerId!);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: active ? color.withValues(alpha: 0.14) : AppColors.background.withValues(alpha: 0.4),
        border: Border.all(
            color: active ? color : Colors.white.withValues(alpha: 0.06),
            width: active ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Opacity(
            opacity: future ? 0.35 : 1,
            child: KitIcon(club: club, size: 22),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              pick == null
                  ? (active ? t('draft.picking') : '—')
                  : (player?.name ?? t('common.pass')),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: pick == null ? AppColors.textMuted : AppColors.text,
              ),
            ),
          ),
          if (pick != null)
            Text(game.criterion.format(pick.value),
                style: displayStyle(16, color: color, spacing: 0.5)),
        ],
      ),
    );
  }
}
