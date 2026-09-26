import 'dart:async';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../game/ai_player.dart';
import '../game/game_controller.dart';
import '../theme.dart';
import '../widgets/board.dart';
import '../widgets/player_search_sheet.dart';

const Map<String, String> difficultyLabels = {
  'kolay': 'Kolay',
  'orta': 'Orta',
  'zor': 'Zor',
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
    _bot = widget.botLevel == null ? null : Bot(widget.botLevel!, widget.repo);
    _game = GameController(
      grid: widget.repo.randomGrid(widget.difficulty),
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
      _toast('Bot pas geçti. Sıra sende!');
      return;
    }
    final cell = move.cell!;
    final player = move.player!;
    final result = _game.guess(cell, player);
    if (result == GuessResult.correct) {
      _toast('Bot: ${player.name}', color: AppColors.o.withValues(alpha: 0.9));
    } else if (result == GuessResult.wrong) {
      final row = widget.repo.club(_game.rowClubId(cell)).name;
      final col = widget.repo.club(_game.colClubId(cell)).name;
      _toast('Bot yanıldı: ${player.name} ($row × $col). Sıra sende!');
    }
  }

  // ---------- Oyuncu hamlesi ----------

  void _onTimeout(Mark who) {
    if (!mounted || _game.isOver) return;
    _toast('Süre doldu! Sıra: ${_game.nameOf(who.other)}');
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
        rowClub: rowClub,
        colClub: colClub,
        usedIds: _game.usedPlayerIds,
      ),
    );
    _sheetOpen = false;
    if (player == null || !mounted) return;

    final result = _game.guess(cell, player);
    switch (result) {
      case GuessResult.correct:
        _toast('Doğru! ${player.name}', color: AppColors.success);
      case GuessResult.wrong:
        _toast(
          'Yanlış! ${player.name}, ${rowClub.name} ve ${colClub.name} '
          'kulüplerinin ikisinde birden oynamamış.',
          color: AppColors.danger,
        );
      case GuessResult.alreadyUsed:
        _toast('Bu oyuncu bu maçta zaten kullanıldı.');
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
    if (winner != null) {
      if (_vsBot) {
        title = winner == Mark.x ? 'Kazandın!' : 'Bot kazandı';
        message = winner == Mark.x
            ? 'Üç hücreyi yan yana dizdin.'
            : 'Bu sefer bot daha iyi bildi. Rövanş?';
      } else {
        title = '${_game.nameOf(winner)} kazandı!';
        message = 'Üç hücreyi yan yana dizdi.';
      }
    } else if (_game.endReason == EndReason.stalemate) {
      title = 'Berabere';
      message = 'Üst üste ${GameController.maxTurnsWithoutProgress} tur '
          'kimse doğru cevap veremedi.';
    } else {
      title = 'Berabere';
      message = 'Tablo doldu ama kimse üçlü yapamadı.';
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
          '$message\n\nBoş kalan hücrelerde örnek cevapları görebilirsin.',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tabloyu Gör'),
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
    final diffLabel =
        difficultyLabels[widget.difficulty] ?? widget.difficulty;

    return ListenableBuilder(
      listenable: _game,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
            title: Text(
              '$modeLabel · $diffLabel',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  TurnBar(game: _game, botThinking: _botTurn),
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
                            label: Text(_vsBot ? 'Rövanş' : 'Yeni Oyun'),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: _botTurn ? null : _game.pass,
                            icon: const Icon(Icons.skip_next),
                            label: const Text('Pas Geç'),
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
