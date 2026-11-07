# Validation V1.1 sur Mac

Avant d’installer sur une base V1 existante : exporter sa sauvegarde JSON. Garder le bundle identifier et le conteneur d’application pour vérifier la migration. **Ne pas désinstaller l’app, effacer le simulateur ou supprimer le store pour contourner une erreur de migration.**

1. Ouvrir le projet V1.1 dans Xcode 15+ avec un simulateur iPhone iOS 17+. Exécuter `./scripts/test-ios.sh`, ou Product > Test (⌘U). Aucun compte développeur requis pour le simulateur.
2. Confirmer que les 14 méthodes XCTest se sont exécutées. Les tests couvrent les critères V1 plus la règle des 4 points individuels/6 réels, les valeurs de statistiques, les QB secondaires, les affiliations multiples, les photos dans la sauvegarde, le format JSON V1 et les imports CSV répétés/invalides.
3. Installer la V1, ajouter joueurs, saison, match, événements et paiements ; exporter un JSON. Sans désinstaller, lancer V1.1 avec la même signature et le même bundle identifier. Vérifier les UUID, valeurs, reçus et historique. Les ajouts de schéma sont optionnels ou munis de valeurs par défaut ; leur migration automatique reste à vérifier sur ce vrai store.
4. Équipes → Tous les joueurs : ajouter Rusher + DB, retirer le numéro, choisir une photo. Créer deux équipes avec logos, inclure le même joueur dans les deux, désigner un capitaine. Vérifier la fiche Profil, l’historique et les équipes.
5. Depuis une équipe, planifier un match. Vérifier son nom prérempli, adversaire existant ou manuel, présents et côtés. Corriger date/lieu ; aucun changement de stats ou de paiements ne doit apparaître. Une personne commune aux deux effectifs reste unique et côté Bleus par défaut.
6. Saisir 4 passes TD avec receveur : 16 points de contribution pour le QB, 4 TD et 4 réceptions pour le receveur, 24 points réels si l’ajout au score est activé. Supprimer l’événement lié puis ressaisir une correction sans ajouter au score : les agrégats doivent se recalculer sans doublon. Vérifier verges, plaqués, sacks, interceptions lancées et défensives.
7. Finir le match. Vérifier accueil, leaders de la semaine civile, classements par position/saison et bilan des équipes. Modifier le résultat : la carte d’activité dérivée doit se mettre à jour sans nouvelle copie.
8. Importer `examples/calendrier.csv` dans la saison choisie. Confirmer deux lignes ; réimporter et obtenir zéro nouveau match. Corriger les présents dans chaque match importé. Essayer un fichier invalide : aucune importation partielle.
9. Exporter V1.1, restaurer dans une installation de test vide, vérifier photos, équipes, positions et quantités de stats. Importer le JSON V1 dans une autre installation vide. L’import dans une installation non vide doit être refusé.
10. Vérifier Finances : coût 280 $, 14 présents, 10 paiements reçus = 200 $ et 80 $ manquants. Le fichier et les calculs Finances sont conservés.
11. Tester iPhone physique, grandes tailles de texte, VoiceOver, claviers et photos. Comparer performances du simulateur et de l’appareil ; le présent environnement ne permet pas un profilage iOS.

## Vérifications disponibles ici

Linux sans Xcode/Swift/SDK Apple : analyse de syntaxe Swift, projet OpenStep et schéma XML, inclusion des fichiers, syntaxe Bash et comparaison du fichier Finances. Aucun XCTest, build iOS, migration réelle ni rendu d’écran n’est revendiqué comme exécuté. Le test de compatibilité JSON n’est pas un test de migration SwiftData.
