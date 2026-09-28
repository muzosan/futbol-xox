import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../data/text_utils.dart';
import '../game/engine/imposter_engine.dart';
import '../game/imposter_setup.dart';
import '../theme.dart';
import '../widgets/kit_icon.dart';
import '../widgets/player_card.dart' show CardBack, FlipCard, PlayerCard;
import '../widgets/player_search_sheet.dart';

const _red = Color(0xFFE5484D);

class ImposterScreen extends StatefulWidget {
  const ImposterScreen({
    super.key,
    required this.repo,
    required this.difficulty,
    required this.names,
    required this.imposterHint,
  });

  final Repository repo;
  final String difficulty;
  final List<String> names;
  final bool imposterHint;

  @override
  State<ImposterScreen> createState() => _ImposterScreenState();
}

class _ImposterScreenState extends State<ImposterScreen> {
  late final ImposterEngine _e = ImposterEngine(names: widget.names);
  final Set<String> _usedSecrets = {};
  bool _cardOpen = false; // rol kartı açık mı

  Player get _secret => widget.repo.playerById(_e.secretPlayerId)!;

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  void _newRound() {
    final p = pickImposterSecret(widget.repo, widget.difficulty, exclude: _usedSecrets);
    _usedSecrets.add(p.id);
    _e.startRound(p.id);
    _cardOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_e.phase) {
      ImposterPhase.reveal => _revealPhase(),
      ImposterPhase.clues => _cluePhase(),
      ImposterPhase.voting => _votingPhase(),
      ImposterPhase.impostorGuess => _accusedPhase(),
      ImposterPhase.result => _resultPhase(),
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Oyundan çıkılsın mı?'),
            content: const Text('Skorlar kaybolacak.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Çık')),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          title: Text('Sahtekâr · Tur ${_e.roundNumber}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: KeyedSubtree(
                key: ValueKey('${_e.phase}-${_e.revealIndex}-${_e.voterIndex}-${_e.clueRound}'),
                child: body,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ Roller
  Widget _revealPhase() {
    final i = _e.revealIndex;
    final name = _e.names[i];
    final isImpostor = i == _e.impostor;
    return Column(
      children: [
        _PhaseTitle('ROLLER', '${i + 1}/${_e.playerCount}'),
        const SizedBox(height: 8),
        Text(_cardOpen ? name.toUpperCase() : 'TELEFONU ${name.toUpperCase()} ALSIN',
            textAlign: TextAlign.center, style: displayStyle(30)),
        Text(
          _cardOpen
              ? 'Kimseye gösterme!'
              : 'Diğerleri bakmasın. Hazır olunca karta dokun.',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final w = (c.maxHeight / 1.62).clamp(0.0, c.maxWidth * 0.8).toDouble();
            return GestureDetector(
              onTap: _cardOpen ? null : () => setState(() => _cardOpen = true),
              child: Center(
                child: FlipCard(
                  faceUp: _cardOpen,
                  front: isImpostor
                      ? _ImpostorCard(
                          width: w,
                          hint: widget.imposterHint ? imposterHint(widget.repo, _secret) : null)
                      : _SecretCard(player: _secret, repo: widget.repo, width: w),
                  back: CardBack(width: w),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton.icon(
            onPressed: _cardOpen
                ? () => setState(() {
                      _cardOpen = false;
                      _e.nextReveal();
                    })
                : () => setState(() => _cardOpen = true),
            icon: Icon(_cardOpen ? Icons.visibility_off : Icons.touch_app),
            label: Text(_cardOpen
                ? (i + 1 < _e.playerCount
                    ? 'GÖRDÜM · SIRADAKİ: ${_e.names[i + 1].toUpperCase()}'
                    : 'GÖRDÜM · İPUÇLARINA GEÇ')
                : 'KARTIMI GÖSTER'),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ İpuçları
  Widget _cluePhase() {
    final speaker = _e.currentSpeaker;
    return Column(
      children: [
        _PhaseTitle('İPUCU TURU', '${_e.clueRound + 1}/${_e.clueRounds}'),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: AppDecor.card(accent: AppColors.primary, active: true),
          child: Column(
            children: [
              const Icon(Icons.record_voice_over, color: AppColors.primary, size: 36),
              const SizedBox(height: 6),
              Text(_e.names[speaker].toUpperCase(), style: displayStyle(36)),
              const SizedBox(height: 4),
              const Text('Futbolcuyla ilgili TEK KELİMELİK bir ipucu söyle',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              for (var k = 0; k < _e.playerCount; k++)
                _OrderRow(
                  name: _e.names[_e.order[k]],
                  done: k < _e.clueIndex,
                  active: k == _e.clueIndex,
                ),
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton.icon(
            onPressed: () => setState(_e.nextClue),
            icon: const Icon(Icons.check),
            label: const Text('SÖYLEDİ'),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ Oylama
  Widget _votingPhase() {
    final voter = _e.voterIndex;
    return Column(
      children: [
        _PhaseTitle('GİZLİ OYLAMA', '${voter + 1}/${_e.playerCount}'),
        const SizedBox(height: 8),
        Text('TELEFON ${_e.names[voter].toUpperCase()}\'DA',
            textAlign: TextAlign.center, style: displayStyle(30)),
        const Text('Sence sahtekâr kim? Kimse görmesin.',
            style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: [
              for (var t = 0; t < _e.playerCount; t++)
                if (t != voter)
                  Material(
                    color: Colors.transparent,
                    child: Ink(
                      decoration: AppDecor.card(accent: _red, radius: 14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _confirmVote(t),
                        child: Center(
                          child: Text(_e.names[t].toUpperCase(),
                              textAlign: TextAlign.center,
                              style: displayStyle(22)),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmVote(int target) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('${_e.names[target]} mı?'),
        content: const Text('Oyun geri alınamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Değiştir')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oyla')),
        ],
      ),
    );
    if (ok == true) setState(() => _e.vote(target));
  }

  // ------------------------------------------------------------------ Suçlanan sahtekâr
  Widget _accusedPhase() {
    final imp = _e.names[_e.impostor];
    return Column(
      children: [
        const _PhaseTitle('SONUÇ', ''),
        const SizedBox(height: 12),
        _TallyList(engine: _e),
        const Spacer(),
        const Icon(Icons.gpp_bad, color: _red, size: 64),
        Text('${imp.toUpperCase()} SAHTEKÂRDI!', textAlign: TextAlign.center,
            style: displayStyle(38, color: _red)),
        const SizedBox(height: 8),
        Text('$imp, son şansın: futbolcuyu doğru tahmin edersen kurtulursun!',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted)),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white),
            onPressed: _impostorGuess,
            icon: const Icon(Icons.search),
            label: const Text('FUTBOLCUYU TAHMİN ET'),
          ),
        ),
      ],
    );
  }

  Future<void> _impostorGuess() async {
    final p = await showModalBottomSheet<Player>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PlayerSearchSheet(
        repo: widget.repo,
        title: 'Gizli futbolcu kim?',
        hint: 'Tek tahmin hakkın var',
        usedIds: const <String>{},
      ),
    );
    if (p == null || !mounted) return;
    setState(() => _e.impostorGuess(p.id));
  }

  // ------------------------------------------------------------------ Tur sonucu
  Widget _resultPhase() {
    final imp = _e.names[_e.impostor];
    final String headline;
    final Color color;
    if (_e.accused != _e.impostor) {
      headline = 'SAHTEKÂR KAÇTI!';
      color = _red;
    } else if (_e.impostorGuessedRight == true) {
      headline = 'SAHTEKÂR KURTULDU!';
      color = _red;
    } else {
      headline = 'SAHTEKÂR YAKALANDI!';
      color = AppColors.primary;
    }
    final detail = _e.accused == null
        ? 'Oylar eşit çıktı, kimse suçlanmadı. Sahtekâr: $imp'
        : _e.accused != _e.impostor
            ? '${_e.names[_e.accused!]} masumdu. Sahtekâr: $imp'
            : _e.impostorGuessedRight == true
                ? '$imp futbolcuyu doğru tahmin etti.'
                : '$imp futbolcuyu bilemedi.';

    return Column(
      children: [
        Text(headline, textAlign: TextAlign.center, style: displayStyle(40, color: color)),
        Text(detail, textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              Center(child: _SecretCard(player: _secret, repo: widget.repo, width: 170)),
              const SizedBox(height: 16),
              Text('SKOR TABLOSU', textAlign: TextAlign.center,
                  style: displayStyle(22, color: AppColors.gold)),
              const SizedBox(height: 8),
              ..._scoreRows(),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                child: const Text('Bitir'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: () => setState(_newRound),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                icon: const Icon(Icons.refresh),
                label: const Text('YENİ TUR'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _scoreRows() {
    final idx = List.generate(_e.playerCount, (i) => i)
      ..sort((a, b) => _e.scores[b].compareTo(_e.scores[a]));
    return [
      for (var r = 0; r < idx.length; r++)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: AppDecor.card(
              radius: 12, raised: false, accent: r == 0 ? AppColors.gold : null, active: r == 0),
          child: Row(
            children: [
              Text('${r + 1}.', style: displayStyle(20, color: AppColors.textMuted)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_e.names[idx[r]],
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              if (idx[r] == _e.impostor)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.theater_comedy, color: _red, size: 18),
                ),
              Text('${_e.scores[idx[r]]}', style: displayStyle(24, color: AppColors.gold)),
            ],
          ),
        ),
    ];
  }
}

// ==================================================================== Parçalar

class _PhaseTitle extends StatelessWidget {
  const _PhaseTitle(this.title, this.progress);

  final String title;
  final String progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: displayStyle(24, color: AppColors.gold)),
        const Spacer(),
        if (progress.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(progress,
                style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary)),
          ),
      ],
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.name, required this.done, required this.active});

  final String name;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: AppDecor.card(
          radius: 12, raised: false, accent: active ? AppColors.primary : null, active: active),
      child: Row(
        children: [
          Icon(done ? Icons.check_circle : (active ? Icons.mic : Icons.circle_outlined),
              size: 20,
              color: done || active ? AppColors.primary : AppColors.textMuted),
          const SizedBox(width: 10),
          Text(name,
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: done ? AppColors.textMuted : AppColors.text)),
        ],
      ),
    );
  }
}

class _TallyList extends StatelessWidget {
  const _TallyList({required this.engine});

  final ImposterEngine engine;

  @override
  Widget build(BuildContext context) {
    final t = engine.tally;
    final entries = t.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final e in entries)
          Chip(
            label: Text('${engine.names[e.key]} · ${e.value} oy',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
      ],
    );
  }
}

/// Gizli futbolcunun kartı (herkesin gördüğü)
class _SecretCard extends StatelessWidget {
  const _SecretCard({required this.player, required this.repo, required this.width});

  final Player player;
  final Repository repo;
  final double width;

  @override
  Widget build(BuildContext context) {
    final w = width;
    final club = repo.mainClub(player);
    final nat = player.nationality;
    return Container(
      width: w,
      height: PlayerCard.heightFor(w),
      padding: EdgeInsets.all(w * 0.07),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(w * 0.09),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B3A2E), Color(0xFF0B1A14), Color(0xFF050C09)],
        ),
        border: Border.all(color: AppColors.primary, width: 2),
        boxShadow: [...AppShadows.card, ...AppShadows.glow(AppColors.primary, 0.35)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('GİZLİ FUTBOLCU',
              style: TextStyle(
                  fontSize: w * 0.06,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary)),
          SizedBox(height: w * 0.06),
          if (club != null) KitIcon(club: club, size: w * 0.42),
          SizedBox(height: w * 0.06),
          Text(player.name.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 2,
              style: displayStyle(w * 0.15)),
          SizedBox(height: w * 0.03),
          Text(
            [
              if (nat != null) '${flagEmoji(nat)} ${repo.countryName(nat)}',
              if (player.positions.isNotEmpty) player.positions.first,
            ].join(' · '),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: w * 0.065, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Sahtekârın kartı
class _ImpostorCard extends StatelessWidget {
  const _ImpostorCard({required this.width, this.hint});

  final double width;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final w = width;
    return Container(
      width: w,
      height: PlayerCard.heightFor(w),
      padding: EdgeInsets.all(w * 0.08),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(w * 0.09),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A0F14), Color(0xFF1E0508), Color(0xFF0A0203)],
        ),
        border: Border.all(color: _red, width: 2),
        boxShadow: [...AppShadows.card, ...AppShadows.glow(_red, 0.45)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.theater_comedy, color: _red, size: w * 0.35),
          SizedBox(height: w * 0.05),
          Text('SAHTEKÂRSIN', style: displayStyle(w * 0.16, color: _red)),
          SizedBox(height: w * 0.04),
          Text('Futbolcuyu bilmiyorsun. Diğerlerini dinle, belli etme!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: w * 0.065, color: AppColors.textMuted)),
          if (hint != null) ...[
            SizedBox(height: w * 0.06),
            Container(
              padding: EdgeInsets.all(w * 0.04),
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _red.withValues(alpha: 0.5)),
              ),
              child: Text('İPUCU: $hint',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: w * 0.06, fontWeight: FontWeight.w900, color: AppColors.text)),
            ),
          ],
        ],
      ),
    );
  }
}
