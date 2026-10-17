import Accelerate

/// A note of the 12-tone scale, numbered as in MIDI (A4 = 69).
nonisolated struct Note: Equatable, Sendable {
    static let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]

    let number: Int

    var name: String { Self.names[(number % 12 + 12) % 12] }
    var octave: Int { Int((Double(number) / 12).rounded(.down)) - 1 }

    /// The nearest note to `frequency`, and how far off it is in cents (−50 to +50).
    static func nearest(to frequency: Double, reference: Double = 440) -> (note: Note, cents: Double) {
        let position = 69 + 12 * log2(frequency / reference)
        let number = Int(position.rounded())
        return (Note(number: number), (position - Double(number)) * 100)
    }
}

/// Finds the pitch of a sound with the YIN algorithm (de Cheveigné & Kawahara, 2002),
/// which looks for how often the waveform repeats. Overtones don't fool it the way they fool
/// picking the loudest frequency, so it hears a guitar's low E as E, not its octave.
nonisolated enum Pitch {
    /// The range we listen for: a piano's lowest A to a little above its highest C.
    static let lowest = 26.0
    static let highest = 4500.0
    /// Quieter than this (RMS) counts as silence.
    static let silence: Float = 0.003
    /// How clearly the sound must repeat; lower is stricter.
    static let threshold: Float = 0.15

    /// The frequency in Hz, or nil if the sound is too quiet or has no clear pitch.
    /// Needs at least two periods of the lowest note: 4096 samples at 48 kHz.
    static func frequency(of samples: UnsafeBufferPointer<Float>, sampleRate: Double) -> Double? {
        guard let x = samples.baseAddress else { return nil }
        let half = samples.count / 2

        var rms: Float = 0
        vDSP_rmsqv(x, 1, &rms, vDSP_Length(samples.count))
        guard rms > silence else { return nil }

        let minLag = max(2, Int(sampleRate / highest))
        let maxLag = min(half - 2, Int(sampleRate / lowest))
        guard minLag < maxLag else { return nil }

        // How different the sound is from itself, shifted along by each lag.
        var difference = [Float](repeating: 0, count: maxLag + 2)
        for lag in 1...maxLag + 1 {
            vDSP_distancesq(x, 1, x + lag, 1, &difference[lag], vDSP_Length(half))
        }

        // The same, divided by its running average, so the threshold works at any volume.
        var normalised = [Float](repeating: 1, count: difference.count)
        var total: Float = 0
        for lag in 1..<difference.count {
            total += difference[lag]
            if total > 0 { normalised[lag] = difference[lag] * Float(lag) / total }
        }

        // The first dip below the threshold, followed down to its bottom, is one period.
        var lag = minLag
        while lag < maxLag, normalised[lag] >= threshold { lag += 1 }
        guard lag < maxLag else { return nil }
        while lag + 1 < maxLag, normalised[lag + 1] < normalised[lag] { lag += 1 }

        // Fit a parabola through the dip to find the period between samples.
        let a = difference[lag - 1], b = difference[lag], c = difference[lag + 1]
        let curve = a - 2 * b + c
        let shift = curve > 0 ? Double((a - c) / (2 * curve)) : 0
        return sampleRate / (Double(lag) + shift)
    }
}
