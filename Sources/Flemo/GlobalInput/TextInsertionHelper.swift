import Cocoa
import ApplicationServices

class TextInsertionHelper {
    static let shared = TextInsertionHelper()

    func replaceTriggerText(triggerChar: String, keyword: String, with text: String) {
        postBackspaces(count: triggerChar.count + keyword.count)
        postKeyboardEvents(text: text)
    }

    func insertText(_ text: String) {
        let sys = AXUIElementCreateSystemWide()
        var app: CFTypeRef?
        guard AXUIElementCopyAttributeValue(sys, kAXFocusedApplicationAttribute as CFString, &app) == .success,
              let appElem = app else { postKeyboardEvents(text: text); return }
        let axApp = appElem as! AXUIElement
        var focus: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focus) == .success,
              let focusElem = focus else { postKeyboardEvents(text: text); return }
        let axFocus = focusElem as! AXUIElement
        let cfText = text as CFTypeRef
        let r = AXUIElementSetAttributeValue(axFocus, kAXSelectedTextAttribute as CFString, cfText)
        if r != .success { postKeyboardEvents(text: text) }
    }

    private func postBackspaces(count: Int) {
        guard let src = CGEventSource(stateID: .combinedSessionState) else { return }
        for _ in 0..<count {
            if let down = CGEvent(keyboardEventSource: src, virtualKey: 0x33, keyDown: true) {
                down.post(tap: .cgAnnotatedSessionEventTap)
            }
            if let up = CGEvent(keyboardEventSource: src, virtualKey: 0x33, keyDown: false) {
                up.post(tap: .cgAnnotatedSessionEventTap)
            }
        }
    }

    private func postKeyboardEvents(text: String) {
        guard let src = CGEventSource(stateID: .combinedSessionState) else { return }
        let chars = Array(text.utf16)
        for ch in chars {
            var u = [ch]
            if let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true) {
                down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &u)
                down.post(tap: .cgAnnotatedSessionEventTap)
            }
            if let up = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false) {
                up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &u)
                up.post(tap: .cgAnnotatedSessionEventTap)
            }
        }
    }
}
