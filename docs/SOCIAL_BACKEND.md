# Première version sociale — approche proposée

La V1.1 fonctionne encore sur un seul appareil. Sélectionner une fiche dans Profil n’authentifie personne. Les désignations de capitaine ne sont pas une sécurité. Aucun appel réseau, connexion factice ni bouton d’invitation fictif n’a été ajouté.

## Choix : Supabase pour la prochaine étape

Une base PostgreSQL convient aux appartenances plusieurs-à-plusieurs, aux saisons et aux statistiques liées. Supabase fournit Auth, Storage et des politiques RLS vérifiables en SQL, avec un SDK Swift. Firebase reste possible mais demanderait de dénormaliser les agrégats et de contrôler leur cohérence. Aucun SDK n’est installé dans V1.1 ; le service n’est pas provisionné.

Avant l’intégration, choisir la région du projet, les règles de visibilité et la méthode de connexion. Commencer par email/mot de passe avec validation email et récupération, puis évaluer Sign in with Apple selon les exigences de distribution. Ne pas publier sans autorisation.

## Schéma serveur à implémenter

- `profiles(id = auth.users.id, display_name, primary_position, secondary_positions, avatar_path, visibility)` : identité stable, distincte d’un joueur créé localement par un gérant.
- `organizations`, `organization_members(user_id, organization_id, role)` : administrateurs de l’organisation.
- `players(id, organization_id, profile_id nullable, ... )` : conserver les UUID locaux et autoriser temporairement des joueurs non revendiqués. Un compte peut être associé à plusieurs fiches d’organisation, par preuve d’invitation.
- `teams`, `team_members(player_id, team_id, role, active_since, active_until)` : appartenances multiples et historique. Les anciens matchs ne suivent pas les changements d’effectif.
- `seasons`, `matches`, `match_participants(match_id, player_id, side)`, `stat_events`, `stat_lines(event_id, player_id, kind, value)` : passe et réception liées, mise à jour atomique avec contrainte d’unicité des lignes.
- `invitations(team_id, invited_email, token_hash, expires_at, claimed_at)` : jetons aléatoires à usage unique, uniquement leur hash en base ; expiration et limitation de tentatives.
- `follows`, puis `activities(source_match_id, source_revision, actor_id)` et `likes` avec contraintes d’unicité. Une modification met à jour la même activité ; elle ne republie pas le même résultat.
- `player_ratings(player_id, overall, effective_at, author_id)` pour un historique manuel ultérieur.
- `payments` : données privées du gérant, à isoler des profils et activités publics. Les conserver locales au début.

Chaque table mutable doit disposer d’un UUID, d’une révision monotone, de timestamps serveur et, pour la synchronisation, d’un tombstone de suppression. Interdire la modification côté client des colonnes d’identité, d’auteur et de droits. Ne jamais accepter un `accountID` local comme preuve de propriété.

## Règles d’accès indispensables

Activer RLS avant d’exposer des tables. Tester avec au moins deux comptes et un visiteur :

- Un joueur ne modifie que son profil, pas les statistiques officielles. Une fiche privée est visible selon une politique explicite (membres de la même équipe par défaut).
- Seuls les capitaines actifs de l’équipe et les administrateurs de l’organisation peuvent saisir/corriger ses matchs. Le serveur vérifie l’appartenance et l’organisation de chaque participant.
- Un capitaine ne peut pas se donner le rôle administrateur ou modifier une autre équipe. La revendication d’une fiche et l’acceptation d’une invitation doivent être validées par une fonction serveur transactionnelle.
- Les buckets privés de photos utilisent des chemins contrôlés par propriétaire et des URL signées courtes ; vérifier type, taille et droits avant upload.
- Les paiements ne sont accessibles qu’aux gestionnaires autorisés. Aucun montant impayé dans le fil public.
- Enregistrer les corrections de stats dans un journal d’audit. Recalculer les agrégats depuis les lignes, sans incréments réappliqués lors d’un retry.

Ne pas se limiter à masquer des boutons SwiftUI. Les droits doivent être vérifiés par PostgreSQL/fonctions serveur. Les politiques SQL et leurs tests restent à écrire avant activation.

## Mise en place externe précise

1. Le propriétaire crée un projet Supabase dans la région retenue. Définir la visibilité par défaut et les responsables des données.
2. Écrire et revoir les migrations SQL, contraintes, index, politiques RLS et tests de séparation entre organisations. Appliquer d’abord sur un projet de test.
3. Activer le fournisseur email et définir les URL de redirection/récupération. Pour liens universels, configurer domaine, Associated Domains et fichier AASA ; cela nécessite les réglages Apple adaptés. Ne pas utiliser de redirection non autorisée.
4. Créer les buckets privés de photos et leurs politiques. Configurer limites d’upload et rétention.
5. Ajouter le SDK officiel Supabase Swift via Swift Package Manager et figer sa version. Injecter `SUPABASE_URL` et la clé **publishable** dans un fichier local `.xcconfig` ignoré. Une clé publishable n’accorde aucune autorisation sans RLS. **Jamais** de clé service-role/admin dans l’application, le dépôt ou le chat.
6. Implémenter un `AuthSession` réel, le stockage sécurisé des jetons dans Keychain, la validation email, la déconnexion et la récupération. Faire valider les invitations côté serveur, pas par un simple UUID dans l’URL.
7. Introduire des repositories (`PlayerRepository`, `TeamRepository`, `MatchRepository`) derrière les services d’écriture. SwiftData reste le cache local ; vues, règles de contribution et agrégats locaux demeurent réutilisables.
8. Préparer un export V1/V1.1, puis un import serveur explicite avec prévisualisation et transaction. Associer les UUID existants à l’organisation autorisée sans jamais vider SwiftData.
9. Ajouter une file d’envoi locale (UUID d’opération unique, version attendue), une stratégie de conflits et un rafraîchissement paginé. Appliquer ensemble les deux lignes d’une passe TD. Tester coupures réseau, retry, comptes distincts et changement d’équipe.
10. Ajouter le fil partagé, les profils consultables, invitations, suivis et mentions J’aime seulement après validation des accès. Tester suppression de compte, export et récupération des données avant bêta.

Le financement du service, son provisionnement, les identifiants et les règles de confidentialité ne sont pas disponibles dans cet environnement. Cette documentation prépare l’intégration ; elle n’établit aucune synchronisation opérationnelle.
