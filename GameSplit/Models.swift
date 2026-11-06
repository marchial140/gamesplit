import Foundation
import SwiftData

// IDs and flat, local-only records keep the V1 reliable and allow future multi-sport support.
@Model final class Club {
    var id: UUID
    var name: String
    var sport: String
    var createdAt: Date
    init(name: String, sport: String = "football") {
        id = UUID(); self.name = name; self.sport = sport; createdAt = .now
    }
}

@Model final class Season {
    var id: UUID
    var clubID: UUID
    var name: String
    var createdAt: Date
    init(clubID: UUID, name: String) {
        id = UUID(); self.clubID = clubID; self.name = name; createdAt = .now
    }
}

@Model final class Player {
    var id: UUID
    var clubID: UUID
    var name: String
    var position: String
    var number: Int
    var overall: Int
    var createdAt: Date
    init(clubID: UUID, name: String, position: String = "WR", number: Int = 0, overall: Int = 75) {
        id = UUID(); self.clubID = clubID; self.name = name
        self.position = position; self.number = number; self.overall = overall; createdAt = .now
    }
}

@Model final class MatchGame {
    var id: UUID
    var clubID: UUID
    var seasonID: UUID
    var date: Date
    var venue: String
    var bluePlayerIDs: String
    var redPlayerIDs: String
    var paidPlayerIDs: String
    var totalCost: Double
    var blueScore: Int
    var redScore: Int
    var touchdownPoints: Int = 6
    var conversionPoints: Int = 1
    var isFinished: Bool

    init(clubID: UUID, seasonID: UUID, date: Date, venue: String, totalCost: Double = 0) {
        id = UUID(); self.clubID = clubID; self.seasonID = seasonID
        self.date = date; self.venue = venue; self.totalCost = totalCost
        bluePlayerIDs = ""; redPlayerIDs = ""; paidPlayerIDs = ""
        blueScore = 0; redScore = 0; isFinished = false
    }
    var blueIDs: Set<UUID> {
        get { IDList.decode(bluePlayerIDs) }
        set { bluePlayerIDs = IDList.encode(newValue) }
    }
    var redIDs: Set<UUID> {
        get { IDList.decode(redPlayerIDs) }
        set { redPlayerIDs = IDList.encode(newValue) }
    }
    var paidIDs: Set<UUID> {
        get { IDList.decode(paidPlayerIDs) }
        set { paidPlayerIDs = IDList.encode(newValue) }
    }
    var participants: Set<UUID> { blueIDs.union(redIDs) }
    var costPerPlayer: Double { participants.isEmpty ? 0 : totalCost / Double(participants.count) }
    var collected: Double { costPerPlayer * Double(paidIDs.intersection(participants).count) }
    var outstanding: Double { max(0, totalCost - collected) }
}

@Model final class StatEntry {
    var id: UUID
    var eventID: UUID? = nil
    var matchID: UUID
    var playerID: UUID
    var kind: String
    var createdAt: Date
    init(matchID: UUID, playerID: UUID, kind: String) {
        id = UUID(); self.matchID = matchID; self.playerID = playerID
        self.kind = kind; createdAt = .now
    }
}

enum IDList {
    static func decode(_ s: String) -> Set<UUID> {
        Set(s.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
    }
    static func encode(_ ids: Set<UUID>) -> String {
        ids.map(\.uuidString).sorted().joined(separator: ",")
    }
}

enum Position: String, CaseIterable, Identifiable {
    case QB, WR, RB, DB, FLEX
    var id: String { rawValue }
}

enum StatKind: String, CaseIterable, Identifiable {
    case passTD = "pass_td"
    case receivingTD = "receiving_td"
    case rushingTD = "rushing_td"
    case interception = "interception"
    case conversion = "conversion"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .passTD: "Passe TD"
        case .receivingTD: "Réception TD"
        case .rushingTD: "Course TD"
        case .interception: "Interception défensive"
        case .conversion: "Conversion réussie"
        }
    }
}

struct PlayerTotals {
    var passTD = 0
    var receivingTD = 0
    var rushingTD = 0
    var interceptions = 0
    var conversions = 0
    var appearances = 0
    var wins = 0
    var touchdowns: Int { receivingTD + rushingTD }
    var contributionPoints: Int { touchdowns * 6 + passTD * 2 + interceptions * 2 + conversions }
}

enum Totals {
    static func forPlayer(_ id: UUID, games: [MatchGame], entries: [StatEntry]) -> PlayerTotals {
        var total = PlayerTotals()
        let gameIDs = Set(games.map(\.id))
        for entry in entries where entry.playerID == id && gameIDs.contains(entry.matchID) {
            switch entry.kind {
            case StatKind.passTD.rawValue: total.passTD += 1
            case StatKind.receivingTD.rawValue: total.receivingTD += 1
            case StatKind.rushingTD.rawValue: total.rushingTD += 1
            case StatKind.interception.rawValue: total.interceptions += 1
            case StatKind.conversion.rawValue: total.conversions += 1
            default: break
            }
        }
        for game in games where game.isFinished && game.participants.contains(id) {
            total.appearances += 1
            if game.blueScore != game.redScore &&
               ((game.blueScore > game.redScore && game.blueIDs.contains(id)) ||
                (game.redScore > game.blueScore && game.redIDs.contains(id))) {
                total.wins += 1
            }
        }
        return total
    }
}

enum TeamsBalancer {
    /// Greedy OVR balance with an early QB split; intended for recreational games.
    static func split(_ players: [Player]) -> (blue: Set<UUID>, red: Set<UUID>) {
        let unique = Dictionary(players.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let sorted = unique.values.sorted {
            if ($0.position == "QB") != ($1.position == "QB") { return $0.position == "QB" }
            if $0.overall != $1.overall { return $0.overall > $1.overall }
            return $0.id.uuidString < $1.id.uuidString
        }
        var blue = Set<UUID>(), red = Set<UUID>()
        var blueScore = 0, redScore = 0
        let blueCapacity = (sorted.count + 1) / 2
        let redCapacity = sorted.count / 2
        for player in sorted {
            let chooseBlue: Bool
            if blue.count >= blueCapacity { chooseBlue = false }
            else if red.count >= redCapacity { chooseBlue = true }
            else if player.position == "QB" {
                let qbBlue = sorted.filter { $0.position == "QB" && blue.contains($0.id) }.count
                let qbRed = sorted.filter { $0.position == "QB" && red.contains($0.id) }.count
                chooseBlue = qbBlue == qbRed ? blueScore <= redScore : qbBlue < qbRed
            } else { chooseBlue = blueScore <= redScore }
            if chooseBlue { blue.insert(player.id); blueScore += player.overall }
            else { red.insert(player.id); redScore += player.overall }
        }
        // Improve OVR differences by swaps, preserving sizes and QB distribution.
        var improved = true
        while improved {
            improved = false
            let difference = abs(blueScore - redScore)
            var best = difference
            var swap: (Player, Player)?
            for b in sorted where blue.contains(b.id) {
                for r in sorted where red.contains(r.id) {
                    guard (b.position == "QB") == (r.position == "QB") else { continue }
                    let candidate = abs((blueScore - b.overall + r.overall) - (redScore - r.overall + b.overall))
                    if candidate < best { best = candidate; swap = (b, r) }
                }
            }
            if let (b, r) = swap {
                blue.remove(b.id); red.remove(r.id); blue.insert(r.id); red.insert(b.id)
                blueScore += r.overall - b.overall; redScore += b.overall - r.overall
                improved = true
            }
        }
        return (blue, red)
    }
}

/// A pass and its reception form one atomic event. Scores remain explicitly manual.
enum FootballEvents {
    static func make(game: MatchGame, kind: StatKind, playerID: UUID, receiverID: UUID? = nil) -> [StatEntry] {
        guard game.participants.contains(playerID) else { return [] }
        if kind == .passTD {
            guard let receiverID, receiverID != playerID,
                  (game.blueIDs.contains(playerID) && game.blueIDs.contains(receiverID)) ||
                  (game.redIDs.contains(playerID) && game.redIDs.contains(receiverID)) else { return [] }
            let eventID = UUID()
            let pass = StatEntry(matchID: game.id, playerID: playerID, kind: kind.rawValue)
            let reception = StatEntry(matchID: game.id, playerID: receiverID, kind: StatKind.receivingTD.rawValue)
            pass.eventID = eventID; reception.eventID = eventID
            return [pass, reception]
        }
        return [StatEntry(matchID: game.id, playerID: playerID, kind: kind.rawValue)]
    }
    static func points(kind: StatKind, game: MatchGame) -> Int {
        switch kind {
        case .passTD, .receivingTD, .rushingTD: return game.touchdownPoints
        case .conversion: return game.conversionPoints
        case .interception: return 0
        }
    }
    static func applyScore(kind: StatKind, playerID: UUID, game: MatchGame) {
        let award = points(kind: kind, game: game)
        if game.blueIDs.contains(playerID) { game.blueScore += award }
        else if game.redIDs.contains(playerID) { game.redScore += award }
    }
    static func related(to entry: StatEntry, in entries: [StatEntry]) -> [StatEntry] {
        entries.filter { candidate in
            candidate.id == entry.id || (entry.eventID != nil && candidate.eventID == entry.eventID && candidate.matchID == entry.matchID)
        }
    }
}

enum InputValidation {
    static func cost(_ text: String) -> Double? {
        guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")),
              value.isFinite, value >= 0, value <= 1_000_000 else { return nil }
        return (value * 100).rounded() / 100
    }
}
