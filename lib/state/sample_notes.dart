import '../core/models/note.dart';
import '../core/models/note_type.dart';
import '../data/file_repository.dart';

/// Example notes dropped into a brand-new vault, taken from the design's own
/// mock content.
///
/// This runs only when `~/JotVault/` did not exist, so it can never touch an
/// existing set of notes. It exists so the first launch shows a working app -
/// grouping, badges, syntax colours and search all have something to chew on -
/// instead of four empty columns.
abstract final class SampleNotes {
  static Future<void> seed(FileRepository files) async {
    final now = DateTime.now();
    DateTime ago(Duration d) => now.subtract(d);

    for (final folder in const ['Enko', 'Klém', 'Yewash']) {
      await files.createFolder(folder);
    }

    final seeds = <_Seed>[
      _Seed(
        title: 'webhook checkout.session',
        folder: Folder.inbox,
        tags: const ['api', 'stripe'],
        pinned: true,
        modified: ago(const Duration(minutes: 4)),
        created: ago(const Duration(days: 2)),
        content: '''
{
  "id": "evt_1PqR2sK9xLmT4uV",
  "type": "checkout.session.completed",
  "created": 1753683142,
  "livemode": false,
  "data": {
    "object": {
      "id": "cs_test_b1Kd9ZqA",
      "amount_total": 4900,
      "currency": "eur",
      "customer_email": "dev@yewash.io",
      "metadata": {
        "order_id": "ord_88213",
        "plan": "team",
        "source": "webhook"
      }
    }
  },
  "request": {
    "id": "req_7Hx2Kd",
    "idempotency_key": "ik_4f21ab"
  }
}''',
      ),
      _Seed(
        title: 'Clé API staging Yewash',
        folder: Folder.inbox,
        tags: const ['creds'],
        pinned: true,
        modified: ago(const Duration(days: 1, hours: 3)),
        created: ago(const Duration(days: 9)),
        content:
            'YW_STG_sk_4f8a21c9de77b03e1a55, rotation prévue le 1er de chaque mois\n'
            'Endpoint : https://staging.yewash.io/api/v2\n'
            'Ne pas utiliser en prod.',
      ),
      _Seed(
        title: 'debounce provider Riverpod',
        folder: Folder.inbox,
        tags: const ['snippet'],
        modified: ago(const Duration(days: 3, hours: 5)),
        created: ago(const Duration(days: 3, hours: 5)),
        content: '''
final debounced = ref.watch(searchQueryProvider.select((q) => q.trim()));

final results = ref.watch(
  FutureProvider.autoDispose((ref) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    ref.onDispose(() {});
    return ref.read(indexProvider).search(debounced);
  }),
);''',
      ),
      _Seed(
        title: 'Dashboard Grafana, latence Enko',
        folder: Folder.inbox,
        type: NoteType.url,
        modified: ago(const Duration(days: 3, hours: 9)),
        created: ago(const Duration(days: 3, hours: 9)),
        content: 'https://grafana.enko.internal/d/9fbz1/api-latency',
      ),
      _Seed(
        title: 'Migration 0042, colonnes manquantes',
        folder: Folder.inbox,
        tags: const ['bug'],
        modified: ago(const Duration(days: 4, hours: 2)),
        created: ago(const Duration(days: 4, hours: 2)),
        content: '''
ALTER TABLE invoices ADD COLUMN settled_at TIMESTAMPTZ;
ALTER TABLE invoices ADD COLUMN settlement_ref TEXT;

CREATE INDEX idx_invoices_settled_at ON invoices (settled_at DESC);''',
      ),
      _Seed(
        title: 'Retour recette Klém, points bloquants',
        folder: Folder.inbox,
        modified: ago(const Duration(days: 4, hours: 8)),
        created: ago(const Duration(days: 4, hours: 8)),
        content:
            "Le tri par date casse quand le fuseau est UTC+13. Vérifier l'export CSV : "
            "les colonnes 4 et 5 sont inversées quand le libellé contient un point-virgule.\n\n"
            "À revoir avec l'équipe avant la démo.",
      ),
      _Seed(
        title: 'payload erreur 422, validation',
        folder: Folder.inbox,
        modified: ago(const Duration(days: 13)),
        created: ago(const Duration(days: 13)),
        content: '''
{
  "source": "webhook",
  "status": 422,
  "errors": [
    { "field": "email", "code": "invalid_format" },
    { "field": "amount", "code": "out_of_range" }
  ]
}''',
      ),
      _Seed(
        title: 'Vérif signature webhook (Dart)',
        folder: 'Enko',
        tags: const ['api', 'snippet'],
        modified: ago(const Duration(days: 1, hours: 6)),
        created: ago(const Duration(days: 20)),
        content: '''
final sig = Hmac(sha256, secret).convert(utf8.encode(payload));
if (!constantTimeEquals(sig.toString(), header)) {
  throw StateError('signature invalide');
}''',
      ),
      _Seed(
        title: 'Logs Stripe, tentatives échouées',
        folder: 'Enko',
        type: NoteType.url,
        tags: const ['api'],
        modified: ago(const Duration(days: 18)),
        created: ago(const Duration(days: 18)),
        content: 'https://dashboard.enko.dev/logs?filter=webhook_failed',
      ),
      _Seed(
        title: 'Timeout job queue',
        folder: 'Enko',
        modified: ago(const Duration(days: 25)),
        created: ago(const Duration(days: 25)),
        content: '{ "retry_after": 120, "queue": "enko-jobs" }',
      ),
    ];

    for (final seed in seeds) {
      final note = await files.create(
        content: seed.content,
        title: seed.title,
        type: seed.type,
        folder: seed.folder,
        tags: seed.tags,
        pinned: seed.pinned,
      );
      // Rewrite with the intended timestamps so the list's date grouping has
      // something realistic to show on first launch.
      await files.write(
        note.copyWith(created: seed.created, modified: seed.modified),
      );
    }
  }
}

class _Seed {
  const _Seed({
    required this.title,
    required this.content,
    required this.folder,
    required this.created,
    required this.modified,
    this.type,
    this.tags = const [],
    this.pinned = false,
  });

  final String title;
  final String content;
  final String folder;
  final DateTime created;
  final DateTime modified;
  final NoteType? type;
  final List<String> tags;
  final bool pinned;
}
