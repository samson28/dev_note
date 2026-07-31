import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

import 'file_repository.dart';
import 'index_repository.dart';

/// Watches the vault and keeps the index in step with whatever happens on
/// disk, edits from another editor, a Dropbox sync, a `git checkout`.
///
/// Events are coalesced over a short window: a save from an external editor
/// often lands as remove+add, and re-indexing twice for one logical change
/// would be wasted work.
class FileWatcherService {
  FileWatcherService(this.files, this.index);

  final FileRepository files;
  final IndexRepository index;

  static const _debounce = Duration(milliseconds: 220);

  StreamSubscription<WatchEvent>? _subscription;
  Timer? _timer;
  final Set<String> _dirty = {};

  final _changes = StreamController<void>.broadcast();

  /// Fires after a batch of disk changes has been folded into the index.
  Stream<void> get onIndexChanged => _changes.stream;

  /// Paths this process is about to write itself. Suppressing them avoids a
  /// pointless round trip through the watcher for our own saves.
  final Set<String> _selfWrites = {};

  void expectSelfWrite(String relativePath) {
    _selfWrites.add(relativePath);
    // Never let a suppression outlive the write that scheduled it.
    Timer(const Duration(seconds: 2), () => _selfWrites.remove(relativePath));
  }

  Future<void> start() async {
    await stop();
    final watcher = DirectoryWatcher(files.root.path);
    _subscription = watcher.events.listen(_onEvent, onError: (_) {
      // A transient FS error (a folder vanishing mid-scan) is not fatal: the
      // next synchronise() pass reconciles whatever we missed.
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _subscription?.cancel();
    _subscription = null;
  }

  void _onEvent(WatchEvent event) {
    if (p.extension(event.path).toLowerCase() != '.md') return;

    final relative = files.relativePathOf(File(event.path));
    if (p.split(relative).any((s) => s.startsWith('.'))) return;
    if (_selfWrites.remove(relative)) return;

    _dirty.add(relative);
    _timer?.cancel();
    _timer = Timer(_debounce, _flush);
  }

  Future<void> _flush() async {
    final batch = Set<String>.from(_dirty);
    _dirty.clear();
    if (batch.isEmpty) return;

    for (final relative in batch) {
      final file = File(p.joinAll([files.root.path, ...p.split(relative)]));
      if (await file.exists()) {
        final note = await files.tryRead(file);
        if (note != null) await index.upsert(note);
      } else {
        await index.removeByPath(relative);
      }
    }

    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() async {
    await stop();
    await _changes.close();
  }
}
