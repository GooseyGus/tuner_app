import SwiftUI

/// The last few seconds of pitch as a line running down the screen: the newest reading at the
/// top, flat to the left and sharp to the right (lined up with the meter above), coloured by
/// whether each moment was in tune. It breaks where the sound stopped or the note changed.
/// The line is eased and curved for looks; the note and meter above stay exact.
struct PitchTrail: View {
    let history: [Tuner.Moment]
    let palette: Palette
    var lineWidth: CGFloat = 4

    var body: some View {
        let tolerance = Tuner.Reading.inTuneCents
        ZStack {
            // The in-tune lane and the centre line.
            Canvas { context, size in
                let x = { (cents: Double) in size.width / 2 + size.width / 2 * cents / 50 }
                context.fill(
                    Path(CGRect(x: x(-tolerance), y: 0, width: x(tolerance) - x(-tolerance), height: size.height)),
                    with: .color(palette.inTune.opacity(0.12))
                )
                context.fill(
                    Path(CGRect(x: x(0) - 1, y: 0, width: 2, height: size.height)),
                    with: .color(palette.text.opacity(0.25))
                )
            }

            TimelineView(.animation(paused: history.isEmpty)) { timeline in
                Canvas { context, size in
                    let now = timeline.date
                    let x = { (cents: Double) in size.width / 2 + size.width / 2 * cents / 50 }
                    let y = { (time: Date) in now.timeIntervalSince(time) / Tuner.historyLength * size.height }

                    for run in runs {
                        let points = run.map { CGPoint(x: x($0.smoothedCents), y: y($0.time)) }
                        // Curves bent towards each reading, joining the midpoints either side of it,
                        // so the line flows instead of zigzagging. Each stretch of one colour is
                        // stroked as a single path, so there are no seams where pieces overlap.
                        var path = Path()
                        var pathInTune: Bool?
                        for i in points.indices {
                            let start = i == 0 ? points[i] : midpoint(points[i - 1], points[i])
                            let end = i == points.count - 1 ? points[i] : midpoint(points[i], points[i + 1])
                            let inTune = abs(run[i].smoothedCents) < tolerance
                            if inTune != pathInTune {
                                if let pathInTune { stroke(path, inTune: pathInTune, in: context) }
                                path = Path()
                                path.move(to: start)
                                pathInTune = inTune
                            }
                            path.addQuadCurve(to: end, control: points[i])
                        }
                        if let pathInTune { stroke(path, inTune: pathInTune, in: context) }
                    }
                }
            }
            // Older is lower, so fading towards the bottom fades it with age.
            .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
        }
        .accessibilityHidden(true)
    }

    private func stroke(_ path: Path, inTune: Bool, in context: GraphicsContext) {
        context.stroke(
            path,
            with: .color(inTune ? palette.inTune : palette.offPitch),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )
    }

    /// The history split into unbroken stretches of one note.
    private var runs: [[Tuner.Moment]] {
        var runs: [[Tuner.Moment]] = []
        var current: [Tuner.Moment] = []
        for moment in history {
            guard let reading = moment.reading else {
                if !current.isEmpty { runs.append(current) }
                current = []
                continue
            }
            if let last = current.last?.reading, last.note != reading.note {
                runs.append(current)
                current = []
            }
            current.append(moment)
        }
        if !current.isEmpty { runs.append(current) }
        return runs
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}
