import 'dart:math';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../theme.dart';

/// Oyuncu arama paneli. Seçilen oyuncuyla kapanır (Navigator.pop ile döner).
/// Not: Liste cevabı ele vermez; aranan isimle eşleşen herkesi gösterir.
class PlayerSearchSheet extends StatefulWidget {
  const PlayerSearchSheet({
    super.key,
    required this.repo,
    required this.rowClub,
    required this.colClub,
    required this.usedIds,
  });

  final Repository repo;
  final Club rowClub;
  final Club colClub;
  final Set<String> usedIds;

  @override
  State<PlayerSearchSheet> createState() => _PlayerSearchSheetState();
}

class _PlayerSearchSheetState extends State<PlayerSearchSheet> {
  final _controller = TextEditingController();
  List<Player> _results = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    setState(() => _results = widget.repo.search(query));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final height = max(220.0,
        min(media.size.height * 0.6, media.size.height - keyboard - 80));

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(child: _ClubName(widget.rowClub.name)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('×',
                        style: TextStyle(
                            fontSize: 20, color: AppColors.textMuted)),
                  ),
                  Flexible(child: _ClubName(widget.colClub.name)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: AppColors.text),
                decoration: InputDecoration(
                  hintText: 'Oyuncu ara...',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _controller.text.trim().length < 2
                              ? 'İki kulüpte de oynamış bir futbolcu yaz'
                              : 'Oyuncu bulunamadı',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, i) {
                        final p = _results[i];
                        final used = widget.usedIds.contains(p.id);
                        final details = [
                          if (p.birthYear != null) 'd. ${p.birthYear}',
                          if (used) 'Bu maçta kullanıldı',
                        ].join(' · ');
                        return ListTile(
                          enabled: !used,
                          leading: const Icon(Icons.person_outline,
                              color: AppColors.textMuted),
                          title: Text(p.name),
                          subtitle: details.isEmpty
                              ? null
                              : Text(details,
                                  style: const TextStyle(
                                      color: AppColors.textMuted)),
                          onTap: used ? null : () => Navigator.pop(context, p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClubName extends StatelessWidget {
  const _ClubName(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: AppColors.text,
      ),
    );
  }
}
