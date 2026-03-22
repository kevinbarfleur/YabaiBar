import Foundation
import Security

// MARK: - Data Models

public enum QuotaData: Sendable {
    case claudeSubscription(ClaudeSubscriptionUsage)
    case codexSubscription(CodexSubscriptionUsage)
}

public struct ClaudeSubscriptionUsage: Sendable {
    public let sessionUtilization: Double
    public let sessionResetTime: Date?
    public let sessionStatus: String
    public let weeklyUtilization: Double
    public let weeklyResetTime: Date?
    public let weeklyStatus: String
    public let overallStatus: String
    public let lastChecked: Date
    public let error: String?

    public var sessionHealth: Health {
        healthFromUtilization(sessionUtilization)
    }

    public var weeklyHealth: Health {
        healthFromUtilization(weeklyUtilization)
    }

    public var overallHealth: Health {
        let worst = max(sessionUtilization, weeklyUtilization)
        return healthFromUtilization(worst)
    }

    private func healthFromUtilization(_ u: Double) -> Health {
        if u > 0.9 { return .critical }
        if u > 0.5 { return .warning }
        return .ok
    }

    public init(
        sessionUtilization: Double = 0,
        sessionResetTime: Date? = nil,
        sessionStatus: String = "unknown",
        weeklyUtilization: Double = 0,
        weeklyResetTime: Date? = nil,
        weeklyStatus: String = "unknown",
        overallStatus: String = "unknown",
        lastChecked: Date = Date(),
        error: String? = nil
    ) {
        self.sessionUtilization = sessionUtilization
        self.sessionResetTime = sessionResetTime
        self.sessionStatus = sessionStatus
        self.weeklyUtilization = weeklyUtilization
        self.weeklyResetTime = weeklyResetTime
        self.weeklyStatus = weeklyStatus
        self.overallStatus = overallStatus
        self.lastChecked = lastChecked
        self.error = error
    }
}

public struct CodexSubscriptionUsage: Sendable {
    public let sessionUsedPercent: Double
    public let sessionResetTime: Date?
    public let weeklyUsedPercent: Double
    public let weeklyResetTime: Date?
    public let limitReached: Bool
    public let allowed: Bool
    public let planType: String
    public let lastChecked: Date
    public let error: String?

    public var sessionHealth: Health {
        healthFromPercent(sessionUsedPercent)
    }

    public var weeklyHealth: Health {
        healthFromPercent(weeklyUsedPercent)
    }

    public var overallHealth: Health {
        if limitReached { return .critical }
        let worst = max(sessionUsedPercent, weeklyUsedPercent)
        return healthFromPercent(worst)
    }

    private func healthFromPercent(_ p: Double) -> Health {
        if p >= 90 { return .critical }
        if p >= 50 { return .warning }
        return .ok
    }

    public init(
        sessionUsedPercent: Double = 0, sessionResetTime: Date? = nil,
        weeklyUsedPercent: Double = 0, weeklyResetTime: Date? = nil,
        limitReached: Bool = false, allowed: Bool = true,
        planType: String = "unknown",
        lastChecked: Date = Date(), error: String? = nil
    ) {
        self.sessionUsedPercent = sessionUsedPercent
        self.sessionResetTime = sessionResetTime
        self.weeklyUsedPercent = weeklyUsedPercent
        self.weeklyResetTime = weeklyResetTime
        self.limitReached = limitReached
        self.allowed = allowed
        self.planType = planType
        self.lastChecked = lastChecked
        self.error = error
    }
}

public enum Health: Sendable {
    case ok, warning, critical, unknown
}

// MARK: - Client

public enum AIQuotaClient {

    // MARK: Claude Subscription (via OAuth + Anthropic API headers)

    public static func readClaudeOAuthToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String,
              !token.isEmpty else {
            return nil
        }
        return token
    }

    public static func fetchClaudeSubscriptionUsage(oauthToken: String) async -> ClaudeSubscriptionUsage {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(oauthToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = #"{"model":"claude-haiku-4-5-20251001","max_tokens":1,"messages":[{"role":"user","content":"h"}]}"#.data(using: .utf8)
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return ClaudeSubscriptionUsage(error: "Invalid response")
            }

            if http.statusCode == 401 {
                return ClaudeSubscriptionUsage(error: "OAuth token expired")
            }

            let headers = http.allHeaderFields

            let sessionUtil = doubleHeader(headers, "anthropic-ratelimit-unified-5h-utilization") ?? 0
            let sessionReset = timestampHeader(headers, "anthropic-ratelimit-unified-5h-reset")
            let sessionStatus = stringHeader(headers, "anthropic-ratelimit-unified-5h-status") ?? "unknown"

            let weeklyUtil = doubleHeader(headers, "anthropic-ratelimit-unified-7d-utilization") ?? 0
            let weeklyReset = timestampHeader(headers, "anthropic-ratelimit-unified-7d-reset")
            let weeklyStatus = stringHeader(headers, "anthropic-ratelimit-unified-7d-status") ?? "unknown"

            let overallStatus = stringHeader(headers, "anthropic-ratelimit-unified-status") ?? "unknown"

            return ClaudeSubscriptionUsage(
                sessionUtilization: sessionUtil,
                sessionResetTime: sessionReset,
                sessionStatus: sessionStatus,
                weeklyUtilization: weeklyUtil,
                weeklyResetTime: weeklyReset,
                weeklyStatus: weeklyStatus,
                overallStatus: overallStatus
            )
        } catch {
            return ClaudeSubscriptionUsage(error: error.localizedDescription)
        }
    }

    // MARK: Codex Subscription (via ChatGPT OAuth)

    public static func readCodexOAuthToken() -> String? {
        let authPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex")
            .appendingPathComponent("auth.json")
        guard let data = try? Data(contentsOf: authPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = json["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String,
              !accessToken.isEmpty else {
            return nil
        }
        return accessToken
    }

    public static func fetchCodexSubscriptionUsage(oauthToken: String) async -> CodexSubscriptionUsage {
        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(oauthToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return CodexSubscriptionUsage(error: "Invalid response")
            }

            if http.statusCode == 401 || http.statusCode == 403 {
                return CodexSubscriptionUsage(error: "Token expired")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return CodexSubscriptionUsage(error: "Invalid JSON")
            }

            let rateLimit = json["rate_limit"] as? [String: Any] ?? [:]
            let limitReached = rateLimit["limit_reached"] as? Bool ?? false
            let allowed = rateLimit["allowed"] as? Bool ?? true
            let planType = json["plan_type"] as? String ?? "unknown"

            let primary = rateLimit["primary_window"] as? [String: Any] ?? [:]
            let secondary = rateLimit["secondary_window"] as? [String: Any]

            let sessionPercent = primary["used_percent"] as? Double ?? 0
            let sessionResetSecs = primary["reset_after_seconds"] as? Double
            let sessionReset = sessionResetSecs.map { Date().addingTimeInterval($0) }

            let weeklyPercent = secondary?["used_percent"] as? Double ?? 0
            let weeklyResetSecs = secondary?["reset_after_seconds"] as? Double
            let weeklyReset = weeklyResetSecs.map { Date().addingTimeInterval($0) }

            return CodexSubscriptionUsage(
                sessionUsedPercent: sessionPercent,
                sessionResetTime: sessionReset,
                weeklyUsedPercent: weeklyPercent,
                weeklyResetTime: weeklyReset,
                limitReached: limitReached,
                allowed: allowed,
                planType: planType
            )
        } catch {
            return CodexSubscriptionUsage(error: error.localizedDescription)
        }
    }

    // MARK: - Header Parsing

    private static func stringHeader(_ headers: [AnyHashable: Any], _ name: String) -> String? {
        headers[name] as? String ?? headers[name.lowercased()] as? String
    }

    private static func intHeader(_ headers: [AnyHashable: Any], _ name: String) -> Int? {
        guard let value = stringHeader(headers, name) else { return nil }
        return Int(value)
    }

    private static func doubleHeader(_ headers: [AnyHashable: Any], _ name: String) -> Double? {
        guard let value = stringHeader(headers, name) else { return nil }
        return Double(value)
    }

    private static func timestampHeader(_ headers: [AnyHashable: Any], _ name: String) -> Date? {
        guard let value = stringHeader(headers, name), let ts = TimeInterval(value) else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    private static func resetDurationHeader(_ headers: [AnyHashable: Any], _ name: String) -> Date? {
        guard let value = stringHeader(headers, name) else { return nil }

        var seconds: Double = 0
        let pattern = /(\d+(?:\.\d+)?)(ms|h|m|s)/
        for match in value.matches(of: pattern) {
            guard let number = Double(match.1) else { continue }
            switch match.2 {
            case "ms": seconds += number / 1000
            case "h": seconds += number * 3600
            case "m": seconds += number * 60
            case "s": seconds += number
            default: break
            }
        }

        return seconds > 0 ? Date().addingTimeInterval(seconds) : nil
    }
}
