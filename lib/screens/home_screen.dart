import 'package:flutter/material.dart';

import '../data/records.dart';
import '../data/repository.dart';
import '../game/ai_player.dart';
import '../report/report.dart';
import '../theme.dart';
import 'chain_screen.dart';
import 'draft_screen.dart';
import 'duel_screen.dart';
import 'game_screen.dart';
import 'hunt_screen.dart';
import 'imposter_setup_screen.dart';
import 'quiz_screen.dart';
import 'who_screen.dart';
import '../l10n/l10n.dart';

enum GameMode { xox, duel, draft, imposter, hunt, chain, quiz, who }

class _ModeInfo {
  const _ModeInfo(this.id, this.icon, {this.solo = false, this.party = false});

  final String id;
  final IconData icon;

  /// Tek kişilik mod (bot veya 2 kişilik seçimi yok)
  final bool solo;

  /// Kalabalık grup modu (3-8 kişi, tek telefon)
  final bool party;

  // Metinler her seferinde geçerli dilde okunur
  String get title => t('mode.$id.title');
  String get description => t('mode.$id.desc');
  List<String> get levelTexts =>
      [t('mode.$id.l1'), t('mode.$id.l2'), t('mode.$id.l3')];
}

const Map<GameMode, _ModeInfo> _modes = {
  GameMode.xox: _ModeInfo('xox', Icons.grid_3x3),
  GameMode.duel: _ModeInfo('duel', Icons.style),
  GameMode.draft: _ModeInfo('draft', Icons.groups),
  GameMode.imposter: _ModeInfo('imposter', Icons.theater_comedy, party: true),
  GameMode.hunt: _ModeInfo('hunt', Icons.hub_outlined),
  GameMode.chain: _ModeInfo('chain', Icons.link),
  GameMode.quiz: _ModeInfo('quiz', Icons.bolt, solo: true),
  GameMode.who: _ModeInfo('who', Icons.person_search, solo: true),
};

/// Tek kişilik modların rekor anahtarları
String? _recordKey(GameMode mode, String difficulty) => switch (mode) {
      GameMode.quiz => QuizScreen.recordKey(difficulty),
      GameMode.who => WhoScreen.recordKey(difficulty),
      _ => null,
    };

class _Level {
  const _Level(this.key, this.color, this.icon, this.bot);

  final String key;
  final Color color;
  final IconData icon;
  final BotLevel bot;

  String get title => t('diff.$key');
  String get botText => t('bot.$key');
}

const List<_Level> _levels = [
  _Level('kolay', AppColors.primary, Icons.sentiment_satisfied_alt, BotLevel.easy),
  _Level('orta', AppColors.amber, Icons.local_fire_department_outlined, BotLevel.medium),
  _Level('zor', AppColors.o, Icons.psychology_outlined, BotLevel.hard),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<Repository> _repoFuture = Repository.load();
  bool _vsBot = true;
  GameMode _mode = GameMode.xox;
  Map<String, int> _records = {};

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final records = <String, int>{};
    for (final mode in GameMode.values) {
      for (final level in _levels) {
        final key = _recordKey(mode, level.key);
        if (key != null) records[key] = await Records.best(key);
      }
    }
    if (mounted) setState(() => _records = records);
  }

  Future<void> _start(Repository repo, _Level level) async {
    final bot = _vsBot ? level.bot : null;
    final Widget screen = switch (_mode) {
      GameMode.xox =>
        GameScreen(repo: repo, difficulty: level.key, botLevel: bot),
      GameMode.duel =>
        DuelScreen(repo: repo, difficulty: level.key, botLevel: bot),
      GameMode.draft =>
        DraftScreen(repo: repo, difficulty: level.key, botLevel: bot),
      GameMode.imposter =>
        ImposterSetupScreen(repo: repo, difficulty: level.key),
      GameMode.hunt =>
        HuntScreen(repo: repo, difficulty: level.key, botLevel: bot),
      GameMode.chain =>
        ChainScreen(repo: repo, difficulty: level.key, botLevel: bot),
      GameMode.quiz => QuizScreen(repo: repo, difficulty: level.key),
      GameMode.who => WhoScreen(repo: repo, difficulty: level.key),
    };
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _loadRecords(); // yeni rekor olmuş olabilir
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: KeyedSubtree(
          child: FutureBuilder<Repository>(
            future: _repoFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(t('home.load_error', {'e': snapshot.error}),
                        textAlign: TextAlign.center),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Hero(),
                      SizedBox(height: 36),
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                            strokeWidth: 3, color: AppColors.gold),
                      ),
                      SizedBox(height: 14),
                      Text(t('home.loading'),
                          style: TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                );
              }
              return _buildMenu(snapshot.data!);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMenu(Repository repo) {
    final info = _modes[_mode]!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: AlignmentDirectional.centerEnd,
                child: _LangButton(),
              ),
              const _Hero(),
              const SizedBox(height: 24),
              // Mod seçimi
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.4,
                children: [
                  for (final mode in GameMode.values)
                    _ModeCard(
                      info: _modes[mode]!,
                      selected: _mode == mode,
                      onTap: () => setState(() => _mode = mode),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 64,
                child: Text(
                  info.description,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: AppColors.textMuted, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
              if (info.party) ...[
                Text(
                  t('home.party'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.text),
                ),
                const SizedBox(height: 20),
              ] else if (!info.solo) ...[
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: true,
                      label: Text(t('common.vs_bot')),
                      icon: Icon(Icons.smart_toy_outlined),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text(t('common.two_players')),
                      icon: Icon(Icons.people_outline),
                    ),
                  ],
                  selected: {_vsBot},
                  onSelectionChanged: (s) => setState(() => _vsBot = s.first),
                ),
                const SizedBox(height: 20),
              ] else ...[
                Text(
                  t('home.solo'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.text),
                ),
                const SizedBox(height: 20),
              ],
              for (var i = 0; i < _levels.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _LevelTile(
                    level: _levels[i],
                    subtitle: [
                      info.levelTexts[i],
                      if (info.solo)
                        t('common.record', {'n': _records[_recordKey(_mode, _levels[i].key)] ?? 0})
                      else if (_vsBot && !info.party)
                        _levels[i].botText,
                    ].join(' · '),
                    onTap: () => _start(repo, _levels[i]),
                  ),
                ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => showReportDialog(
                    context, DataReport(mode: t('home.report_mode'))),
                icon: const Icon(Icons.flag_outlined, size: 16),
                label: Text(t('home.report')),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              Text(
                'MUON STUDIO',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.gold.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.info,
    required this.selected,
    required this.onTap,
  });

  final _ModeInfo info;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final color = selected ? AppColors.primary : AppColors.textMuted;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: AppDecor.card(
          radius: 16,
          accent: selected ? AppColors.primary : null,
          active: selected,
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(info.icon, color: color, size: 28,
                    shadows: selected ? AppShadows.glow(AppColors.primary, 0.8)
                        .map((b) => Shadow(color: b.color, blurRadius: b.blurRadius))
                        .toList() : null),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    info.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: selected ? AppColors.text : AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.subtitle,
    required this.onTap,
  });

  final _Level level;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: AppDecor.card(accent: level.color),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        level.color.withValues(alpha: 0.35),
                        level.color.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: level.color.withValues(alpha: 0.5)),
                    boxShadow: AppShadows.glow(level.color, 0.25),
                  ),
                  child: Icon(level.icon, color: level.color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        upper(level.title),
                        style: const TextStyle(
                          letterSpacing: 1.2,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: level.color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo, altın başlık ve slogan; açılışta yumuşakça belirir.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: child),
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [AppColors.surfaceHigh, AppColors.background],
              ),
              border: Border.all(color: AppColors.gold, width: 2.5),
              boxShadow: [
                ...AppShadows.glow(AppColors.gold, 0.35),
                ...AppShadows.card,
              ],
            ),
            child: const Icon(Icons.sports_soccer, size: 56, color: AppColors.text),
          ),
          const SizedBox(height: 18),
          const GoldText('VOLEA', size: 72, spacing: 8),
          const SizedBox(height: 8),
          Text(
            t('home.tagline'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 3.5,
              fontWeight: FontWeight.w900,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sağ üstteki dil seçme butonu (bayrak + dil kodu)
class _LangButton extends StatelessWidget {
  const _LangButton();

  @override
  Widget build(BuildContext context) {
    final lang = L10n.instance.lang;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _open(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: AppDecor.card(radius: 20, raised: false),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(lang.flag, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(lang.code.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
              const Icon(Icons.expand_more, size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(upper(t('home.language')),
                  style: displayStyle(24, color: AppColors.gold)),
              const SizedBox(height: 8),
              for (final l in kLangs)
                ListTile(
                  leading: Text(l.flag, style: const TextStyle(fontSize: 26)),
                  title: Text(l.nativeName),
                  trailing: l.code == currentLang
                      ? const Icon(Icons.check_circle, color: AppColors.primary)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    L10n.instance.setLang(l.code);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
