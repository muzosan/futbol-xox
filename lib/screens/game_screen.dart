import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../game/game_controller.dart';
import '../widgets/board.dart';
import '../widgets/player_search_sheet.dart';

const Map<String, String> difficultyLabels = {
  'kolay': 'Kolay',
  'orta': 'Orta',
  'zor': 'Zor',
};

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.repo, required this.difficulty});

  final Repository repo;
  final String difficulty;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController _game;
  bool _sheetOpen = false;
  int _sheetTurn = -1;
  bool _resultShown = false;

  @override
  void initState() {
    super.initState();
    _createGame();
  }

  @override
  void dispose() {
    _game.removeListener(_onGameChanged);
    _game.dispose();
    super.dispose();
  }

  void _createGame() {
    _game = GameController(
      grid: widget.repo.randomGrid(widget.difficulty),
      onTimeout: _onTimeout,
    );
    _game.addListener(_onGameChanged);
    _resultShown = false;
  }

  void _restart() {
    _game.removeListener(_onGameChanged);
    _game.dispose();
    setState(_createGame);
  }

  void _onGameChanged() {
    // Arama paneli açıkken süre dolarsa paneli kapat
    if (_sheetOpen && (_game.turnNumber != _sheetTurn || _game.isOver)) {
      _sheetOpen = false;
      Navigator.of(context).pop();
    }
    if (_game.isOver && !_resultShown) {
      _resultShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showResult());
    }
  }

  void _onTimeout(Mark who) {
    if (!mounted || _game.isOver) return;
    _toast('Süre doldu! Sıra ${who.other.playerName}\'de.');
  }

  void _toast(String message, {Color? color}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
  }

  Future<void> _onCellTap(int cell) async {
    if (_game.isOver || _game.cells[cell] != null || _sheetOpen) return;

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
        _toast('Doğru! ${player.name}', color: Colors.green.shade700);
      case GuessResult.wrong:
        _toast(
          'Yanlış! ${player.name}, ${rowClub.name} ve ${colClub.name} '
          'kulüplerinin ikisinde birden oynamamış.',
          color: Colors.red.shade700,
        );
      case GuessResult.alreadyUsed:
        _toast('Bu oyuncu bu maçta zaten kullanıldı.');
      case GuessResult.invalid:
        break;
    }
  }

  Future<void> _showResult() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final String title;
    final String message;
    if (_game.winner != null) {
      title = '${_game.winner!.playerName} kazandı!';
      message = 'Üç hücreyi yan yana dizdi.';
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
        title: Text(title),
        content: Text('$message\n\nBoş kalan hücrelerde örnek cevapları '
            'görebilirsin.'),
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
            child: const Text('Yeni Oyun'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _game,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Futbol XOX'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Chip(
                  label: Text(difficultyLabels[widget.difficulty] ??
                      widget.difficulty),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TurnBar(game: _game),
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
                    child: _game.isOver
                        ? FilledButton.icon(
                            onPressed: _restart,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Yeni Oyun'),
                          )
                        : OutlinedButton.icon(
                            onPressed: _game.pass,
                            icon: const Icon(Icons.skip_next),
                            label: const Text('Pas Geç'),
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
