//
//  BackendService.swift
//  escrow
//
//  Thin HTTP client for the Rust backend: SIWE auth and the escrow
//  descriptions (deal terms kept off-chain). Pure networking — no crypto.
//  Signing happens in the Rust/AlloySwift layer; this only carries the
//  already-built message, signature or JWT to the server.
//

import Foundation

enum BackendError: Error, LocalizedError {
    case invalidURL
    case badStatus(Int, String)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Bad backend URL."
        case .badStatus(let code, let body):
            return "Server returned \(code): \(body)"
        case .decoding(let error):
            return "Couldn't read the server's response: \(error.localizedDescription)"
        }
    }
}

struct BackendService {
    let baseURL: String

    init(baseURL: String = AppConfig.backendBaseURL) {
        self.baseURL = baseURL
    }

    /// `GET /api/auth/nonce
    func getNonce() async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/auth/nonce") else {
            throw BackendError.invalidURL
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.ensureOK(response, data)
        do {
            return try JSONDecoder().decode(NonceResponse.self, from: data).nonce
        } catch {
            throw BackendError.decoding(error)
        }
    }

    /// `POST /api/auth/verify
    func verifyAndLogin(
        message: String,
        signature: String,
        address: String
    ) async throws -> AuthResponse {
        guard let url = URL(string: "\(baseURL)/api/auth/verify") else {
            throw BackendError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([
            "message": message,
            "signature": signature,
            "address": address,
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.ensureOK(response, data)
        do {
            return try JSONDecoder().decode(AuthResponse.self, from: data)
        } catch {
            throw BackendError.decoding(error)
        }
    }

    /// `POST /api/escrows/:id/description`
    func saveDescription(escrowId: UInt64, description: String, token: String) async throws {
        var request = try authorized("/api/escrows/\(escrowId)/description", token: token)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["description": description])
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.ensureOK(response, data)
    }

    /// `GET /api/escrows/descriptions?ids=…` — only the caller's own escrows
    /// come back; escrows without a description are absent.
    func descriptions(escrowIds: [UInt64], token: String) async throws -> [UInt64: EscrowDescriptionResponse] {
        guard !escrowIds.isEmpty else { return [:] }
        let ids = escrowIds.map(String.init).joined(separator: ",")
        let request = try authorized("/api/escrows/descriptions?ids=\(ids)", token: token)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.ensureOK(response, data)
        do {
            let rows = try JSONDecoder().decode([EscrowDescriptionResponse].self, from: data)
            return Dictionary(rows.map { ($0.escrowId, $0) }, uniquingKeysWith: { a, _ in a })
        } catch {
            throw BackendError.decoding(error)
        }
    }

    /// `GET /api/escrows/:id/description?key=…` — terms for an invite link's
    /// holder. nil when the key is wrong or there is no description.
    func inviteDescription(escrowId: UInt64, key: String, token: String) async throws -> String? {
        var components = URLComponents()
        components.path = "/api/escrows/\(escrowId)/description"
        components.queryItems = [URLQueryItem(name: "key", value: key)]
        guard let path = components.string else { throw BackendError.invalidURL }

        let request = try authorized(path, token: token)
        let (data, response) = try await URLSession.shared.data(for: request)
        if (response as? HTTPURLResponse)?.statusCode == 404 { return nil }
        try Self.ensureOK(response, data)
        do {
            return try JSONDecoder().decode(EscrowDescriptionResponse.self, from: data).description
        } catch {
            throw BackendError.decoding(error)
        }
    }

    private func authorized(_ path: String, token: String) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw BackendError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private static func ensureOK(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw BackendError.badStatus(-1, "No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw BackendError.badStatus(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }
}

struct EscrowDescriptionResponse: Decodable {
    let escrowId: UInt64
    let description: String
    let inviteKey: String?

    enum CodingKeys: String, CodingKey {
        case escrowId = "escrow_id"
        case description
        case inviteKey = "invite_key"
    }
}
