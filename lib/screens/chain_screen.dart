import 'dart:async';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../game/ai_player.dart';
import '../game/chain_controller.dart';
import '../game/engine/common.dart';
import '../theme.dart';
import '../widgets/board.dart' show clubColor;
import '../widgets/player_search_sheet.dart';
import '../widgets/players_header.dart';
import 'game_screen.dart' show difficultyLabels;

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
    super.dispose();
  }

  void _createGame() {
    _bot = widget.botLevel == null
        ? null
        : ChainBot(widget.botLevel!, widget.repo);
    _game = ChainController(
      repo: widget.repo,
      engine: ChainEngine(
        startPlayerId: pickChainStart(widget.repo, widget.difficulty),
        clubsOf: widget.repo.clubsOf,
      ),
      onTimeout: _onTimeout,
      names: _vsBot
          ? const {Mark.x: 'Sen', Mark.o: 'Bot'}
          : const {Mark.x: 'Oyuncu 1', Mark.o: 'Oyuncu 2'},
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
      _toast('Bot pas geçti ve bir can kaybetti.');
      return;
    }
    final result = _game.answer(player);
    if (result.outcome == GuessResult.correct) {
      final via = widget.repo.club(result.link!.viaClub!).name;
      _toast('Bot: ${player.name} (bağlantı: $via)',
          color: AppColors.o.withValues(alpha: 0.9));
    } else if (result.outcome == GuessResult.wrong) {
      _toast('Bot yanıldı: ${player.name}. Bot bir can kaybetti.');
    }
  }

  // ---------- Oyuncu hamlesi ----------

  void _onTimeout(Mark who) {
    if (!mounted || _game.isOver) return;
    _toast('Süre doldu! ${_game.nameOf(who)} bir can kaybetti.');
  }

  void _toast(String message, {Color? color}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color ?? AppColors.surfaceHigh,
        duration: const Duration(seconds: 2),
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
        title: '${last.name} ile aynı kulüpte oynamış biri',
        hint: 'Listedeki kulüplerden birinde ${last.name} ile '
            'ortak olan bir futbolcu yaz',
        usedIds: _game.usedPlayerIds,
      ),
    );
    _sheetOpen = false;
    if (player == null || !mounted) return;

    final result = _game.answer(player);
    switch (result.outcome) {
      case GuessResult.correct:
        final via = widget.repo.club(result.link!.viaClub!).name;
        _toast('Doğru! Bağlantı: $via', color: AppColors.success);
      case GuessResult.wrong:
        _toast(
          result.fail == ChainFail.clubLimit
              ? 'Ortak kulüpleri kullanım sınırına ulaştı. Bir can kaybettin.'
              : '${player.name}, ${last.name} ile listedeki kulüplerin '
                  'hiçbirinde oynamamış. Bir can kaybettin.',
          color: AppColors.danger,
        );
      case GuessResult.alreadyUsed:
        _toast('Bu oyuncu zincirde zaten var.');
      case GuessResult.invalid:
        break;
    }
  }

  // ---------- Sonuç ----------

  Future<void> _showResult() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final winner = _game.winner!;
    final title = _vsBot
        ? (winner == Mark.x ? 'Kazandın!' : 'Bot kazandı')
        : '${_game.nameOf(winner)} kazandı!';

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(Icons.emoji_events, size: 40, color: markColor(winner)),
        title: Text(title),
        content: Text(
          '${_game.nameOf(winner.other)} canlarını tüketti.\n'
          'Zincir uzunluğu: ${_game.length}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
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
      listenable: _game,
      builder: (context, _) {
        final current = _game.current;
        String hearts(Mark m) => '♥' * _game.livesOf(m);
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
            title: Text(
              'Zincir · $modeLabel · $diffLabel',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
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
                        ? 'Bot düşünüyor…'
                        : 'Sıra: ${_game.nameOf(current)} · ${_game.secondsLeft} sn',
                  ),
                  const SizedBox(height: 14),
                  _LastPlayerCard(game: _game),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        'Zincir: ${_game.length}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary),
                      ),
                      const Spacer(),
                      Text(
                        'Kulüp başına en fazla ${_game.engine.maxClubUses} bağlantı',
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
          label: Text(_vsBot ? 'Rövanş' : 'Yeni Oyun'),
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
              child: const Text('Pas (−1 can)'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _botTurn ? null : _openSearch,
              icon: const Icon(Icons.link),
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
          const Text('SON OYUNCU',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(
            player.name,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.text),
          ),
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
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: clubColor(club.id), shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              club.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
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
                      fontWeight: FontWeight.w600, color: AppColors.text),
                ),
              ),
              Text(
                isStart
                    ? 'başlangıç'
                    : 'via ${game.repo.club(link.viaClub!).name}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        );
      },
    );
  }
}
