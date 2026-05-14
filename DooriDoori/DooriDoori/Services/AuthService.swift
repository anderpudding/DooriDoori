import Foundation
import Supabase

final class AuthService {
    static let shared = AuthService()

    private let injectedClient: SupabaseClient?
    private var client: SupabaseClient {
        injectedClient ?? SupabaseManager.shared.client
    }

    #if DEBUG
    private var hasPrintedAccessToken = false
    #endif

    init(client: SupabaseClient? = nil) {
        injectedClient = client
    }

    var currentUserId: String? {
        client.auth.currentUser?.id.uuidString
    }

    @discardableResult
    func ensureSession() async throws -> String {
        if let session = try? await client.auth.session, !session.isExpired {
            #if DEBUG
            print("Supabase session user id:", session.user.id.uuidString)
            await printCurrentSupabaseAccessTokenOnce()
            #endif

            return session.user.id.uuidString
        }

        let session: Session
        do {
            session = try await client.auth.signInAnonymously()
        } catch {
            #if DEBUG
            print("Anonymous Supabase sign-in failed:", error)
            #endif

            throw error
        }

        #if DEBUG
        print("Supabase anonymous session user id:", session.user.id.uuidString)
        await printCurrentSupabaseAccessTokenOnce()
        #endif

        return session.user.id.uuidString
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    #if DEBUG
    func printCurrentSupabaseAccessTokenOnce() async {
        guard !hasPrintedAccessToken else { return }

        hasPrintedAccessToken = true

        print("----- DEBUG TOKEN PRINT HOOK REACHED -----")

        do {
            let session = try await client.auth.session
            print("----- SUPABASE ACCESS TOKEN START -----")
            print(session.accessToken)
            print("----- SUPABASE ACCESS TOKEN END -----")
        } catch {
            print("No active Supabase session:", error)
        }
    }

    // DEBUG ONLY:
    // Prints the Supabase Auth access token so local Edge Functions can be tested with:
    // curl -H "Authorization: Bearer <token>" ...
    // Never use this in production.
    func printCurrentSupabaseAccessToken() async {
        await printCurrentSupabaseAccessTokenOnce()
    }
    #endif
}
