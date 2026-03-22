import Foundation
import Security

// MARK: - Data Models

public struct JiraCredentials: Sendable {
    public let siteUrl: String
    public let email: String
    public let apiToken: String

    public init(siteUrl: String, email: String, apiToken: String) {
        self.siteUrl = siteUrl
        self.email = email
        self.apiToken = apiToken
    }

    public var basicAuthHeader: String {
        let raw = "\(email):\(apiToken)"
        return "Basic \(Data(raw.utf8).base64EncodedString())"
    }

    public var baseApiUrl: String {
        let trimmed = siteUrl.hasSuffix("/") ? String(siteUrl.dropLast()) : siteUrl
        return "\(trimmed)/rest/api/3"
    }

    public func browseUrl(for issueKey: String) -> String {
        let trimmed = siteUrl.hasSuffix("/") ? String(siteUrl.dropLast()) : siteUrl
        return "\(trimmed)/browse/\(issueKey)"
    }
}

public struct JiraIssue: Sendable, Identifiable {
    public let id: String
    public let key: String
    public let summary: String
    public let status: String
    public let issueType: String?
    public let priorityName: String?
    public let updated: Date?
    public let browseUrl: String
}

public struct JiraIssueType: Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    public static func == (lhs: JiraIssueType, rhs: JiraIssueType) -> Bool {
        lhs.name == rhs.name
    }
}

public struct JiraProject: Sendable, Identifiable {
    public let id: String
    public let key: String
    public let name: String
}

public struct JiraStatus: Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let categoryKey: String

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    public static func == (lhs: JiraStatus, rhs: JiraStatus) -> Bool {
        lhs.name == rhs.name
    }
}

// MARK: - Client

public enum JiraClient {

    private static let keychainService = "OpenNotch-Jira"
    private static let keychainAccount = "credentials"

    // MARK: Keychain

    public static func saveCredentials(_ creds: JiraCredentials) -> Bool {
        deleteCredentials()

        let payload: [String: String] = [
            "siteUrl": creds.siteUrl,
            "email": creds.email,
            "apiToken": creds.apiToken,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    public static func readCredentials() -> JiraCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let siteUrl = json["siteUrl"] as? String, !siteUrl.isEmpty,
              let email = json["email"] as? String, !email.isEmpty,
              let apiToken = json["apiToken"] as? String, !apiToken.isEmpty else {
            return nil
        }
        return JiraCredentials(siteUrl: siteUrl, email: email, apiToken: apiToken)
    }

    @discardableResult
    public static func deleteCredentials() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }

    // MARK: API — Validate Connection

    public static func validateConnection(_ creds: JiraCredentials) async -> (displayName: String?, error: String?) {
        guard let url = URL(string: "\(creds.baseApiUrl)/myself") else {
            return (nil, "Invalid site URL")
        }

        var request = URLRequest(url: url)
        request.setValue(creds.basicAuthHeader, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return (nil, "Invalid response")
            }

            if http.statusCode == 401 {
                return (nil, "Invalid credentials")
            }
            if http.statusCode == 403 {
                return (nil, "Access denied")
            }
            if http.statusCode < 200 || http.statusCode >= 300 {
                return (nil, "HTTP \(http.statusCode)")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return (nil, "Invalid JSON")
            }

            let displayName = json["displayName"] as? String
            return (displayName, nil)
        } catch {
            return (nil, error.localizedDescription)
        }
    }

    // MARK: API — Fetch Issues

    public static func fetchIssues(_ creds: JiraCredentials, jql: String) async -> (issues: [JiraIssue], error: String?) {
        guard let url = URL(string: "\(creds.baseApiUrl)/search/jql") else {
            return ([], "Invalid site URL")
        }

        let body: [String: Any] = [
            "jql": jql,
            "fields": ["summary", "status", "priority", "updated", "issuetype"],
            "maxResults": 50,
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(creds.basicAuthHeader, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return ([], "Invalid response")
            }

            if http.statusCode == 401 {
                return ([], "Invalid credentials")
            }
            if http.statusCode == 403 {
                return ([], "Access denied")
            }
            if http.statusCode == 400 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let messages = json["errorMessages"] as? [String],
                   let first = messages.first {
                    return ([], first)
                }
                return ([], "Invalid JQL query")
            }
            if http.statusCode < 200 || http.statusCode >= 300 {
                return ([], "HTTP \(http.statusCode)")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return ([], "Invalid JSON (not a dictionary)")
            }

            guard let issuesArray = json["issues"] as? [[String: Any]] else {
                let total = json["total"] as? Int ?? -1
                let keys = Array(json.keys.prefix(5)).joined(separator: ", ")
                return ([], "Unexpected response (total=\(total), keys=\(keys))")
            }

            let issues = issuesArray.compactMap { raw -> JiraIssue? in
                let id: String
                if let s = raw["id"] as? String { id = s }
                else if let n = raw["id"] as? Int { id = String(n) }
                else { return nil }

                guard let key = raw["key"] as? String,
                      let fields = raw["fields"] as? [String: Any],
                      let summary = fields["summary"] as? String else {
                    return nil
                }

                let statusObj = fields["status"] as? [String: Any]
                let status = statusObj?["name"] as? String ?? "Unknown"

                let issueTypeObj = fields["issuetype"] as? [String: Any]
                let issueType = issueTypeObj?["name"] as? String

                let priorityObj = fields["priority"] as? [String: Any]
                let priorityName = priorityObj?["name"] as? String

                var updated: Date?
                if let updatedStr = fields["updated"] as? String {
                    updated = Self.parseJiraDate(updatedStr)
                }

                return JiraIssue(
                    id: id,
                    key: key,
                    summary: summary,
                    status: status,
                    issueType: issueType,
                    priorityName: priorityName,
                    updated: updated,
                    browseUrl: creds.browseUrl(for: key)
                )
            }

            return (issues, nil)
        } catch {
            return ([], error.localizedDescription)
        }
    }

    // MARK: API — Fetch Projects

    public static func fetchProjects(_ creds: JiraCredentials) async -> (projects: [JiraProject], error: String?) {
        guard let url = URL(string: "\(creds.baseApiUrl)/project?recent=50") else {
            return ([], "Invalid site URL")
        }

        var request = URLRequest(url: url)
        request.setValue(creds.basicAuthHeader, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return ([], "Invalid response")
            }

            if http.statusCode == 401 { return ([], "Invalid credentials") }
            if http.statusCode < 200 || http.statusCode >= 300 { return ([], "HTTP \(http.statusCode)") }

            guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return ([], "Invalid JSON")
            }

            let projects = array.compactMap { raw -> JiraProject? in
                guard let id = raw["id"] as? String,
                      let key = raw["key"] as? String,
                      let name = raw["name"] as? String else {
                    return nil
                }
                return JiraProject(id: id, key: key, name: name)
            }

            return (projects, nil)
        } catch {
            return ([], error.localizedDescription)
        }
    }

    // MARK: API — Fetch Statuses

    public static func fetchStatuses(_ creds: JiraCredentials) async -> (statuses: [JiraStatus], error: String?) {
        guard let url = URL(string: "\(creds.baseApiUrl)/status") else {
            return ([], "Invalid site URL")
        }

        var request = URLRequest(url: url)
        request.setValue(creds.basicAuthHeader, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return ([], "Invalid response")
            }

            if http.statusCode == 401 { return ([], "Invalid credentials") }
            if http.statusCode < 200 || http.statusCode >= 300 { return ([], "HTTP \(http.statusCode)") }

            guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return ([], "Invalid JSON")
            }

            var seen = Set<String>()
            let statuses = array.compactMap { raw -> JiraStatus? in
                guard let id = raw["id"] as? String,
                      let name = raw["name"] as? String else {
                    return nil
                }
                guard seen.insert(name).inserted else { return nil }

                let categoryObj = raw["statusCategory"] as? [String: Any]
                let categoryKey = categoryObj?["key"] as? String ?? "undefined"
                return JiraStatus(id: id, name: name, categoryKey: categoryKey)
            }

            return (statuses.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }, nil)
        } catch {
            return ([], error.localizedDescription)
        }
    }

    // MARK: JQL Builder

    public static func buildJQL(statusFilter: Set<String>, projectFilter: Set<String>, typeFilter: Set<String> = []) -> String {
        var clauses = ["assignee = currentUser()"]

        if !statusFilter.isEmpty {
            let escaped = statusFilter.sorted().map { "\"\($0)\"" }.joined(separator: ", ")
            clauses.append("status IN (\(escaped))")
        }

        if !projectFilter.isEmpty {
            let escaped = projectFilter.sorted().map { "\"\($0)\"" }.joined(separator: ", ")
            clauses.append("project IN (\(escaped))")
        }

        if !typeFilter.isEmpty {
            let escaped = typeFilter.sorted().map { "\"\($0)\"" }.joined(separator: ", ")
            clauses.append("issuetype IN (\(escaped))")
        }

        return clauses.joined(separator: " AND ") + " ORDER BY updated DESC"
    }

    // MARK: API — Fetch Issue Types

    public static func fetchIssueTypes(_ creds: JiraCredentials) async -> (types: [JiraIssueType], error: String?) {
        guard let url = URL(string: "\(creds.baseApiUrl)/issuetype") else {
            return ([], "Invalid site URL")
        }

        var request = URLRequest(url: url)
        request.setValue(creds.basicAuthHeader, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return ([], "Invalid response")
            }

            if http.statusCode == 401 { return ([], "Invalid credentials") }
            if http.statusCode < 200 || http.statusCode >= 300 { return ([], "HTTP \(http.statusCode)") }

            guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return ([], "Invalid JSON")
            }

            var seen = Set<String>()
            let types = array.compactMap { raw -> JiraIssueType? in
                guard let id = raw["id"] as? String,
                      let name = raw["name"] as? String else {
                    return nil
                }
                guard seen.insert(name).inserted else { return nil }
                return JiraIssueType(id: id, name: name)
            }

            return (types.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }, nil)
        } catch {
            return ([], error.localizedDescription)
        }
    }

    // MARK: Date Parsing

    private static func parseJiraDate(_ string: String) -> Date? {
        let primary = ISO8601DateFormatter()
        primary.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = primary.date(from: string) { return date }

        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: string)
    }
}
