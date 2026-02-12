import Foundation
import SwiftUI

struct PingResult: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let isUp: Bool
    let ip: String?
}

@MainActor
final class PingMonitor: ObservableObject {
    @Published var country: String = "!?"
    @Published var publicIP: String = "255.255.255.255"
    @Published var statuses: [PingResult] = []
    @Published var internetStatus: Bool = false
    @Published var vpnNotActive: Bool = false

    @Published var includeAppleCheck: Bool = UserDefaults.standard.object(forKey: Keys.includeAppleCheck) as? Bool ?? true {
        didSet { UserDefaults.standard.set(includeAppleCheck, forKey: Keys.includeAppleCheck) }
    }
    @Published var includeMicrosoftCheck: Bool = UserDefaults.standard.object(forKey: Keys.includeMicrosoftCheck) as? Bool ?? true {
        didSet { UserDefaults.standard.set(includeMicrosoftCheck, forKey: Keys.includeMicrosoftCheck) }
    }
    @Published var includeRouterCheck: Bool = UserDefaults.standard.object(forKey: Keys.includeRouterCheck) as? Bool ?? false {
        didSet { UserDefaults.standard.set(includeRouterCheck, forKey: Keys.includeRouterCheck) }
    }
    @Published var includeVPNCheck: Bool = UserDefaults.standard.object(forKey: Keys.includeVPNCheck) as? Bool ?? true {
        didSet { UserDefaults.standard.set(includeVPNCheck, forKey: Keys.includeVPNCheck) }
    }
    @Published var pingInterval: Int = UserDefaults.standard.object(forKey: Keys.pingInterval) as? Int ?? 10 {
        didSet { UserDefaults.standard.set(pingInterval, forKey: Keys.pingInterval) }
    }
    @Published var ignoredTimeouts: Int = UserDefaults.standard.object(forKey: Keys.ignoredTimeouts) as? Int ?? 1 {
        didSet { UserDefaults.standard.set(ignoredTimeouts, forKey: Keys.ignoredTimeouts) }
    }
    @Published var customDomains: [String] = UserDefaults.standard.stringArray(forKey: Keys.customDomains) ?? [] {
        didSet { UserDefaults.standard.set(customDomains, forKey: Keys.customDomains) }
    }
    @Published var newDomainInput: String = ""

    private let networkChecker = NetworkChecker()
    private let notifications = NotificationManager()
    private let pingTimeoutSeconds = 20
    private let vpnRiskCountries: Set<String> = ["ru", "kz", "cn"]

    private var monitorTask: Task<Void, Never>?
    private var firstIteration = true
    private var failedRuns = 0

    var menuBarTitle: String {
        let connectivity: String
        if statuses.isEmpty {
            connectivity = "…"
        } else if statuses.allSatisfy(\.isUp) {
            connectivity = "✅"
        } else {
            connectivity = statuses.map { $0.isUp ? "🟢" : "💔" }.joined()
        }
        let vpnEmoji: String
        if includeVPNCheck {
            vpnEmoji = vpnNotActive ? "💀" : "🥽"
        } else {
            vpnEmoji = ""
        }
        return "\(flagEmoji(from: country)) \(connectivity)\(vpnEmoji)"
    }

    func start() {
        guard monitorTask == nil else { return }
        notifications.requestPermission()
        monitorTask = Task { [weak self] in
            await self?.runLoop()
        }
    }

    func stop() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    func addDomainFromInput() {
        let value = newDomainInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        guard !customDomains.contains(value) else {
            newDomainInput = ""
            return
        }
        customDomains.append(value)
        newDomainInput = ""
    }

    func removeDomains(at offsets: IndexSet) {
        customDomains.remove(atOffsets: offsets)
    }

    private func runLoop() async {
        while !Task.isCancelled {
            if firstIteration {
                notifications.send(
                    title: "ping_",
                    subtitle: "Please, wait...",
                    message: "Check is running.",
                    tone: .none
                )
            }

            await updateIPAndCountry()
            let currentTargets = makeTargets()
            let results = await pingTargets(targets: currentTargets)
            statuses = results

            let upCount = results.filter(\.isUp).count
            let total = max(1, results.count)

            if upCount < total - ignoredTimeouts {
                failedRuns += 1
                if failedRuns > 1 {
                    notifications.send(
                        title: "ping_",
                        subtitle: "Something is wrong!",
                        message: "\(upCount) domains of \(total) is online.",
                        tone: .failure
                    )
                }
                internetStatus = false
            } else if upCount < total {
                failedRuns += 1
                if failedRuns > 1 {
                    notifications.send(
                        title: "ping_",
                        subtitle: "Just one timeout, worry?",
                        message: "\(upCount) domains of \(total) is online.",
                        tone: .failure
                    )
                }
                internetStatus = false
            } else {
                if !internetStatus {
                    notifications.send(
                        title: "ping_",
                        subtitle: firstIteration ? "You are online!" : "You are back online!",
                        message: "All \(total) domains is online.",
                        tone: .success
                    )
                }
                internetStatus = true
                failedRuns = 0
            }

            firstIteration = false
            let nanos = UInt64(max(1, pingInterval)) * 1_000_000_000
            try? await Task.sleep(nanoseconds: nanos)
        }
    }

    private func updateIPAndCountry() async {
        if let ip = await networkChecker.getPublicIP() {
            publicIP = ip
            if let foundCountry = await networkChecker.getCountry(ip: ip), !foundCountry.isEmpty {
                country = foundCountry.count == 2 ? foundCountry.uppercased() : "\(country.prefix(2))?"
                vpnNotActive = includeVPNCheck && vpnRiskCountries.contains(foundCountry.lowercased())
            }
        }
    }

    private enum Target: Sendable {
        case host(String)
        case apple
        case microsoft

        var name: String {
            switch self {
            case .host(let value): return value
            case .apple: return "Apple"
            case .microsoft: return "Microsoft"
            }
        }
    }

    private func makeTargets() -> [Target] {
        var targets: [Target] = customDomains.map(Target.host)
        targets.append(.host("8.8.8.8"))
        if includeRouterCheck { targets.append(.host("192.168.1.1")) }
        if includeAppleCheck { targets.append(.apple) }
        if includeMicrosoftCheck { targets.append(.microsoft) }
        return targets
    }

    private func pingTargets(targets: [Target]) async -> [PingResult] {
        await withTaskGroup(of: (Int, PingResult).self) { group in
            for (index, target) in targets.enumerated() {
                group.addTask { [networkChecker, pingTimeoutSeconds] in
                    switch target {
                    case .host(let host):
                        let result = await networkChecker.ping(host: host, timeoutSeconds: pingTimeoutSeconds)
                        return (index, PingResult(name: target.name, isUp: result.isUp, ip: result.ip))
                    case .apple:
                        let up = await networkChecker.checkApple()
                        return (index, PingResult(name: target.name, isUp: up, ip: nil))
                    case .microsoft:
                        let up = await networkChecker.checkMicrosoft()
                        return (index, PingResult(name: target.name, isUp: up, ip: nil))
                    }
                }
            }

            var ordered = Array<PingResult?>(repeating: nil, count: targets.count)
            for await (index, result) in group {
                ordered[index] = result
            }
            return ordered.compactMap { $0 }
        }
    }

    private func flagEmoji(from countryCode: String) -> String {
        let normalized = countryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalized.count == 2 else { return "🏳️" }
        let scalars = normalized.unicodeScalars
        guard scalars.allSatisfy({ CharacterSet.uppercaseLetters.contains($0) }) else { return "🏳️" }

        let base: UInt32 = 127397
        let mapped = scalars.compactMap { UnicodeScalar(base + $0.value) }
        guard mapped.count == 2 else { return "🏳️" }
        return String(String.UnicodeScalarView(mapped))
    }
}

private enum Keys {
    static let includeAppleCheck = "includeAppleCheck"
    static let includeMicrosoftCheck = "includeMicrosoftCheck"
    static let includeRouterCheck = "includeRouterCheck"
    static let includeVPNCheck = "includeVPNCheck"
    static let pingInterval = "pingInterval"
    static let ignoredTimeouts = "ignoredTimeouts"
    static let customDomains = "customDomains"
}
