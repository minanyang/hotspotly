import HotspotlyCore
import SwiftUI

extension Drop: Identifiable {
    public var id: String { "\(start.timeIntervalSince1970)-\(network)" }

    var causeText: String {
        switch cause {
        case .networkEnded: L("Ended by the phone or router")
        case .signalLost: L("Signal lost")
        case .switched: L("macOS switched networks")
        case .slept: L("Mac slept")
        case .unknown: L("Cause unknown")
        }
    }
}

/// Whether Hotspotly helps, from the Mac's own measurements: the same networks with AWDL up and
/// down, why they dropped, and what Hotspotly did.
struct InsightsTab: View {
    @ObservedObject var model: SettingsModel
    @State private var scope = Scope.hotspots
    @State private var confirmingReset = false

    enum Scope: Hashable {
        case hotspots, wifi
        case network(String)

        func includes(_ name: String, hotspot: Bool) -> Bool {
            switch self {
            case .hotspots: hotspot
            case .wifi: !hotspot
            case .network(let only): name == only
            }
        }
    }

    var networks: [(String, NetworkInsights)] {
        model.insights.networks.filter { scope.includes($0.key, hotspot: $0.value.hotspot) }.map { ($0.key, $0.value) }
    }

    var awdlOff: RoundStats { networks.reduce(RoundStats()) { $0 + $1.1.awdlOff } }
    var awdlOn: RoundStats { networks.reduce(RoundStats()) { $0 + $1.1.awdlOn } }

    var drops: [Drop] {
        model.insights.drops.filter { scope.includes($0.network, hotspot: $0.hotspot) }.reversed().prefix(50).map { $0 }
    }

    var body: some View {
        Form {
            Picker(L("Show"), selection: $scope) {
                Text(L("Mobile Hotspots")).tag(Scope.hotspots)
                Text(L("Wi-Fi")).tag(Scope.wifi)
                Divider()
                ForEach(model.insights.networks.keys.sorted(), id: \.self) { Text($0).tag(Scope.network($0)) }
            }

            Section(L("With and without AWDL")) {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                    GridRow {
                        Text("")
                        Text(L("AWDL off")).bold()
                        Text(L("AWDL on")).bold()
                    }
                    row(L("Latency")) { $0.latencyMs.map { "\(Int($0.rounded())) ms" } }
                    row(L("Packet loss")) { $0.packetLoss.map(percent) }
                    row(L("Slow or lossy rounds")) { $0.slowShare.map(percent) }
                    row(L("Drops per hour")) { $0.dropsPerHour.map { String(format: "%.1f", $0) } }
                    GridRow {
                        Text(L("Time measured")).foregroundStyle(.secondary)
                        Text(duration(awdlOff))
                        Text(duration(awdlOn))
                    }
                }
                Text(L("AWDL is on while AirDrop is allowed, and on networks where Hotspotly leaves it alone. A column needs about five minutes of data to mean much."))
                    .font(.callout).foregroundStyle(.secondary)
            }

            Section(L("What Hotspotly did")) {
                LabeledContent(L("Turned AWDL off"), value: times(model.insights.awdlBlocked))
                LabeledContent(L("Brought the Mac back to the pinned network"), value: times(model.insights.rejoins))
            }

            Section(L("Recent drops")) {
                if drops.isEmpty {
                    Text(L("No drops recorded yet.")).foregroundStyle(.secondary)
                }
                ForEach(drops) { drop in
                    LabeledContent {
                        if let end = drop.end { Text(Duration.seconds(end.timeIntervalSince(drop.start)), format: .units(width: .abbreviated, maximumUnitCount: 2)) }
                    } label: {
                        Text(drop.causeText + (drop.reason.map { " · IEEE \($0)" } ?? ""))
                        Text("\(drop.network) · \(drop.start.formatted(date: .abbreviated, time: .shortened))")
                    }
                }
            }

            Section {
                HStack {
                    Text(L("Measured on this Mac since \(model.insights.since.formatted(date: .abbreviated, time: .omitted)). Drops shorter than about 10 seconds may be missed."))
                        .font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Button(L("Reset…")) { confirmingReset = true }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 600)
        .onAppear(perform: model.loadInsights)
        .confirmationDialog(L("Reset insights?"), isPresented: $confirmingReset) {
            Button(L("Reset"), role: .destructive, action: model.resetInsights)
        } message: {
            Text(L("This clears the measurements and the list of drops."))
        }
    }

    /// "—" until a column has enough rounds to compare.
    func row(_ title: String, _ value: @escaping (RoundStats) -> String?) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary)
            Text(awdlOff.rounds >= RoundStats.enoughRounds ? value(awdlOff) ?? "—" : "—")
            Text(awdlOn.rounds >= RoundStats.enoughRounds ? value(awdlOn) ?? "—" : "—")
        }
    }

    func times(_ count: Int) -> String { count == 1 ? L("1 time") : L("\(count) times") }

    func percent(_ share: Double) -> String { share.formatted(.percent.precision(.fractionLength(1))) }

    func duration(_ stats: RoundStats) -> String {
        Duration.seconds(stats.rounds * 10).formatted(.units(width: .abbreviated, maximumUnitCount: 2))
    }
}
