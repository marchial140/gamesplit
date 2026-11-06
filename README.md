# GameSplit V1 — iPhone, flag / touch football

Application française SwiftUI + SwiftData, iOS 17+, entièrement locale. Pas de compte, serveur, banque, API tierce ou synchronisation cloud. Le champ `Club.sport` et les types de statistiques préparent une extension future ; seul le football est actif.

## Exécution sur Mac

1. Installer Xcode 15+ et un simulateur iPhone iOS 17+.
2. Ouvrir `GameSplit.xcodeproj`, choisir le schéma GameSplit et un simulateur, puis Product > Run.
3. Exécuter `./scripts/test-ios.sh` (build puis XCTest). Pour imposer un simulateur : `GAMESPLIT_SIMULATOR_ID=<UDID> ./scripts/test-ios.sh`.
4. Sur iPhone physique, sélectionner votre équipe Apple et un identifiant de bundle personnel dans Signing & Capabilities.

Utiliser le checkout existant ; aucun worktree supplémentaire n’est nécessaire. Aucune dépendance applicative à installer.

## Fonctionnalités

- Groupe et première saison, effectif modifiable : nom, numéro, position et OVR 1–99.
- Création de matchs, coût validé, sélection des présents, équilibrage des effectifs et OVR avec séparation des QB et amélioration par échanges. Ajustement manuel des équipes avant la première statistique.
- Résultat officiel modifiable et statut terminé ; égalités acceptées.
- Passe TD et réception liées : une seule attribution de points d’équipe. TD au sol, réception simple, interception et conversion. Points TD/conversion configurables par match.
- À l’ajout d’une stat, choisir si ses points doivent être ajoutés au résultat. Pour les matchs terminés, cette option est désactivée par défaut afin de compléter les stats sans recompter le score.
- Correction : supprimer l’événement puis le ressaisir. Une passe et sa réception sont supprimées ensemble. **La suppression ne modifie pas le résultat officiel** : corriger ses points dans Résultat si nécessaire. Les anciennes entrées sans identifiant d’événement restent indépendantes.
- Équipes verrouillées après une statistique ou la fin du match pour préserver les historiques. Pour les corriger, supprimer les statistiques concernées et rouvrir le match ; vérifier ensuite le score.
- Fiches carrière et saison, matchs et victoires ; classements TD, passes TD, interceptions et contribution GameSplit explicitement non officielle (TD marqué ×6, passe TD ×2, INT ×2, conversion ×1).
- Nouvelles saisons sans effacer les anciennes ; partage du classement et du résultat via la feuille de partage iOS.
- Coûts, paiements reçus cochés manuellement, reste à recevoir, rappel partageable ou copiable. Aucun paiement réel n’est déclenché.
- Export JSON de toutes les données depuis Accueil > Sauvegarde. Import depuis l’accueil initial, **uniquement dans une base vide**, sans remplacement ni fusion. Format versionné, références et valeurs validées avant insertion ; sauvegarde atomique avec annulation en cas d’échec.
- Sauvegardes SwiftData explicites et erreurs visibles. Pas de suppression de base ni migration destructive programmée.

## Vérifications effectuées dans cet environnement

Machine Linux sans `swift`, `xcodebuild`, SDK iOS ni simulateur : **aucune compilation iOS, aucun XCTest ni lancement de l’application n’a pu être effectué**. La compilabilité, le rendu, la migration SwiftData et la persistance sur appareil restent donc à confirmer sur Mac.

Contrôles structurels exécutés avec succès : analyse de syntaxe de 9 fichiers Swift, lecture du projet Xcode, références et inclusion des sources, version de langage Swift et XML du schéma. Ces contrôles ne vérifient pas les types ni les API Apple. Le réglage `SWIFT_VERSION` a été corrigé de `5.9` à `5.0`, valeur du mode de langage Swift 5, compatible avec le compilateur Swift 5.9+.

Pour reproduire ces contrôles facultatifs : installer `tree-sitter`, `tree-sitter-swift` et `openstep-parser` dans un environnement Python séparé, puis lancer `python scripts/review_project.py`.

8 tests XCTest sont fournis : encodage des identifiants, équilibrage impair, coût sans présents, 14 joueurs/2 QB et paiements 280/200/80, passe TD et correction groupée, interception/égalité/nouvelle saison, cas limites et règles, persistance sur disque après réouverture et export/import. **Ils sont écrits, pas exécutés ici.**

## Limites V1

Un seul groupe par installation. Coûts stockés en Double et parts non arrondies avant affichage : une division non exacte peut afficher un écart de quelques cents entre parts affichées et total. Pas de fusion de sauvegardes ni de synchronisation entre appareils. Les sauvegardes JSON contiennent des données personnelles en clair : les conserver dans un emplacement de confiance. Import limité à 20 Mo.

Tester sur iPhone les grandes tailles de texte, VoiceOver, petits écrans, claviers et feuille de partage. La compatibilité de migration depuis une éventuelle installation du prototype n’a pas été exécutée ; exporter les données avant toute mise à jour. Aucune promesse de validation iOS n’est faite sur la base de la seule revue statique.

## Vers une bêta TestFlight — sans publication automatique

1. Sur Mac, réussir le build et les 8 XCTest avec le script fourni ; corriger tout diagnostic Apple restant.
2. Tester les parcours complets sur simulateur puis sur iPhone : 14 joueurs, équipes, score, stats, paiements, deux saisons, fermeture/réouverture et restauration dans une installation de test vide.
3. Vérifier l’accessibilité et fournir icône d’app, captures, identité de signature, identifiant final, politique de confidentialité et déclarations App Store Connect adaptées.
4. Après autorisation explicite du propriétaire, préparer une archive signée et organiser la bêta TestFlight. Le dépôt GitHub contient le code source. Aucun envoi TestFlight ou dépôt App Store n’a été effectué.
