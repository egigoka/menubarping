import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var monitor: PingMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            statusSection
            Divider()
            settingsSection
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(12)
        .frame(minWidth: 340)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Status").font(.headline)
            Text("Country: \(monitor.country)")
            Text("Public IP: \(monitor.publicIP)")
            if monitor.vpnNotActive {
                Text("VPN: 💀 not active")
            } else {
                Text("VPN: 🥽 active")
            }
            if monitor.statuses.isEmpty {
                Text("Checks: running...")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(monitor.statuses) { item in
                    Text("\(item.isUp ? "🟢" : "💔") \(item.name)\(item.ip.map { " (\($0))" } ?? "")")
                }
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Settings").font(.headline)
            Toggle("Include Apple check", isOn: $monitor.includeAppleCheck)
            Toggle("Include Microsoft check", isOn: $monitor.includeMicrosoftCheck)
            Toggle("Include router", isOn: $monitor.includeRouterCheck)
            Toggle("VPN safety check", isOn: $monitor.includeVPNCheck)

            Picker("Ping interval", selection: $monitor.pingInterval) {
                Text("1s").tag(1)
                Text("5s").tag(5)
                Text("10s").tag(10)
                Text("30s").tag(30)
                Text("60s").tag(60)
            }
            .pickerStyle(.segmented)

            Stepper("Ignored timeouts: \(monitor.ignoredTimeouts)", value: $monitor.ignoredTimeouts, in: 0...5)

            HStack {
                TextField("Add custom host", text: $monitor.newDomainInput)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    monitor.addDomainFromInput()
                }
            }

            if !monitor.customDomains.isEmpty {
                List {
                    ForEach(monitor.customDomains, id: \.self) { domain in
                        Text(domain)
                    }
                    .onDelete(perform: monitor.removeDomains)
                }
                .frame(height: 120)
            }
        }
    }
}
