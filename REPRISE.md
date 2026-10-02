# GymFlow : fiche de reprise (état au 02/10/2026)

À lire en premier au début d'une nouvelle discussion. Détails : `README.md` (installation, comptes), `DECISIONS.md` (choix et raisons), `PROGRESS.md` (avancement), `SECURITE_CONFIDENTIALITE.md` (données personnelles, conformité, audit à venir), `ASSETS.md` (origine des médias).

## 1. Le projet
Application Flutter d'une salle de sport (Super Admin / Coach / Abonné), style Strava, en français, devise TND.
- Palette imposée : marine `#002855`, rouge `#BA0C2F`, or `#FFCF70`, crème `#FFF4E0`, fond `#F5F5F0`. Mode clair uniquement, contraste WCAG AA (tests de contraste).
- Données locales : SQLite sur Android (`sqflite`), en mémoire sur le web (`kIsWeb` → `MemoryDataStore`).
- Paiement : Stripe en mode test si une clé `sk_test_` est fournie (`--dart-define-from-file=secrets.json`, jamais commitée), sinon passerelle simulée (carte 4242 4242 4242 4242).

## 2. Où sont les choses
| Élément | Emplacement |
|---|---|
| Projet | `C:\Users\youss\Desktop\Projet Mobile Flutter\gymflow` |
| Dépôt GitHub (public) | https://github.com/YoussefBY22/ProjetDevMobile-5SAE6-FAMY |
| Code | branche **`GymFlow-V1`** |
| `main` | **volontairement vide** (un seul commit vide) |
| `gh-pages` | uniquement la version web compilée (publiée sur GitHub Pages) |
| Version web en ligne | https://youssefby22.github.io/ProjetDevMobile-5SAE6-FAMY/ |
| Téléphone de test | vivo V2332, Android 16, identifiant adb `10HE8DF73N0025Y` |
| Flutter | `C:\Users\youss\flutter` (3.44.3, Dart 3.12.2), dans le PATH |
| adb | `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe` (hors PATH ; `flutter install` suffit) |

Historique de `GymFlow-V1` (du plus récent au plus ancien) :
- `c9ba764` Bibliothèque collaborative, recherche bilingue, filtres mémorisés, favoris animés
- `03ab050` Communauté, partage avec consentement, confidentialité, version ordinateur
- `a87ba28` … `074ac98` Application de base (modules 6.1 à 6.6, tests, documentation)

## 3. Règles de travail convenues
- **Aucune trace de Claude dans les commits** (pas de `Co-Authored-By`, pas de mention dans les messages). Auteur : `YoussefBY22 <youssef.benyoussef@esprit.tn>`.
- **Pousser seulement sur demande explicite** de Youssef. Commits locaux autorisés.
- Ne pas remettre de code sur `main`.
- Messages, textes de l'app et documentation en français.
- Avant de livrer : `dart format lib test`, `flutter analyze` (0 problème), `flutter test` (tout vert).
- Sur ce PC, l'outil Bash est cassé : utiliser PowerShell.

## 4. Ce que fait l'application aujourd'hui
**Socle (modules 6.1 à 6.6)** : connexion / inscription (mots de passe PBKDF2, verrouillage après 5 échecs), profils, progression (IMC, courbes, records, série, badges), exercices / workouts / programmes avec vidéos, lecteur de séance (séries, minuteur de repos), cours (statuts, réservations, liste d'attente, présences, notes, rappels), boutique (panier, paiement, commandes), tableaux de bord admin et coach, annonces, recherche globale, notifications, journal d'audit.

**Communauté et confidentialité (`03ab050`)**
- Tout est privé par défaut : profil, réseaux sociaux, séances. Chaque séance se partage par un geste (« Partager » ou « Garder privée »).
- Annuaire « Membres de la salle » (membres visibles et majeurs seulement), réseaux en option (Instagram, Facebook, LinkedIn, Snapchat, e-mail), signalement, modération par l'admin.
- Accueil : bouton « Masquer les autres » sur le fil.
- Présentation verticale au premier lancement + choix + acceptation des CGU ; inscription réservée aux 18 ans et plus.
- Export des données (JSON), historique des consentements, suppression du compte (commandes conservées mais anonymisées).
- Version ordinateur : navigation latérale à partir de 900 px, contenu centré, colonnes.

**Bibliothèque collaborative (`c9ba764`)**
- Les abonnés créent exercices, workouts et programmes, **privés** par défaut ; « Proposer à la publication » → un coach ou l'admin **accepte** ou **refuse avec un motif** (écran « Propositions à valider »). « Copier pour personnaliser ».
- Recherche bilingue FR ↔ EN : glossaire du sport (`lib/core/search.dart`), noms anglais du contenu du club (`lib/services/seed/seed_translations.dart`), langue de saisie choisie au début des formulaires, bouton FR / EN pour l'affichage des noms.
- Filtres dans une feuille (bouton « Filtres », aperçu du nombre de résultats), **mémorisés avec le compte** : programmes, workouts, exercices, cours, boutique, utilisateurs.
- Favoris en tête de liste avec animation.
- CGU en version `2026-10-b` (clause sur les créations des membres).

## 5. Architecture (repères)
```
lib/core/       theme, routes (garde de rôle), legal (CGU, politique, versions),
                search (recherche bilingue), responsive, security, validators…
lib/models/     user (+ prefs, privacy), content (statut de publication, langue),
                exercise, workout (+ programme), session_log, course, shop…
lib/services/   backend (point d'accès Backend.I), library (visibilité, publication,
                recherche, filtres), exercise, workout, training_log, privacy,
                community, course, product, auth, seed/ (données de démo)…
lib/screens/    auth, shell, home, training (dont review_screen), courses, shop,
                profile, admin, community, privacy, misc
lib/widgets/    filter_bar (filtres), flip (animation des favoris),
                library_widgets (statut, publication, langue), cards…
test/           135 tests (règles métier, droits, sécurité, confidentialité,
                bibliothèque, widgets, parcours complet, version ordinateur)
```
Les contrôles d'accès sont dans les services (`requireUser`, `requireRole`, `LibraryService.canSee` / `canEdit`), pas seulement dans l'interface.

## 6. Comptes de démonstration
| Rôle | E-mail | Mot de passe |
|---|---|---|
| Super admin | admin@gymflow.tn | Admin2026! |
| Coachs | amira@, mehdi@, sarra@gymflow.tn | Coach2026! |
| Abonnés | nour@ (aucune séance), ahmed@, leila@, omar@, ines@, rami@, salma@gymflow.tn | Membre2026! |
| Abonnement expiré | hedi@gymflow.tn | Membre2026! |
| Compte désactivé | walid@gymflow.tn | Membre2026! |

Créations de démo : workout d'Ines publié, workout de Rami **en attente** (à valider avec un coach), workout de Leila refusé, workout + exercice privés d'Ahmed.

## 7. Commandes utiles (PowerShell, depuis le dossier du projet)
Aller dans le projet :
```
cd "C:\Users\youss\Desktop\Projet Mobile Flutter\gymflow"
```
Lancer la version web sur le PC :
```
flutter run -d chrome --release
```
Mettre à jour l'application sur le téléphone (USB, débogage USB activé, écran déverrouillé) :
```
flutter build apk --release
flutter install --release
```
Vérifier la qualité :
```
dart format lib test
flutter analyze
flutter test
```
Republier la version web en ligne :
```
flutter build web --release --base-href /ProjetDevMobile-5SAE6-FAMY/
cd build\web
ni .nojekyll
git init -b gh-pages
git add -A
git commit -m "Mise à jour de la version web"
git push -f https://github.com/YoussefBY22/ProjetDevMobile-5SAE6-FAMY.git gh-pages
cd ..\..
```
Pousser le code :
```
git push origin GymFlow-V1
```

## 8. Limites connues
- Web : données en mémoire (remises à zéro à chaque chargement) ; images wger bloquées par le navigateur (CORS), visibles sur Android.
- L'interface (menus, boutons, libellés de muscles) n'est qu'en français ; seuls les noms et descriptions des contenus existent en anglais.
- Base SQLite locale non chiffrée ; pas de serveur : en production, tous les contrôles d'accès devront être refaits côté serveur.
- Durées de conservation affichées mais pas encore purgées automatiquement.
- Médias envoyés par les membres stockés en fichiers locaux de l'appareil.

## 9. Reste à faire / pistes
- **Audit de sécurité complet** dès que le professeur aura validé la base de données (liste détaillée : `SECURITE_CONFIDENTIALITE.md`, § 9).
- Traduction complète de l'interface en anglais (`flutter gen-l10n`), si besoin.
- Relecture juridique des textes (`lib/core/legal.dart`) avant toute commercialisation.
- Retirer le panneau « Comptes de démo » de l'écran de connexion pour une vraie mise en production.
