import AVFoundation

/// Listens to the microphone and says which note it hears, and how far off it is.
@Observable
final class Tuner {
    enum Status {
        case idle, listening, noPermission, failed

        var message: String {
            switch self {
            case .idle, .listening: ""
            case .noPermission: "MICROPHONE ACCESS IS OFF: TURN IT ON IN SETTINGS"
            case .failed: "COULDN'T START THE MICROPHONE"
            }
        }
    }

    struct Reading: Equatable {
        let frequency: Double
        let note: Note
        /// How far off the note, from −50 (flat) to +50 (sharp).
        let cents: Double

        /// Within this many cents counts as in tune.
        static let inTuneCents = 10.0
        var isInTune: Bool { abs(cents) < Self.inTuneCents }
    }

    /// A moment in the recent past, for drawing the pitch trail.
    struct Moment {
        let time: Date
        /// Nil while nothing was sounding, which leaves a gap in the trail.
        let reading: Reading?
        /// `reading`'s cents eased over time, so the trail glides rather than jitters.
        let smoothedCents: Double
    }

    /// How far back `history` goes, in seconds.
    static let historyLength = 6.0
    /// How far the trail moves towards each new reading, from 0 (not at all) to 1 (all the way).
    /// Lower is smoother but slower to follow.
    static let trailEasing = 0.5

    private(set) var status = Status.idle
    /// The last note heard. It stays after the sound stops, so it can still be read.
    private(set) var reading: Reading?
    /// Whether a note is sounding right now.
    private(set) var isHearing = false
    /// What was heard over the last few seconds, oldest first.
    private(set) var history: [Moment] = []
    /// The frequency of A4 that every note is measured against.
    var reference = 440.0

    private var engine: AVAudioEngine?
    private var observers: [NSObjectProtocol] = []
    /// Recent pitches as fractional note numbers, for smoothing out jitter.
    private var recent: [Double] = []
    /// Readings in a row with no pitch, so one dropout doesn't blank the display.
    private var misses = 0

    func start() async {
        guard engine == nil else { return }
        guard await AVAudioApplication.requestRecordPermission() else {
            status = .noPermission
            return
        }
        do {
            try startEngine()
            status = .listening
        } catch {
            stop()
            status = .failed
        }
    }

    func stop() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        #if !os(macOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        isHearing = false
        recent = []
        history = []
        status = .idle
    }

    private func startEngine() throws {
        #if !os(macOS)
        let session = AVAudioSession.sharedInstance()
        // Measurement mode turns off the voice processing that would colour the sound.
        try session.setCategory(.record, mode: .measurement)
        try session.setActive(true)
        #endif

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw CocoaError(.featureUnsupported) }

        let listener = Listener(sampleRate: format.sampleRate) { [weak self] frequency in
            let tuner = self
            Task { @MainActor in tuner?.hear(frequency) }
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            listener.process(buffer)
        }
        try engine.start()
        self.engine = engine

        #if !os(macOS)
        // A phone call or another app can take the microphone away; pick up again afterwards.
        observers.append(NotificationCenter.default.addObserver(
            forName: AVAudioSession.resumptionRecommendationNotification, object: session, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let engine = self?.engine else { return }
                try? AVAudioSession.sharedInstance().setActive(true)
                try? engine.start()
            }
        })
        #endif
    }

    private func hear(_ frequency: Double?) {
        guard engine != nil else { return }
        guard let frequency else {
            misses += 1
            if misses >= 3 {
                if isHearing { remember(nil) }
                isHearing = false
                recent = []
            }
            return
        }
        misses = 0
        let position = 69 + 12 * log2(frequency / reference)
        // A jump of more than a semitone is a new note: start smoothing afresh.
        if let last = recent.last, abs(position - last) > 1 { recent = [] }
        recent = Array((recent + [position]).suffix(5))
        let smoothed = recent.sorted()[recent.count / 2]  // median, so one stray reading can't pull it

        let number = Int(smoothed.rounded())
        reading = Reading(
            frequency: reference * pow(2, (smoothed - 69) / 12),
            note: Note(number: number),
            cents: (smoothed - Double(number)) * 100
        )
        isHearing = true
        remember(reading)
    }

    private func remember(_ reading: Reading?) {
        let now = Date()
        var smoothed = reading?.cents ?? 0
        // Ease from where the trail was, unless it's a new note or the sound just started.
        if let reading, let last = history.last, let lastReading = last.reading, lastReading.note == reading.note {
            smoothed = last.smoothedCents + (reading.cents - last.smoothedCents) * Self.trailEasing
        }
        history.append(Moment(time: now, reading: reading, smoothedCents: smoothed))
        if let first = history.firstIndex(where: { now.timeIntervalSince($0.time) < Self.historyLength }), first > 0 {
            history.removeFirst(first - 1)  // keep one older moment, so the trail runs off the end
        }
    }
}

/// Collects microphone samples into overlapping windows and finds the pitch of each,
/// off the main thread. Only ever touched by the audio tap, one buffer at a time.
private nonisolated final class Listener: @unchecked Sendable {
    static let windowLength = 4096
    /// A new reading every 2048 samples: about 23 a second at 48 kHz.
    static let hopLength = 2048

    private let sampleRate: Double
    private let report: @Sendable (Double?) -> Void
    private var samples: [Float] = []

    init(sampleRate: Double, report: @escaping @Sendable (Double?) -> Void) {
        self.sampleRate = sampleRate
        self.report = report
        samples.reserveCapacity(Self.windowLength * 2)
    }

    func process(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        while samples.count >= Self.windowLength {
            let frequency = samples.withUnsafeBufferPointer {
                Pitch.frequency(of: UnsafeBufferPointer(rebasing: $0.prefix(Self.windowLength)), sampleRate: sampleRate)
            }
            report(frequency)
            samples.removeFirst(Self.hopLength)
        }
    }
}
