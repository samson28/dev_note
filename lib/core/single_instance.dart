import 'dart:async';
import 'dart:io';

/// Stops a second launch of the main window from starting a competing
/// engine that fights the first one over the search index file, the global
/// hotkey and the tray icon.
///
/// That fight is what left the app fully unresponsive after a double
/// launch: two processes racing for the same per-user resources, neither
/// one finishing its window setup cleanly.
///
/// A loopback TCP socket on a fixed port is the lock. Binding it is atomic
/// across processes, needs no native plugin, and doubles as the channel a
/// second launch uses to tell the first one to come to the front instead
/// of silently doing nothing.
abstract final class SingleInstance {
  static const _port = 51923;

  /// Set by the caller once the window is able to show itself. Left unset,
  /// a second launch still exits cleanly; it just cannot raise the first
  /// window on top for the user.
  static void Function()? onActivate;

  /// True when another instance already holds the lock — the caller must
  /// return immediately without creating a window. On the first instance,
  /// starts listening for later launches and returns false.
  static Future<bool> alreadyRunning() async {
    try {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, _port);
      server.listen((client) {
        client.listen((_) => onActivate?.call());
      });
      return false;
    } on SocketException {
      // Someone already holds the port. Ask them to come forward; whether
      // or not the ping lands, starting a second engine is never the right
      // outcome, so this process is done either way.
      try {
        final socket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          _port,
          timeout: const Duration(milliseconds: 500),
        );
        socket.write('show');
        await socket.flush();
        await socket.close();
      } on Object {
        // The other instance may be mid-startup or mid-shutdown; there is
        // nothing more this one can usefully do about it.
      }
      return true;
    }
  }
}
