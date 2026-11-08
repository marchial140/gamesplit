import XCTest
import SwiftData
@testable import GameSplit

final class GameSplitTests: XCTestCase {
    func testIDEncodingRoundtrip() {
        let ids: Set<UUID> = [UUID(), UUID()]
        XCTAssertEqual(IDList.decode(IDList.encode(ids)), ids)
    }
    func testBalancingKeepsEveryoneAndSimilarCounts() {
        let clubID = UUID()
        let people = (0..<15).map { index in
            Player(clubID: clubID, name: "Person \(index)", position: index < 2 ? "QB" : "WR", overall: 60 + index)
        }
        let result = TeamsBalancer.split(people)
        XCTAssertEqual(result.blue.count + result.red.count, people.count)
        XCTAssertTrue(result.blue.isDisjoint(with: result.red))
        XCTAssertLessThanOrEqual(abs(result.blue.count - result.red.count), 1)
        XCTAssertEqual(result.blue.intersection(Set(people.prefix(2).map(\.id))).count, 1)
        XCTAssertEqual(result.red.intersection(Set(people.prefix(2).map(\.id))).count, 1)
    }
    func testPerPlayerCostWithoutParticipants() {
        let game = MatchGame(clubID: UUID(), seasonID: UUID(), date: .now, venue: "", totalCost: 300)
        XCTAssertEqual(game.costPerPlayer, 0)
    }
}

@MainActor
final class AcceptanceTests: XCTestCase {
    private func fixture() -> (MatchGame, [Player]) {
        let club = UUID()
        let players = (0..<14).map { Player(clubID: club, name: "Joueur \($0)", position: $0 < 2 ? "QB" : "WR", overall: 50 + $0 * 3) }
        let game = MatchGame(clubID: club, seasonID: UUID(), date: .now, venue: "Parc", totalCost: 280)
        let teams = TeamsBalancer.split(players)
        game.blueIDs = teams.blue; game.redIDs = teams.red
        return (game, players)
    }
    func testFourteenPlayersAndPayments() {
        let (game, players) = fixture()
        XCTAssertEqual(game.blueIDs.count, 7)
        XCTAssertEqual(game.redIDs.count, 7)
        XCTAssertEqual(game.participants.count, 14)
        XCTAssertTrue(game.blueIDs.isDisjoint(with: game.redIDs))
        XCTAssertNotEqual(game.blueIDs.contains(players[0].id), game.blueIDs.contains(players[1].id))
        XCTAssertEqual(game.costPerPlayer, 20)
        game.paidIDs = Set(players.prefix(10).map(\.id))
        XCTAssertEqual(game.collected, 200)
        XCTAssertEqual(game.outstanding, 80)
    }
    func testPassingEventAndAtomicCorrection() {
        let (game, players) = fixture()
        let alex = players.first { game.blueIDs.contains($0.id) }!
        let max = players.first { game.blueIDs.contains($0.id) && $0.id != alex.id }!
        let entries = FootballEvents.make(game: game, kind: .passTD, playerID: alex.id, receiverID: max.id)
        FootballEvents.applyScore(kind: .passTD, playerID: alex.id, game: game)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(game.blueScore, 6)
        XCTAssertEqual(Totals.forPlayer(alex.id, games: [game], entries: entries).passTD, 1)
        XCTAssertEqual(Totals.forPlayer(max.id, games: [game], entries: entries).receivingTD, 1)
        XCTAssertEqual(FootballEvents.related(to: entries[1], in: entries).count, 2)
        // Removing both records corrects stats; the official score remains explicit.
        XCTAssertEqual(Totals.forPlayer(max.id, games: [game], entries: []).receivingTD, 0)
        XCTAssertEqual(game.blueScore, 6)
        XCTAssertTrue(FootballEvents.make(game: game, kind: .passTD, playerID: alex.id, receiverID: alex.id).isEmpty)
        let opponent = players.first { game.redIDs.contains($0.id) }!
        XCTAssertTrue(FootballEvents.make(game: game, kind: .passTD, playerID: alex.id, receiverID: opponent.id).isEmpty)
    }
    func testInterceptionTieAndSeasons() {
        let (game, players) = fixture()
        let sam = players[0]
        let entries = FootballEvents.make(game: game, kind: .interception, playerID: sam.id)
        FootballEvents.applyScore(kind: .interception, playerID: sam.id, game: game)
        game.isFinished = true
        let second = MatchGame(clubID: game.clubID, seasonID: game.seasonID, date: .now, venue: "")
        second.blueIDs = [sam.id]; second.blueScore = 12; second.isFinished = true
        let totals = Totals.forPlayer(sam.id, games: [game, second], entries: entries)
        XCTAssertEqual(totals.appearances, 2)
        XCTAssertEqual(totals.wins, 1)
        XCTAssertEqual(totals.interceptions, 1)
        let newSeason = Season(clubID: game.clubID, name: "Nouvelle saison")
        XCTAssertEqual(Totals.forPlayer(sam.id, games: [game, second].filter { $0.seasonID == newSeason.id }, entries: entries).interceptions, 0)
        XCTAssertEqual(game.blueScore, 0)
    }
    func testEdgeCasesAndRules() {
        XCTAssertTrue(TeamsBalancer.split([]).blue.isEmpty)
        let player = Player(clubID: UUID(), name: "Solo")
        let split = TeamsBalancer.split([player, player])
        XCTAssertEqual(split.blue.union(split.red), [player.id])
        let game = MatchGame(clubID: player.clubID, seasonID: UUID(), date: .now, venue: "")
        game.blueIDs = [player.id]
        XCTAssertEqual(game.costPerPlayer, 0)
        game.touchdownPoints = 7; game.conversionPoints = 2
        FootballEvents.applyScore(kind: .rushingTD, playerID: player.id, game: game)
        FootballEvents.applyScore(kind: .conversion, playerID: player.id, game: game)
        XCTAssertEqual(game.blueScore, 9)
        XCTAssertEqual(InputValidation.cost("280,00"), 280)
        for invalid in ["-1", "nan", "inf", "abc", ""] { XCTAssertNil(InputValidation.cost(invalid)) }
        XCTAssertEqual(IDList.decode("invalid," + player.id.uuidString), [player.id])
    }
}

@MainActor
final class PersistenceTests: XCTestCase {
    private var schema: Schema { Schema([Club.self, Season.self, Player.self, MatchGame.self, StatEntry.self, Team.self]) }
    func testDiskReopenPreservesEditsAndBackupRoundtrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.store")
        let id: UUID
        let backupData: Data
        do {
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(url: url)])
            let context = ModelContext(container)
            let club = Club(name: "Amis")
            let season = Season(clubID: club.id, name: "Automne")
            let player = Player(clubID: club.id, name: "Alex")
            let game = MatchGame(clubID: club.id, seasonID: season.id, date: .now, venue: "Parc", totalCost: 20)
            context.insert(club); context.insert(season); context.insert(player); context.insert(game)
            game.blueIDs = [player.id]; game.paidIDs = [player.id]
            player.overall = 91; player.name = "Alex modifié"; game.blueScore = 12; game.isFinished = true
            let entry = FootballEvents.make(game: game, kind: .rushingTD, playerID: player.id)[0]
            context.insert(entry)
            try context.save()
            id = player.id
            backupData = try JSONEncoder().encode(LocalBackup(context: context))
        }
        let reopened = try ModelContainer(for: schema, configurations: [ModelConfiguration(url: url)])
        let context = ModelContext(reopened)
        let player = try XCTUnwrap(context.fetch(FetchDescriptor<Player>()).first)
        XCTAssertEqual(player.id, id); XCTAssertEqual(player.overall, 91); XCTAssertEqual(player.name, "Alex modifié")
        let game = try XCTUnwrap(context.fetch(FetchDescriptor<MatchGame>()).first)
        XCTAssertEqual(game.blueScore, 12); XCTAssertTrue(game.isFinished); XCTAssertEqual(game.collected, 20)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<StatEntry>()), 1)
        let restored = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let destination = ModelContext(restored)
        let backup = try JSONDecoder().decode(LocalBackup.self, from: backupData)
        try backup.restore(context: destination)
        XCTAssertEqual(try destination.fetch(FetchDescriptor<Player>()).first?.id, id)
        XCTAssertEqual(try destination.fetch(FetchDescriptor<MatchGame>()).first?.blueScore, 12)
        XCTAssertEqual(try destination.fetchCount(FetchDescriptor<StatEntry>()), 1)
        XCTAssertThrowsError(try backup.restore(context: destination))
    }
}

@MainActor
final class V11Tests: XCTestCase {
    private func container() throws -> ModelContainer {
        try ModelContainer(for: Club.self, Season.self, Player.self, MatchGame.self, StatEntry.self, Team.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
    func testFourIndividualPointsDoNotChangeSixTeamPoints() throws {
        let player = Player(clubID: UUID(), name: "Alex", position: "QB")
        let receiver = Player(clubID: player.clubID, name: "Max")
        let game = MatchGame(clubID: player.clubID, seasonID: UUID(), date: .now, venue: "")
        game.blueIDs = [player.id, receiver.id]
        let entries = FootballEvents.make(game: game, kind: .passTD, playerID: player.id, receiverID: receiver.id, value: 4)
        FootballEvents.applyScore(kind: .passTD, playerID: player.id, game: game, value: 4)
        XCTAssertEqual(game.blueScore, 24)
        // Backup serialization must preserve quantities and the linked event ID.
        let saved = try JSONEncoder().encode(StatEntryRecord(entries[0]))
        let restored = try JSONDecoder().decode(StatEntryRecord.self, from: saved).model()
        XCTAssertEqual(restored.value, 4)
        XCTAssertEqual(restored.id, entries[0].id)
        XCTAssertEqual(restored.eventID, entries[0].eventID)
        XCTAssertEqual(restored.kind, entries[0].kind)
        let totals = Totals.byPlayer(games: [game], entries: entries)
        XCTAssertEqual(totals[player.id]?.contributionPoints, 16)
        XCTAssertEqual(totals[receiver.id]?.receivingTD, 4)
        XCTAssertEqual(totals[receiver.id]?.receptions, 4)
        entries[0].value = 2; entries[1].value = 2
        XCTAssertEqual(Totals.forPlayer(player.id, games: [game], entries: entries).contributionPoints, 8)
        XCTAssertEqual(game.blueScore, 24) // Explicit manual score correction, never stats-derived.
    }
    func testPositionStatisticsAndSecondaryQuarterback() {
        let player = Player(clubID: UUID(), name: "Sam", position: "Rusher")
        player.secondaryPositions = "QB,DB"
        XCTAssertEqual(player.positions, ["Rusher", "QB", "DB"])
        let otherQB = Player(clubID: player.clubID, name: "Alex", position: "QB")
        let split = TeamsBalancer.split([player, otherQB])
        XCTAssertEqual(split.blue.count, 1); XCTAssertEqual(split.red.count, 1)
        let game = MatchGame(clubID: player.clubID, seasonID: UUID(), date: .now, venue: "")
        game.blueIDs = [player.id]; game.isFinished = true
        let kinds: [(StatKind, Int)] = [(.passingYards, 240), (.receivingYards, 83), (.reception, 5), (.tackle, 7), (.sack, 2), (.thrownInterception, 1)]
        let entries = kinds.flatMap { FootballEvents.make(game: game, kind: $0.0, playerID: player.id, value: $0.1) }
        let totals = Totals.forPlayer(player.id, games: [game], entries: entries)
        XCTAssertEqual(totals.passingYards, 240); XCTAssertEqual(totals.receivingYards, 83)
        XCTAssertEqual(totals.receptions, 5); XCTAssertEqual(totals.tackles, 7)
        XCTAssertEqual(totals.sacks, 2); XCTAssertEqual(totals.thrownInterceptions, 1)
        XCTAssertEqual(totals.contributionPoints, 0)
        XCTAssertTrue(FootballEvents.make(game: game, kind: .sack, playerID: player.id, value: 0).isEmpty)
    }
    func testTeamsAndV11BackupRoundtrip() throws {
        let source = try container(); let context = ModelContext(source)
        let club = Club(name: "Communauté"); let season = Season(clubID: club.id, name: "2027")
        let player = Player(clubID: club.id, name: "Sam", position: "Rusher")
        player.secondaryPositions = "DB"; player.hasNumber = false; player.photoData = Data([1, 2, 3])
        club.localProfileID = player.id
        let first = Team(clubID: club.id, name: "Éclairs"), second = Team(clubID: club.id, name: "Lynx")
        first.memberIDs = [player.id]; first.captainIDs = [player.id]; second.memberIDs = [player.id]
        first.logoData = Data([4, 5])
        context.insert(club); context.insert(season); context.insert(player); context.insert(first); context.insert(second)
        let game = MatchGame(clubID: club.id, seasonID: season.id, date: .now, venue: "Parc")
        game.teamID = first.id; game.opponentTeamID = second.id; game.blueIDs = [player.id]
        game.blueScore = 20; game.redScore = 12; game.isFinished = true; context.insert(game)
        try context.save()
        let backup = try JSONDecoder().decode(LocalBackup.self, from: JSONEncoder().encode(LocalBackup(context: context)))
        let destination = try container(); let target = ModelContext(destination)
        try backup.restore(context: target)
        let restored = try XCTUnwrap(target.fetch(FetchDescriptor<Player>()).first)
        XCTAssertEqual(restored.photoData, player.photoData); XCTAssertFalse(restored.hasNumber)
        XCTAssertEqual(restored.positions, ["Rusher", "DB"])
        XCTAssertEqual(try target.fetch(FetchDescriptor<Club>()).first?.localProfileID, player.id)
        let teams = try target.fetch(FetchDescriptor<Team>())
        XCTAssertEqual(teams.filter { $0.memberIDs.contains(player.id) }.count, 2)
        XCTAssertEqual(teams.first { $0.id == first.id }?.logoData, first.logoData)
        let summary = TeamRecordSummary.calculate(teamID: first.id, games: [game])
        XCTAssertEqual(summary.wins, 1); XCTAssertEqual(summary.pointsFor, 20)
        XCTAssertEqual(TeamRecordSummary.calculate(teamID: second.id, games: [game]).losses, 1)
    }
    func testLegacyJSONStillImportsWithoutNewKeys() throws {
        let source = try container(); let context = ModelContext(source)
        let club = Club(name: "V1"); let season = Season(clubID: club.id, name: "2026")
        let player = Player(clubID: club.id, name: "Max")
        let game = MatchGame(clubID: club.id, seasonID: season.id, date: .now, venue: "")
        game.blueIDs = [player.id]
        context.insert(club); context.insert(season); context.insert(player); context.insert(game)
        context.insert(StatEntry(matchID: game.id, playerID: player.id, kind: StatKind.receivingTD.rawValue))
        try context.save()
        let data = try JSONEncoder().encode(LocalBackup(context: context))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["version"] = 1; json.removeValue(forKey: "teams")
        let additions = ["clubs": ["localProfileID"], "players": ["photoData", "hasNumber", "secondaryPositions"], "matchgames": ["teamID", "opponentTeamID", "opponentName"], "statentrys": ["value"]]
        for (key, fields) in additions {
            var records = try XCTUnwrap(json[key] as? [[String: Any]])
            for index in records.indices { for field in fields { records[index].removeValue(forKey: field) } }
            json[key] = records
        }
        let decoded = try JSONDecoder().decode(LocalBackup.self, from: JSONSerialization.data(withJSONObject: json))
        let destination = try container(); let target = ModelContext(destination)
        try decoded.restore(context: target)
        XCTAssertEqual(try target.fetchCount(FetchDescriptor<Team>()), 0)
        XCTAssertTrue(try XCTUnwrap(target.fetch(FetchDescriptor<Player>()).first).hasNumber)
        XCTAssertEqual(try target.fetch(FetchDescriptor<StatEntry>()).first?.value, 1)
    }
    func testCSVQuotedFieldsAndInvalidInput() throws {
        let rows = try CalendarCSV.parse("date,lieu,adversaire,equipe,cout\n2027-06-12T19:00:00-04:00,\"Parc, Nord\",Lynx,Éclairs,280\n")
        XCTAssertEqual(rows.count, 1); XCTAssertEqual(rows[0].venue, "Parc, Nord"); XCTAssertEqual(rows[0].cost, 280)
        XCTAssertThrowsError(try CalendarCSV.parse("lieu\nParc"))
        XCTAssertThrowsError(try CalendarCSV.parse("date,cout\ninvalid,10"))
        XCTAssertThrowsError(try CalendarCSV.parse("date,cout\n2027-06-12T19:00:00Z,-1"))
        XCTAssertThrowsError(try CalendarCSV.parse("date,lieu\n2027-06-12T19:00:00Z,\"unclosed"))
        let semicolon = try CalendarCSV.parse("date;cout\n2027-06-12T19:00:00Z;20,50")
        XCTAssertEqual(semicolon.first?.cost, 20.5)
    }
    func testCalendarImportIsIdempotentAndValidatesWholeBatch() throws {
        let source = try container(); let context = ModelContext(source)
        let club = Club(name: "Amis"), team = Team(clubID: UUID(), name: "Éclairs")
        team.clubID = club.id
        let season = Season(clubID: club.id, name: "2027")
        let homePlayer = Player(clubID: club.id, name: "Alex"), awayPlayer = Player(clubID: club.id, name: "Sam")
        team.memberIDs = [homePlayer.id]
        context.insert(homePlayer); context.insert(awayPlayer)
        context.insert(club); context.insert(team); context.insert(season); try context.save()
        let rows = try CalendarCSV.parse("date,equipe,adversaire,bleus,rouges\n2027-06-12T19:00:00Z,Éclairs,Lynx,\(homePlayer.id),\(awayPlayer.id)\n2027-06-12T19:00:00Z,Éclairs,Lynx,\(homePlayer.id),\(awayPlayer.id)")
        let first = try CalendarImporter.run(rows: rows, clubID: club.id, seasonID: season.id, context: context)
        XCTAssertEqual(first.added, 1); XCTAssertEqual(first.duplicates, 1)
        let second = try CalendarImporter.run(rows: rows, clubID: club.id, seasonID: season.id, context: context)
        XCTAssertEqual(second.added, 0); XCTAssertEqual(second.duplicates, 2)
        let invalid = try CalendarCSV.parse("date,equipe\n2027-08-12T19:00:00Z,Éclairs\n2027-08-13T19:00:00Z,Inconnue")
        XCTAssertThrowsError(try CalendarImporter.run(rows: invalid, clubID: club.id, seasonID: season.id, context: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MatchGame>()), 1)
    }
}

@MainActor
final class V111ValidationTests: XCTestCase {
    private func fixture() -> (Club, Team, Team, Player, Player) {
        let club = Club(name: "Flag Nord")
        let home = Team(clubID: club.id, name: "Éclairs"), away = Team(clubID: club.id, name: "Lynx")
        let alex = Player(clubID: club.id, name: "Alex", position: "QB"), sam = Player(clubID: club.id, name: "Sam", position: "DB")
        home.memberIDs = [alex.id]; away.memberIDs = [sam.id]
        return (club, home, away, alex, sam)
    }
    func testOfficialMatchRequiresBothCampsAndCorrectMembership() {
        let (club, home, away, alex, sam) = fixture()
        func issue(_ blue: Set<UUID>, _ red: Set<UUID>) -> String? {
            MatchValidation.issue(clubID: club.id, teamID: home.id, opponentTeamID: away.id, opponentName: "", blue: blue, red: red, teams: [home, away], players: [alex, sam])
        }
        XCTAssertNil(issue([alex.id], [sam.id]))
        XCTAssertNotNil(issue([], [sam.id]))
        XCTAssertNotNil(issue([alex.id], []))
        XCTAssertNotNil(issue([sam.id], [alex.id]))
        XCTAssertNotNil(issue([alex.id], [alex.id]))
    }
    func testOfficialTeamsMustBeDistinctAndBelongToOrganization() {
        let (club, home, away, alex, sam) = fixture()
        func issue(_ homeID: UUID?, _ awayID: UUID?) -> String? {
            MatchValidation.issue(clubID: club.id, teamID: homeID, opponentTeamID: awayID, opponentName: "", blue: [alex.id], red: [sam.id], teams: [home, away], players: [alex, sam])
        }
        XCTAssertNotNil(issue(home.id, home.id))
        XCTAssertNotNil(issue(UUID(), away.id))
        XCTAssertNotNil(issue(home.id, UUID()))
        XCTAssertNotNil(issue(nil, away.id))
        away.clubID = UUID()
        XCTAssertNotNil(issue(home.id, away.id))
    }
    func testManualOpponentRequiresNameAndTrackedParticipants() {
        let (club, home, _, alex, sam) = fixture()
        func issue(_ name: String, _ red: Set<UUID>) -> String? {
            MatchValidation.issue(clubID: club.id, teamID: home.id, opponentTeamID: nil, opponentName: name, blue: [alex.id], red: red, teams: [home], players: [alex, sam])
        }
        XCTAssertNil(issue("Invités", [sam.id]))
        XCTAssertNotNil(issue(" \n ", [sam.id]))
        XCTAssertNotNil(issue("Invités", []))
        XCTAssertNotNil(issue("Invités", [UUID()]))
        sam.clubID = UUID()
        XCTAssertNotNil(issue("Invités", [sam.id]))
    }
    func testBalancingRemainsRecreationalAndDoesNotMutateOfficialRecords() {
        let (club, home, away, alex, sam) = fixture()
        let game = MatchGame(clubID: club.id, seasonID: UUID(), date: .now, venue: "Parc", totalCost: 40)
        game.blueIDs = [alex.id]; game.redIDs = [sam.id]; game.paidIDs = [alex.id]; game.blueScore = 18
        XCTAssertTrue(MatchValidation.canAutoBalance(game))
        game.teamID = home.id; game.opponentTeamID = away.id
        XCTAssertFalse(MatchValidation.canAutoBalance(game))
        XCTAssertNil(MatchValidation.issue(clubID: club.id, teamID: game.teamID, opponentTeamID: game.opponentTeamID, opponentName: "", blue: game.blueIDs, red: game.redIDs, teams: [home, away], players: [alex, sam]))
        XCTAssertEqual(game.blueIDs, [alex.id]); XCTAssertEqual(game.redIDs, [sam.id])
        XCTAssertEqual(game.blueScore, 18); XCTAssertEqual(game.collected, 20)
        XCTAssertEqual(game.paidIDs, [alex.id])
        // Leaving an organization team later must not invalidate the stored match sides.
        home.memberIDs = []; away.memberIDs = []
        XCTAssertNil(MatchValidation.issue(clubID: club.id, teamID: game.teamID, opponentTeamID: game.opponentTeamID, opponentName: "", blue: game.blueIDs, red: game.redIDs, teams: [home, away], players: [alex, sam], checkCurrentMembership: false))
        XCTAssertNil(MatchValidation.issue(clubID: club.id, teamID: nil, opponentTeamID: nil, opponentName: "", blue: [], red: [], teams: [], players: [], requireRecreationalParticipants: false))
        XCTAssertNotNil(MatchValidation.issue(clubID: club.id, teamID: nil, opponentTeamID: nil, opponentName: "", blue: [alex.id], red: [], teams: [], players: [alex]))
    }
    func testOfficialCSVWithoutParticipantsFailsBeforeAnyInsertion() throws {
        let (club, home, _, alex, _) = fixture()
        let container = try ModelContainer(for: Club.self, Season.self, Player.self, MatchGame.self, StatEntry.self, Team.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let season = Season(clubID: club.id, name: "2027")
        context.insert(club); context.insert(home); context.insert(alex); context.insert(season); try context.save()
        let rows = try CalendarCSV.parse("date,equipe,adversaire\n2027-06-12T19:00:00Z,,Amis\n2027-06-13T19:00:00Z,Éclairs,Lynx")
        XCTAssertThrowsError(try CalendarImporter.run(rows: rows, clubID: club.id, seasonID: season.id, context: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MatchGame>()), 0)
    }
    func testCSVRejectsMalformedParticipantIDs() {
        XCTAssertThrowsError(try CalendarCSV.parse("date,bleus\n2027-06-12T19:00:00Z,pas-un-uuid"))
    }
    func testEmptyLeadersRequireCompletedGamesAndPositionStats() {
        var totals = PlayerTotals(); totals.passTD = 3
        XCTAssertFalse(PerformanceEligibility.hasPerformance(totals, position: "QB"))
        totals.appearances = 1
        XCTAssertTrue(PerformanceEligibility.hasPerformance(totals, position: "QB"))
        XCTAssertFalse(PerformanceEligibility.hasPerformance(totals, position: "DB"))
        totals.tackles = 2
        XCTAssertTrue(PerformanceEligibility.hasPerformance(totals, position: "DB"))
        XCTAssertTrue(PerformanceEligibility.hasPerformance(totals, position: "Rusher"))
    }
    func testPersonalRecordsUseFinishedGamesAndCurrentEntries() {
        let (club, _, _, alex, _) = fixture()
        let finished = MatchGame(clubID: club.id, seasonID: UUID(), date: .now, venue: "")
        finished.blueIDs = [alex.id]; finished.isFinished = true
        let future = MatchGame(clubID: club.id, seasonID: finished.seasonID, date: .now, venue: "")
        future.blueIDs = [alex.id]
        let first = FootballEvents.make(game: finished, kind: .passingYards, playerID: alex.id, value: 100)[0]
        let second = FootballEvents.make(game: finished, kind: .passingYards, playerID: alex.id, value: 80)[0]
        let unplayed = FootballEvents.make(game: future, kind: .passingYards, playerID: alex.id, value: 900)[0]
        var records = PersonalRecords.best(playerID: alex.id, games: [finished, future], entries: [first, second, unplayed])
        XCTAssertEqual(records.first { $0.kind == .passingYards }?.value, 180)
        first.value = 50
        records = PersonalRecords.best(playerID: alex.id, games: [finished, future], entries: [first, unplayed])
        XCTAssertEqual(records.first { $0.kind == .passingYards }?.value, 50)
        XCTAssertTrue(PersonalRecords.best(playerID: alex.id, games: [finished], entries: []).isEmpty)
    }
}
