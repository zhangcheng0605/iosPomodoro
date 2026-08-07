import AVFoundation
import Foundation

/// The music channel.
///
/// This exists as its own engine rather than another `AVAudioPlayer` because
/// AAC cannot be looped gaplessly by a file player: the encoder prepends
/// priming frames and pads the tail, so every repeat ticks. Decoding once into
/// a buffer, trimming it to the exact loop length the generator recorded, and
/// scheduling that buffer with `.loops` is sample-accurate and runs forever
/// with no further work.
///
/// Two player nodes, so changing track can crossfade instead of cutting.
final class MusicPlayer {
    static let shared = MusicPlayer()

    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private var players: [AVAudioPlayerNode] = [AVAudioPlayerNode(), AVAudioPlayerNode()]
    private var active = 0
    private var buffers: [String: AVAudioPCMBuffer] = [:]

    private(set) var current: MusicTrack?
    private var started = false
    private var radioTask: Task<Void, Never>?
    /// The format the player nodes are currently wired to the mixer with.
    ///
    /// This has to equal the scheduled buffer's format exactly. See
    /// `startEngineIfNeeded(format:)` — getting it wrong is fatal, not
    /// degraded.
    private var connectedFormat: AVAudioFormat?
    private var sessionConfigured = false
    private var nodesAttached = false
    private var configObserver: NSObjectProtocol?
    /// Most-recently-used track ids, oldest first.
    private var bufferOrder: [String] = []

    /// A decoded track is ~2.4 MB of float samples (27 s, mono, 22.05 kHz).
    /// Keeping all fifty would be roughly 120 MB of dirty memory held for the
    /// life of the app — and radio mode walks the whole catalogue on its own,
    /// so it is reachable without the user doing anything unusual. Three is
    /// enough for a crossfade plus the track behind it.
    private static let maxCachedBuffers = 3

    /// Radio asks for the next track when the current one has gone round a few
    /// times. Rotating on phase boundaries instead would leave a 27-second loop
    /// repeating fifty times inside one focus session, which is the very thing
    /// radio exists to fix.
    var nextForRadio: (() -> MusicTrack?)?

    /// 0...1, applied on top of whatever each node is doing.
    var volume: Float = 0.7 {
        didSet { mixer.outputVolume = volume }
    }

    private init() {}

    // MARK: Transport

    func play(_ track: MusicTrack, crossfade: TimeInterval = 1.6) {
        guard track != current else { return }
        guard let buffer = buffer(for: track) else { return }
        guard startEngineIfNeeded(format: buffer.format) else { return }
        // Belt and braces: `scheduleBuffer` raises an Objective-C exception on
        // a format mismatch, and Swift cannot catch it — the process dies. If
        // the wiring somehow didn't take, drop the track instead of the app.
        guard let connectedFormat, connectedFormat.isEqual(buffer.format) else { return }

        let outgoing = players[active]
        active = (active + 1) % players.count
        let incoming = players[active]

        incoming.stop()
        incoming.volume = 0
        incoming.scheduleBuffer(buffer, at: nil, options: [.loops])
        incoming.play()

        current = track
        ramp(incoming, to: 1, over: crossfade)
        if outgoing.isPlaying {
            ramp(outgoing, to: 0, over: crossfade) { outgoing.stop() }
        }
        scheduleRadioRotation(after: track)
    }

    private func scheduleRadioRotation(after track: MusicTrack) {
        radioTask?.cancel()
        guard nextForRadio != nil else { return }
        let seconds = Double(track.loopFrames) / 22_050.0 * 3.0
        radioTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled, let self, let next = self.nextForRadio?() else { return }
            self.play(next, crossfade: 2.4)
        }
    }

    func stop(fade: TimeInterval = 0.6) {
        radioTask?.cancel()
        current = nil
        for player in players where player.isPlaying {
            ramp(player, to: 0, over: fade) { player.stop() }
        }
    }

    /// Called when the app is backgrounded: iOS tears the engine down anyway,
    /// and holding it running is the sort of thing that gets an app rejected.
    func suspend() {
        radioTask?.cancel()
        guard started else { return }
        for player in players { player.stop() }
        engine.pause()
    }

    func resumeIfNeeded() {
        guard started, let current else { return }
        // Rebuild from scratch rather than guessing the engine's state.
        let track = current
        self.current = nil
        play(track, crossfade: 0.4)
    }

    // MARK: Plumbing

    /// Brings the engine up, wired for exactly this buffer format.
    ///
    /// The player→mixer connection **must** carry the buffer's own format.
    /// Connecting with `nil` uses the hardware's format instead — stereo
    /// 48 kHz on an iPhone — and every track here is mono 22.05 kHz. The
    /// mismatch only shows on a device, because the Simulator happens to
    /// negotiate a compatible format, and it kills the app rather than
    /// failing quietly: `scheduleBuffer` raises
    /// `_outputFormat.channelCount == buffer.format.channelCount`.
    ///
    /// The mixer→main connection stays `nil` on purpose: an `AVAudioMixerNode`
    /// is the thing that *does* the sample-rate conversion, so that is where
    /// the two worlds are allowed to meet.
    private func startEngineIfNeeded(format: AVAudioFormat) -> Bool {
        configureSessionIfNeeded()

        // Attachment is tracked separately from `started`: if `engine.start()`
        // ever fails, `started` goes back to false, and attaching an
        // already-attached node the next time round is its own exception.
        if !nodesAttached {
            for player in players {
                engine.attach(player)
            }
            engine.attach(mixer)
            nodesAttached = true
            observeConfigurationChanges()
        }

        if connectedFormat == nil || !connectedFormat!.isEqual(format) {
            // Both hops are rebuilt: a configuration change tears the whole
            // graph down, not just the half we own.
            engine.connect(mixer, to: engine.mainMixerNode, format: nil)
            for player in players {
                player.stop()
                engine.disconnectNodeOutput(player)
                engine.connect(player, to: mixer, format: format)
            }
            connectedFormat = format
        }

        mixer.outputVolume = volume

        // `suspend()` pauses the engine, and a paused engine cannot start a
        // player node — that throws too. Always confirm it is actually
        // running rather than trusting `started`.
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                started = false
                return false
            }
        }
        started = true
        return engine.isRunning
    }

    /// Records a track as most recently used, and drops the coldest buffers
    /// once there are more than `maxCachedBuffers` of them.
    ///
    /// The track currently playing is never evicted — its buffer is scheduled
    /// on a live player node, and the loop reads from it forever.
    private func cache(_ buffer: AVAudioPCMBuffer, for id: String) {
        buffers[id] = buffer
        touch(id)
        while bufferOrder.count > Self.maxCachedBuffers,
              let coldest = bufferOrder.first(where: { $0 != current?.id }) {
            bufferOrder.removeAll { $0 == coldest }
            buffers.removeValue(forKey: coldest)
        }
    }

    private func touch(_ id: String) {
        bufferOrder.removeAll { $0 == id }
        bufferOrder.append(id)
    }

    /// Unplugging headphones, or a Bluetooth device arriving, changes the
    /// hardware format and makes the engine throw its graph away. The cached
    /// `connectedFormat` would then be a lie, and the next `scheduleBuffer`
    /// would raise exactly the exception this class exists to avoid.
    private func observeConfigurationChanges() {
        guard configObserver == nil else { return }
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.connectedFormat = nil
            guard let track = self.current else { return }
            self.current = nil
            self.play(track, crossfade: 0.3)
        }
    }

    /// Music shares the session with the ambience channel, on the same
    /// category, so the two layer instead of interrupting one another.
    private func configureSessionIfNeeded() {
        guard !sessionConfigured else { return }
        sessionConfigured = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default)
        try? session.setActive(true)
    }

    /// Decodes the track once and trims it to the generator's exact loop
    /// length, dropping the encoder's priming frames.
    private func buffer(for track: MusicTrack) -> AVAudioPCMBuffer? {
        if let cached = buffers[track.id] {
            touch(track.id)
            return cached
        }
        guard let url = Self.url(for: track),
              let file = try? AVAudioFile(forReading: url)
        else { return nil }

        let format = file.processingFormat
        let capacity = AVAudioFrameCount(file.length)
        guard capacity > 0,
              let decoded = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity),
              (try? file.read(into: decoded)) != nil
        else { return nil }

        let wanted = AVAudioFrameCount(track.loopFrames)
        guard decoded.frameLength > wanted,
              let trimmed = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: wanted)
        else {
            cache(decoded, for: track.id)
            return decoded
        }

        // Priming frames sit at the *start*; any remaining excess is trailing
        // padding. Splitting the difference would land the loop point half a
        // priming block late. In practice CoreAudio already reports the exact
        // length and this path doesn't run — it's here so a decoder that
        // doesn't still loops cleanly.
        let priming = min(AVAudioFrameCount(2112), decoded.frameLength - wanted)
        let channels = Int(format.channelCount)
        if let source = decoded.floatChannelData, let destination = trimmed.floatChannelData {
            for channel in 0..<channels {
                destination[channel].update(
                    from: source[channel] + Int(priming),
                    count: Int(wanted)
                )
            }
        }
        trimmed.frameLength = wanted
        cache(trimmed, for: track.id)
        return trimmed
    }

    private static func url(for track: MusicTrack) -> URL? {
        Bundle.main.url(forResource: track.assetName, withExtension: "m4a")
            ?? Bundle.main.url(forResource: track.assetName, withExtension: "m4a", subdirectory: "Music")
    }

    /// Equal-power-ish volume ramp on the node itself. `AVAudioPlayerNode`
    /// has no built-in fade, and a linear jump is audible.
    private func ramp(
        _ player: AVAudioPlayerNode,
        to target: Float,
        over seconds: TimeInterval,
        then finished: (@Sendable () -> Void)? = nil
    ) {
        let steps = max(1, Int(seconds * 30))
        let from = player.volume
        Task { @MainActor in
            for step in 1...steps {
                let progress = Float(step) / Float(steps)
                player.volume = from + (target - from) * progress
                try? await Task.sleep(nanoseconds: UInt64(seconds / Double(steps) * 1_000_000_000))
            }
            player.volume = target
            finished?()
        }
    }
}
