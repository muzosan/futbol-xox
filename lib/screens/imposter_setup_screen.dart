import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../theme.dart';
import 'game_screen.dart' show difficultyLabels;
import 'imposter_screen.dart';
import '../l10n/l10n.dart';

/// Sahtekâr kurulumu: oyuncu isimleri ve sahtekâra ipucu ayarı
class ImposterSetupScreen extends StatefulWidget {
  const ImposterSetupScreen({super.key, required this.repo, required this.difficulty});

  final Repository repo;
  final String difficulty;

  @override
  State<ImposterSetupScreen> createState() => _ImposterSetupScreenState();
}

class _ImposterSetupScreenState extends State<ImposterSetupScreen> {
  static const _min = 3, _max = 8;
  final List<TextEditingController> _names = [];
  late bool _hint = widget.difficulty == 'kolay';

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 4; i++) {
      _add();
    }
  }

  @override
  void dispose() {
    for (final c in _names) {
      c.dispose();
    }
    super.dispose();
  }

  void _add() => _names.add(TextEditingController());

  List<String> get _finalNames => [
        for (var i = 0; i < _names.length; i++)
          _names[i].text.trim().isEmpty ? t('common.player_n', {'n': i + 1}) : _names[i].text.trim(),
      ];

  void _start() {
    final names = _finalNames;
    if (names.toSet().length != names.length) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t('imp.names_unique')),
      ));
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ImposterScreen(
          repo: widget.repo,
          difficulty: widget.difficulty,
          names: names,
          imposterHint: _hint,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final diffLabel = difficultyLabels[widget.difficulty] ?? widget.difficulty;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(t('imp.title', {'diff': diffLabel}),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Center(child: Text(t('imp.players'), style: displayStyle(34, color: AppColors.gold))),
            const SizedBox(height: 4),
            Text(
              t('imp.seating'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < _names.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  decoration: AppDecor.card(radius: 14),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text('${i + 1}',
                            style: displayStyle(26, color: AppColors.primary)),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _names[i],
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                          decoration: InputDecoration(
                            hintText: t('common.player_n', {'n': i + 1}),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      if (_names.length > _min)
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textMuted),
                          onPressed: () => setState(() => _names.removeAt(i).dispose()),
                        ),
                    ],
                  ),
                ),
              ),
            if (_names.length < _max)
              OutlinedButton.icon(
                onPressed: () => setState(_add),
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(t('imp.add_player')),
              ),
            const SizedBox(height: 16),
            Container(
              decoration: AppDecor.card(radius: 14),
              child: SwitchListTile(
                value: _hint,
                onChanged: (v) => setState(() => _hint = v),
                title: Text(t('imp.hint_toggle')),
                subtitle: Text(t('imp.hint_desc')),
              ),
            ),
            const SizedBox(height: 16),
            _rules(),
            const SizedBox(height: 20),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(t('imp.start', {'n': _names.length})),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rules() {
    const style = TextStyle(color: AppColors.textMuted, height: 1.5);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecor.card(radius: 14, raised: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('imp.how'), style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          SizedBox(height: 6),
          Text(t('imp.rule1'), style: style),
          Text(t('imp.rule2'), style: style),
          Text(t('imp.rule3'), style: style),
        ],
      ),
    );
  }
}
