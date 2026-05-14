import Foundation
import Supabase

final class AuthService {
    static let shared = AuthService()

    private let injectedClient: SupabaseClient?
    private var client: SupabaseClient {
        injectedClient ?? SupabaseManager.shared.client
    }

    init(client: SupabaseClient? = nil) {
        injectedClient = client
    }

    var currentUserId: String? {
        client.auth.currentUser?.id.uuidString
    }

    @discardableResult
    func ensureSession() async throws -> String {
        if let session = try? await client.auth.session, !session.isExpired {
            return session.user.id.uuidString
        }

        let session = try await client.auth.signInAnonymously()
        return session.user.id.uuidString
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }
}
