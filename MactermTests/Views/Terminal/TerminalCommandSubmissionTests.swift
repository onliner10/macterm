@testable import Macterm
import Testing

struct TerminalCommandSubmissionTests {
    @Test
    func returnAndKeypadEnterAreSubmissions() {
        #expect(TerminalCommandSubmission.isReturn(
            keyCode: 36, isRepeat: false, hasMarkedText: false, hasUserModifiers: false
        ))
        #expect(TerminalCommandSubmission.isReturn(
            keyCode: 76, isRepeat: false, hasMarkedText: false, hasUserModifiers: false
        ))
    }

    @Test(arguments: [
        (36, true, false, false),
        (36, false, true, false),
        (36, false, false, true),
        (49, false, false, false),
    ])
    func rejectsRepeatCompositionModifiersAndOtherKeys(
        keyCode: Int,
        isRepeat: Bool,
        hasMarkedText: Bool,
        hasUserModifiers: Bool
    ) {
        #expect(!TerminalCommandSubmission.isReturn(
            keyCode: UInt16(keyCode),
            isRepeat: isRepeat,
            hasMarkedText: hasMarkedText,
            hasUserModifiers: hasUserModifiers
        ))
    }

    @Test
    func programmaticTextRequiresNewline() {
        #expect(TerminalCommandSubmission.textContainsNewline("sleep 1\n"))
        #expect(TerminalCommandSubmission.textContainsNewline("sleep 1\r"))
        #expect(!TerminalCommandSubmission.textContainsNewline("sleep 1"))
    }

    @Test
    func contentEvidenceIgnoresBlankAndControlText() {
        var evidence = TerminalCommandSubmission.Evidence()
        evidence.recordText(" \t\r\n\u{3}")
        let consumed = evidence.consume()
        #expect(!consumed)
    }

    @Test
    func contentEvidenceIsConsumedOnce() {
        var evidence = TerminalCommandSubmission.Evidence()
        evidence.recordText("! sleep 10")
        let first = evidence.consume()
        let second = evidence.consume()
        #expect(first)
        #expect(!second)

        evidence.recordText("こんにちは")
        let imeText = evidence.consume()
        #expect(imeText)
    }

    @Test
    func imeCommitReturnPreservesContentForFollowingSubmission() {
        var evidence = TerminalCommandSubmission.Evidence()
        evidence.recordText("かな")
        let commitIsSubmission = TerminalCommandSubmission.isReturn(
            keyCode: 36,
            isRepeat: false,
            hasMarkedText: true,
            hasUserModifiers: false
        )
        #expect(!commitIsSubmission)

        let followingReturnIsSubmission = TerminalCommandSubmission.isReturn(
            keyCode: 36,
            isRepeat: false,
            hasMarkedText: false,
            hasUserModifiers: false
        )
        let hasContent = evidence.consume()
        #expect(followingReturnIsSubmission)
        #expect(hasContent)
    }

    @Test
    func pasteEvidenceUsesResolvedContent() {
        var evidence = TerminalCommandSubmission.Evidence()
        evidence.recordText(" \n\t")
        let blankPaste = evidence.consume()
        #expect(!blankPaste)

        evidence.recordText("! sleep 10\n")
        let commandPaste = evidence.consume()
        #expect(commandPaste)
    }

    @Test
    func destructiveInputDiscardsEvidence() {
        var evidence = TerminalCommandSubmission.Evidence()
        evidence.recordText("x")
        #expect(TerminalCommandSubmission.clearsInputEvidence(
            keyCode: 51, hasControl: false, hasCommand: false
        ))
        evidence.clear()
        let erased = evidence.consume()
        #expect(!erased)

        #expect(TerminalCommandSubmission.clearsInputEvidence(
            keyCode: 53, hasControl: false, hasCommand: false
        ))
        #expect(TerminalCommandSubmission.clearsInputEvidence(
            keyCode: 8, hasControl: true, hasCommand: false
        ))
        #expect(TerminalCommandSubmission.clearsInputEvidence(
            keyCode: 0, hasControl: false, hasCommand: true
        ))
        #expect(TerminalCommandSubmission.clearsInputEvidence(
            keyCode: 7, hasControl: false, hasCommand: true
        ))
        #expect(!TerminalCommandSubmission.clearsInputEvidence(
            keyCode: 8, hasControl: false, hasCommand: false
        ))
    }

    /// The key codes `TerminalCommandSubmission` names are the same hardware
    /// codes `HotkeyRegistry` binds shortcuts to. Cross-check every one the
    /// registry knows, so a typo in either table shows up here rather than as a
    /// silently mis-cleared evidence flag. (Backspace 51 and forward-delete 117
    /// aren't bindable, so the registry has no entry to check them against.)
    @Test(arguments: [
        (0, "a"), (7, "x"), (8, "c"), (4, "h"), (13, "w"), (32, "u"), (40, "k"),
        (36, "return"), (76, "return"), (53, "escape"),
    ])
    func namedKeyCodesMatchTheHotkeyVocabulary(keyCode: Int, token: String) {
        #expect(HotkeyRegistry.baseToken(forKeyCode: UInt16(keyCode)) == token)
    }

    /// Every code `clearsInputEvidence` recognizes, and the modifier it needs.
    /// A bare Ctrl-letter code with no Ctrl held, or a Cmd chord with no Cmd,
    /// must not clear — that's what keeps ordinary typing evidence intact.
    @Test(arguments: [
        (53, false, false), // escape
        (51, false, false), // backspace
        (117, false, false), // forward delete
        (4, true, false), // ctrl-h
        (8, true, false), // ctrl-c
        (13, true, false), // ctrl-w
        (32, true, false), // ctrl-u
        (40, true, false), // ctrl-k
        (0, false, true), // cmd-a
        (7, false, true), // cmd-x
    ])
    func clearsInputEvidenceCoversEachDiscardChord(keyCode: Int, hasControl: Bool, hasCommand: Bool) {
        #expect(TerminalCommandSubmission.clearsInputEvidence(
            keyCode: UInt16(keyCode), hasControl: hasControl, hasCommand: hasCommand
        ))
        guard hasControl || hasCommand else { return }
        #expect(!TerminalCommandSubmission.clearsInputEvidence(
            keyCode: UInt16(keyCode), hasControl: false, hasCommand: false
        ))
    }

    @Test
    func optionAsAltTextDoesNotCountAsLiteralContent() {
        #expect(!TerminalCommandSubmission.shouldRecordLiteralText(hasOption: true))
        #expect(TerminalCommandSubmission.shouldRecordLiteralText(hasOption: false))
    }
}
