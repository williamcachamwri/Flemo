import Cocoa
import os.log

class GlobalInputMonitor: NSObject {
    private let log = OSLog(subsystem: "com.flemo.app", category: "InputMonitor")
    private let appState: AppState
    private let textProvider = TextContextProvider.shared
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private var pollTimer: Timer?
    private var isTriggered = false
    private var eventBuffer = ""
    private var lastDetectedKeyword = ""
    private var hasDetectedTrigger = false
    private var lastFireTime: Date = .distantPast
    private var lastKeyEventTime: Date = .distantPast
    private var pendingCancelWorkItem: DispatchWorkItem?
    private let pollingCancelGrace: TimeInterval = 0.45

    var onTriggerDetected: ((String, CGRect) -> Void)?
    var onTriggerCancelled: (() -> Void)?
    var onNavigateSuggestions: ((Int) -> Void)?
    var onConfirmSuggestion: (() -> Void)?
    var onToggleQuickEmojiBoard: ((CGRect?) -> Void)?
    @Published var isMonitoring = false

    init(appState: AppState) {
        self.appState = appState
    }

    func start() {
        let status = AccessibilityPermissionManager.shared.refreshStatus()
        let hasAX = status.accessibility
        let hasIM = status.inputMonitoring
        os_log(.info, "Permissions: AX=%@ IM=%@", hasAX.description, hasIM.description)

        installKeyboardMonitor()
        startPollingIfNeeded()

        isMonitoring = true
        os_log(.info, "Monitoring started (tap=%@ gm=%@ poll=%.2fs)",
               eventTap != nil ? "yes" : "no",
               globalMonitor != nil ? "yes" : "no",
               pollTimer?.timeInterval ?? 0)
    }

    func refreshPermissionsAndRetry() {
        if !isMonitoring {
            start()
            return
        }
        AccessibilityPermissionManager.shared.refreshStatus()
        installKeyboardMonitor()
    }

    func resetTriggerSession() {
        pendingCancelWorkItem?.cancel()
        pendingCancelWorkItem = nil
        isTriggered = false
        eventBuffer = ""
        lastDetectedKeyword = ""
        hasDetectedTrigger = false
        lastFireTime = .distantPast
    }

    private func startPollingIfNeeded() {
        guard pollTimer == nil else { return }
        let pollInterval: TimeInterval = 0.15
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.pollAXContext()
        }
        RunLoop.current.add(pollTimer!, forMode: .common)
    }

    private func installKeyboardMonitor() {
        if setupEventTap() {
            removeGlobalMonitor()
            return
        }

        if globalMonitor == nil {
            setupGlobalMonitor()
        }
    }

    // MARK: — Event Tap

    @discardableResult
    private func setupEventTap() -> Bool {
        if eventTap != nil { return true }

        let mask = (1 << CGEventType.keyDown.rawValue)
                | (1 << CGEventType.leftMouseDown.rawValue)
                | (1 << CGEventType.tapDisabledByTimeout.rawValue)
                | (1 << CGEventType.tapDisabledByUserInput.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let s = Unmanaged<GlobalInputMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                switch type {
                case .keyDown:
                    if let ns = NSEvent(cgEvent: event), s.processKeyEvent(ns) {
                        return nil
                    }
                case .leftMouseDown:
                    if s.textProvider.rememberPotentialInputAnchor(
                        at: event.location,
                        cocoaPoint: NSEvent.mouseLocation
                    ) {
                        s.isTriggered = false
                        s.eventBuffer = ""
                        s.cancelSuggestions()
                    }
                case .tapDisabledByTimeout, .tapDisabledByUserInput:
                    if let tap = s.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
                    os_log(.info, log: s.log, "Event tap re-enabled")
                default:
                    break
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            os_log(.error, "tapCreate failed")
            return false
        }
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        os_log(.info, "Event tap installed (tailAppend)")
        return true
    }

    // MARK: — Global Monitor

    private func setupGlobalMonitor() {
        guard globalMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.processKeyEvent(event)
        }
        os_log(.info, "Global monitor installed (fallback)")
    }

    private func removeGlobalMonitor() {
        if let m = globalMonitor {
            NSEvent.removeMonitor(m)
            globalMonitor = nil
        }
    }

    // MARK: — Event-based buffer (fast path)

    private func processKeyEvent(_ event: NSEvent) -> Bool {
        if isQuickEmojiBoardShortcut(event) {
            resetTriggerSession()
            cancelSuggestions()
            DispatchQueue.main.async { [weak self] in
                self?.onToggleQuickEmojiBoard?(nil)
            }
            return true
        }

        guard appState.inlineTriggerEnabled else { return false }
        if RulesManager.shared.shouldSuppressInput(appState: appState) {
            resetTriggerSession()
            cancelSuggestions()
            return false
        }

        let chars = event.characters ?? ""
        let rawChars = event.charactersIgnoringModifiers ?? ""
        if !isNavigationKey(event.keyCode) {
            lastKeyEventTime = Date()
        }

        let trigger = appState.triggerCharacter
        let minLen = appState.minTriggerLength
        let opensRecents = appState.inlinePanelOpenMode == .recents

        if appState.isShowingSuggestions {
            switch event.keyCode {
            case 123, 126:
                DispatchQueue.main.async { [weak self] in self?.onNavigateSuggestions?(-1) }
                return true
            case 124, 125:
                DispatchQueue.main.async { [weak self] in self?.onNavigateSuggestions?(1) }
                return true
            case 36, 48, 76:
                DispatchQueue.main.async { [weak self] in self?.onConfirmSuggestion?() }
                return true
            case 53:
                isTriggered = false
                eventBuffer = ""
                cancelSuggestions()
                return true
            default:
                break
            }
        }

        if isNavigationKey(event.keyCode) || isPrivateControlString(chars) || isPrivateControlString(rawChars) {
            return false
        }

        if !isTriggered && (rawChars == trigger || chars == trigger) {
            isTriggered = true
            eventBuffer = ""
            lastDetectedKeyword = ""
            hasDetectedTrigger = false
            pendingCancelWorkItem?.cancel()
            os_log(.info, "Trigger detected via event")
            if opensRecents {
                fireEvent(keyword: "")
            }
            return false
        }
        if !isTriggered { return false }

        if event.keyCode == 0x33 {
            if eventBuffer.isEmpty {
                isTriggered = false
                cancelSuggestions()
            } else {
                eventBuffer.removeLast()
                if eventBuffer.count >= minLen {
                    fireEvent(keyword: eventBuffer)
                } else if eventBuffer.isEmpty, opensRecents {
                    fireEvent(keyword: "")
                } else {
                    cancelSuggestions()
                }
            }
            return false
        }

        if chars == " " || chars == "\n" || chars == "\r" || chars == "\u{1b}" {
            isTriggered = false
            eventBuffer = ""
            cancelSuggestions()
            return false
        }

        if rawChars == trigger || chars == trigger {
            isTriggered = true
            eventBuffer = ""
            lastDetectedKeyword = ""
            hasDetectedTrigger = false
            pendingCancelWorkItem?.cancel()
            if opensRecents {
                fireEvent(keyword: "")
            }
            return false
        }

        var effective = chars
        if effective.hasPrefix(trigger) {
            effective = String(effective.dropFirst(trigger.count))
        }
        if !effective.isEmpty, !isPrivateControlString(effective) {
            eventBuffer += effective
            pendingCancelWorkItem?.cancel()
            if eventBuffer.count >= minLen {
                fireEvent(keyword: eventBuffer)
            } else {
                cancelSuggestions()
            }
        }
        return false
    }

    private func isNavigationKey(_ keyCode: UInt16) -> Bool {
        keyCode == 123 || keyCode == 124 || keyCode == 125 || keyCode == 126
    }

    private func isQuickEmojiBoardShortcut(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return event.keyCode == 0x0E
            && flags.contains(.command)
            && flags.contains(.shift)
            && !flags.contains(.option)
            && !flags.contains(.control)
    }

    private func isPrivateControlString(_ string: String) -> Bool {
        guard !string.isEmpty else { return false }
        return string.unicodeScalars.allSatisfy { scalar in
            scalar.value < 0x20 || (0xF700...0xF8FF).contains(scalar.value)
        }
    }

    private func fireEvent(keyword: String) {
        let rangeLength = (appState.triggerCharacter + keyword).utf16.count
        let expectedBuffer = eventBuffer

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            guard let self, self.isTriggered else { return }
            guard self.eventBuffer == expectedBuffer else { return }
            guard let anchorRect = self.textProvider.bestAnchorBoundsBeforeCursor(length: rangeLength) else {
                os_log(.error, log: self.log, "No usable anchor; suppressing popup")
                return
            }
            self.fireIfNew(keyword: keyword, at: anchorRect)
        }
    }

    private func cancelSuggestions() {
        pendingCancelWorkItem?.cancel()
        pendingCancelWorkItem = nil
        isTriggered = false
        eventBuffer = ""
        lastDetectedKeyword = ""
        hasDetectedTrigger = false
        lastFireTime = .distantPast
        DispatchQueue.main.async { [weak self] in
            self?.onTriggerCancelled?()
        }
    }

    private func schedulePollingCancel() {
        guard !isTriggered,
              Date().timeIntervalSince(lastKeyEventTime) >= pollingCancelGrace
        else { return }

        pendingCancelWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  !self.isTriggered,
                  Date().timeIntervalSince(self.lastKeyEventTime) >= self.pollingCancelGrace
            else { return }
            self.cancelSuggestions()
        }
        pendingCancelWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }

    // MARK: — AX polling (reliable fallback)

    private func pollAXContext() {
        guard appState.inlineTriggerEnabled else { return }
        if RulesManager.shared.shouldSuppressInput(appState: appState) {
            resetTriggerSession()
            cancelSuggestions()
            return
        }
        guard let ctx = textProvider.getTextContext() else { return }

        let trigger = appState.triggerCharacter
        let minLen = appState.minTriggerLength
        let allowEmpty = appState.inlinePanelOpenMode == .recents

        guard let keyword = detectTrigger(
            in: ctx.textBeforeCursor,
            triggerChar: trigger,
            minLength: minLen,
            allowEmpty: allowEmpty
        ) else {
            if hasDetectedTrigger || appState.isShowingSuggestions {
                schedulePollingCancel()
            }
            return
        }
        pendingCancelWorkItem?.cancel()
        let rangeLength = (trigger + keyword).utf16.count
        let anchorRect = textProvider.bestAnchorBoundsBeforeCursor(length: rangeLength)
            ?? ctx.cursorScreenBounds
        fireIfNew(keyword: keyword, at: anchorRect)
    }

    // MARK: — Trigger detection + dedup

    private func detectTrigger(
        in text: String,
        triggerChar: String,
        minLength: Int,
        allowEmpty: Bool
    ) -> String? {
        let nsText = text as NSString
        let range = nsText.range(of: triggerChar, options: .backwards)
        guard range.location != NSNotFound else { return nil }
        let afterStart = range.location + range.length
        if afterStart == nsText.length {
            return allowEmpty ? "" : nil
        }
        guard afterStart < nsText.length else { return nil }
        let after = nsText.substring(from: afterStart)
        guard !after.isEmpty, after.count >= minLength else { return nil }
        guard after.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return nil }
        return after
    }

    private func fireIfNew(keyword: String, at anchorRect: CGRect) {
        if appState.isShowingSuggestions && hasDetectedTrigger && keyword == lastDetectedKeyword {
            DispatchQueue.main.async { [weak self] in
                self?.onTriggerDetected?(keyword, anchorRect)
            }
            return
        }
        if hasDetectedTrigger && keyword == lastDetectedKeyword {
            DispatchQueue.main.async { [weak self] in
                self?.onTriggerDetected?(keyword, anchorRect)
            }
            return
        }
        os_log(.info, "FIRE: keyword='%{public}s'", keyword)
        lastDetectedKeyword = keyword
        hasDetectedTrigger = true
        lastFireTime = Date()
        DispatchQueue.main.async { [weak self] in
            self?.onTriggerDetected?(keyword, anchorRect)
        }
    }

    // MARK: — Stop

    func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes) }
        removeGlobalMonitor()
        pollTimer?.invalidate()
        eventTap = nil
        runLoopSource = nil
        pollTimer = nil
        isTriggered = false
        eventBuffer = ""
        lastDetectedKeyword = ""
        hasDetectedTrigger = false
        pendingCancelWorkItem?.cancel()
        isMonitoring = false
    }
}
