# GameSplit — V1.1 : Transformation en réseau social de flag football

## 1. Vision du projet

GameSplit doit devenir une application iOS qui combine les fonctionnalités de Strava, Sleeper et Madden NFL, mais exclusivement pour le flag football.

**Notre objectif : construire un réseau social sportif où chaque joueur possède son propre profil, ses statistiques, son historique de carrière, ses équipes et son classement.**

Un utilisateur doit pouvoir :
- Créer son compte et son profil sportif.
- Rejoindre une ou plusieurs équipes.
- Consulter les statistiques de ses matchs.
- Suivre ses amis et ses coéquipiers.
- Comparer ses performances aux autres joueurs.
- Consulter un fil d'actualité sportif.
- Suivre l'évolution de son OVR et de ses statistiques au fil des saisons.
- Partager ses performances.

Les capitaines et gestionnaires pourront créer des équipes, gérer les matchs et saisir les statistiques, qui seront ensuite automatiquement associées aux profils des joueurs concernés.

**Important : nous développons un réseau social pour joueurs, pas un logiciel administratif de gestion de ligues.**

Les fonctionnalités de gestion doivent soutenir l'expérience sociale, sans la dominer.

## 2. Modernisation complète du design

Le design actuel ressemble encore trop à un prototype.

Créer une interface moderne, colorée, sportive et professionnelle.

Inspirations :
- Strava : profils, activités et communauté.
- Sleeper : interface sportive, statistiques et navigation.
- Madden NFL : cartes de joueurs, OVR et progression.
- ESPN : résultats et classements.

Améliorations :
- Palette de couleurs cohérente et distinctive.
- Cartes de joueurs visuellement attrayantes.
- Photos de profil et logos d'équipes.
- Badges pour les positions.
- Présentation dynamique des statistiques.
- Navigation simple et fluide.
- Interfaces adaptées aux différents formats d'iPhone.
- Animations légères lorsque pertinentes.

Conserver une bonne lisibilité et éviter de surcharger les écrans.

## 3. Nouvelle navigation principale

Réorganiser progressivement l'application autour de cinq sections :

**Accueil**
- Fil d'actualité sportif.
- Résultats des matchs récents.
- Performances des joueurs suivis.
- Meilleurs joueurs de la semaine.
- Actualités des équipes rejointes.

**Matchs**
- Calendrier des matchs.
- Résultats.
- Statistiques individuelles.
- Historique des rencontres.

**Classements**
- Classements par position.
- Classements par saison.
- Comparaison entre joueurs.
- Statistiques des équipes.

**Équipes**
- Liste des équipes de l'utilisateur.
- Effectifs.
- Calendriers.
- Gestion des équipes pour les capitaines.

**Profil**
- Photo.
- Nom et positions.
- Équipes.
- OVR.
- Statistiques de saison et de carrière.
- Historique des performances.
- Réalisations sportives.

La section Finances actuelle doit rester accessible aux gestionnaires, sans devenir un élément central du réseau social.

## 4. Accueil et fil d'actualité

Transformer l'accueil en véritable fil d'actualité.

Permettre l'affichage de publications sportives générées automatiquement, comme :
- Une équipe a remporté son match.
- Un joueur a réussi 4 passes de touché.
- Un joueur a atteint un nouveau record personnel.
- Les meilleurs joueurs de la semaine.
- Les résultats des équipes suivies.

Ajouter progressivement la possibilité de :
- Suivre d'autres joueurs.
- Aimer les publications.
- Accéder aux profils depuis les publications.
- Partager une carte de performance.

Pour cette V1.1, privilégier un fil d'actualité automatique fonctionnel. Les publications manuelles, les commentaires et les fonctionnalités sociales avancées pourront venir plus tard.

### Classements sur l'accueil

Remplacer le classement général des meilleurs joueurs par des classements adaptés aux positions.

**QB**
- Passing TD
- Passing Yards
- Interceptions lancées

**WR**
- Receiving Yards
- Receiving TD
- Réceptions

**DB**
- Tackles
- Interceptions

**Rusher**
- Sacks
- Tackles

Afficher les meilleurs joueurs avec leur photo, leur équipe et leurs principales statistiques.

## 5. Joueurs et profils

Faire des profils de joueurs l'une des fonctionnalités centrales de GameSplit.

### Création et modification

- Ajouter une photo de profil.
- Ajouter la position Rusher.
- Autoriser plusieurs positions par joueur.
- Autoriser l'appartenance à plusieurs équipes.
- Pouvoir ajouter et retirer des équipes facilement.
- Conserver le système d'OVR de 1 à 99.

### Fiche de joueur

Chaque joueur doit disposer d'une page dédiée contenant :
- Photo et nom.
- Numéro de joueur, facultatif.
- Position principale et positions secondaires.
- Équipe(s).
- OVR.
- Nombre de matchs joués.
- Statistiques de la saison.
- Statistiques de carrière.
- Historique des matchs.
- Meilleures performances personnelles.

S'inspirer visuellement des cartes Madden pour la présentation du joueur.

### OVR

Conserver les évaluations manuelles pour l'instant.

Prévoir une architecture permettant éventuellement :
- Historique des OVR.
- Évolution des notes.
- Badges et récompenses.
- Hall of Fame.

Ne pas développer un algorithme d'OVR automatique dans cette version.

## 6. Équipes

Chaque équipe doit posséder :
- Un nom.
- Un logo personnalisable.
- Un effectif.
- Un ou plusieurs capitaines/gestionnaires.
- Un historique de matchs.
- Un bilan victoires/défaites.
- Des statistiques collectives.

Un joueur peut appartenir à plusieurs équipes simultanément.

Prévoir des rôles clairs :
- Joueur : consultation de son profil et de ses statistiques.
- Capitaine : gestion de son équipe et saisie des matchs.
- Administrateur : gestion des autorisations de son organisation.

Les utilisateurs ne doivent pas pouvoir modifier librement les statistiques officielles d'autres joueurs.

## 7. Matchs

Améliorer la gestion des matchs existante.

### Création des matchs

- Préremplir le nom de l'équipe sélectionnée.
- Permettre de choisir une équipe adverse existante.
- Permettre de saisir manuellement un nouvel adversaire.
- Permettre de modifier les informations d'un match.
- Conserver la date, l'heure, le lieu et le résultat.

### Statistiques individuelles

Permettre au capitaine ou au gestionnaire de saisir les performances des joueurs.

**QB**
- Passes de touché
- Verges par la passe
- Interceptions lancées

**WR**
- Réceptions
- Verges de réception
- Touchés sur réception

**DB**
- Plaqués
- Interceptions

**Rusher**
- Sacks
- Plaqués

Ces statistiques doivent mettre automatiquement à jour :
- Les profils des joueurs.
- Les classements.
- Les statistiques saisonnières.
- Les statistiques de carrière.
- Les publications automatiques du fil d'actualité.

Un match modifié ne doit jamais produire de double comptage.

### Calendrier

- Ajouter une option d'importation de calendrier.
- Prendre en charge les fichiers CSV et, si possible, .ics.
- Afficher les matchs à venir et terminés.
- Prévoir une vérification des doublons lors de l'importation.

## 8. Statistiques et pointage

Modifier le système de points statistiques :

**Une passe de touché vaut 4 points dans le système de points individuels.**

Ne pas confondre les points individuels avec le score réel d'un match de flag football.

Centraliser les règles de calcul pour que les classements, les fiches et les résumés utilisent les mêmes résultats.

## 9. Comptes utilisateurs et synchronisation

C'est une étape fondamentale pour transformer GameSplit en réseau social.

Actuellement, les données sont principalement locales.

Préparer l'application pour qu'à terme :
- Chaque joueur possède son propre compte.
- Un joueur puisse rejoindre une équipe par invitation.
- Les membres voient les mêmes statistiques.
- Les résultats soient synchronisés entre appareils.
- Un utilisateur conserve son profil lorsqu'il change d'équipe.
- Les photos et les données soient associées aux bons utilisateurs.

Privilégier une solution backend adaptée à SwiftUI, par exemple Supabase ou Firebase.

Avant d'intégrer le backend, examiner l'architecture existante et choisir une approche cohérente.

Ne pas remplacer brutalement la sauvegarde locale ou supprimer des données existantes.

Prévoir les règles d'accès, l'association sécurisée des joueurs à leurs comptes, la confidentialité des profils et les mécanismes de récupération des données.

Si une configuration externe est nécessaire, fournir des instructions précises. Ne pas créer de faux systèmes de connexion ou de synchronisation présentés comme fonctionnels.

## 10. Finances

Ne pas modifier la section Finances actuelle.

Conserver son interface, ses calculs, ses fonctionnalités et les données existantes.

## 11. Priorités de développement

Ne pas essayer de construire toutes les fonctionnalités de Strava dans une seule itération.

**Priorité 1 — V1.1**
- Moderniser le design.
- Ajouter les photos de joueurs et d'équipes.
- Améliorer les fiches de joueurs.
- Gérer plusieurs équipes et plusieurs positions.
- Ajouter Rusher.
- Améliorer la saisie des matchs.
- Ajouter les statistiques par position.
- Corriger la règle des 4 points.
- Améliorer les classements.
- Préserver toutes les fonctionnalités existantes.

**Priorité 2 — Première version sociale**
- Comptes individuels.
- Base de données partagée.
- Invitations dans les équipes.
- Synchronisation des statistiques.
- Fil d'actualité automatique.
- Profils consultables entre utilisateurs.
- Possibilité de suivre des joueurs.

**Priorité 3 — Versions futures**
- Badges et réalisations.
- OVR évolutifs.
- Hall of Fame.
- Comparaisons de carrière.
- Rivalités.
- Défis et interactions sociales avancées.

Concevoir l'architecture de la V1.1 pour faciliter l'ajout des fonctionnalités sociales sans devoir réécrire toute l'application.

## 12. Exigences techniques

- Continuer à partir du projet SwiftUI actuel.
- Ne pas repartir de zéro.
- Préserver les données existantes.
- Maintenir les fonctionnalités qui fonctionnent déjà.
- Organiser le code pour faciliter les prochaines versions.
- Éviter les écrans et boutons fictifs.
- Écrire ou adapter les tests nécessaires.
- Vérifier la compilation et corriger les erreurs.
- Signaler les fonctionnalités nécessitant une configuration backend ou un compte développeur.

À la fin, fournir :
1. Un résumé des changements.
2. La liste des fonctionnalités réellement opérationnelles.
3. Les fichiers importants modifiés.
4. Les étapes nécessaires pour tester sur Xcode.
5. Les fonctionnalités reportées et les raisons.
6. Les prochaines étapes recommandées pour devenir un véritable réseau social.

## Résultat attendu

GameSplit doit évoluer d'une petite application de gestion de matchs vers une véritable plateforme sociale dédiée au flag football.

L'expérience recherchée est simple :

**Je joue au flag football, mon équipe enregistre le match, mes statistiques apparaissent sur mon profil, mes amis peuvent voir mes performances et je peux suivre ma progression au fil de ma carrière.**

C'est cette expérience qui doit guider les décisions de conception et de développement.