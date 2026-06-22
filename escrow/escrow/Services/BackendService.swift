//
//  BackendService.swift
//  escrow
//
//  Thin HTTP client for the Rust backend's auth endpoints. Pure networking —
//  no crypto. Signing happens in the Rust/AlloySwift layer; this only carries
//  the already-built message and signature to the server.
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

    /// `GET /api/auth/nonce` — a fresh single-use nonce to put in the SIWE message.
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

    /// `POST /api/auth/verify` — server recovers the signer, checks it matches
    /// `address`, and returns a JWT.
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

    private static func ensureOK(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw BackendError.badStatus(-1, "No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw BackendError.badStatus(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }
}
