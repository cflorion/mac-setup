import Carbon
import PaperlikeCore

// Register one hotkey, without observing keystrokes or requesting Accessibility.
final class HotKey {
    private var key: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let agent: Agent

    init(agent: Agent) {
        self.agent = agent
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                          nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard result == noErr, id.signature == 0x50415052, id.id == 1 else { return OSStatus(eventNotHandledErr) }
            let hotkey = Unmanaged<HotKey>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.global(qos: .userInitiated).async {
                let reply = hotkey.agent.request(["refresh"])
                hotkey.agent.recordShortcutResult(reply)
            }
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
        let result = installed == noErr
            ? RegisterEventHotKey(UInt32(kVK_ANSI_R), UInt32(controlKey | optionKey | cmdKey),
                                  EventHotKeyID(signature: 0x50415052, id: 1), GetApplicationEventTarget(), 0, &key)
            : installed
        agent.recordShortcutRegistration(result)
    }

    deinit {
        if let key { UnregisterEventHotKey(key) }
        if let handler { RemoveEventHandler(handler) }
    }
}
