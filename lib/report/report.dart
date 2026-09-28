import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';
import '../theme.dart';

/// Hata raporlarının gideceği adres.
/// (Online moda geçince raporlar e-posta yerine doğrudan Firebase'e gidecek.)
const String kSupportEmail = 'muazonurluer2312@gmail.com';

/// Oyuncunun itiraz ettiği durumun bilgileri.
class DataReport {
  const DataReport({
    required this.mode,
    this.player,
    this.clubs = const [],
    this.claim = '',
  });

  final String mode;
  final Player? player;
  final List<Club> clubs;

  /// Oyunun söylediği (ör. "İki kulüpte birden oynamamış")
  final String claim;
}

const _issueTypes = [
  'Bu oyuncu bu kulüpte oynadı (oyun yanlış dedi)',
  'Bu oyuncu bu kulüpte oynamadı (oyun doğru dedi)',
  'Oyuncu bilgisi yanlış (isim, mevki, uyruk, doğum yılı)',
  'Kulüp bilgisi yanlış (isim, forma rengi)',
  'Diğer',
];

/// Yanlış cevap mesajlarına eklenen "Bildir" butonu.
SnackBarAction reportAction(BuildContext context, DataReport report) =>
    SnackBarAction(
      label: 'Bildir',
      textColor: Colors.white,
      onPressed: () => showReportDialog(context, report),
    );

Future<void> showReportDialog(BuildContext context, DataReport report) async {
  var selected = report.player == null ? _issueTypes.length - 1 : 0;
  final noteController = TextEditingController();

  final send = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hatalı veri bildir'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (report.player != null)
                Text(
                  [
                    report.player!.name,
                    if (report.clubs.isNotEmpty)
                      report.clubs.map((c) => c.name).join(', '),
                  ].join(' · '),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.text),
                ),
              if (report.claim.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(report.claim,
                    style: const TextStyle(color: AppColors.textMuted)),
              ],
              const SizedBox(height: 12),
              for (var i = 0; i < _issueTypes.length; i++)
                RadioListTile<int>(
                  value: i,
                  groupValue: selected,
                  onChanged: (v) => setState(() => selected = v!),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(_issueTypes[i],
                      style: const TextStyle(fontSize: 14)),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Not (isteğe bağlı): ör. "2007-2011 arası Benfica\'da oynadı"',
                  filled: true,
                  fillColor: AppColors.surfaceHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gönder'),
          ),
        ],
      ),
    ),
  );
  final note = noteController.text.trim();
  noteController.dispose();
  if (send != true || !context.mounted) return;

  final body = _buildBody(report, _issueTypes[selected], note);
  final uri = Uri(
    scheme: 'mailto',
    path: kSupportEmail,
    query: _encodeQuery({
      'subject': '[Volea] Hatalı veri: ${report.player?.name ?? report.mode}',
      'body': body,
    }),
  );

  var opened = false;
  try {
    opened = await launchUrl(uri);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    // E-posta uygulaması yoksa: metni kopyalanabilir şekilde göster
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('E-posta uygulaması açılamadı'),
        content: SingleChildScrollView(
          child: SelectableText(
            'Aşağıdaki metni $kSupportEmail adresine gönderebilirsin:\n\n$body',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: body));
              Navigator.pop(ctx);
            },
            child: const Text('Kopyala'),
          ),
        ],
      ),
    );
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Teşekkürler! Bildirimin incelenecek.'),
    ));
  }
}

String _buildBody(DataReport r, String issue, String note) {
  final p = r.player;
  final lines = <String>[
    'Mod: ${r.mode}',
    if (p != null)
      'Oyuncu: ${p.name}${p.birthYear != null ? ' (d. ${p.birthYear})' : ''} [${p.id}]',
    if (r.clubs.isNotEmpty)
      'Kulüpler: ${r.clubs.map((c) => '${c.name} [${c.id}]').join(', ')}',
    if (r.claim.isNotEmpty) 'Oyunun söylediği: ${r.claim}',
    'Sorun: $issue',
    if (note.isNotEmpty) 'Not: $note',
  ];
  // Geliştirici için: duzeltmeler.json'a yapıştırılabilir satırlar
  if (p != null && r.clubs.isNotEmpty && issue == _issueTypes[0]) {
    lines.add('');
    lines.add('--- duzeltmeler.json "kulup_ekle" için öneri (doğru kulübü seç) ---');
    for (final c in r.clubs.where((c) => !p.clubs.contains(c.id))) {
      lines.add('{"oyuncu": "${p.name}", '
          '${p.birthYear != null ? '"dogum": ${p.birthYear}, ' : ''}'
          '"kulup": "${c.name}"}');
    }
  }
  return lines.join('\n');
}

/// mailto bağlantısında boşlukların "+" yerine "%20" olması için
String _encodeQuery(Map<String, String> params) => params.entries
    .map((e) =>
        '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
    .join('&');
