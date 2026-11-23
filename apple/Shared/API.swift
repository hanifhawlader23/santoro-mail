import Foundation
import AuthenticationServices
#if os(iOS)
import UIKit
#else
import AppKit
#endif

let BASE = "https://hanif.jamalhanif2002.workers.dev"

enum APIError: LocalizedError {
    case login, server(String)
    var errorDescription: String? {
        switch self { case .login: return "Inicia sesión de nuevo"; case .server(let m): return m }
    }
}

// MARK: models (same JSON as the web app's /api)
struct Addr: Codable, Hashable { var n: String; var e: String }

struct Mail: Codable, Identifiable, Hashable {
    var id: String
    var folder: String?
    var from: Addr
    var to: [String]
    var cc: [String]?
    var sub: String
    var snip: String
    var date: String
    var unread: Bool
    var star: Bool
    var att: Bool
    var pri: Bool?
    var when: Date { ISO.parse(date) }
}

struct Detail: Decodable { var html: String?; var atts: [Att]? }
struct Att: Decodable, Hashable, Identifiable { var id: String; var name: String; var type: String?; var size: Int? }
struct Me: Decodable { var name: String?; var email: String; var aliases: [String]?; var ai: Bool?; var aiPro: Bool? }
struct Open: Decodable, Hashable { var t: String; var d: String?; var p: String?; var auto: Bool? }
struct Click: Decodable, Hashable { var t: String; var u: String? }
struct Track: Decodable, Identifiable, Hashable {
    var id: String; var from: String?; var to: Addr; var sub: String; var date: String
    var opens: [Open]; var clicks: [Click]?; var replied: Bool?; var wait: Bool?
    var realOpens: [Open] { opens.filter { $0.auto != true } }
}

enum ISO {
    static let a: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f }()
    static let b = ISO8601DateFormatter()
    static func parse(_ s: String) -> Date { a.date(from: s) ?? b.date(from: s) ?? Date.distantPast }
}

func relTime(_ d: Date) -> String {
    let s = Date().timeIntervalSince(d)
    if s < 60 { return "ahora" }
    if s < 3600 { return "\(Int(s / 60)) min" }
    if Calendar.current.isDateInToday(d) { return d.formatted(date: .omitted, time: .shortened) }
    if Calendar.current.isDateInYesterday(d) { return "ayer" }
    if s < 6 * 86400 { return d.formatted(.dateTime.weekday(.abbreviated)) }
    return d.formatted(.dateTime.day().month(.abbreviated))
}

// MARK: HTTP
final class API {
    static let shared = API()
    var token: String? {
        get { UserDefaults.standard.string(forKey: "sm_token") }
        set { UserDefaults.standard.set(newValue, forKey: "sm_token") }
    }
    static func enc(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? s }

    @discardableResult
    func req(_ path: String, method: String = "GET", body: Any? = nil) async throws -> Data {
        guard let url = URL(string: BASE + "/api" + path) else { throw APIError.server("URL") }
        var r = URLRequest(url: url, timeoutInterval: 40)
        r.httpMethod = method
        r.setValue("Bearer \(token ?? "")", forHTTPHeaderField: "Authorization")
        if let body {
            r.httpBody = try JSONSerialization.data(withJSONObject: body)
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (d, resp) = try await URLSession.shared.data(for: r)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 { throw APIError.login }
        if code >= 400 {
            let msg = ((try? JSONSerialization.jsonObject(with: d)) as? [String: Any])?["error"] as? String ?? "Error \(code)"
            throw APIError.server(msg)
        }
        return d
    }
    func get<T: Decodable>(_ path: String, _ t: T.Type) async throws -> T {
        try JSONDecoder().decode(T.self, from: try await req(path))
    }
    func json(_ path: String) async throws -> [String: Any] {
        (try JSONSerialization.jsonObject(with: try await req(path)) as? [String: Any]) ?? [:]
    }
    func ai(_ prompt: String) async throws -> String {
        let d = try await req("/ai", method: "POST", body: ["prompt": prompt])
        return ((try JSONSerialization.jsonObject(with: d) as? [String: Any])?["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: Microsoft sign-in (through our server, which keeps the Microsoft tokens)
@MainActor
final class Auth: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = Auth()
    private var session: ASWebAuthenticationSession?

    nonisolated func presentationAnchor(for s: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            #if os(iOS)
            return UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first ?? ASPresentationAnchor()
            #else
            return NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? ASPresentationAnchor()
            #endif
        }
    }

    func login() async throws -> String {
        try await withCheckedThrowingContinuation { c in
            let s = ASWebAuthenticationSession(url: URL(string: BASE + "/auth/login?app=1")!, callbackURLScheme: "santoromail") { url, err in
                if let url, let t = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "t" })?.value {
                    c.resume(returning: t)
                } else { c.resume(throwing: err ?? APIError.login) }
            }
            s.presentationContextProvider = self
            s.prefersEphemeralWebBrowserSession = false
            session = s
            s.start()
        }
    }
}
