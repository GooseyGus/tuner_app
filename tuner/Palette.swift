import SwiftUI

/// A colour scheme for the whole app, with each colour assigned a role.
struct Palette {
    /// The four source colours, shown as stripes on the palette button.
    let swatch: [Color]
    /// Light or dark, so the status bar stays readable.
    let scheme: ColorScheme
    let background: Color
    let text: Color
    /// In tune.
    let accent: Color
    let accentText: Color
    /// Off pitch, and the needle.
    let highlight: Color
    let highlightText: Color
    /// Buttons and quieter elements.
    let control: Color
    let controlText: Color
    /// The note is in tune: the screen glows with this.
    let inTune: Color
    /// The note is flat or sharp.
    let offPitch: Color

    init(
        swatch: [UInt32], scheme: ColorScheme,
        background: UInt32, text: UInt32,
        accent: UInt32, accentText: UInt32,
        highlight: UInt32, highlightText: UInt32,
        control: UInt32, controlText: UInt32,
        inTune: UInt32, offPitch: UInt32
    ) {
        self.swatch = swatch.map(Color.init(hex:))
        self.scheme = scheme
        self.background = Color(hex: background)
        self.text = Color(hex: text)
        self.accent = Color(hex: accent)
        self.accentText = Color(hex: accentText)
        self.highlight = Color(hex: highlight)
        self.highlightText = Color(hex: highlightText)
        self.control = Color(hex: control)
        self.controlText = Color(hex: controlText)
        self.inTune = Color(hex: inTune)
        self.offPitch = Color(hex: offPitch)
    }

    static let all = [
        // Navy
        Palette(
            swatch: [0x0A2947, 0x8B5E3C, 0xD3D4C0, 0xF3E4C9], scheme: .dark,
            background: 0x0A2947, text: 0xF3E4C9,
            accent: 0x8B5E3C, accentText: 0xF3E4C9,
            highlight: 0xD3D4C0, highlightText: 0x0A2947,
            control: 0xD3D4C0, controlText: 0x0A2947,
            inTune: 0x6FA36B, offPitch: 0xC9544A
        ),
        // Valve: warm charcoal, amber lamp glow and bone, like an old valve amp.
        Palette(
            swatch: [0x1C1A17, 0x3A352F, 0xD9822B, 0xEDE3CF], scheme: .dark,
            background: 0x1C1A17, text: 0xEDE3CF,
            accent: 0xD9822B, accentText: 0x1C1A17,
            highlight: 0xEDE3CF, highlightText: 0x1C1A17,
            control: 0x3A352F, controlText: 0xEDE3CF,
            inTune: 0x9DB35A, offPitch: 0xD0482E
        ),
        // Harbour: deep sea teal with a rust accent.
        Palette(
            swatch: [0x102B30, 0xC86B3C, 0xCFD2BE, 0xF2E8D5], scheme: .dark,
            background: 0x102B30, text: 0xF2E8D5,
            accent: 0xC86B3C, accentText: 0xF2E8D5,
            highlight: 0xCFD2BE, highlightText: 0x102B30,
            control: 0xCFD2BE, controlText: 0x102B30,
            inTune: 0x5FB08E, offPitch: 0xD05A3C
        ),
        // Forest: pine green and brass.
        Palette(
            swatch: [0x1E2B23, 0x35473B, 0xC9A043, 0xEFE7D4], scheme: .dark,
            background: 0x1E2B23, text: 0xEFE7D4,
            accent: 0xC9A043, accentText: 0x1E2B23,
            highlight: 0xEFE7D4, highlightText: 0x1E2B23,
            control: 0x35473B, controlText: 0xEFE7D4,
            inTune: 0x8CBF62, offPitch: 0xC8553E
        ),
        // Oxblood: dark burgundy leather and mustard.
        Palette(
            swatch: [0x2E1215, 0x4A2328, 0xD9A55B, 0xF2E6D3], scheme: .dark,
            background: 0x2E1215, text: 0xF2E6D3,
            accent: 0xD9A55B, accentText: 0x2E1215,
            highlight: 0xF2E6D3, highlightText: 0x2E1215,
            control: 0x4A2328, controlText: 0xF2E6D3,
            inTune: 0x93B36B, offPitch: 0xE0644F
        ),
        // Olive: army-surplus olive with a burnt orange accent.
        Palette(
            swatch: [0x2A2B1E, 0x45472F, 0xC4622D, 0xEDE6D0], scheme: .dark,
            background: 0x2A2B1E, text: 0xEDE6D0,
            accent: 0xC4622D, accentText: 0xEDE6D0,
            highlight: 0xEDE6D0, highlightText: 0x2A2B1E,
            control: 0x45472F, controlText: 0xEDE6D0,
            inTune: 0xA6BC5E, offPitch: 0xD14A2E
        ),
        // Espresso: dark roast brown, caramel and milk.
        Palette(
            swatch: [0x261B16, 0x3E2E25, 0xC07A48, 0xF4EBDD], scheme: .dark,
            background: 0x261B16, text: 0xF4EBDD,
            accent: 0xC07A48, accentText: 0x261B16,
            highlight: 0xD8C3A5, highlightText: 0x261B16,
            control: 0x3E2E25, controlText: 0xF4EBDD,
            inTune: 0x93A862, offPitch: 0xCC5640
        ),
        // Slate
        Palette(
            swatch: [0x37353E, 0x44444E, 0x715A5A, 0xD3DAD9], scheme: .dark,
            background: 0x37353E, text: 0xD3DAD9,
            accent: 0x715A5A, accentText: 0xD3DAD9,
            highlight: 0xD3DAD9, highlightText: 0x37353E,
            control: 0x44444E, controlText: 0xD3DAD9,
            inTune: 0x7FAE8C, offPitch: 0xC0626A
        ),
    ]
}

extension Color {
    nonisolated init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
