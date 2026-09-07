import SwiftUI

enum V {
    static let background = Color(red: 0.035, green: 0.043, blue: 0.043)
    static let panel = Color(red: 0.073, green: 0.086, blue: 0.086)
    static let signal = Color(red: 0.80, green: 0.94, blue: 0.36)
    static let muted = Color(red: 0.60, green: 0.65, blue: 0.63)
    static let blue = Color(red: 0.48, green: 0.71, blue: 0.84)
    static let orange = Color(red: 0.95, green: 0.57, blue: 0.35)
}
struct Panel<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View { VStack(alignment: .leading, spacing: 18) { content }.frame(maxWidth: .infinity, alignment: .leading).padding(22).background(V.panel, in: RoundedRectangle(cornerRadius: 20)) }
}
struct Eyebrow: View {
    let text: String
    var body: some View { Text(text.uppercased()).font(.system(.caption2, design: .monospaced, weight: .medium)).tracking(2).foregroundStyle(V.muted) }
}
struct Page<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) { Eyebrow(text: subtitle); Text(title).font(.system(.largeTitle, weight: .bold)).tracking(-1) }.padding(.top, 16)
                content
            }.padding(.horizontal, 20).padding(.bottom, 30)
        }.background(V.background)
    }
}
struct Metric: View {
    let label: String
    let value: String
    let unit: String
    var color: Color = .white
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Eyebrow(text: label)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(size: 38, weight: .semibold, design: .rounded)).monospacedDigit().minimumScaleFactor(0.6)
                Text(unit).font(.caption).foregroundStyle(V.muted)
            }.foregroundStyle(color)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct SignalBar: View {
    let value: Double
    var color: Color = V.signal
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 3) {
                ForEach(0..<32) { index in Rectangle().fill(Double(index) < max(0, min(1, value)) * 32 ? color : Color.white.opacity(0.08)) }
            }.frame(width: geometry.size.width, height: 12)
        }.frame(height: 12).accessibilityLabel("\(Int(value * 100)) percent")
    }
}
extension Double {
    var oneDecimal: String { formatted(.number.precision(.fractionLength(1))) }
}
