import Foundation
import Darwin
import InnerEarTUIKit

/// Raw terminal mode manager. Puts stdin into non-canonical, no-echo mode
/// on init, and restores the original settings on `restore()` or `deinit`.
/// Uses POSIX `termios` APIs via Darwin.
///
/// `@unchecked Sendable`: `restore()` can now be called from two contexts —
/// the main run loop's normal exit paths, and the SIGINT/SIGTERM handler's
/// `restoreAction` closure, which must be `@Sendable` since it's captured
/// by an unstructured `Task`. `originalTermios` is set once in `init` and
/// never mutated again, so it's safe to read from either context without
/// synchronization; `isRestored`'s check-and-set is guarded by a lock so a
/// genuinely concurrent call from both paths can't race (the practical
/// consequence of losing that race would only be a harmless redundant
/// restore, but this avoids relying on that being "fine" and just makes it
/// actually safe).
final class RawTerminalMode: @unchecked Sendable {
    private var originalTermios: termios
    private let lock = NSLock()
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

    /// Restore the original terminal settings. Safe to call multiple times,
    /// and safe to call concurrently from more than one context.
    func restore() {
        lock.lock()
        defer { lock.unlock() }
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

/// One-byte pushback buffer for `readRawByteNonBlocking()`. Needed so
/// `readKeyOrArrowNonBlocking()` can look ahead for an arrow-key escape
/// sequence without losing a byte that turns out to belong to the NEXT
/// keypress. Only ever touched from the single-threaded TUI run loop
/// (never called concurrently), matching this project's existing
/// "no new concurrency surface in the run loop" constraint — a plain
/// `nonisolated(unsafe) var` is safe here for the same reason it's safe
/// in `installSignalHandlers`'s `Holder.sources`.
nonisolated(unsafe) private var pendingByte: UInt8? = nil

private func readRawByteNonBlocking() -> UInt8? {
    if let p = pendingByte {
        pendingByte = nil
        return p
    }
    var buffer: [UInt8] = [0]
    let bytesRead = read(STDIN_FILENO, &buffer, 1)
    guard bytesRead > 0 else { return nil }
    return buffer[0]
}

/// Read a single character from stdin without blocking.
/// Returns `nil` if no byte was available (relies on VMIN=0, VTIME=1).
func readKeyNonBlocking() -> Character? {
    guard let byte = readRawByteNonBlocking() else { return nil }
    // Convert the single byte to a Character (assumes ASCII/UTF-8 single-byte char)
    // For multi-byte UTF-8 sequences this would need more sophisticated handling,
    // but for our control keys (a-z, Enter, etc.) single byte is sufficient.
    return Character(UnicodeScalar(byte))
}

/// Like `readKeyNonBlocking()`, but also recognizes arrow-key ANSI escape
/// sequences (`ESC [ A/B/C/D`) and maps Up/Down to the same `'k'`/`'j'`
/// characters the controller already treats as list-navigation keys — so
/// no changes were needed in TUIController/TUIRenderer to support arrow
/// keys. Left/Right map to `TUIController.leftArrowKey`/`.rightArrowKey`,
/// dedicated Private-Use-Area sentinel characters (not reused letters like
/// 'h'/'l') specifically so the controller can treat them as global,
/// Tab-like pane-switch keys without ever colliding with literal typed
/// text (see the case-3.5 comment in `TUIController.reduce(_:_:)`). A bare
/// Esc keypress (nothing, or something other than `[`, follows within this
/// read cycle) is still returned as `"\u{1B}"` exactly as before.
func readKeyOrArrowNonBlocking() -> Character? {
    guard let first = readRawByteNonBlocking() else { return nil }
    guard first == 0x1B else {
        return Character(UnicodeScalar(first))
    }
    // Possible start of an escape sequence. This next read blocks up to
    // ~0.1s (VTIME) waiting for a follow-up byte — real terminals send the
    // whole sequence in one burst well within that window, so this only
    // adds latency to a bare Esc keypress (once per press), not to every
    // frame. This is the same ambiguity every terminal app with both
    // "Esc means something" and "arrow keys work" has to resolve.
    let second = readRawByteNonBlocking()
    guard second == UInt8(ascii: "[") else {
        // Not an escape sequence — this was a bare Esc. If a second byte
        // WAS read but wasn't '[', push it back so it isn't silently
        // dropped; it belongs to whatever the user pressed next.
        // (`second` must be a plain local, not a `guard let` binding —
        // bindings from `guard let x = ..., cond else { ... }` are only
        // visible AFTER the guard succeeds, not inside its own else block.)
        if let second { pendingByte = second }
        return Character(UnicodeScalar(first))
    }
    guard let third = readRawByteNonBlocking() else {
        // Incomplete sequence — a real terminal never stops mid-sequence
        // like this, but if it happens, treat as a bare Esc.
        return Character(UnicodeScalar(first))
    }
    switch third {
    case UInt8(ascii: "A"): return "k"       // Up
    case UInt8(ascii: "B"): return "j"       // Down
    case UInt8(ascii: "C"): return TUIController.rightArrowKey // Right
    case UInt8(ascii: "D"): return TUIController.leftArrowKey  // Left
    default:
        return Character(UnicodeScalar(first)) // unrecognized sequence — treat as bare Esc
    }
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

/// Write an array of lines to the terminal, redrawing the existing frame
/// in place. Lines are joined with `\r\n` (a separator, not a terminator)
/// because the terminal is in raw mode. Deliberately no trailing `\r\n`
/// after the last line: the multipane renderer always emits exactly
/// `height` lines, so a trailing newline would move the cursor past the
/// bottom row and force the terminal to scroll on every single redraw —
/// even inside the alternate screen buffer, this reliably leaked frames
/// into scrollback.
///
/// Deliberately does NOT emit `ESC[2J` (clear entire screen) before
/// redrawing. A full clear blanks every cell for one frame before the new
/// content lands, and that blank-then-redraw flash is what many terminal
/// emulators render as a visible jump/scroll on every update, even though
/// no actual scrolling happens in the alternate buffer. The renderer
/// already pads every line to exactly `width` columns and emits exactly
/// `height` rows, so moving the cursor home (`ESC[H`) and overwriting each
/// cell with new content is sufficient — nothing is left over from the
/// previous frame. `ESC[J` (clear from cursor to end of screen) after the
/// last line only matters immediately after a resize to a shorter frame,
/// where a stale row from the previous, larger frame could otherwise
/// survive below the new content.
func writeToTerminal(_ lines: [String]) {
    let output = "\u{1B}[H" + lines.joined(separator: "\r\n") + "\u{1B}[J"
    rawTerminalWrite(output)
}

/// Install signal handlers for SIGINT and SIGTERM that run a best-effort
/// async cleanup, then call `restoreAction` (typically
/// `RawTerminalMode.restore()`) and exit cleanly.
///
/// Uses `DispatchSourceSignal` per the documented Darwin/Swift pattern:
/// 1. Ignore the default disposition via `signal(_, SIG_IGN)`.
/// 2. Create a `DispatchSourceSignal` for each signal.
/// 3. Set the event handler to spawn a `Task` that races `cleanup()`
///    against a fixed timeout, then calls `restoreAction()` and `exit(0)`
///    unconditionally.
/// 4. Resume the sources and retain them strongly (via static storage) so
///    they aren't deallocated.
///
/// Uses a dedicated background queue rather than `.main`: this run loop's
/// `@main async` entry point never calls `dispatchMain()`/`RunLoop.main.run()`,
/// so nothing guarantees the GCD main queue is actively drained — a source
/// on `.main` could sit unfired while the process is inside `Task.sleep` or
/// an awaited service call. A private serial queue is drained by GCD's own
/// worker threads independent of the async main executor.
///
/// - Parameters:
///   - restoreAction: Synchronous terminal restoration, run after `cleanup`
///     finishes or times out. Never skipped, regardless of how `cleanup`
///     behaves — Ctrl-C/SIGTERM must never leave the terminal broken.
///   - cleanup: Best-effort async work to run before exiting (e.g. stop and
///     save an in-progress recording so a live capture isn't silently
///     discarded on Ctrl-C). Raced against a 3-second timeout so a hang
///     here can never make the program unresponsive to Ctrl-C — this is
///     the one place a `Task` is introduced outside the main run loop,
///     scoped narrowly to shutdown and bounded so it can't regress the
///     "no new concurrency surface" goal the rest of the run loop keeps.
func installSignalHandlers(
    restoreAction: @escaping @Sendable () -> Void,
    cleanup: @escaping @Sendable () async -> Void
) {
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
            Task {
                await raceAgainstTimeout(cleanup, seconds: 3)
                restoreAction()
                exit(0)
            }
        }
        source.resume()
        Holder.sources.append(source)
    }
}

/// Runs `work`, but returns as soon as either `work` finishes OR `seconds`
/// elapses — whichever comes first — WITHOUT waiting for the loser.
///
/// `withTaskGroup`/`cancelAll()` is NOT sufficient for this: structured
/// concurrency requires the group to wait for every child task before
/// returning, and `Task.isCancelled` is cooperative — `work` here (stopping
/// a capture, saving a file) never checks it, so a `cancelAll()` after the
/// timeout task "wins" would NOT actually cut the wait short; the group
/// would still block until `work` eventually finishes on its own, silently
/// defeating the whole point of the timeout. Two independent, unstructured
/// `Task`s racing to resume a single checked continuation (guarded so only
/// the first resume counts) genuinely doesn't wait for the loser — the
/// loser keeps running in the background, which is fine here since the
/// caller calls `exit(0)` immediately after, killing it regardless.
private func raceAgainstTimeout(_ work: @escaping @Sendable () async -> Void, seconds: Int) async {
    let guardActor = FirstWriterWins()
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        Task {
            await work()
            if await guardActor.claim() {
                continuation.resume()
            }
        }
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            if await guardActor.claim() {
                continuation.resume()
            }
        }
    }
}

/// Ensures exactly one of two racing tasks resumes a continuation — a
/// `CheckedContinuation` traps if resumed twice.
private actor FirstWriterWins {
    private var claimed = false
    func claim() -> Bool {
        guard !claimed else { return false }
        claimed = true
        return true
    }
}