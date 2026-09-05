import Foundation

enum RobloxLibrary {
    static func placeDetails(placeID: String, cookie: String? = nil) async -> DemoGame? {
        if let cookie, let game = await placeDetailsAuthenticated(placeID: placeID, cookie: cookie) {
            return game
        }
        if let universeID = await universeID(forPlace: placeID),
           let game = await gamesFromUniverses([universeID]).first {
            return game
        }
        var game = DemoGame(id: placeID, title: "Place \(placeID)", placeID: placeID, hue: hue(for: placeID))
        game.thumbnailURL = await thumbnail(placeID: placeID)
        return game
    }

    static func recentlyPlayed(userID: Int, cookie: String) async -> [DemoGame] {
        let continued = await continuePlaying(cookie: cookie)
        if !continued.isEmpty { return continued }

        for raw in [
            "https://games.roblox.com/v2/users/\(userID)/recently-played-games?limit=10",
            "https://games.roblox.com/v2/users/\(userID)/games?accessFilter=2&sortOrder=Desc&limit=10"
        ] {
            let games = await fetchGameList(raw, cookie: cookie)
            if !games.isEmpty { return games }
        }
        return []
    }

    static func favoriteGames(userID: Int, cookie: String) async -> [DemoGame] {
        await fetchGameList(
            "https://games.roblox.com/v2/users/\(userID)/favorite/games?accessFilter=2&sortOrder=Desc&limit=10",
            cookie: cookie
        )
    }

    static func news() async -> [NewsItem] {
        guard let url = URL(string: "https://blog.roblox.com/feed/") else { return [] }
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let xml = String(data: data, encoding: .utf8)
        else { return [] }

        let items = xml.components(separatedBy: "<item>").dropFirst().prefix(5)
        return items.enumerated().compactMap { index, chunk in
            guard let title = firstTag("title", in: chunk)?
                .replacingOccurrences(of: "<![CDATA[", with: "")
                .replacingOccurrences(of: "]]>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !title.isEmpty,
                  let link = firstTag("link", in: chunk)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let url = URL(string: link)
            else { return nil }
            let date = firstTag("pubDate", in: chunk).flatMap(shortDate) ?? ""
            return NewsItem(
                id: UUID(),
                title: title,
                date: date,
                source: "Roblox Blog",
                url: url,
                hue: 0.12 + Double(index) * 0.18
            )
        }
    }

    static func searchExperiences(_ query: String, cookie: String? = nil) async -> [SearchExperience] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if trimmed.allSatisfy(\.isNumber), let exact = await placeDetails(placeID: trimmed, cookie: cookie) {
            return [
                SearchExperience(
                    placeID: exact.placeID,
                    title: exact.title,
                    creator: nil,
                    detail: "Place ID \(exact.placeID)",
                    playing: nil,
                    thumbnailURL: exact.thumbnailURL,
                    hue: exact.hue
                )
            ]
        }

        var hits = await omniSearch(trimmed, cookie: cookie)
        if hits.isEmpty {
            hits = await keywordSearch(trimmed, cookie: cookie)
        }
        return await decorate(hits)
    }

    static func searchPeople(_ query: String) async -> [SearchPerson] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://users.roblox.com/v1/users/search?keyword=\(encoded)&limit=10")
        else { return [] }

        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = json["data"] as? [[String: Any]]
        else { return [] }

        var people: [SearchPerson] = []
        for row in rows.prefix(10) {
            guard let id = intString(row["id"]) else { continue }
            let username = (row["name"] as? String) ?? "User"
            let display = (row["displayName"] as? String) ?? username
            people.append(
                SearchPerson(
                    userID: id,
                    username: username,
                    displayName: display,
                    avatarURL: await avatarHeadshot(userID: id)
                )
            )
        }
        return people
    }

    static func thumbnail(placeID: String) async -> String? {
        guard let url = URL(string: "https://thumbnails.roblox.com/v1/places/gameicons?placeIds=\(placeID)&returnPolicy=PlaceHolder&size=256x256&format=Png") else {
            return nil
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["data"] as? [[String: Any]]
        else { return nil }
        return list.first?["imageUrl"] as? String
    }

    private static func continuePlaying(cookie: String) async -> [DemoGame] {
        guard let url = URL(string: "https://apis.roblox.com/discovery-api/omni-recommendation") else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        RobloxAuth.apply(cookie: cookie, to: &request)
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "pageType": "Home",
            "sessionId": UUID().uuidString
        ])

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }

        var universeIDs: [String] = []
        let sorts = json["sorts"] as? [[String: Any]] ?? []
        let continueSort = sorts.first { sort in
            let topic = ((sort["topic"] as? String) ?? (sort["displayName"] as? String) ?? "").lowercased()
            return topic.contains("continue") || topic.contains("recent") || topic.contains("played")
        }
        let recs = (continueSort?["recommendationList"] as? [[String: Any]])
            ?? (continueSort?["contentList"] as? [[String: Any]])
            ?? []
        for rec in recs {
            if let id = intString(rec["contentId"]) ?? intString(rec["universeId"]) {
                universeIDs.append(id)
            }
        }

        if universeIDs.isEmpty,
           let meta = json["contentMetadata"] as? [String: Any],
           let games = meta["Game"] as? [String: Any] {
            universeIDs = Array(games.keys)
        }

        return await gamesFromUniverses(universeIDs)
    }

    private static func placeDetailsAuthenticated(placeID: String, cookie: String) async -> DemoGame? {
        guard let url = URL(string: "https://games.roblox.com/v1/games/multiget-place-details?placeIds=\(placeID)") else {
            return nil
        }
        var request = URLRequest(url: url)
        RobloxAuth.apply(cookie: cookie, to: &request)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200
        else { return nil }

        let rows = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]]
            ?? ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]).map { [$0] }
            ?? []
        guard let row = rows.first else { return nil }
        let name = (row["name"] as? String) ?? (row["Name"] as? String)
        let id = intString(row["placeId"]) ?? placeID
        var game = DemoGame(id: id, title: name ?? "Place \(placeID)", placeID: id, hue: hue(for: id))
        game.thumbnailURL = await thumbnail(placeID: id)
        return game
    }

    private static func omniSearch(_ query: String, cookie: String?) async -> [SearchExperience] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
        let session = UUID().uuidString
        let raw = "https://apis.roblox.com/search-api/omni-search?searchQuery=\(encoded)&pageType=all&sessionId=\(session)&verticalType=game"
        guard let url = URL(string: raw) else { return [] }
        var request = URLRequest(url: url)
        if let cookie {
            RobloxAuth.apply(cookie: cookie, to: &request)
        } else {
            request.setValue(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
                forHTTPHeaderField: "User-Agent"
            )
        }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }

        let groups = json["searchResults"] as? [[String: Any]] ?? []
        var hits: [SearchExperience] = []
        for group in groups {
            let contents = (group["contents"] as? [[String: Any]]) ?? []
            for row in contents {
                if let hit = experience(from: row) {
                    hits.append(hit)
                }
            }
        }
        return Array(unique(hits).prefix(12))
    }

    private static func keywordSearch(_ query: String, cookie: String?) async -> [SearchExperience] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://games.roblox.com/v1/games/list?model.keyword=\(encoded)&model.maxRows=20")
        else { return [] }
        var request = URLRequest(url: url)
        if let cookie {
            RobloxAuth.apply(cookie: cookie, to: &request)
        }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }

        let rows = (json["games"] as? [[String: Any]]) ?? (json["data"] as? [[String: Any]]) ?? []
        return Array(rows.prefix(12).compactMap(experience(from:)))
    }

    private static func experience(from row: [String: Any]) -> SearchExperience? {
        let universeID = intString(row["universeId"]) ?? intString(row["universeID"])
        let placeID = intString(row["rootPlaceId"])
            ?? intString(row["placeId"])
            ?? intString(row["rootPlaceID"])
            ?? universeID
        guard let placeID else { return nil }
        let title = (row["name"] as? String) ?? (row["title"] as? String) ?? "Experience"
        let playing = row["playerCount"] as? Int ?? (row["playerCount"] as? NSNumber)?.intValue
        let creator = (row["creatorName"] as? String) ?? (row["creator"] as? [String: Any])?["name"] as? String
        let detail = (row["description"] as? String)?.replacingOccurrences(of: "\n", with: " ")
        return SearchExperience(
            placeID: placeID,
            universeID: universeID,
            title: title,
            creator: creator,
            detail: detail.flatMap { $0.isEmpty ? nil : String($0.prefix(160)) },
            playing: playing,
            thumbnailURL: nil,
            hue: hue(for: placeID)
        )
    }

    private static func decorate(_ hits: [SearchExperience]) async -> [SearchExperience] {
        var result: [SearchExperience] = []
        for hit in hits {
            var next = hit
            if let universeID = hit.universeID, let extra = await gamesFromUniverses([universeID]).first {
                next.placeID = extra.placeID
                if next.thumbnailURL == nil { next.thumbnailURL = extra.thumbnailURL }
                if next.title == "Experience" { next.title = extra.title }
            }
            if next.thumbnailURL == nil {
                next.thumbnailURL = await thumbnail(placeID: next.placeID)
            }
            result.append(next)
        }
        return result
    }

    private static func unique(_ hits: [SearchExperience]) -> [SearchExperience] {
        var seen: Set<String> = []
        return hits.filter { seen.insert($0.placeID).inserted }
    }

    private static func avatarHeadshot(userID: String) async -> String? {
        guard let url = URL(string: "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=\(userID)&size=150x150&format=Png") else {
            return nil
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["data"] as? [[String: Any]]
        else { return nil }
        return list.first?["imageUrl"] as? String
    }

    private static func universeID(forPlace placeID: String) async -> String? {
        guard let url = URL(string: "https://apis.roblox.com/universes/v1/places/\(placeID)/universe") else {
            return nil
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return intString(json["universeId"])
    }

    private static func gamesFromUniverses(_ ids: [String]) async -> [DemoGame] {
        let unique = Array(Set(ids)).prefix(10)
        guard !unique.isEmpty else { return [] }
        let joined = unique.joined(separator: ",")
        guard let url = URL(string: "https://games.roblox.com/v1/games?universeIds=\(joined)") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = json["data"] as? [[String: Any]]
        else { return [] }

        var games: [DemoGame] = []
        for row in rows {
            guard let placeID = intString(row["rootPlaceId"]) ?? intString(row["placeId"]) else { continue }
            let title = (row["name"] as? String) ?? "Experience"
            var game = DemoGame(id: placeID, title: title, placeID: placeID, hue: hue(for: placeID))
            game.thumbnailURL = await thumbnail(placeID: placeID)
            games.append(game)
        }
        return games
    }

    private static func fetchGameList(_ raw: String, cookie: String) async -> [DemoGame] {
        guard let url = URL(string: raw) else { return [] }
        var request = URLRequest(url: url)
        RobloxAuth.apply(cookie: cookie, to: &request)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = json["data"] as? [[String: Any]]
        else { return [] }

        var placeIDs: [String] = []
        var universeIDs: [String] = []
        var titled: [String: String] = [:]

        for row in rows.prefix(8) {
            let root = row["rootPlace"] as? [String: Any]
            if let placeID = intString(root?["id"]) ?? intString(row["rootPlaceId"]) ?? intString(row["placeId"]) {
                placeIDs.append(placeID)
                if let title = (row["name"] as? String) ?? (row["title"] as? String) {
                    titled[placeID] = title
                }
            } else if let universeID = intString(row["universeId"]) ?? intString(row["id"]) {
                universeIDs.append(universeID)
            }
        }

        var games: [DemoGame] = []
        if !universeIDs.isEmpty {
            games.append(contentsOf: await gamesFromUniverses(universeIDs))
        }
        for placeID in placeIDs where !games.contains(where: { $0.placeID == placeID }) {
            var game = DemoGame(
                id: placeID,
                title: titled[placeID] ?? "Experience",
                placeID: placeID,
                hue: hue(for: placeID)
            )
            game.thumbnailURL = await thumbnail(placeID: placeID)
            games.append(game)
        }
        return Array(games.prefix(8))
    }

    private static func intString(_ value: Any?) -> String? {
        if let number = value as? Int { return String(number) }
        if let number = value as? NSNumber { return number.stringValue }
        if let text = value as? String, !text.isEmpty { return text }
        return nil
    }

    private static func hue(for placeID: String) -> Double {
        let hash = abs(placeID.hashValue)
        return Double(hash % 1000) / 1000
    }

    private static func firstTag(_ name: String, in xml: String) -> String? {
        guard let start = xml.range(of: "<\(name)>"),
              let end = xml.range(of: "</\(name)>", range: start.upperBound..<xml.endIndex)
        else { return nil }
        return String(xml[start.upperBound..<end.lowerBound])
    }

    private static func shortDate(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        guard let date = formatter.date(from: trimmed) else {
            return String(trimmed.prefix(16))
        }
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
