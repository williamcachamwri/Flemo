import Cocoa
import ApplicationServices

struct TextInsertionTarget {
    let focusedElement: AXUIElement
    let appPID: pid_t?
}

class TextInsertionHelper {
    static let shared = TextInsertionHelper()

    func replaceTriggerText(triggerChar: String, keyword: String, with text: String) {
        postBackspaces(count: triggerChar.count + keyword.count)
        postKeyboardEvents(text: text)
    }

    func insertText(_ text: String) {
        insertText(text, into: nil)
    }

    func captureFocusedTarget() -> TextInsertionTarget? {
        let sys = AXUIElementCreateSystemWide()
        var app: CFTypeRef?
        guard AXUIElementCopyAttributeValue(sys, kAXFocusedApplicationAttribute as CFString, &app) == .success,
              let appElem = app else { return nil }
        let axApp = appElem as! AXUIElement
        var focus: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focus) == .success,
              let focusElem = focus else { return nil }

        var pid: pid_t = 0
        let appPID = AXUIElementGetPid(axApp, &pid) == .success ? pid : nil
        return TextInsertionTarget(focusedElement: focusElem as! AXUIElement, appPID: appPID)
    }

    func insertText(_ text: String, into target: TextInsertionTarget?) {
        let target = target ?? captureFocusedTarget()
        guard let target else {
            postKeyboardEvents(text: text)
            return
        }

        let cfText = text as CFTypeRef
        let r = AXUIElementSetAttributeValue(target.focusedElement, kAXSelectedTextAttribute as CFString, cfText)
        if r != .success {
            if let appPID = target.appPID {
                NSRunningApplication(processIdentifier: appPID)?.activate(options: [])
            }
            postKeyboardEvents(text: text)
        }
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
        let units = Array(text.utf16)
        guard !units.isEmpty else { return }

        units.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }

            if let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true) {
                down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: base)
                down.post(tap: .cgAnnotatedSessionEventTap)
            }
            if let up = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false) {
                up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: base)
                up.post(tap: .cgAnnotatedSessionEventTap)
            }
        }
    }
}
