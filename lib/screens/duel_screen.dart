import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../game/ai_player.dart' show BotLevel;
import '../game/duel_controller.dart';
import '../game/engine/common.dart';
import '../reactions/reactions.dart';
import '../report/report.dart';
import '../theme.dart';
import '../widgets/player_card.dart';
import '../widgets/players_header.dart';
import 'game_screen.dart' show difficultyLabels;

class DuelScreen extends StatefulWidget {
  const DuelScreen({
    super.key,
    required this.repo,
    required this.difficulty,
    this.botLevel,
  });

  final Repository repo;
  final String difficulty;

  /// null ise aynı telefonda 2 kişilik
  final BotLevel? botLevel;

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen> {
  DuelController? _game;
  DuelBot? _bot;
  Timer? _botTimer;
  int _botScheduledTurn = -1;
  bool _resultShown = false;
  final _reactions = ReactionController();
  BotReactor? _botReactor;

  bool get _vsBot => widget.botLevel != null;
  bool get _botTurn =>
      _vsBot && _game != null && !_game!.revealed && _game!.chooser == Mark.o;

  @override
  void initState() {
    super.initState();
    _createGame();
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    _game?.removeListener(_onChanged);
    _game?.dispose();
    _botReactor?.dispose();
    _reactions.dispose();
    super.dispose();
  }

  void _createGame() {
    final pool = duelPool(widget.repo, widget.difficulty);
    if (pool.length < 14) {
      _game = null; // istatistik verisi yok
      return;
    }
    final stats = cardStatsFor(widget.repo);
    _bot = _vsBot ? DuelBot(widget.botLevel!, pool, stats) : null;
    _botReactor?.dispose();
    _botReactor = _vsBot ? BotReactor(_reactions) : null;
    _game = DuelController(
      repo: widget.repo,
      engine: DuelEngine(
        decks: dealDecks(pool),
        statOf: (id, stat) => widget.repo.playerById(id)!.stat(stat),
      ),
      names: _vsBot
          ? const {Mark.x: 'Sen', Mark.o: 'Bot'}
          : const {Mark.x: 'Oyuncu 1', Mark.o: 'Oyuncu 2'},
      stats: stats,
    );
    _game!.addListener(_onChanged);
    _resultShown = false;
    _botScheduledTurn = -1;
    _maybeScheduleBot();
  }

  void _restart() {
    _botTimer?.cancel();
    _game?.removeListener(_onChanged);
    _game?.dispose();
    setState(_createGame);
  }

  void _onChanged() {
    final g = _game!;
    if (g.revealed) {
      final r = g.engine.currentRound!;
      if (r.winner == Mark.o) _botReactor?.onBotScored();
      if (r.winner == Mark.x) _botReactor?.onPlayerScored();
    }
    if (g.isOver && !_resultShown) {
      _resultShown = true;
      if (g.engine.winner != null) {
        _botReactor?.onGameEnd(botWon: g.engine.winner == Mark.o);
      }
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) _showResult();
      });
    }
    _maybeScheduleBot();
  }

  void _maybeScheduleBot() {
    if (!_botTurn || _botScheduledTurn == _game!.turnNumber) return;
    _botScheduledTurn = _game!.turnNumber;
    _botTimer?.cancel();
    _botTimer = Timer(_bot!.thinkingTime(), () {
      if (!mounted || !_botTurn) return;
      _game!.pick(_bot!.pickStat(_game!.cardOf(Mark.o)));
    });
  }

  Future<void> _showResult() async {
    final g = _game!;
    final winner = g.engine.winner;
    final title = winner == null
        ? 'Berabere!'
        : _vsBot
            ? (winner == Mark.x ? 'Kazandın!' : 'Bot kazandı')
            : '${g.nameOf(winner)} kazandı!';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(winner != null ? Icons.emoji_events : Icons.handshake,
            size: 44, color: winner != null ? markColor(winner) : AppColors.textMuted),
        title: Text(title, textAlign: TextAlign.center),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${g.points(Mark.x)}', style: displayStyle(56, color: AppColors.x)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('–', style: displayStyle(40, color: AppColors.textMuted)),
            ),
            Text('${g.points(Mark.o)}', style: displayStyle(56, color: AppColors.o)),
          ],
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

  @override
  Widget build(BuildContext context) {
    final diffLabel = difficultyLabels[widget.difficulty] ?? widget.difficulty;
    final appBar = AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      title: Text('Kart Düellosu · $diffLabel',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      actions: [if (_vsBot) ReactionButton(controller: _reactions)],
    );

    final g = _game;
    if (g == null) {
      return Scaffold(
        appBar: appBar,
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'İstatistik verisi bulunamadı.\n'
              'tools klasöründe "py istatistik_topla.py" ve "py hazirla.py" '
              'çalıştırıp uygulamayı yeniden başlat.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: Listenable.merge([g, _reactions]),
      builder: (context, _) {
        final round = g.engine.currentRound;
        final chooser = g.chooser;
        final status = g.revealed
            ? (round!.winner == null
                ? 'Berabere'
                : '${g.nameOf(round.winner!)} turu aldı')
            : _botTurn
                ? 'Bot istatistik seçiyor…'
                : '${g.nameOf(chooser)}: kartından bir istatistik seç · ${g.secondsLeft} sn';
        return Scaffold(
          appBar: appBar,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  PlayersHeader(
                    names: {Mark.x: g.nameOf(Mark.x), Mark.o: g.nameOf(Mark.o)},
                    values: {
                      Mark.x: '${g.points(Mark.x)}',
                      Mark.o: '${g.points(Mark.o)}',
                    },
                    current: chooser,
                    winner: g.engine.winner,
                    isOver: g.isOver,
                    showTimer: !g.revealed,
                    secondsLeft: g.secondsLeft,
                    turnSeconds: g.turnSeconds,
                    status: status,
                    bubbles: _reactions.bubbles,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('TUR ${g.engine.index + 1}/${g.engine.rounds}',
                          style: displayStyle(22, color: AppColors.gold)),
                      const Spacer(),
                      if (g.revealed)
                        Text(
                          '${cardStat(round!.stat).label}: '
                          '${cardStat(round.stat).format(round.x)} – '
                          '${cardStat(round.stat).format(round.o)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, color: AppColors.text),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(child: _cards(g)),
                  const SizedBox(height: 6),
                  const Text(
                    'Gol, asist, maç ve kartlar: 2012 sonrası Avrupa ligleri ve kupaları',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  _buttons(g),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _cards(DuelController g) {
    final round = g.engine.currentRound;
    // Yüzü açık kartlar: tur açıldıysa ikisi de; değilse bota karşı kendi kartın,
    // 2 kişilikte sadece seçim yapacak oyuncunun kartı
    bool faceUp(Mark m) => g.revealed || (_vsBot ? m == Mark.x : m == g.chooser);
    final canPick = !g.revealed && !_botTurn;

    return LayoutBuilder(builder: (context, c) {
      final w = min((c.maxWidth - 12) / 2, c.maxHeight / 1.62);
      Widget side(Mark m) {
        final player = g.cardOf(m);
        final won = round?.winner == m;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlipCard(
              faceUp: faceUp(m),
              front: PlayerCard(
                key: ValueKey('${player.id}-${g.engine.index}'),
                player: player,
                repo: widget.repo,
                width: w,
                stats: g.stats,
                highlightStat: round?.stat,
                glow: won ? markColor(m) : null,
                onPickStat: canPick && m == g.chooser ? g.pick : null,
              ),
              back: CardBack(width: w),
            ),
          ],
        );
      }

      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [side(Mark.x), const SizedBox(width: 12), side(Mark.o)],
      );
    });
  }

  Widget _buttons(DuelController g) {
    if (!g.revealed) {
      return SizedBox(
        height: 48,
        child: Center(
          child: Text(
            _botTurn ? '' : 'Seçmek için kartındaki bir satıra dokun',
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }
    final round = g.engine.currentRound!;
    return Row(
      children: [
        IconButton(
          tooltip: 'Bu istatistik hatalı mı?',
          icon: const Icon(Icons.flag_outlined, color: AppColors.textMuted),
          onPressed: () => showReportDialog(
            context,
            DataReport(
              mode: 'Kart Düellosu',
              player: g.cardOf(Mark.x),
              claim: '${cardStat(round.stat).label}: '
                  '${g.cardOf(Mark.x).name} ${cardStat(round.stat).format(round.x)}, '
                  '${g.cardOf(Mark.o).name} ${cardStat(round.stat).format(round.o)}',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: g.isOver ? null : g.next,
              icon: const Icon(Icons.arrow_forward),
              label: Text(g.isOver ? 'Maç bitti' : 'Sonraki Tur'),
            ),
          ),
        ),
      ],
    );
  }
}
