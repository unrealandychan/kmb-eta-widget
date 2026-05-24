import Foundation

// MARK: - KMB API Client

enum KMBAPIError: Error {
    case network(Error)
    case decode(Error)
    case empty
}

struct KMBAPIClient {
    static let base = "https://data.etabus.gov.hk/v1/transport/kmb"

    // MARK: All stops (cached in memory for distance calculations)
    private static var _cachedStops: [KMBStop]?
    static func allStops() async throws -> [KMBStop] {
        if let cached = _cachedStops { return cached }
        struct Response: Decodable { let data: [KMBStop] }
        let url = URL(string: "\(base)/stop/")!
        let stops = try await get(url, as: Response.self).data
        _cachedStops = stops
        return stops
    }

    // MARK: Search stops by keyword
    static func searchStops(keyword: String) async throws -> [KMBStop] {
        let all = try await allStops()
        let kw = keyword.lowercased()
        return all.filter {
            $0.nameTc.lowercased().contains(kw) || $0.nameEn.lowercased().contains(kw)
        }
    }

    // MARK: ETA for a stop (all routes)
    static func stopETA(stopID: String) async throws -> [KMBEtaEntry] {
        struct Response: Decodable { let data: [KMBEtaEntry] }
        let url = URL(string: "\(base)/stop-eta/\(stopID)")!
        return try await get(url, as: Response.self).data
    }

    // MARK: Group raw ETAs into RouteEta list
    static func routeEtas(for stopID: String) async throws -> [RouteEta] {
        let raw = try await stopETA(stopID: stopID)
        var dict: [String: (dest: String, times: [Int?])] = [:]
        for entry in raw.sorted(by: { $0.etaSeq < $1.etaSeq }) {
            let key = "\(entry.route)|\(entry.destDisplay)"
            var bucket = dict[key] ?? (dest: entry.destDisplay, times: [])
            bucket.times.append(entry.minutesUntil)
            dict[key] = bucket
        }
        return dict
            .map { key, val in
                let parts = key.split(separator: "|")
                return RouteEta(
                    route: String(parts[0]),
                    dest: val.dest,
                    etas: Array(val.times.prefix(3))
                )
            }
            .sorted { ($0.nextMins ?? 999) < ($1.nextMins ?? 999) }
    }

    // MARK: Generic GET
    private static func get<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T {
        let (data, _) = try await URLSession.shared.data(from: url)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw KMBAPIError.decode(error)
        }
    }
}


