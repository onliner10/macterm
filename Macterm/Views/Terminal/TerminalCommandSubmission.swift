import Foundation

enum TerminalCommandSubmission {
    /// Hardware key codes (Carbon `kVK_*`). Named rather than inlined: bare
    /// literals behind a trailing gloss are easy to mistype on edit, and only
    /// some of these exist in `HotkeyRegistry`'s shortcut vocabulary (backspace
    /// and forward-delete aren't bindable), so that map can't supply them all.
    /// `TerminalCommandSubmissionTests` cross-checks the ones it does know.
    private enum KeyCode {
        static let returnKey: UInt16 = 36
        static let keypadEnter: UInt16 = 76
        static let escape: UInt16 = 53
        static let backspace: UInt16 = 51
        static let forwardDelete: UInt16 = 117
        static let a: UInt16 = 0
        static let c: UInt16 = 8
        static let h: UInt16 = 4
        static let k: UInt16 = 40
        static let u: UInt16 = 32
        static let w: UInt16 = 13
        static let x: UInt16 = 7
    }

    private static let returnKeyCodes: Set<UInt16> = [KeyCode.returnKey, KeyCode.keypadEnter]

    /// Unmodified keys that abandon or erase what was typed.
    private static let discardKeyCodes: Set<UInt16> = [KeyCode.escape, KeyCode.backspace, KeyCode.forwardDelete]
    /// Readline line-editing chords: Ctrl-C abort, Ctrl-H backspace,
    /// Ctrl-W kill word, Ctrl-U kill line, Ctrl-K kill to end of line.
    private static let controlDiscardKeyCodes: Set<UInt16> = [KeyCode.c, KeyCode.h, KeyCode.w, KeyCode.u, KeyCode.k]
    /// Cmd-A (select all, which precedes an overwrite) and Cmd-X (cut).
    private static let commandDiscardKeyCodes: Set<UInt16> = [KeyCode.a, KeyCode.x]

    /// Best-effort evidence that the next Return submits actual prompt text.
    /// Terminal protocols do not expose a TUI's editor buffer, so the view
    /// records committed text it forwards and consumes that evidence on Return.
    /// This rejects a genuinely blank Return without naming any specific TUI.
    struct Evidence {
        private var hasContent = false

        mutating func recordText(_ text: String) {
            if TerminalCommandSubmission.textContainsContent(text) {
                hasContent = true
            }
        }

        mutating func consume() -> Bool {
            defer { hasContent = false }
            return hasContent
        }

        mutating func clear() {
            hasContent = false
        }
    }

    static func isReturn(
        keyCode: UInt16,
        isRepeat: Bool,
        hasMarkedText: Bool,
        hasUserModifiers: Bool
    ) -> Bool {
        returnKeyCodes.contains(keyCode) && !isRepeat && !hasMarkedText && !hasUserModifiers
    }

    static func textContainsNewline(_ text: String) -> Bool {
        text.contains("\n") || text.contains("\r")
    }

    static func textContainsContent(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            !CharacterSet.whitespacesAndNewlines.contains(scalar)
                && !CharacterSet.controlCharacters.contains(scalar)
        }
    }

    static func clearsInputEvidence(
        keyCode: UInt16,
        hasControl: Bool,
        hasCommand: Bool
    ) -> Bool {
        if discardKeyCodes.contains(keyCode) { return true }
        if hasControl, controlDiscardKeyCodes.contains(keyCode) { return true }
        if hasCommand, commandDiscardKeyCodes.contains(keyCode) { return true }
        return false
    }

    static func shouldRecordLiteralText(hasOption: Bool) -> Bool {
        // With macos-option-as-alt, interpretKeyEvents yields a printable base
        // character even though Ghostty sends it as Meta navigation. Prefer a
        // false negative over calling that navigation committed prompt text.
        !hasOption
    }
}
