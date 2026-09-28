import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/records.dart';
import '../data/repository.dart';
import '../game/who_controller.dart';
import '../report/report.dart';
import '../theme.dart';
import '../widgets/player_search_sheet.dart';
import 'game_screen.dart' show difficultyLabels;

class WhoScreen extends StatefulWidget {
  const WhoScreen({super.key, required this.repo, required this.difficulty});

  final Repository repo;
  final String difficulty;

  static String recordKey(String difficulty) => 'who_$difficulty';

  @override
  State<WhoScreen> createState() => _WhoScreenState();
}

class _WhoScreenState extends State<WhoScreen> {
  WhoController? _game;

  @override
  void initState() {
    super.initState();
    _createGame();
  }

  @override
  void dispose() {
    _game?.dispose();
    super.dispose();
  }

  void _createGame() {
    final questions = pickWhoQuestions(widget.repo, widget.difficulty);
    _game = questions.isEmpty
        ? null
        : WhoController(
            repo: widget.repo,
            engine: WhoEngine(
              questions: questions,
              startRevealed: whoStartRevealed(widget.difficulty),
            ),
          );
  }

  void _restart() {
    _game?.dispose();
    setState(_createGame);
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

  Future<void> _openGuess() async {
    final game = _game!;
    final player = await showModalBottomSheet<Player>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PlayerSearchSheet(
        repo: widget.repo,
        title: 'Bu kariyer kimin?',
        hint: 'Tahmin ettiğin futbolcunun adını yaz',
        usedIds: const <String>{},
      ),
    );
    if (player == null || !mounted) return;
    final correct = game.guess(player);
    if (correct) {
      _toast('Doğru! +${game.engine.lastResult!.points} puan',
          color: AppColors.success);
    } else if (game.engine.resolved) {
      _toast('Tahmin hakkın bitti.', color: AppColors.danger);
    } else {
      final left = game.engine.maxWrong - game.engine.wrongGuesses;
      _toast('Yanlış, ${player.name} değil. $left tahmin hakkın kaldı.',
          color: AppColors.danger);
    }
  }

  Future<void> _showFinal() async {
    final game = _game!;
    final key = WhoScreen.recordKey(widget.difficulty);
    final score = game.engine.score;
    final oldBest = await Records.best(key);
    final isRecord = await Records.submit(key, score);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(
          isRecord ? Icons.emoji_events : Icons.person_search,
          size: 40,
          color: isRecord ? AppColors.amber : AppColors.primary,
        ),
        title: Text(isRecord ? 'Yeni rekor!' : 'Oyun bitti'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GoldText('$score', size: 72, spacing: 1),
            Text(
              '${game.engine.totalQuestions * game.engine.maxPoints} puan üzerinden',
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            for (final r in game.engine.results)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(r.solved ? Icons.check_circle : Icons.cancel,
                        size: 18,
                        color:
                            r.solved ? AppColors.primary : AppColors.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.repo.playerById(r.playerId)?.name ?? '',
                        style: const TextStyle(color: AppColors.text),
                      ),
                    ),
                    Text('+${r.points}',
                        style: const TextStyle(color: AppColors.textMuted)),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Text('Rekor: ${isRecord ? score : oldBest}',
                style: const TextStyle(color: AppColors.text)),
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
            child: const Text('Tekrar Oyna'),
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
      title: Text('Kim Bu? · $diffLabel',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
    );

    final game = _game;
    if (game == null) {
      return Scaffold(
        appBar: appBar,
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Kariyer verisi bulunamadı.\n'
              'tools klasöründe "py kariyer_hazirla.py" çalıştırıp '
              'uygulamayı yeniden başlat.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final e = game.engine;
        return Scaffold(
          appBar: appBar,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  _TopBar(engine: e),
                  const SizedBox(height: 14),
                  Expanded(child: _CareerCard(game: game)),
                  const SizedBox(height: 12),
                  if (e.resolved) _AnswerBanner(game: game),
                  if (e.resolved) const SizedBox(height: 12),
                  _buildButtons(game),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildButtons(WhoController game) {
    final e = game.engine;
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

    if (e.resolved) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: e.isOver ? _showFinal : game.nextQuestion,
          icon: Icon(e.isOver ? Icons.flag : Icons.arrow_forward),
          label: Text(e.isOver ? 'Sonuçlar' : 'Sonraki Soru'),
          style: FilledButton.styleFrom(shape: shape),
        ),
      );
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: e.canReveal ? game.reveal : null,
                icon: const Icon(Icons.lock_open),
                label: Text('İpucu (−${e.clueCost})'),
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
                onPressed: _openGuess,
                icon: const Icon(Icons.search),
                label: const Text('Tahmin Et'),
                style: FilledButton.styleFrom(
                  shape: shape,
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: game.giveUp,
          child: const Text('Pes et, cevabı göster',
              style: TextStyle(color: AppColors.textMuted)),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.engine});

  final WhoEngine engine;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Soru ${engine.index + 1}/${engine.totalQuestions}',
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 12),
        Text('Toplam: ${engine.score}',
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.text)),
        const Spacer(),
        if (!engine.resolved)
          Text(
            'Bu soru: ${engine.potentialPoints} puan · '
            'Hak: ${engine.maxWrong - engine.wrongGuesses}',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
      ],
    );
  }
}

/// Kariyer zaman çizelgesi: açılan duraklar ve kilitli olanlar.
class _CareerCard extends StatelessWidget {
  const _CareerCard({required this.game});

  final WhoController game;

  @override
  Widget build(BuildContext context) {
    final e = game.engine;
    final q = e.current;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('KARİYER',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted)),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: [
                for (var i = 0; i < q.steps.length; i++)
                  _StepRow(
                    step: q.steps[i],
                    open: i < e.revealed,
                    isLast: i == q.steps.length - 1 && q.birthYear == null,
                  ),
                if (q.birthYear != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.cake_outlined,
                            size: 18, color: AppColors.textMuted),
                        const SizedBox(width: 10),
                        Text(
                          e.birthYearRevealed
                              ? 'Doğum yılı: ${q.birthYear}'
                              : 'Doğum yılı: ????',
                          style: TextStyle(
                            color: e.birthYearRevealed
                                ? AppColors.text
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.open, required this.isLast});

  final CareerStep step;
  final bool open;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 52,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                open ? (step.year?.toString() ?? '—') : '····',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: open ? AppColors.primary : AppColors.border,
                ),
              ),
            ),
          ),
          // Zaman çizgisi
          SizedBox(
            width: 20,
            child: Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: open ? AppColors.primary : AppColors.surfaceHigh,
                    border: Border.all(
                        color: open ? AppColors.primary : AppColors.border,
                        width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: AppColors.border),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: open ? AppColors.surfaceHigh : AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      open ? step.club : 'Gizli kulüp',
                      style: TextStyle(
                        fontWeight: open ? FontWeight.w800 : FontWeight.w600,
                        color: open ? AppColors.text : AppColors.textMuted,
                      ),
                    ),
                  ),
                  if (!open)
                    const Icon(Icons.lock, size: 16, color: AppColors.border),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soru bitince cevabı gösteren şerit.
class _AnswerBanner extends StatelessWidget {
  const _AnswerBanner({required this.game});

  final WhoController game;

  @override
  Widget build(BuildContext context) {
    final result = game.engine.lastResult!;
    final player = game.answerPlayer();
    final color = result.solved ? AppColors.primary : AppColors.danger;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(result.solved ? Icons.check_circle : Icons.info_outline,
              color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              result.solved
                  ? '${player.name} · +${result.points} puan'
                  : 'Cevap: ${player.name}',
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppColors.text),
            ),
          ),
          IconButton(
            tooltip: 'Kariyer bilgisi hatalı mı?',
            icon: const Icon(Icons.flag_outlined, color: AppColors.textMuted),
            onPressed: () => showReportDialog(
              context,
              DataReport(
                mode: 'Kim Bu?',
                player: player,
                claim: 'Kariyer: ' +
                    game.engine.current.steps
                        .map((st) => '${st.club}${st.year != null ? ' (${st.year})' : ''}')
                        .join(' → '),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
