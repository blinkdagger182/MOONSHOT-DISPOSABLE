import Foundation
import UIKit

// ─── Configuration ────────────────────────────────────────────────────────────
// These values match the credentials in .env at repo root.
private let supabaseURL  = "https://vzfrnmrozutaqkpdgygh.supabase.co"
private let supabaseKey  = "sb_publishable_mpQU7W27wzNQZJLH_uBkmg_dLQxYrEj"

// ─── Models ──────────────────────────────────────────────────────────────────
struct SupabaseEvent: Codable {
    var id: String
    var title: String
    var host_name: String
    var location: String
    var starts_at: String
    var expires_at: String?
    var duration_hours: Int
    var shots_per_guest: Int
    var guest_limit: Int
    var allow_voice_notes: Bool
    var voice_note_max_seconds: Int
    var filter_style: String
    var reveal_mode: String
    var is_public: Bool
    var created_at: String?
}

struct SupabaseGuest: Codable {
    var id: String?
    var event_id: String
    var name: String
    var role: String
    var shots_taken: Int
    var source: String
}

struct SupabasePhoto: Codable {
    var id: String?
    var event_id: String
    var guest_name: String
    var photo_url: String
    var source: String
    var created_at: String?
}

// ─── Manager ──────────────────────────────────────────────────────────────────
final class SupabaseManager {
    static let shared = SupabaseManager()
    private init() {}

    // Common headers for REST calls
    private var headers: [String: String] {
        [
            "apikey": supabaseKey,
            "Authorization": "Bearer \(supabaseKey)",
            "Content-Type": "application/json",
            "Prefer": "return=representation"
        ]
    }

    // ── Events ────────────────────────────────────────────────────────────────

    func createEvent(
        title: String,
        hostName: String,
        location: String,
        startsAt: Date,
        durationHours: Int,
        shotsPerGuest: Int,
        guestLimit: Int,
        allowVoiceNotes: Bool,
        voiceNoteMaxSeconds: Int,
        filterStyle: String,
        revealMode: String
    ) async throws -> SupabaseEvent {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let expiresAt = iso.string(from: startsAt.addingTimeInterval(Double(durationHours) * 3600))

        let body: [String: Any] = [
            "title": title,
            "host_name": hostName,
            "location": location,
            "starts_at": iso.string(from: startsAt),
            "expires_at": expiresAt,
            "duration_hours": durationHours,
            "shots_per_guest": shotsPerGuest,
            "guest_limit": guestLimit,
            "allow_voice_notes": allowVoiceNotes,
            "voice_note_max_seconds": voiceNoteMaxSeconds,
            "filter_style": filterStyle,
            "reveal_mode": revealMode,
            "is_public": true
        ]

        let url = URL(string: "\(supabaseURL)/rest/v1/events")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        let events = try data.decodeOrThrowSupabaseArray([SupabaseEvent].self)
        guard let event = events.first else { throw SupabaseError.empty }
        return event
    }

    func fetchEvent(id: String) async throws -> SupabaseEvent {
        var components = URLComponents(string: "\(supabaseURL)/rest/v1/events")!
        components.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(id)"),
            URLQueryItem(name: "select", value: "*")
        ]
        var req = URLRequest(url: components.url!)
        req.httpMethod = "GET"
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }

        let (data, _) = try await URLSession.shared.data(for: req)
        let events = try data.decodeOrThrowSupabaseArray([SupabaseEvent].self)
        guard let event = events.first else { throw SupabaseError.notFound }
        return event
    }

    func deleteEvent(id: String) async throws {
        var components = URLComponents(string: "\(supabaseURL)/rest/v1/events")!
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        var req = URLRequest(url: components.url!)
        req.httpMethod = "DELETE"
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        _ = try await URLSession.shared.data(for: req)
    }

    // ── Guests ────────────────────────────────────────────────────────────────

    func addGuest(eventId: String, name: String, role: String = "guest") async throws -> SupabaseGuest {
        let body: [String: Any] = [
            "event_id": eventId,
            "name": name,
            "role": role,
            "shots_taken": 0,
            "source": "ios"
        ]
        let url = URL(string: "\(supabaseURL)/rest/v1/guests")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        let guests = try data.decodeOrThrowSupabaseArray([SupabaseGuest].self)
        guard let guest = guests.first else { throw SupabaseError.empty }
        return guest
    }

    func fetchGuestCount(eventId: String) async throws -> Int {
        var components = URLComponents(string: "\(supabaseURL)/rest/v1/guests")!
        components.queryItems = [
            URLQueryItem(name: "event_id", value: "eq.\(eventId)"),
            URLQueryItem(name: "select", value: "id")
        ]
        var req = URLRequest(url: components.url!)
        req.httpMethod = "GET"
        var h = headers
        h["Prefer"] = "count=exact"
        h.forEach { req.setValue($1, forHTTPHeaderField: $0) }

        let (_, response) = try await URLSession.shared.data(for: req)
        // Content-Range: 0-N/total
        if let http = response as? HTTPURLResponse,
           let range = http.value(forHTTPHeaderField: "Content-Range"),
           let total = range.split(separator: "/").last,
           let count = Int(total) {
            return count
        }
        return 0
    }

    // ── Photos ────────────────────────────────────────────────────────────────

    func uploadPhoto(
        eventId: String,
        guestName: String,
        jpegData: Data,
        filterStyle: String,
        expiresAt: String?
    ) async throws -> String {
        let processedData = filterStyle == "vintage" ? applyVintageFilter(jpegData) : jpegData
        let safeName = guestName
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-")).inverted)
            .joined(separator: "_")
            .prefix(40)
        let path = "\(eventId)/\(safeName)_\(Int(Date().timeIntervalSince1970 * 1000)).jpg"

        let storageURL = URL(string: "\(supabaseURL)/storage/v1/object/event-photos/\(path)")!
        var req = URLRequest(url: storageURL)
        req.httpMethod = "POST"
        req.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        req.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        req.httpBody = processedData

        let (_, storageResp) = try await URLSession.shared.data(for: req)
        guard let httpResp = storageResp as? HTTPURLResponse,
              httpResp.statusCode == 200 || httpResp.statusCode == 201 else {
            throw URLError(.badServerResponse)
        }

        let publicURL = "\(supabaseURL)/storage/v1/object/public/event-photos/\(path)"

        // Save metadata
        var body: [String: Any] = [
            "event_id": eventId,
            "guest_name": guestName,
            "photo_url": publicURL,
            "source": "ios-camera"
        ]
        if let exp = expiresAt { body["expires_at"] = exp }

        let dbURL = URL(string: "\(supabaseURL)/rest/v1/photos")!
        var dbReq = URLRequest(url: dbURL)
        dbReq.httpMethod = "POST"
        headers.forEach { dbReq.setValue($1, forHTTPHeaderField: $0) }
        dbReq.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await URLSession.shared.data(for: dbReq)

        return publicURL
    }

    func submitContactForm(name: String, email: String, message: String, subjects: [String]) async throws {
        let body: [String: Any] = [
            "name": name,
            "email": email,
            "message": message,
            "subjects": subjects
        ]
        let url = URL(string: "\(supabaseURL)/rest/v1/contacts")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await URLSession.shared.data(for: req)
    }

    func deletePhoto(id: String) async throws {
        var components = URLComponents(string: "\(supabaseURL)/rest/v1/photos")!
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(id)")]
        var req = URLRequest(url: components.url!)
        req.httpMethod = "DELETE"
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        _ = try await URLSession.shared.data(for: req)
    }

    func fetchPhotos(eventId: String) async throws -> [SupabasePhoto] {
        var components = URLComponents(string: "\(supabaseURL)/rest/v1/photos")!
        components.queryItems = [
            URLQueryItem(name: "event_id", value: "eq.\(eventId)"),
            URLQueryItem(name: "is_deleted", value: "eq.false"),
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "created_at.desc")
        ]
        var req = URLRequest(url: components.url!)
        req.httpMethod = "GET"
        var h = headers
        h.removeValue(forKey: "Prefer")
        h.forEach { req.setValue($1, forHTTPHeaderField: $0) }

        let (data, _) = try await URLSession.shared.data(for: req)
        return try data.decodeOrThrowSupabaseArray([SupabasePhoto].self)
    }

    // ── Cover image ──────────────────────────────────────────────────────────

    func uploadCoverImage(eventId: String, jpegData: Data) async throws -> String {
        let path = "\(eventId)/cover/cover.jpg"
        let storageURL = URL(string: "\(supabaseURL)/storage/v1/object/event-photos/\(path)")!
        var req = URLRequest(url: storageURL)
        req.httpMethod = "POST"
        req.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        req.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        req.httpBody = jpegData
        _ = try await URLSession.shared.data(for: req)
        return "\(supabaseURL)/storage/v1/object/public/event-photos/\(path)"
    }

    // ── Vintage filter (pure Swift, mirrors web JS) ───────────────────────────
    private func applyVintageFilter(_ jpegData: Data) -> Data {
        guard let uiImage = UIImage(data: jpegData),
              let cgImage = uiImage.cgImage else { return jpegData }

        let width  = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return jpegData }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let cx = Double(width) / 2
        let cy = Double(height) / 2
        let maxDist = (cx * cx + cy * cy).squareRoot()

        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * width + x) * bytesPerPixel
                let grain = Double.random(in: -9...9)
                let dist = ((Double(x) - cx) * (Double(x) - cx) + (Double(y) - cy) * (Double(y) - cy)).squareRoot()
                let vignette = 1 - pow(dist / maxDist, 1.7) * 0.32

                var r = Double(rawData[idx])     + 10 + grain
                var g = Double(rawData[idx + 1]) +  3 + grain * 0.75
                var b = Double(rawData[idx + 2]) -  8 + grain * 0.55

                r = ((r - 128) * 1.08 + 128) * vignette
                g = ((g - 128) * 1.08 + 128) * vignette
                b = ((b - 128) * 1.08 + 128) * vignette

                rawData[idx]     = UInt8(max(0, min(255, r)))
                rawData[idx + 1] = UInt8(max(0, min(255, g)))
                rawData[idx + 2] = UInt8(max(0, min(255, b)))
            }
        }

        guard let newCGImage = context.makeImage() else { return jpegData }
        return UIImage(cgImage: newCGImage).jpegData(compressionQuality: 0.92) ?? jpegData
    }
}

enum SupabaseError: Error {
    case empty, notFound, uploadFailed
    case serverError(String)
}

private struct SupabaseErrorResponse: Decodable {
    let message: String?
    let code: String?
    let hint: String?
    let details: String?
}

extension Data {
    func decodeOrThrowSupabaseArray<T: Decodable>(_ type: [T].Type) throws -> [T] {
        do {
            return try JSONDecoder().decode(type, from: self)
        } catch let arrayError {
            if let errResp = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: self),
               let msg = errResp.message ?? errResp.hint ?? errResp.details {
                throw SupabaseError.serverError(msg)
            }
            throw arrayError
        }
    }
}
