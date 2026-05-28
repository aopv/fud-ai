import Foundation

/// Shared HTTP error parsing utilities used by ChatService, GeminiService, and SpeechService.
enum AINetworkHelpers {
    /// Parse a JSON error body. Handles OpenAI/Gemini `{ "error": { "message": "..." } }`,
    /// flat `{ "error": "..." }`, and AssemblyAI `{ "err_msg": "..." }` formats.
    static func parseErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
            return message
        }
        if let message = json["error"] as? String {
            return message
        }
        if let message = json["err_msg"] as? String {
            return message
        }
        return nil
    }

    static func friendlyMessage(for status: Int, raw: String) -> String {
        switch status {
        case 503, 529:
            return "The AI provider is overloaded right now. We retried a few times — please try again in a minute, or switch to a different provider/model in Settings → AI Provider."
        case 429:
            return "Rate limit hit on your API key. Wait a minute, or switch to another provider in Settings → AI Provider."
        case 401, 403:
            return "Your API key was rejected. Open Settings → AI Provider and re-paste a valid key."
        default:
            return raw
        }
    }
}
