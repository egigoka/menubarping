import Foundation

actor NetworkChecker {
    private var countryCache: [String: (country: String, timestamp: Date)] = [:]
    private let cacheTTL: TimeInterval = 60 * 60

    func ping(host: String, timeoutSeconds: Int) async -> (isUp: Bool, ip: String?) {
        await withCheckedContinuation { continuation in
            let process = Process()
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            process.executableURL = URL(fileURLWithPath: "/sbin/ping")
            process.arguments = ["-c", "1", "-W", "\(max(1, timeoutSeconds))", host]

            do {
                try process.run()
            } catch {
                continuation.resume(returning: (false, nil))
                return
            }

            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let ip = extractIP(from: output)
            continuation.resume(returning: (process.terminationStatus == 0, ip))
        }
    }

    func checkApple() async -> Bool {
        await checkBodyContains(
            urlString: "http://captive.apple.com/hotspot-detect.html",
            expectedSubstring: "Success"
        )
    }

    func checkMicrosoft() async -> Bool {
        await checkBodyEquals(
            urlString: "http://www.msftncsi.com/ncsi.txt",
            expectedBody: "Microsoft NCSI"
        )
    }

    func getPublicIP() async -> String? {
        guard let url = URL(string: "https://api.ipify.org") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let ip = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (ip?.isEmpty == false) ? ip : nil
        } catch {
            return nil
        }
    }

    func getCountry(ip: String) async -> String? {
        if let cached = countryCache[ip], Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.country
        }

        guard let url = URL(string: "https://ipinfo.io/\(ip)/json") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let object = try JSONSerialization.jsonObject(with: data)
            guard let dict = object as? [String: Any] else { return nil }

            let country: String
            if let value = dict["country"] as? String {
                country = value
            } else if let bogon = dict["bogon"] as? Bool, bogon {
                country = "bogon"
            } else {
                return nil
            }

            countryCache[ip] = (country, Date())
            return country
        } catch {
            return nil
        }
    }

    private func checkBodyContains(urlString: String, expectedSubstring: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let body = String(data: data, encoding: .utf8) ?? ""
            return body.contains(expectedSubstring)
        } catch {
            return false
        }
    }

    private func checkBodyEquals(urlString: String, expectedBody: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return body == expectedBody
        } catch {
            return false
        }
    }

    private func extractIP(from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"[(]([^)]+)[)]"#) else { return nil }
        let range = NSRange(location: 0, length: text.utf16.count)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 else {
            return nil
        }
        guard let swiftRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[swiftRange])
    }
}
