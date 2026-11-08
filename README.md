# GameSplit V1.1.1 — votre terrain, votre histoire

Application iPhone en français, SwiftUI + SwiftData, iOS 17+. Cette version modernise l’expérience de la V1.1 et corrige la validation des matchs officiels. **Aucun compte en ligne, Supabase ou synchronisation n’est ajouté.**

[Toutes les demandes](docs/V1_1_1_REQUIREMENTS.md) · [Changements, contrôles et procédure Xcode](docs/V1_1_1_VALIDATION.md)

## Voir la nouvelle version

1. Exporter une sauvegarde depuis votre V1.1 avant la mise à jour.
2. Décompresser le ZIP de la branche `gamesplit-v1.1.1` et ouvrir son fichier `GameSplit.xcodeproj` dans Xcode 15+.
3. Choisir le schéma **GameSplit** et un simulateur iPhone iOS 17+, puis **⌘R**.
4. **Ne pas désinstaller l’app** et conserver le même bundle identifier pour garder les données locales.
5. Pour les tests : **⌘U**, ou `./scripts/test-ios.sh`. Le script choisit un simulateur disponible ; `GAMESPLIT_SIMULATOR_ID=<UDID>` permet d’en préciser un.

Sur iPhone réel, choisir son équipe Apple dans Signing & Capabilities et activer le mode développeur si demandé. Aucune publication App Store n’est nécessaire. Utiliser le checkout existant ; aucun worktree ni dépendance applicative supplémentaire.

## Ce qui change

- **Une identité cohérente** : marine, bleu électrique, orange ; surfaces adaptatives, texte sémantique et accents verts retirés. Les cinq onglets conservent le comportement natif d’iOS.
- **Accueil** : organisation, prochain rendez-vous, trois résultats récents et performances, puis leaders hebdomadaires en carrousel. Les catégories vides sont masquées ; un seul état vide invite à planifier. Les activités et records sont calculés exclusivement à partir des données saisies.
- **Matchs** : noms/logos des deux équipes, score final, date/heure/lieu et statut dans des cartes. Action Planifier visible même sans données. Import CSV conservé.
- **Classements** : filtres compacts, podium, photos, OVR, équipes et statistiques de position. Aucun joueur sans match terminé ne figure au classement.
- **Équipes** : cartes avec logo, effectif, bilan V/D/N et prochain match. Les fonctions administratives restent accessibles dans une section **Gestion** repliable.
- **Profil** : photo plus grande, OVR jaune renforcé, position principale, logos d’équipes et statistiques adaptées au poste. Les statistiques complètes restent accessibles en dépliant la section. Records positifs par match terminé. Le sélecteur Carrière utilise une surface et des couleurs lisibles dans les deux modes.

Les cartes utilisent des grilles adaptatives et `ViewThatFits`, sans bloquer la hauteur des textes. Le sélecteur de fiche locale utilise une safe area native au-dessus de la barre d’onglets. Les formulaires de saisie restent natifs.

## Corrections des matchs

- Les matchs **récréatifs** entre amis conservent la répartition et le rééquilibrage OVR.
- Les matchs **officiels** gardent les équipes et n’offrent plus l’équilibrage automatique.
- Création et modification des présents vérifient équipes valides, organisation, adversaire, deux camps non vides, appartenances et absence de doublon entre camps.
- Pour un adversaire manuel, son nom et des participants suivis dans l’effectif sont requis. Aucun joueur adverse fictif n’est créé automatiquement.
- La validation est partagée avec l’import CSV pour ne pas contourner ces règles. Les anciens matchs incomplets ne sont ni supprimés ni réaffectés automatiquement.
- Les côtés historiques restent conservés lorsqu’un joueur quitte une équipe. La finalisation d’un match existant ne réinterprète pas son effectif selon les équipes actuelles.

## Données et fonctions conservées

**Les déclarations des modèles SwiftData et le format de sauvegarde V2 sont inchangés.** L’implémentation de sauvegarde et le fichier Finances sont conservés. Les données, identifiants, photos, positions, équipes, saisons, résultats et statistiques existants ne sont pas réinitialisés.

La section **Équipes → Gestion → Coûts et paiements** garde son interface et ses calculs. Paiements manuels uniquement ; aucun service bancaire. Exemple de contrôle : 280 $ / 14 présents, dix payés = 200 $ reçus, 80 $ manquants. Parts conservées en Double comme auparavant : arrondis d’affichage possibles de quelques cents.

Les positions multiples, Rusher, OVR manuel, affiliations multiples, statistiques détaillées, partage textuel et sauvegardes restent disponibles. Une passe TD vaut **4 points de contribution individuelle**, indépendamment des **6 points d’équipe par défaut**. Les règles sont centralisées dans `ContributionRules`.

Une passe et sa réception forment un événement lié. Saisir quatre passes TD produit quatre passes TD et quatre réceptions TD, pas deux touchdowns d’équipe par passe. Les réceptions TD sont déjà incluses dans les réceptions ; saisir les autres via « Réception (hors TD) ». Les verges se renseignent séparément.

Correction d’une stat : supprimer puis ressaisir. **La suppression ne change pas le résultat officiel** ; corriger ce score si nécessaire et désactiver l’ajout au score lors d’une ressaisie. Les équipes sont verrouillées après une stat ou la fin du match ; un participant payé ne peut pas être retiré via l’éditeur.

## CSV et sauvegardes

[Exemple de calendrier récréatif](examples/calendrier.csv) : `date,lieu,adversaire,equipe,cout`. Si `equipe` est vide, le calendrier entre amis peut être importé sans présents, à compléter ensuite.

Pour un **match officiel**, `equipe` doit correspondre à une équipe existante et il faut fournir les colonnes `bleus` et `rouges`, avec les UUID des participants de chaque camp (disponibles dans la sauvegarde JSON), séparés par des virgules à l’intérieur de cellules entre guillemets. Les effectifs de l’organisation et des équipes sont vérifiés. Un adversaire existant est reconnu par son nom ; sinon il reste un nom manuel. Un lot contenant une nouvelle ligne invalide n’insère rien. Les doublons saison/date à la minute/lieu/équipe/adversaire sont ignorés.

Export JSON V2 et import V1/V2 inchangés. Restauration uniquement dans une installation vide afin de ne pas écraser les données. Limite de 20 Mo ; le fichier contient des données personnelles en clair.

## Vérification réellement effectuée

Dans cet environnement **Linux sans Swift/Xcode/SDK iOS** :

- Syntaxe des 12 fichiers Swift, projet Xcode OpenStep, inclusion des sources et schéma XML : vérifiés.
- Syntaxe Bash, `git diff --check` et préservation du schéma, des sauvegardes et des finances : vérifiés.
- Calcul statique des contrastes des couleurs de texte principales : supérieur à 4,5:1 sur les fonds de référence. Cela ne prouve pas le rendu de tous les matériaux ou états système.
- Script iOS tenté : arrêt explicite avec code 69, prérequis Xcode absent.

**22 méthodes XCTest fournies, non exécutées ici** : les 14 tests précédents conservés/adaptés, plus huit tests couvrant matchs officiels, équipes étrangères/identiques, camps vides, adversaire manuel, intégrité historique, CSV, leaders vides et records.

Aucun build iOS, test fonctionnel, rendu de simulateur, essai sur iPhone ou profilage n’est revendiqué. La compatibilité de sauvegarde JSON ne prouve pas une migration de store. Suivre [la procédure complète sur Mac](docs/V1_1_1_VALIDATION.md), sur petit et grand iPhone, en clair/sombre et grandes tailles de texte.

Contrôles structurels reproductibles : dans un environnement Python séparé, installer `tree-sitter`, `tree-sitter-swift` et `openstep-parser`, puis `python scripts/review_project.py`.

## Reports explicites

- **Mode démonstration** : secondaire et reporté ; aucune fausse donnée injectée dans la base réelle.
- **Logo d’organisation** : le schéma existant n’en stocke pas. Les initiales sont le repli de l’en-tête ; les vrais logos d’équipes sont utilisés ailleurs. Pas de nouveau champ persistant pour cette option.
- **V1.2** : comptes vérifiés, Supabase, invitations, accès sécurisés et synchronisation. La fiche choisie sur cet appareil n’est toujours pas une connexion et les capitaines locaux ne sont pas des autorisations de sécurité. [Architecture proposée](docs/SOCIAL_BACKEND.md).
- Import .ics, cartes de partage en image, OVR automatique et fonctionnalités sociales avancées restent reportés.

Cette version est livrée dans une **branche GitHub dédiée sans fusion dans main**. Aucun environnement, backend, TestFlight ou App Store n’est publié par cette tâche.
