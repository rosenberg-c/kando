import Foundation

// NOTE: We intentionally keep these URLSession shims outside generated OpenAPI
// client code. They work around runtime decode mismatches observed for a subset
// of operations while preserving explicit HTTP status handling in callers.
// Re-evaluate removal once generated runtime decoding is stable for reorder and
// task batch action operations in this project.
enum OpenAPITransportShims {
    static func performJSONRequest<Body: Encodable>(
        url: URL,
        method: String,
        accessToken: String,
        body: Body
    ) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KanbanAPIError.invalidResponse
        }
        return (data, httpResponse)
    }
}
