# Tâche Codex — GameSplit V1 (football)

Tu es le développeur iOS principal. Termine un MVP iOS natif **compilable**, propre et robuste appelé **GameSplit**. Commence par lire `AGENTS.md` et inspecter les fichiers existants. Ne repars pas de zéro si la base est utilisable.

## Produit et contraintes
- App en **français**, pour groupes d'amis jouant au **flag/touch football**.
- **SwiftUI + SwiftData**, iOS 17+, local-first et sans serveur ni compte.
- Architecture facilement extensible à hockey, soccer, basketball et autres sports dans les versions futures, mais seulement football actif dans la V1.
- Style sportif moderne, contrastes accessibles, interface simple pour gérants non techniques.

## Périmètre fonctionnel V1
1. Créer un groupe, un nom de saison, des joueurs (nom, numéro, position QB/WR/RB/DB/FLEX, OVR 1-99), modifier un joueur.
2. Créer des matchs (date, lieu, coût, liste des participants) et générer deux équipes d'effectifs comparables et d'OVR proches, en séparant les QB si possible; permettre de modifier les équipes manuellement.
3. Enregistrer un score final, marquer un match terminé.
4. Ajouter des événements de football : passe TD (QB + receveur), TD au sol, interception défensive, conversion, TD réception simple. Saisie après le match possible. Éviter les doubles comptes. Pouvoir corriger/supprimer une saisie proprement; cohérence de score garantie ou explicitement séparée.
5. Calculer fiches joueurs (stats carrière et par saison, matchs, victoires), classements par TD, passes TD, INT, contribution. **Nommer clairement tout indicateur non officiel**.
6. Répartir le coût du terrain entre présents, cocher les paiements réellement reçus, copier un rappel partageable. Aucune connexion aux banques.
7. Plusieurs saisons sans effacer les anciennes; leaderboard saison et carrière; partage d'un résumé via Share Sheet.
8. Ajouter validations, états vides, persistance fiable, sauvegarde locale export/import si possible. Ne pas faire de promesse cloud.
9. Conserver la possibilité d'ajouter un sport plus tard via modèle `sport` et types de stats.

## Tests d'acceptation indispensables
- Créer 14 joueurs avec overalls différents et 2 QB; répartition 7/7, QB séparés si possible, joueurs uniques.
- Créer une partie coûtant 280 $ avec 14 joueurs; montant par personne de 20 $; marquer 10 payés => 200 $ reçus et 80 $ manquants.
- Enregistrer 1 TD lancé par Alex et attrapé par Max; Alex +1 passe TD, Max +1 réception TD, équipe +6 une seule fois.
- Enregistrer une interception par Sam; Sam +1 interception.
- Terminer deux matchs, créer une nouvelle saison : les statistiques de carrière subsistent, le classement de saison redémarre.
- Modifier overall, joueur et scores; fermeture/réouverture de l'app sans pertes de données.
- Tester le cas 0 joueur, 1 joueur, montant nul, score égal, scores manuels et corrections de stats.
- Build iOS Simulator via Xcode sur un Mac. Exécuter les tests. Donner un résumé clair des erreurs corrigées et des éléments restant à faire.

## Hors périmètre V1
Connexion individuelle des joueurs, invitations par liens, synchronisation entre appareils, notifications push, transfert Interac, cartes visuelles partageables complexes, achats intégrés, tableau détaillé des yards/plaqués, autres sports, Hall of Fame élaboré.

## Livrables attendus
- Projet Xcode `GameSplit.xcodeproj` compilable.
- Tests qui passent sur simulateur ou explication exacte de ce qui n'a pas pu être testé.
- README actualisé avec procédure d'exécution et limites V1.
- Liste des étapes suivantes vers une beta TestFlight, sans publier automatiquement.
