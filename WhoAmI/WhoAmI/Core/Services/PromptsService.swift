import Foundation
import Supabase

protocol PromptsService: Sendable {
    func today() async throws -> Prompt?
    func byId(_ id: UUID) async throws -> Prompt?
}

final class LivePromptsService: PromptsService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClientProvider.shared) {
        self.client = client
    }

    /// The publish_date is assigned in UTC by the publish-daily-prompt function; match that.
    private static var todayString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }

    func today() async throws -> Prompt? {
        let rows: [Prompt] = try await client
            .from("prompts").select()
            .eq("publish_date", value: Self.todayString)
            .limit(1).execute().value
        return rows.first
    }

    func byId(_ id: UUID) async throws -> Prompt? {
        let rows: [Prompt] = try await client
            .from("prompts").select()
            .eq("id", value: id.uuidString)
            .limit(1).execute().value
        return rows.first
    }
}
