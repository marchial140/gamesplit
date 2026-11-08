# GameSplit V1.1.1 — changements et validation

## Changements visuels

Les cinq onglets partagent maintenant les couleurs adaptatives de `SportTheme`, des panneaux arrondis et des titres hiérarchisés. Bleu marine et bleu électrique pour les cartes de marque, orange pour les performances, surfaces système claires/sombres et texte sémantique. Les anciens accents verts sont retirés. L’OVR jaune est conservé.

- Accueil : marque GameSplit, organisation, prochain match, trois résultats récents avec performances et records dérivés des saisies, puis carrousel compact de leaders. Les positions sans statistiques pertinentes sont masquées. Aucun résultat terminé : un seul état vide, avec action Planifier.
- Matchs : cartes avec logos ou initiales, deux noms, score final ou VS, date/heure/lieu et statut distinct. Bouton Planifier explicite et CSV conservé.
- Classements : filtres compacts, podium avec photos/OVR/équipes, statistiques de position et détail accessible. Seuls les joueurs avec un match terminé dans la période sont classés.
- Équipes : cartes de bilan V/D/N, effectifs, logos et prochain match ; Gestion repliable pour joueurs, finances et sauvegarde. Les fiches d’équipe restent accessibles.
- Profil : photo agrandie, OVR jaune plus visible, position principale, affiliations avec logos, statistiques selon le poste, records positifs par match terminé. Statistiques complètes dans une section dépliable. Sélecteur Carrière sur surface opaque avec couleurs sémantiques.

Les cartes de résultats/profils passent en disposition verticale si nécessaire avec `ViewThatFits`. Les grilles sont adaptatives ; pas de hauteur fixe sur les textes. Le contenu utilise les safe areas natives ; le sélecteur de fiche locale est ajouté via `safeAreaInset` au-dessus de la barre d’onglets. Les formulaires de saisie restent natifs.

## Corrections fonctionnelles

- Équilibrage réservé aux matchs récréatifs ; commande absente des matchs officiels et garde dans l’action.
- Validation commune des équipes existantes, de leur organisation, de l’adversaire, des deux camps non vides, des appartenances et de l’unicité des participants.
- Adversaire manuel : nom obligatoire, joueurs adverses suivis dans l’effectif local. Un joueur ne peut pas être dans les deux camps.
- Même validation aux modifications d’effectifs et à l’import CSV. Aucun match officiel incomplet n’est créé par un autre chemin.
- Les anciens matchs, y compris les imports incomplets V1.1, ne sont pas effacés ou réaffectés. Les modifications de participants restent bloquées après saisie de stats ou match terminé ; les joueurs payés ne peuvent pas être retirés.
- Le changement d’effectif actuel d’une équipe ne réaffecte pas les côtés historiques d’un match. Sa finalisation contrôle les camps et identités, sans exiger que les joueurs figurent encore dans l’effectif actuel.
- Classements : joueurs sans match terminé exclus ; catégories hebdomadaires sans performance masquées.
- Records : sommes des entrées actuelles par match terminé ; corrections/suppressions se reflètent dans les valeurs. Aucune publication persistée dupliquée.

## CSV

Les fichiers récréatifs V1.1 (`equipe` vide) restent acceptés sans participants : on complète les présents dans le match. Pour un match officiel (`equipe` renseignée), fournir aussi `bleus` et `rouges` contenant les UUID des participants (lisibles dans la sauvegarde JSON), séparés par des virgules à l’intérieur d’une cellule entre guillemets. L’équipe doit exister ; l’adversaire existant est reconnu par son nom, sinon son nom reste manuel.

Exemple d’en-tête : `date,lieu,adversaire,equipe,cout,bleus,rouges`. Les identifiants doivent être ceux de cette organisation et respecter les effectifs des équipes choisies. Le lot est préparé et validé avant insertion : une ligne nouvelle invalide bloque tout le lot. Un doublon déjà enregistré est ignoré. Aucun joueur n’est créé ni marqué présent silencieusement par l’import.

## Contrôles effectués ici

- Analyse de syntaxe des 12 fichiers Swift avec tree-sitter, lecture OpenStep du projet Xcode, inclusion des sources et XML du schéma : réussis.
- Syntaxe Bash et `git diff --check` : réussis.
- Comparaison avec V1.1 : déclarations des modèles persistés, `Backup.swift`, `FinancesView.swift` et formules financières inchangées.
- Calcul de contraste des couleurs de texte principales : bleu/blanc 5,76:1, bleu clair/surface sombre 7,22:1, orange texte/blanc 6,07:1, orange clair/surface sombre 9,43:1, blanc/bleu 5,76:1, jaune OVR/bleu 5,36:1. Ces valeurs statiques ne remplacent pas un contrôle visuel, notamment pour les matériaux/transparences et les couleurs système.
- `scripts/test-ios.sh` tenté : sortie 69, car macOS/Xcode/SDK Apple sont absents. Aucun build iOS ou XCTest exécuté ici.
- **22 méthodes XCTest** fournies : les 14 existantes conservées/adaptées, plus huit tests de validation des camps/équipes/imports, d’éligibilité des leaders et de records. Le test CSV idempotent existant fournit maintenant les participants requis pour son match officiel.

## À vérifier dans Xcode

1. Exporter une sauvegarde V1.1 avant mise à jour ; garder le même bundle identifier et ne pas désinstaller l’app. Aucun changement de schéma ou de format de sauvegarde dans cette itération.
2. Ouvrir `GameSplit.xcodeproj` de cette branche ; schéma GameSplit, simulateur iOS 17+, puis ⌘R. Exécuter ⌘U ou `./scripts/test-ios.sh` et vérifier les 22 tests.
3. Installation vide : vérifier accueil initial, création du groupe, onglets sans équipes/joueurs/matchs et actions. Ne pas créer de données fictives dans une installation réelle.
4. Sans résultat terminé : un seul état vide sportif sur l’accueil ; aucune catégorie QB/WR/DB/Rusher vide. Terminer un match avec seulement des stats QB : seule la catégorie QB pertinente apparaît cette semaine.
5. Créer un match récréatif à 14 joueurs et vérifier le maintien du rééquilibrage. Pour un officiel, vérifier son absence, deux camps obligatoires, bonne équipe/adversaire, impossibilité d’un joueur partagé entre les camps et refus des équipes/participants invalides dans les tests.
6. Vérifier adversaire manuel avec participants choisis explicitement. Les noms et les côtés doivent rester corrects après réouverture. Modifier un ancien match sans modifier son score ou ses statistiques automatiquement.
7. CSV : récréatif sans présents accepté ; officiel sans présents refusé sans insertion partielle ; officiel complet accepté ; réimport = zéro nouveau match.
8. Podium : pas de joueur sans match terminé. Filtres saison, carrière, poste et métrique restent utilisables. Les statistiques détaillées et le partage restent accessibles.
9. Profil : photo, OVR, poste principal/secondaire, logos, records et statistiques complètes. Modifier/supprimer une entrée et vérifier que les records se recalculent. « Carrière » doit être lisible en mode clair et sombre.
10. Vérifier les cinq onglets sur petit iPhone (SE 3 ou équivalent disponible) et grand iPhone, mode clair/sombre, grandes tailles de texte/accessibilité et VoiceOver. Faire défiler jusqu’au dernier bouton ; vérifier clavier, formulaires, barre d’onglets et sélecteur de fiche sans chevauchement.
11. Finances : même écran/calculs ; 280 $ / 14 présents, 10 payés = 200 $ reçus, 80 $ manquants. Vérifier export/import et historique inchangés.

## Limites et reports

- Rendu, tests, migration de store, performance et safe areas n’ont pas pu être observés dans un simulateur ou sur iPhone ici. Ce document est une procédure de validation, pas une déclaration de réussite iOS.
- Mode démonstration reporté, conformément à sa priorité secondaire : aucune donnée fictive ajoutée aux données réelles, aucune action de suppression de démo incomplète.
- Le schéma V1.1 ne contient pas de logo d’organisation. L’en-tête utilise donc ses initiales ; les vrais logos des équipes et photos des joueurs sont utilisés ailleurs. Pas de champ persistant ajouté pour cette option.
- Pas de backend, Supabase, authentification, synchronisation ou publication App Store. La prochaine étape V1.2 reste séparée.
