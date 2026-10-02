# Sécurité et confidentialité : partage des informations des membres

Ce document couvre le lot « communauté, partage et confidentialité » de la branche `GymFlow-V1`. Il décrit ce que l'application fait aujourd'hui, pourquoi elle le fait, et ce qui reste à faire avant une commercialisation en SaaS auprès de salles de sport, en Tunisie ou à l'étranger.

> **Avertissement.** Ce document est une analyse technique, pas un avis juridique. Avant de signer avec une première salle, il faut faire relire les textes affichés dans l'application (`lib/core/legal.dart`), le contrat de sous-traitance et ce document par un juriste spécialisé en protection des données (Tunisie, et pays de chaque salle cliente).

L'audit de sécurité complet (base de données, hébergement, API) sera fait quand le professeur aura validé la base de données à utiliser. Les points à couvrir sont listés en fin de document (§ 9).

---

## 1. Principes retenus

| Principe | Application concrète dans GymFlow |
|---|---|
| **Confidentialité par défaut** | Un nouveau compte est **invisible** : profil masqué, réseaux sociaux masqués, séances privées. Aucune case n'est pré-cochée. |
| **Consentement explicite et révocable** | Chaque partage est un geste volontaire : rendre son profil visible, afficher ses réseaux, partager **chaque** séance (comme une publication Facebook). Tout se retire à tout moment. |
| **Traçabilité** | Chaque consentement (CGU, visibilité, réseaux, partage de séance) est enregistré avec sa date et la version des textes (`ConsentRecord`), et consultable par le membre (*Confidentialité → Historique de mes choix*). |
| **Minimisation** | Le profil public ne montre que la photo, le nom, l'objectif, la date d'inscription et les séances **partagées**. Jamais l'âge, le poids, la taille, l'IMC, l'abonnement ni l'e-mail de connexion. |
| **Protection des mineurs** | Inscription autonome réservée aux 18 ans et plus. Un compte de mineur, créé à l'accueil avec l'accord d'un représentant légal, **ne peut jamais** être visible. |
| **Droits effectifs** | Export de toutes ses données (JSON), modification des choix, suppression du compte depuis l'application. |
| **Le membre garde la main** | Il peut masquer l'activité des autres sur son accueil, et signaler un profil. La salle peut masquer un profil (modération), et le membre en est prévenu. |

## 2. Rôles juridiques dans un modèle SaaS

| Acteur | Rôle (loi tunisienne 2004-63 / RGPD) | Conséquences |
|---|---|---|
| **La salle de sport** (cliente) | **Responsable du traitement** : elle décide des finalités (gérer ses abonnés, ses cours, sa boutique). | Elle informe ses membres, fait ses formalités auprès de l'autorité de contrôle (INPDP en Tunisie) et répond aux demandes d'exercice des droits. |
| **L'éditeur de GymFlow** (nous) | **Sous-traitant** : il héberge et fait fonctionner le service pour le compte de la salle. | Il n'agit que sur instruction écrite de la salle, ne réutilise jamais les données (ni publicité, ni revente, ni entraînement de modèles), assure la sécurité et aide la salle à respecter ses obligations. |
| **Hébergeur, prestataire d'e-mail, Stripe…** | **Sous-traitants ultérieurs** | Liste tenue à jour et communiquée aux salles ; même niveau d'obligations imposé par contrat. |

Ce partage des rôles est la première protection contre une mise en cause : l'éditeur fournit un outil conforme et s'engage contractuellement, la salle reste responsable de l'usage qu'elle en fait. Il doit être écrit noir sur blanc dans le **contrat SaaS + accord de sous-traitance (DPA)** (§ 7).

## 3. Cadre légal par marché

### Tunisie
- **Loi organique n° 2004-63 du 27 juillet 2004** sur la protection des données à caractère personnel, contrôlée par l'**INPDP** (Instance nationale de protection des données personnelles).
  - Le traitement doit en principe faire l'objet d'une **déclaration préalable** à l'INPDP (par la salle, responsable du traitement).
  - **Consentement** exprès et écrit (y compris sous forme électronique) pour les traitements qui le requièrent ; il est révocable.
  - **Données de santé** : régime renforcé (autorisation de l'INPDP). Poids, taille et IMC sont traités comme des données sensibles : ils ne sont **jamais** partagés ni montrés dans le profil public.
  - **Enfants** : le consentement du représentant légal est nécessaire. GymFlow bloque l'inscription autonome des moins de 18 ans (`Legal.minimumAge`).
  - **Transfert de données à l'étranger** : soumis à l'autorisation de l'INPDP. C'est un point clé pour le **choix de l'hébergement** (§ 9).
- **Convention 108 du Conseil de l'Europe**, ratifiée par la Tunisie en 2017 (et son protocole 108+ à suivre).
- Un projet de réforme de la loi de 2004 est en discussion depuis plusieurs années : vérifier le texte en vigueur au moment de la commercialisation.

### Union européenne (salles en France, Belgique, Italie…)
- **RGPD (UE 2016/679)** : bases légales (contrat pour le service, consentement pour la communauté), art. 9 (santé), art. 8 (mineurs : 13 à 16 ans selon le pays, d'où notre seuil plus strict de 18 ans), art. 28 (contrat de sous-traitance), art. 30 (registre), art. 32 (sécurité), art. 33-34 (violation de données : notification sous 72 h), art. 44 et suivants (transferts hors UE).
- La Tunisie ne bénéficie pas d'une décision d'adéquation : héberger les données de salles européennes **dans l'UE** évite un transfert ; sinon, clauses contractuelles types.

### Autres pays (Maghreb, Golfe, Canada…)
- Maroc (loi 09-08, CNDP), Algérie (loi 18-07), Canada (LPRPDE, Loi 25 au Québec), etc. Les principes de GymFlow (consentement, minimisation, droits) couvrent l'essentiel ; il faut vérifier pour chaque pays les formalités, la localisation des données et l'âge du consentement.

## 4. Ce qui est partagé, avec qui, et comment l'arrêter

| Information | Par défaut | Qui peut la voir si le membre l'active | Comment l'activer / la retirer |
|---|---|---|---|
| Profil (photo, nom, objectif, date d'inscription) | **Masqué** | Les autres membres **actifs et majeurs** de la même salle | *Confidentialité → Profil visible* (ou dernière page de la présentation) |
| Réseaux (Instagram, Facebook, LinkedIn, Snapchat, e-mail public) | **Masqués** | Les mêmes, seulement si le profil est visible | *Confidentialité → Afficher mes réseaux* + saisie des liens |
| Séance réalisée | **Privée** | Les membres de la salle (fil du club et profil public) | Bouton *Partager* sur le récapitulatif ou interrupteur dans le détail de la séance. Retirer le partage efface aussi les « Bravo » reçus. |
| Workout personnel | **Privé** | Personne d'autre (ni le staff dans la liste) | Créé depuis *Entraînement → Workouts → Mon workout* |
| Poids, taille, IMC, âge, abonnement, e-mail de connexion | **Jamais partagés** | Le membre ; la salle pour la gestion de l'abonnement | — |
| Activité des autres sur mon accueil | Affichée | — | Bouton *Masquer les autres* sur l'accueil, ou *Confidentialité* |

À noter : une séance partagée affiche le nom et la photo de son auteur dans le fil, même si son profil complet est masqué. C'est voulu (on publie une séance comme on publie un post) et c'est expliqué au moment du partage. On ne peut pas ouvrir le profil d'un membre qui ne l'a pas rendu visible.

## 5. Mesures de sécurité en place (côté application)

**Contrôle d'accès dans les services, pas seulement dans l'interface.** Chaque méthode vérifie la session et le rôle (`requireUser`, `requireRole`) :
- `CommunityService.profile` refuse un profil privé (`PermissionDeniedException`), même si on connaît l'identifiant.
- `TrainingLogService.byId` ne renvoie une séance qu'à son auteur, à l'admin ou si elle est partagée ; `historyOf` seulement à soi ou à l'admin ; `setShared` seulement à l'auteur ; les « Bravo » seulement sur une séance partagée.
- `WorkoutService` cache les workouts privés des autres (liste et accès direct), et seul l'auteur peut les modifier ou les supprimer.
- `PrivacyService.updateSettings` empêche un mineur d'être visible, coupe les réseaux si le profil est masqué et **ne laisse pas** le membre lever une mesure de modération.

**Liens externes maîtrisés.**
- Instagram et Snapchat : on enregistre un **identifiant** (lettres, chiffres, `.`, `_`, `-`) et c'est l'application qui construit l'URL officielle.
- Facebook et LinkedIn : seules les adresses HTTPS des **domaines officiels** sont acceptées (`facebook.com`, `fb.com`, `linkedin.com`). `https://facebook.com.site-piege.tn` et les liens vers d'autres sites sont refusés (testé).
- Avant d'ouvrir un réseau, une confirmation prévient l'utilisateur qu'il quitte GymFlow.

**Modération et signalement.** Un membre peut signaler un profil (motif de 5 à 300 caractères, une fois par jour et par profil). Les admins sont notifiés et le signalement est inscrit au journal d'audit. L'admin peut *Masquer de la communauté* : le profil et ses séances partagées disparaissent, l'action est tracée et le membre est notifié.

**Droits des personnes.**
- *Exporter mes données* : JSON lisible de tout ce qui concerne le membre (compte, séances, pesées, réservations, commandes, notifications, workouts personnels), **sans aucun secret** (ni empreinte, ni sel, ni jeton).
- *Supprimer mon compte* : demande le mot de passe. Supprime le compte, les identifiants, les séances, les pesées, les réservations (avec promotion de la liste d'attente), les « Bravo » donnés, les notifications et les workouts personnels. Les **commandes** sont conservées pour l'obligation comptable mais **anonymisées** (`anonyme-<empreinte>`). La suppression d'un compte par l'admin applique le même effacement.

**Hérités du socle** (voir `DECISIONS.md`) : mots de passe PBKDF2-HMAC-SHA256 avec sel, jeton de session dont seule l'empreinte est stockée, verrouillage après 5 échecs, aucune API qui renvoie un mot de passe, pas d'usurpation de compte par l'admin, journal d'audit, contrôle du type et de la taille des fichiers envoyés, secrets hors de git.

**Couverture de tests** : `test/privacy_test.dart` (15 tests : réglages par défaut, consentements datés, mineurs, CGU obligatoires, modération, réseaux et liens piégés, séances privées et partagées, signalement, workouts personnels, export sans secret, suppression avec anonymisation) et `test/desktop_test.dart`.

## 5 bis. Contenus créés par les membres (exercices, workouts, programmes)

| Risque | Mesure |
|---|---|
| Consigne dangereuse publiée (charge, posture) | Rien n'est public sans **validation d'un coach ou de l'admin** ; refus motivé ; le staff peut modifier ou retirer un contenu publié ; rappel « ne remplace pas l'avis d'un coach » dans les CGU. |
| Atteinte aux droits d'auteur (vidéo, photo d'un tiers) | À la proposition, l'auteur déclare avoir les droits (CGU) ; le coach vérifie les médias ; contenu retirable. |
| Fuite de contenus privés | Contrôle d'accès dans les services (`LibraryService.canSee`) : un contenu non publié n'est visible que de son auteur (et du staff quand il est proposé). La recherche globale respecte la même règle (testé). |
| Exposition de l'auteur | Signature limitée à « Prénom N. » ; aucune autre donnée de profil. |
| Effacement du compte | Créations non publiées supprimées ; créations publiées conservées et anonymisées, comme annoncé avant la proposition et dans les CGU. |
| Traçabilité | Proposition, publication et refus inscrits au journal d'audit ; l'auteur est notifié de chaque décision. |

À prévoir en SaaS : stockage serveur des médias envoyés (aujourd'hui fichiers locaux de l'appareil), analyse antivirus et limites de taille côté serveur, modération des images.

## 6. Textes affichés dans l'application

- **Présentation** au premier lancement (et après une nouvelle version des textes) : 5 pages verticales (glisser vers le haut sur téléphone, molette ou flèches sur ordinateur), puis une page de choix où **tout est désactivé**. L'acceptation des CGU et de la politique est obligatoire ; elle est déjà cochée seulement si le membre l'a acceptée lors de son inscription.
- **Politique de confidentialité** (11 sections) et **conditions d'utilisation** (7 sections) dans `lib/core/legal.dart`, accessibles sans être connecté (*Lire*), depuis la présentation et depuis *Confidentialité*.
- **Version des textes** : `Legal.version` (actuellement `2026-10-b`, ajout de la clause sur les créations des membres). Si elle change, le consentement aux CGU est redemandé à la connexion suivante.
- **Durées de conservation** affichées : compte pendant l'abonnement + 3 ans d'inactivité ; séances, pesées et réservations supprimées avec le compte ; commandes 10 ans, anonymisées ; journal d'audit 1 an.

## 7. Documents à préparer avant de vendre (hors code)

1. **Contrat SaaS + accord de sous-traitance (DPA)** avec chaque salle : objet, durée, nature des données, instructions, confidentialité du personnel, sécurité, sous-traitants ultérieurs, aide à l'exercice des droits, notification des violations (sans délai, au plus tard sous 48 h pour que la salle respecte ses 72 h RGPD), restitution et suppression en fin de contrat, audits. **Limitation de responsabilité** et rappel que la salle reste responsable de ses formalités et de la modération de sa communauté.
2. **Kit conformité pour les salles** : modèle de déclaration INPDP, registre des traitements pré-rempli, affichage pour l'accueil, formulaire papier de consentement parental pour les mineurs.
3. **Liste des sous-traitants ultérieurs** et pays d'hébergement.
4. **Procédure de violation de données** : détection, qualification, information de la salle, aide à la notification (INPDP / autorité européenne), registre des incidents.
5. **Mentions légales de l'éditeur** et contact du délégué à la protection des données ou du référent.
6. **Relecture juridique** de `legal.dart` pour chaque marché (langue, droit applicable, tribunal compétent).

## 8. Limites connues de cette version

Elles sont listées honnêtement pour ne pas promettre plus que ce qui est fait :
- **Données sur le téléphone** : la base SQLite locale n'est **pas chiffrée** (seul le jeton de session est dans le stockage sécurisé). C'est acceptable pour une démo mono-appareil, pas pour la production.
- **Pas de serveur** : en production, les contrôles d'accès décrits au § 5 doivent être **refaits côté serveur**. Ceux du client ne suffisent jamais seuls.
- **Durées de conservation** : affichées mais pas encore **purgées automatiquement** (inactivité de 3 ans, audit de 1 an).
- **Photos de profil** : pas de modération automatique (signalement manuel uniquement) et métadonnées EXIF non nettoyées.
- **Panneau « Comptes de démo »** sur l'écran de connexion : à retirer pour la production (voir `README.md`).
- **Mot de passe oublié** : l'envoi d'e-mail est simulé et révèle si un compte existe.
- **Suppression du compte** : en libre-service pour les abonnés seulement. Les coachs passent par l'admin.

## 9. À faire lors de l'audit complet (après validation de la base de données)

1. **Hébergement et localisation** : Tunisie (pas de transfert, mais vérifier les certifications de l'hébergeur) ou UE pour les salles européennes. Obtenir l'autorisation de l'INPDP si des données de membres tunisiens sortent du pays.
2. **Isolation multi-salles (multi-tenant)** : chaque requête est filtrée par salle, au niveau de la base (sécurité par ligne si la base le permet) et pas seulement dans le code. Tests d'accès croisé entre salles.
3. **API serveur** : authentification par jetons à durée courte, autorisation sur chaque route, limitation de débit (connexion, signalement), validation des entrées, en-têtes de sécurité, HTTPS/TLS 1.2+ uniquement.
4. **Chiffrement** : au repos (disque et sauvegardes), base locale chiffrée sur le téléphone (SQLCipher ou équivalent) si un cache hors-ligne est gardé.
5. **Sauvegardes** chiffrées, testées et purgées selon les durées de conservation.
6. **Journalisation** sans données personnelles inutiles ; conservation d'un an ; accès réservé.
7. **Purge automatique** des comptes inactifs et du journal d'audit.
8. **Médias** : stockage privé, URLs signées à durée limitée, suppression des métadonnées EXIF, modération des photos.
9. **Tests d'intrusion** (OWASP MASVS pour l'application mobile, OWASP ASVS pour l'API) et analyse des dépendances.
10. **Plan de réponse aux incidents** et exercice de simulation.
11. **Analyse d'impact (AIPD/DPIA)** : données de santé et fonction communautaire, à mener avec une salle pilote.
