import Foundation
import Supabase

protocol PromptsService: Sendable {
    func byId(_ id: UUID) async throws -> Prompt?
    /// Per-profile rotation feed for the Today screen (see `today_feed` RPC).
    func todayFeed() async throws -> TodayFeed
}

final class LivePromptsService: PromptsService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClientProvider.shared) {
        self.client = client
    }

    func byId(_ id: UUID) async throws -> Prompt? {
        let rows: [Prompt] = try await client
            .from("prompts").select()
            .eq("id", value: id.uuidString)
            .limit(1).execute().value
        return rows.first
    }

    func todayFeed() async throws -> TodayFeed {
        try await client.rpc("today_feed").execute().value
    }
}
