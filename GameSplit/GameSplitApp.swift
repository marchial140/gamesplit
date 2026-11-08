import SwiftUI
import SwiftData

@main
struct GameSplitApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
            .modelContainer(for: [Club.self, Season.self, Player.self, MatchGame.self, StatEntry.self, Team.self])
    }
}

@MainActor
struct RootView: View {
    @Query(sort: \Club.createdAt) private var clubs: [Club]
    @State private var showNewClub = false

    var body: some View {
        Group {
            if let club = clubs.first { ClubTabs(club: club) }
            else {
                NavigationStack {
                    ScrollView {
                        VStack(spacing: 22) {
                            VStack(alignment: .leading, spacing: 14) {
                                Image(systemName: "bolt.fill").font(.largeTitle).foregroundStyle(SportTheme.orange)
                                Text("GAMESPLIT").font(.system(.largeTitle, design: .rounded).weight(.heavy)).foregroundStyle(.white)
                                Text("Votre terrain. Votre histoire.").font(.title2.bold()).foregroundStyle(.white)
                                Text("Le collectif, les performances et les souvenirs du flag football.").font(.subheadline).foregroundStyle(.white.opacity(0.85))
                            }.padding(26).frame(maxWidth: .infinity, alignment: .leading)
                                .background(LinearGradient(colors: [SportTheme.navy, SportTheme.electric], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 26))
                            SportEmptyState(symbol: "flag.checkered", title: "Prêts pour le premier match ?", message: "Créez votre organisation pour réunir vos joueurs et suivre vos performances. Tout reste sur cet appareil.", actionTitle: "Créer mon groupe", action: { showNewClub = true })
                            NavigationLink { BackupView() } label: { Label("Restaurer une sauvegarde", systemImage: "externaldrive") }.buttonStyle(.bordered)
                        }.padding(16).padding(.bottom, 24)
                    }.background(SportTheme.background)
                }
            }
        }
        .sheet(isPresented: $showNewClub) { NewClubView() }
        .tint(SportTheme.accent)
        .environment(\.locale, Locale(identifier: "fr_CA"))


    }
}

@MainActor
struct NewClubView: View {
    @Environment(\.modelContext) private var context
    @State private var saveError: String?
    private func saveChanges() -> Bool {
        do { try context.save(); return true }
        catch { context.rollback(); saveError = "Sauvegarde impossible : \(error.localizedDescription)"; return false }
    }
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var seasonName = "2026-2027"
    var body: some View {
        NavigationStack {
            Form {
                Section("Groupe") {
                    TextField("Ex. Friday Night Football", text: $name)
                    LabeledContent("Sport", value: "Flag / touch football")
                }
                Section("Première saison") { TextField("Nom de saison", text: $seasonName) }
            }
            .navigationTitle("Nouveau groupe")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") {
                        let club = Club(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
                        context.insert(club)
                        context.insert(Season(clubID: club.id, name: seasonName.trimmingCharacters(in: .whitespacesAndNewlines)))
                        if saveChanges() { dismiss() }
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || seasonName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .alert("Erreur de sauvegarde", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "") }

    }
}

@MainActor
struct ClubTabs: View {
    let club: Club
    var body: some View {
        TabView {
            DashboardView(club: club).tabItem { Label("Accueil", systemImage: "bolt.fill") }
            MatchesView(club: club).tabItem { Label("Matchs", systemImage: "sportscourt") }
            StandingsView(club: club).tabItem { Label("Classements", systemImage: "chart.bar.xaxis") }
            TeamsView(club: club).tabItem { Label("Équipes", systemImage: "person.3.fill") }
            LocalProfileView(club: club).tabItem { Label("Profil", systemImage: "person.crop.circle") }
        }
        .toolbarBackground(.visible, for: .tabBar)
    }
}

@MainActor
struct LabelValue: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title3.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

@MainActor
struct EmptyHint: View {
    let title: String
    let subtitle: String
    var body: some View {
        ContentUnavailableView(title, systemImage: "flag", description: Text(subtitle))
    }
}
