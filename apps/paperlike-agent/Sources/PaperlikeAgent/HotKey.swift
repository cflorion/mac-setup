import Carbon
import PaperlikeCore

// Registers the configured shortcuts through RegisterEventHotKey: the agent
// never observes keystrokes and never needs Accessibility permission. Each
// binding's outcome is reported, because a shortcut already taken by another
// application fails silently otherwise.
final class HotKeyCenter {
    private struct Registered { let binding: HotKeyBinding; var ref: EventHotKeyRef? }

    private static let signature: OSType = 0x50415052   // 'PAPR'
    private var registered: [UInt32: Registered] = [:]
    private var handler: EventHandlerRef?
    private let agent: Agent

    init(agent: Agent, bindings: [HotKeyBinding]) {
        self.agent = agent
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let read = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                         nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard read == noErr, id.signature == HotKeyCenter.signature else { return OSStatus(eventNotHandledErr) }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(context).takeUnretainedValue()
            guard let entry = center.registered[id.id] else { return OSStatus(eventNotHandledErr) }
            // The serial exchange takes a few hundred milliseconds; keeping it off
            // the main run loop leaves the rest of the system responsive.
            DispatchQueue.global(qos: .userInitiated).async {
                center.agent.recordShortcutResult(entry.binding.keys, center.agent.request(entry.binding.action))
            }
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)

        var results: [(HotKeyBinding, OSStatus)] = []
        for (index, binding) in bindings.enumerated() {
            let id = UInt32(index + 1)
            guard installed == noErr else { results.append((binding, installed)); continue }
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(binding.keyCode, binding.modifiers,
                                             EventHotKeyID(signature: HotKeyCenter.signature, id: id),
                                             GetApplicationEventTarget(), 0, &ref)
            if status == noErr { registered[id] = Registered(binding: binding, ref: ref) }
            results.append((binding, status))
        }
        agent.recordShortcutRegistrations(results)
    }

    deinit {
        for entry in registered.values { if let ref = entry.ref { UnregisterEventHotKey(ref) } }
        if let handler { RemoveEventHandler(handler) }
    }
}
