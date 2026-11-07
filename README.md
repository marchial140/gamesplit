# GameSplit V1.1 — profils, équipes et performances

Application native iPhone en français, SwiftUI + SwiftData, iOS 17+. Cette itération réalise la **priorité 1 locale** du [cahier V1.1](docs/V1_1_REQUIREMENTS.md), et prépare l’étape sociale sans simuler un service en ligne.

## Ce qui est implémenté

- Navigation : **Accueil, Matchs, Classements, Équipes, Profil**. Cartes sportives bleu nuit/bleu électrique, photos, logos et badges de position.
- Joueurs : photo locale redimensionnée, numéro facultatif, position principale et positions secondaires dont **Rusher**, OVR manuel 1–99, appartenance à plusieurs équipes. Les modifications conservent le même UUID et l’historique.
- Fiches : statistiques saison/carrière, matchs, victoires, équipes, historique, meilleurs nombres de passes TD/TD en un match et partage textuel des performances. Profil permet de choisir sa fiche sur cet appareil ; **ce n’est pas un compte**.
- Équipes : nom, logo, effectif modifiable et capitaines désignés ; calendrier, bilan V/D/N, points marqués/encaissés, statistiques collectives à partir des côtés historiques.
- Matchs : calendrier/résultats, équipe préremplie depuis sa fiche, adversaire existant ou texte libre, sélection des présents, modification de date/lieu/adversaire. Mode match entre amis et équilibrage OVR conservés ; les positions QB secondaires participent à la séparation des QB.
- Saisie : passes TD liées à leur réception, TD au sol, réception simple, interceptions défensives et lancées, conversions, verges par la passe/réception, réceptions hors TD, plaqués et sacs du quart. Les quantités se saisissent en une fois (1–10 000).
- **Une passe TD = 4 points de contribution individuelle**, centralisés dans `ContributionRules`. Un TD réel vaut toujours les points configurés du match (6 par défaut). Les classements n’ajoutent jamais leurs points au score réel.
- Classements filtrés par position et saison/carrière : TD, passes TD, interceptions, verges, réceptions, plaqués, sacks, contribution non officielle. Moins d’interceptions lancées se classe en premier pour cet indicateur.
- Accueil : résultat des 30 derniers matchs terminés, leurs deux meilleurs contributeurs, accès aux profils et leaders par position de la semaine civile en cours. Les cartes sont dérivées des matchs : une correction met à jour la même carte sans republier un doublon. **Le fil est local, sans abonnements ou comptes partagés.**
- Import CSV avec aperçu, confirmation, validation de tout le lot avant insertion et dédoublonnage saison/date à la minute/lieu/équipe/adversaire. Exemple : [examples/calendrier.csv](examples/calendrier.csv). Les présents se complètent dans le match après import.
- Finances conservées, accessibles par **Équipes → Coûts et paiements — gestion**. Paiements manuels, rappels copiable/partageable, aucune banque.
- Export JSON V2 couvrant photos, équipes et nouvelles statistiques, et import du format V1 conservé. Restauration uniquement dans une installation vide pour ne pas écraser les données. Limite 20 Mo ; le JSON contient des données personnelles en clair.

## Règles qui évitent les doubles comptes

Une passe et sa réception sont deux lignes d’un même événement. Saisir 4 passes TD avec un receveur produit 4 passes TD et 4 réceptions TD, soit **24 points d’équipe** avec les règles par défaut, pas 48. Les réceptions TD sont incluses dans le nombre de réceptions : la stat « Réception (hors TD) » sert aux autres attrapés. Les verges se saisissent séparément.

Chaque nouvelle saisie ajoute une performance. Pour corriger, supprimer l’événement puis saisir la version correcte. La suppression d’une passe supprime aussi sa réception. **La suppression de statistiques ne change pas le score officiel** : corriger le résultat si nécessaire et désactiver « Ajouter les points au score officiel » lors d’une ressaisie. Cette option est désactivée par défaut après la fin du match. Les anciens événements V1 sans liaison restent indépendants.

Les équipes/présents sont verrouillés après une stat ou la fin du match pour préserver les résultats. Les joueurs payés ne peuvent pas être retirés via l’éditeur des présents. Pour un match lié à une équipe, les Bleus correspondent à cette équipe et les Rouges à son adversaire ; vérifier les côtés avant de saisir des stats.

## Tester sur Xcode

1. **Exporter la sauvegarde de votre V1 avant mise à jour.** Garder le même bundle identifier, sans désinstaller l’app, pour tester la migration.
2. Ouvrir `GameSplit.xcodeproj` dans Xcode 15+, sélectionner GameSplit et un simulateur iPhone iOS 17+, puis ⌘R.
3. Product → Test (⌘U), ou `./scripts/test-ios.sh`. Le script choisit un simulateur disponible ; `GAMESPLIT_SIMULATOR_ID=<UDID>` permet de le préciser.
4. Sur iPhone réel, sélectionner votre équipe Apple dans Signing & Capabilities et activer le mode développeur si demandé. Aucun déploiement App Store n’est nécessaire.
5. Suivre [la validation détaillée](docs/V1_1_VALIDATION.md), dont la mise à jour d’un store V1 existant, le retour après fermeture, les photos, les imports et les paiements.

Aucune dépendance applicative à installer. Utiliser le checkout existant, sans worktree supplémentaire.

## Vérification réellement effectuée ici

**Linux sans Swift, Xcode, SDK Apple ni simulateur : aucun build iOS, XCTest, rendu ou test de migration n’a pu s’exécuter.** Le script iOS a été tenté et signale explicitement ce prérequis manquant (code 69). Les fonctionnalités ci-dessus sont implémentées dans les sources, leur exécution iOS reste à valider sur Mac.

Contrôles structurels : syntaxe des 12 fichiers Swift, syntaxe Bash du script, projet Xcode OpenStep et schéma XML, références et inclusion des sources. Le fichier `FinancesView.swift` est identique à V1. Ces vérifications ne remplacent ni le contrôle des types Apple ni les tests fonctionnels.

**14 méthodes XCTest** sont fournies : 8 critères V1, plus 6 tests V1.1 couvrant les 4 points individuels/6 points réels, quantités et corrections, positions secondaires, affiliations/photos et sauvegarde V2, import JSON V1 et CSV valide/invalide/idempotent. Ils ne sont pas déclarés réussis ici.

Les ajouts SwiftData sont optionnels ou possèdent des valeurs par défaut, sans renommage/suppression de champs. La migration automatique doit être testée sur une vraie base V1 ; un test de compatibilité JSON ne suffit pas.

Contrôles facultatifs reproductibles : dans un environnement Python séparé, installer `tree-sitter`, `tree-sitter-swift`, `openstep-parser`, puis lancer `python scripts/review_project.py`.

## Reporté et prochaines étapes sociales

- **Comptes, invitations, synchronisation, profils distants, suivis et J’aime** : priorité 2, nécessitent backend, authentification et politiques serveur vérifiées. Les capitaines locaux ne sont pas des permissions de sécurité.
- **Import .ics** : reporté ; CSV est implémenté et testable. Le parsing de récurrences/fuseaux et le dédoublonnage des UID doivent être traités correctement.
- **Cartes de performance en image**, animations élaborées, comparaisons avancées, badges, historique/évolution OVR et Hall of Fame : ultérieurs. Le partage actuel est textuel.
- Un seul groupe/organisation par installation ; plusieurs équipes à l’intérieur. Pas de fusion de sauvegardes, ni de synchronisation cloud. Parts monétaires conservées en Double comme en V1 : les arrondis affichés peuvent différer de quelques cents du total.

L’approche retenue pour la prochaine étape est **Supabase** : identités stables, relations PostgreSQL, invitations transactionnelles, politiques RLS, stockage privé et cache SwiftData conservé. [Architecture, sécurité et configuration externe](docs/SOCIAL_BACKEND.md). Aucun compte externe ou backend n’a été créé.

Avant TestFlight : réussir la compilation et les 14 tests sur Mac, valider la migration et l’accessibilité, profiler sur appareil, fournir icône définitive, identité de signature et informations de confidentialité. Publication uniquement après autorisation.

## Fichiers principaux

- `Models.swift` : modèle additif, équipes, statistiques, équilibrage et règles centralisées.
- `SportUI.swift`, `PlayersView.swift`, `TeamsView.swift` : photos, profils, affiliations, capitaines et composants visuels.
- `MatchesView.swift`, `CalendarImport.swift` : saisie, modifications, présents et import sans doublons.
- `DashboardView.swift`, `StandingsView.swift` : activités locales et classements.
- `Backup.swift`, `GameSplitTests.swift` : compatibilité des sauvegardes et tests.
