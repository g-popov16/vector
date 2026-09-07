import SwiftUI
import Charts
import UIKit

struct HealthMonitorView: View {
    @Environment(AppStore.self) private var store
    @State private var window = 30
    @State private var report: URL?
    var body: some View {
        Page(title: "Know your normal.", subtitle: "Health monitor / latest available") {
            Picker("Trend window", selection: $window) { Text("30 days").tag(30); Text("180 days").tag(180) }.pickerStyle(.segmented)
            if store.snapshot.readings.isEmpty { Text("Connect Apple Health and allow the metrics you want to see. Some readings depend on Watch settings and regional availability.").foregroundStyle(V.muted) }
            ForEach(store.snapshot.readings) { reading in
                Panel {
                    Metric(label: reading.id, value: reading.value.oneDecimal, unit: reading.unit, color: reading.date < Date().addingTimeInterval(-86400) ? V.orange : V.signal)
                    Text("\(reading.date.formatted(date: .abbreviated, time: .shortened)) · \(reading.source)").font(.caption).foregroundStyle(V.muted)
                }
            }
            Panel {
                Eyebrow(text: "Resting heart rate / \(window) days")
                Chart(store.snapshot.history.filter { $0.date >= Date().addingTimeInterval(-Double(window) * 86400) }) { day in
                    if let rhr = day.restingHR { LineMark(x: .value("Date", day.date), y: .value("bpm", rhr)).foregroundStyle(V.signal) }
                }.frame(height: 180)
                Text("Latest readings are not a continuous live monitor. Wrist temperature is an overnight measurement, not core body temperature.").font(.caption).foregroundStyle(V.muted)
            }
            Button("Create health summary PDF", systemImage: "doc") {
                do { report = try HealthReport.create(store: store) }
                catch { store.message = "PDF export failed: \(error.localizedDescription)" }
            }.buttonStyle(.borderedProminent)
            if let report { ShareLink("Share health summary", item: report) }
        }
    }
}
@MainActor enum HealthReport {
    static func create(store: AppStore) throws -> URL {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: "VECTOR health summary"]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842), format: format)
        let url = FileManager.default.temporaryDirectory.appending(path: "VECTOR-\(UUID().uuidString).pdf")
        let data = renderer.pdfData { context in
            var y: CGFloat = 48
            func line(_ value: String, title: Bool = false) {
                let attributes: [NSAttributedString.Key: Any] = [.font: title ? UIFont.boldSystemFont(ofSize: 22) : UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.black]
                let text = value as NSString
                let height = text.boundingRect(with: CGSize(width: 499, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: attributes, context: nil).height + 12
                if y + height > 790 { context.beginPage(); y = 48 }
                text.draw(in: CGRect(x: 48, y: y, width: 499, height: height), withAttributes: attributes); y += height
            }
            context.beginPage()
            line("VECTOR / Health summary", title: true)
            line("Generated \(Date().formatted()) · \(store.demo ? "FICTIONAL DEMO DATA" : "Apple Health data")")
            line("Personal tracking report. Scores are experimental wellness estimates, not medical findings. Missing readings do not indicate normal values.")
            for reading in store.snapshot.readings { line("\(reading.id): \(reading.value.oneDecimal) \(reading.unit) · \(reading.date.formatted()) · \(reading.source)") }
            line("Recovery: \(store.recovery.score.map(String.init) ?? "Unavailable") / 100. \(store.recovery.explanation)")
            line("Observed strain: \(store.snapshot.strain?.oneDecimal ?? "Unavailable") / 21. Recording coverage: \(Int(store.snapshot.heartCoverage * 100))%")
            line("Daily history / up to 180 days", title: true)
            for day in store.snapshot.history { line("\(day.date.formatted(date: .abbreviated, time: .omitted)) · HRV \(day.hrv?.oneDecimal ?? "—") ms · Resting HR \(day.restingHR?.oneDecimal ?? "—") bpm · Respiration \(day.respiratoryRate?.oneDecimal ?? "—") /min · Sleep \(day.sleepHours?.oneDecimal ?? "—") h") }
        }
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
}
