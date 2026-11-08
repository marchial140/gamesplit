La V1.1 fonctionne comme une bonne base, mais l'application ressemble encore trop à un prototype SwiftUI.
Je veux maintenant une V1.1.1 axée sur le design, l'expérience utilisateur et les corrections de bugs.
Vision à conserver : GameSplit doit devenir le Strava du flag football, combiné à une expérience de statistiques inspirée de Sleeper et de cartes de joueurs inspirées de Madden NFL.
Ne pas repartir de zéro. Conserver le code, les données, les statistiques, les équipes et les fonctionnalités de la V1.1.
Ne pas intégrer Supabase ou de comptes en ligne dans cette version.
Créer une identité visuelle cohérente pour toute l'application.
Palette recommandée :
- Bleu marine : couleur principale.
- Bleu électrique : couleur secondaire.
- Orange vif : performances, records et éléments importants.
- Blanc et gris clair : arrière-plans et lisibilité.
Remplacer les accents verts qui ne correspondent pas à cette identité.
Utiliser des cartes sportives modernes, des contrastes marqués, des typographies hiérarchisées et des icônes cohérentes.
Éviter que tous les écrans ressemblent à des formulaires iOS standards.
Préserver une excellente lisibilité, notamment en mode sombre.
L'accueil doit donner envie d'ouvrir GameSplit après chaque match.
Modifier la structure :
1. En-tête GameSplit avec le nom de l'organisation et son logo, si disponible.
2. Prochain match avec date, adversaire et accès rapide.
3. Activités récentes : résultats, performances individuelles, records et meilleurs joueurs.
4. Leaders de la semaine par position.
Important : actuellement, les quatre catégories QB, WR, DB et Rusher prennent trop de place lorsque les statistiques sont vides.
- Masquer les classements sans performances.
- Afficher un seul état vide élégant lorsqu'aucun match n'a été joué.
- Présenter les leaders dans des cartes compactes ou un carrousel horizontal.
- Utiliser les photos des joueurs et leurs statistiques principales.
- Prévoir un bouton clair pour créer un premier match.
Aucune publication fictive : utiliser uniquement les données réellement enregistrées.
Moderniser l'affichage des matchs.
- Créer des cartes avec noms et logos des deux équipes.
- Mettre le score en évidence.
- Afficher les dates, lieux et statuts.
- Distinguer visuellement les matchs à venir des matchs terminés.
- Ajouter un gros bouton « Planifier un match » lorsqu'aucun match n'existe.
- Conserver l'importation CSV.
Corrections fonctionnelles :
- Désactiver l'équilibrage automatique des joueurs pour les matchs officiels entre équipes.
- Réserver cette fonctionnalité aux matchs récréatifs entre amis.
- Empêcher la création de matchs officiels avec des équipes invalides ou sans participants dans les deux camps.
- Conserver les statistiques et résultats existants.
Transformer cet écran en véritable classement sportif.
- Rendre les filtres de saison et de position plus compacts.
- Mettre davantage en évidence les trois meilleurs joueurs.
- Ajouter photos, positions, équipes et OVR.
- Mettre en évidence les statistiques pertinentes pour chaque position.
- Conserver les classements détaillés et leurs filtres.
- Ne pas présenter un joueur sans match comme un véritable leader statistique.
- Prévoir un état vide avec une invitation à enregistrer un match.
L'interface doit donner envie aux joueurs de comparer leurs performances.
Transformer l'onglet Équipes en espace sportif plutôt qu'administratif.
Afficher les équipes sous forme de cartes avec :
- Logo.
- Nom.
- Bilan victoires/défaites.
- Nombre de joueurs.
- Prochain match, si disponible.
Permettre d'ouvrir une fiche d'équipe pour consulter son effectif, ses statistiques et ses résultats.
Déplacer visuellement les fonctions administratives (joueurs, finances, sauvegarde) dans une section Gestion moins dominante.
Ne pas modifier le fonctionnement de la section Finances.
Conserver la carte actuelle bleu marine / bleu électrique avec l'OVR jaune : c'est une bonne direction.
L'améliorer avec :
- Une photo de joueur plus grande.
- Un OVR très visible.
- Une position principale clairement identifiable.
- Les logos des équipes.
- Une meilleure hiérarchie visuelle.
- Des statistiques principales adaptées à la position.
Exemples :
QB : passes TD, verges par la passe, interceptions lancées.
WR : réceptions, verges, TD.
DB : interceptions, plaqués.
Rusher : sacks, plaqués.
Conserver l'accès aux statistiques complètes, y compris pour les joueurs qui occupent plusieurs positions.
Ajouter une section visuelle de records personnels lorsque des performances existent.
Prévoir une présentation qu'on pourra éventuellement transformer en carte partageable sur les réseaux sociaux.
Corriger également le contraste du sélecteur de saison « Carrière », actuellement difficile à lire dans certaines circonstances.
- Harmoniser les cinq onglets : Accueil, Matchs, Classements, Équipes, Profil.
- Utiliser la même couleur d'accent partout.
- Vérifier les safe areas.
- Empêcher les cartes, formulaires et boutons d'être masqués par la barre inférieure.
- Tester les petits et grands écrans iPhone.
- Préserver le comportement natif d'iOS.
L'application doit être agréable même lorsqu'elle ne contient aucune donnée.
Créer des états vides personnalisés avec des actions utiles.
Ajouter, si possible, un mode démonstration activable volontairement, permettant de créer un ensemble cohérent de données fictives :
- Une organisation.
- Deux équipes.
- Plusieurs joueurs avec positions et OVR.
- Quelques matchs.
- Des statistiques réalistes.
- Des classements.
Ne jamais mélanger silencieusement les données de démonstration aux vraies données. Prévoir une suppression sûre des données de démo et ne pas supprimer les données réelles.
Cette fonctionnalité est secondaire : ne pas sacrifier les corrections ou le design pour l'implémenter.
- Préserver les données SwiftData V1 et V1.1.
- Ne pas modifier inutilement le schéma.
- Ne pas casser les statistiques ou les sauvegardes.
- Conserver les tests existants.
- Ajouter des tests pour les nouvelles validations de matchs.
- Corriger toute erreur de compilation détectée.
- Exécuter les tests si Xcode est disponible.
- Ne pas prétendre avoir testé l'application sur iPhone si ce n'est pas le cas.
Si une fonctionnalité n'est pas réalisable dans cette itération, l'indiquer clairement plutôt que créer une interface non fonctionnelle.
À la fin :
1. Fournir la liste des modifications.
2. Expliquer les changements visuels.
3. Identifier les bugs corrigés.
4. Préciser les tests exécutés et non exécutés.
5. Fournir les instructions de vérification dans Xcode.
6. Publier le travail dans une branche GitHub dédiée à la V1.1.1, sans fusionner automatiquement dans main.
Résultat recherché : GameSplit doit ressembler à une véritable application sportive moderne, avec une identité forte, des profils attractifs et une expérience intuitive.
Prioriser la qualité visuelle et la simplicité plutôt que l'accumulation de fonctionnalités.
Notre prochaine étape après cette version sera la V1.2 : comptes utilisateurs, Supabase et synchronisation entre joueurs.