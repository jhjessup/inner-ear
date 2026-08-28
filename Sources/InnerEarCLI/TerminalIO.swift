import Foundation
import Darwin

/// Raw terminal mode manager. Puts stdin into non-canonical, no-echo mode
/// on init, and restores the original settings on `restore()` or `deinit`.
/// Uses POSIX `termios` APIs via Darwin.
final class RawTerminalMode {
    private var originalTermios: termios
    private var isRestored = false

    init() throws {
        // Get current terminal attributes for stdin (fd 0)
        var term = termios()
        guard tcgetattr(STDIN_FILENO, &term) == 0 else {
            throw TerminalError.tcgetattrFailed(errno: errno)
        }
        self.originalTermios = term

        // Modify a copy: disable canonical mode (line buffering) and echo
        var raw = term
        raw.c_lflag &= ~tcflag_t(ICANON | ECHO)
        // Non-blocking-ish read: return immediately if no data, or after 0.1s.
        // NOTE: on Darwin, c_cc's tuple indices follow sys/termios.h's VEOF=0,
        // VEOL=1, ... VMIN=16, VTIME=17 — NOT the Linux/glibc VMIN=6/VTIME=5
        // layout, and not index 0/1 either. Using .0/.1 here would silently
        // set VEOF/VEOL instead, leaving VMIN/VTIME at their inherited
        // canonical-mode defaults and making reads block on a full line.
        raw.c_cc.16 = 0  // VMIN = 0
        raw.c_cc.17 = 1  // VTIME = 1 (deciseconds = 0.1s)

        guard tcsetattr(STDIN_FILENO, TCSANOW, &raw) == 0 else {
            throw TerminalError.tcsetattrFailed(errno: errno)
        }

        // Switch to the ANSI alternate screen buffer. Without this, a full
        // clear-and-redraw cycle fights with the terminal emulator's own
        // resize behavior: shrinking the window commonly scrolls existing
        // on-screen content into scrollback to preserve it, which visually
        // pushes the next redraw toward the bottom of the window instead of
        // staying top-aligned. The alternate buffer has no scrollback to
        // preserve, so ESC[2J + cursor-home always produces a clean
        // top-aligned frame regardless of resize timing — the same
        // mechanism vim/less/htop/tmux use for exactly this reason.
        rawTerminalWrite("\u{1B}[?1049h")
    }

    /// Restore the original terminal settings. Safe to call multiple times.
    func restore() {
        guard !isRestored else { return }
        _ = tcsetattr(STDIN_FILENO, TCSANOW, &originalTermios)
        // Leave the alternate screen buffer, restoring the user's original
        // terminal content and scrollback exactly as it was before the TUI
        // started.
        rawTerminalWrite("\u{1B}[?1049l")
        isRestored = true
    }

    deinit {
        restore()
    }

    enum TerminalError: Error, Equatable {
        case tcgetattrFailed(errno: Int32)
        case tcsetattrFailed(errno: Int32)
        case ioctlFailed(errno: Int32)
    }
}

/// Query the current terminal window size via `ioctl(TIOCGWINSZ)`.
/// Returns a fallback of (80, 24) if the ioctl fails.
func terminalSize() -> (width: Int, height: Int) {
    var ws = winsize()
    // Use stdout (fd 1) for the controlling terminal
    let result = ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws)
    if result == 0, ws.ws_col > 0, ws.ws_row > 0 {
        return (width: Int(ws.ws_col), height: Int(ws.ws_row))
    }
    return (width: 80, height: 24)
}

/// Read a single character from stdin without blocking.
/// Returns `nil` if no byte was available (relies on VMIN=0, VTIME=1).
func readKeyNonBlocking() -> Character? {
    var buffer: [UInt8] = [0]
    let bytesRead = read(STDIN_FILENO, &buffer, 1)
    guard bytesRead > 0 else { return nil }
    // Convert the single byte to a Character (assumes ASCII/UTF-8 single-byte char)
    // For multi-byte UTF-8 sequences this would need more sophisticated handling,
    // but for our control keys (a-z, Enter, etc.) single byte is sufficient.
    return Character(UnicodeScalar(buffer[0]))
}

/// Write raw bytes directly to stdout (fd 1) via `write(2)`, bypassing
/// Swift's buffered `print`/stdout entirely (which would cause jerky or
/// partial-frame redraws in a raw-mode terminal loop).
func rawTerminalWrite(_ s: String) {
    let bytes = Array(s.utf8)
    bytes.withUnsafeBytes { buffer in
        _ = write(STDOUT_FILENO, buffer.baseAddress, buffer.count)
    }
}

/// Write an array of lines to the terminal, clearing the screen first.
/// Lines are terminated with `\r\n` because the terminal is in raw mode.
func writeToTerminal(_ lines: [String]) {
    // ANSI escape: clear screen + move cursor home
    var output = "\u{1B}[2J\u{1B}[H"
    for line in lines {
        output += line
        output += "\r\n"
    }
    rawTerminalWrite(output)
}

/// Install signal handlers for SIGINT and SIGTERM that call `restoreAction`
/// (typically `RawTerminalMode.restore()`) and then exit cleanly.
///
/// Uses `DispatchSourceSignal` per the documented Darwin/Swift pattern:
/// 1. Ignore the default disposition via `signal(_, SIG_IGN)`.
/// 2. Create a `DispatchSourceSignal` for each signal.
/// 3. Set the event handler to call `restoreAction()` then `exit(0)`.
/// 4. Resume the sources and retain them strongly (via static storage) so
///    they aren't deallocated.
///
/// Uses a dedicated background queue rather than `.main`: this run loop's
/// `@main async` entry point never calls `dispatchMain()`/`RunLoop.main.run()`,
/// so nothing guarantees the GCD main queue is actively drained — a source
/// on `.main` could sit unfired while the process is inside `Task.sleep` or
/// an awaited service call. A private serial queue is drained by GCD's own
/// worker threads independent of the async main executor.
func installSignalHandlers(restoreAction: @escaping () -> Void) {
    // Ignore default dispositions so our handler runs exclusively.
    signal(SIGINT, SIG_IGN)
    signal(SIGTERM, SIG_IGN)

    // Retain the dispatch sources for the lifetime of the process.
    // Using a static property ensures they stay alive. `nonisolated(unsafe)`
    // is safe here: appends happen only during this one setup call at
    // startup (never concurrently), and the array is never read again.
    struct Holder {
        nonisolated(unsafe) static var sources: [DispatchSourceSignal] = []
    }

    let signalQueue = DispatchQueue(label: "com.innerear.tui.signals")
    for sig in [SIGINT, SIGTERM] {
        let source = DispatchSource.makeSignalSource(signal: sig, queue: signalQueue)
        source.setEventHandler {
            restoreAction()
            exit(0)
        }
        source.resume()
        Holder.sources.append(source)
    }
}