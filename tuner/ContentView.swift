import SwiftUI

struct ContentView: View {
    @AppStorage("paletteIndex") private var paletteIndex = 0
    @State private var tuner = Tuner()
    @Environment(\.scenePhase) private var scenePhase

    private var palette: Palette { Palette.all[paletteIndex % Palette.all.count] }

    /// The colour the whole screen glows while a note sounds: in tune, or flat/sharp.
    private var glow: Color? {
        guard tuner.isHearing, let reading = tuner.reading else { return nil }
        return reading.isInTune ? palette.inTune : palette.offPitch
    }

    var body: some View {
        VStack(spacing: 24) {
            header
            noteDisplay
                .padding(.top, 16)
            CentsMeter(cents: tuner.reading?.cents, palette: palette)
                .frame(height: 64)
                .opacity(tuner.isHearing ? 1 : 0.35)
            PitchTrail(history: tuner.history, palette: palette)
                .frame(maxHeight: .infinity)
            if !tuner.status.message.isEmpty {
                Text(tuner.status.message)
                    .font(.system(size: 13,  weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(palette.offPitch)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .foregroundStyle(palette.text)
        .background {
            palette.background
                .mix(with: glow ?? palette.background, by: 0.5, in: .perceptual)
                .animation(.easeOut(duration: 0.15), value: glow)
                .ignoresSafeArea()
        }
        .preferredColorScheme(palette.scheme)
        // Only listen while the app is on screen.
        .onChange(of: scenePhase, initial: true) {
            if scenePhase == .active {
                Task { await tuner.start() }
            } else {
                tuner.stop()
            }
        }
    }

    private var header: some View {
        HStack {
            Text("TUNER APP")
                .font(.system(size: 22, weight: .black))
                .tracking(3)
            Spacer()
            PressButton(action: { paletteIndex = (paletteIndex + 1) % Palette.all.count }) {
                // Shows the current palette as four stripes.
                HStack(spacing: 0) {
                    ForEach(palette.swatch.indices, id: \.self) { i in
                        Rectangle().fill(palette.swatch[i])
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(palette.text, lineWidth: 1))
            }
            .frame(width: 64, height: 44)
            .accessibilityLabel("Change colour palette")
        }
    }

    private var noteDisplay: some View {
        let reading = tuner.reading
        return VStack(spacing: 8) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(reading?.note.name ?? "–")
                    .font(.system(size: 140, weight: .black))
                Text(reading.map { "\($0.note.octave)" } ?? "")
                    .font(.system(size: 40, weight: .black))
            }
            .contentTransition(.identity)

            Text(reading.map { $0.isInTune ? "IN TUNE" : centsLabel($0.cents) } ?? "PLAY A NOTE")
                .font(.system(size: 20, weight: .heavy))
                .tracking(2)
            Text(reading.map { String(format: "%.1f HZ", $0.frequency) } ?? " ")
                .font(.system(size: 15, weight: .bold).monospacedDigit())
                .opacity(0.6)
        }
        .opacity(tuner.isHearing || reading == nil ? 1 : 0.35)
        .accessibilityElement(children: .combine)
    }

    private func centsLabel(_ cents: Double) -> String {
        let rounded = Int(cents.rounded())
        return rounded < 0 ? "\(-rounded)¢ FLAT" : "\(rounded)¢ SHARP"
    }
}

/// A strip from 50 cents flat to 50 cents sharp, with a needle at the current reading.
struct CentsMeter: View {
    let cents: Double?
    let palette: Palette

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width, height = geometry.size.height
            let x = { (cents: Double) in width / 2 + width / 2 * cents / 50 }
            let tolerance = Tuner.Reading.inTuneCents
            ZStack(alignment: .topLeading) {
                // The in-tune zone.
                RoundedRectangle(cornerRadius: 4)
                    .fill(palette.inTune.opacity(0.35))
                    .frame(width: x(tolerance) - x(-tolerance), height: height)
                    .offset(x: x(-tolerance))
                // A tick every 10 cents; longer at the centre.
                ForEach(-5...5, id: \.self) { i in
                    let tall = i == 0
                    Rectangle()
                        .fill(palette.text.opacity(tall ? 1 : 0.5))
                        .frame(width: tall ? 3 : 2, height: height * (tall ? 0.7 : 0.4))
                        .offset(x: x(Double(i * 10)) - (tall ? 1.5 : 1), y: height * (tall ? 0.15 : 0.3))
                }
                if let cents {
                    Capsule()
                        .fill(abs(cents) < tolerance ? palette.inTune : palette.offPitch)
                        .overlay(Capsule().strokeBorder(palette.text, lineWidth: 1.5))
                        .frame(width: 10, height: height)
                        .offset(x: x(cents) - 5)
                        .animation(.easeOut(duration: 0.08), value: cents)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Tuning")
        .accessibilityValue(cents.map { "\(Int($0.rounded())) cents" } ?? "No note")
    }
}

#Preview {
    ContentView()
}
