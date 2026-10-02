# GymFlow

Application mobile Flutter de la salle de sport **GymFlow** (super admin, coachs, abonnés), style Strava, en français, devise TND.
Données stockées localement (SQLite) : aucune configuration serveur n'est nécessaire, un jeu de démonstration réaliste est chargé au premier lancement.

- `PROGRESS.md` : avancement par module · `DECISIONS.md` : choix et sources · `ASSETS.md` : origine et licence des médias · `SECURITE_CONFIDENTIALITE.md` : partage des données, consentements, conformité (Tunisie, UE) et points à auditer.

Le code est sur la branche **`GymFlow-V1`** (la branche `main` est volontairement vide).

### Bibliothèque collaborative, recherche bilingue et filtres
- **Chacun crée ses contenus** : exercices (photos, vidéos du téléphone, liens YouTube), workouts et programmes, depuis le bouton *Mon exercice / Mon workout / Mon programme* de l'onglet Entraînement. Ils sont **privés** (visibles par leur auteur seul).
- **Publication modérée** : *Proposer à la publication* → un coach ou l'admin **accepte** (visible de tous, dans la liste correspondante) ou **refuse avec un motif** (l'auteur corrige et repropose). Les éléments personnels utilisés (exercices d'un workout…) sont proposés avec lui. File *Propositions à valider* (menu et icône de l'onglet Entraînement) pour le staff.
- *Copier pour personnaliser* : n'importe quel contenu visible devient une copie personnelle modifiable.
- **Recherche bilingue** : « bench press » trouve *Développé couché*, « pull-up » trouve *Tractions*, « chest » trouve les exercices de pectoraux ; un workout est trouvé par les exercices qu'il contient. Glossaire FR ↔ EN du sport + noms anglais de tout le contenu du club + traduction facultative à la création (langue de saisie choisie au début). Bouton **FR / EN** pour afficher les noms dans la langue voulue.
- **Filtres en feuille** (bouton *Filtres* avec le nombre de filtres actifs, aperçu « Voir N résultats », étiquettes supprimables) sur Programmes, Workouts, Exercices, Cours, Boutique et Utilisateurs. Ils sont **mémorisés avec le compte** : retrouvés après une déconnexion.
- **Cours** : *Quand ?* (aujourd'hui, demain, cette semaine…), *Jour de la semaine* en tuiles datées, *Moment de la journée*, discipline, coach, niveau, places disponibles.
- **Favoris en tête** : un favori remonte en haut de la liste avec une animation (la carte se soulève et glisse à sa nouvelle place), le plus récent en premier.

### Nouveautés de la V1 « communauté et confidentialité »
- **Tout est privé par défaut** : profil, réseaux sociaux et séances restent invisibles tant que le membre ne les partage pas.
- **Partage avec accord** : à la fin d'une séance, *Partager* ou *Garder privée* (comme une publication). Le partage se retire à tout moment depuis le détail de la séance.
- **Membres de la salle** : annuaire des membres qui ont choisi d'être visibles (photo, objectif, séances partagées et, s'ils l'acceptent, Instagram, Facebook, LinkedIn, Snapchat, e-mail). Signalement d'un profil, modération par l'admin.
- **Accueil** : bouton *Masquer les autres* pour ne garder que ses propres séances dans le fil.
- **Présentation** au premier lancement : pages verticales (glisser vers le haut) sur le partage, les workouts personnels, la communauté et les droits, puis les choix (tous désactivés par défaut).
- **Workouts personnels** : un abonné compose ses propres séances (*Entraînement → Workouts → Mon workout*), visibles par lui seul.
- **Mes données** : export JSON, historique des consentements, suppression du compte (*Menu → Confidentialité & mes données*).
- **Version ordinateur** : au-delà de 900 px, navigation latérale (libellés à partir de 1280 px), contenu centré, listes en 2 ou 3 colonnes, accueil en 2 colonnes, filtres sur plusieurs lignes, glisser à la souris, présentation à la molette ou aux flèches.

## 1. Prérequis
- Flutter **stable** (développé avec Flutter 3.44.3 / Dart 3.12.2), JDK 17.
- Android SDK (plateforme 36, installée automatiquement par Gradle si besoin).
- Vérifier : `flutter doctor` (le seul avertissement acceptable est « cmdline-tools component is missing », non bloquant).
- Licences Android : `flutter doctor --android-licenses` (répondre `y`). Cette commande exige les *cmdline-tools* : Android Studio → *SDK Manager* → *SDK Tools* → cocher **Android SDK Command-line Tools**.

## 2. Préparer le téléphone Android
1. **Options développeur** : *Paramètres → À propos du téléphone* → toucher **7 fois** « Numéro de build ».
2. *Paramètres → Système → Options pour les développeurs* → activer **Débogage USB**.
3. Brancher le câble USB (un câble **données**, pas « charge seulement »).
4. Sur le téléphone, accepter la fenêtre **« Autoriser le débogage USB ? »** (empreinte RSA ; cocher « Toujours autoriser »).
5. Si le téléphone le demande, choisir le mode USB **« Transfert de fichiers »**.

## 3. Vérifier la connexion
`adb` se trouve dans `%LOCALAPPDATA%\Android\Sdk\platform-tools` (à ajouter au PATH si besoin).

```bash
adb devices
```
Le téléphone doit apparaître avec le statut `device`.

```bash
flutter devices
```

## 4. Lancer l'application
Depuis le dossier `gymflow` :

```bash
flutter pub get
```

```bash
flutter run -d <id_appareil>
```
(l'application est installée automatiquement sur le téléphone ; `<id_appareil>` est donné par `flutter devices`).

Sur ordinateur (navigateur, données de démonstration en mémoire, remises à zéro à chaque rechargement) :

```bash
flutter run -d chrome
```

APK de débogage (fichier `build/app/outputs/flutter-apk/app-debug.apk`, installable à la main) :

```bash
flutter build apk --debug
```

### Paiement Stripe (mode test, facultatif)
Sans clé, la boutique utilise la passerelle **simulée** (carte `4242 4242 4242 4242`, date future, CVC quelconque ; `4000 0000 0000 0002` = refus).
Pour utiliser Stripe Checkout en mode test : copier `secrets.example.json` en `secrets.json` (ignoré par git), y mettre votre clé **`sk_test_…`**, puis :

```bash
flutter run -d <id_appareil> --dart-define-from-file=secrets.json
```

## 5. Dépannage USB
| Problème | Solution |
|---|---|
| `unauthorized` | Débrancher/rebrancher et accepter la fenêtre RSA ; sinon *Options développeur → Révoquer les autorisations de débogage USB* puis recommencer. |
| `offline` | Redémarrer adb (commandes ci-dessous), changer de port USB. |
| Aucun appareil listé | Câble « charge seulement » → utiliser un câble données ; mode USB « Transfert de fichiers » ; installer le pilote USB du fabricant (Windows : *Google USB Driver* via SDK Manager, ou pilote Samsung/Xiaomi…). |
| Installation refusée | Désinstaller une ancienne version de GymFlow, vérifier l'espace libre. |

```bash
adb kill-server
```

```bash
adb start-server
```

## 6. Comptes de démonstration
Un panneau « Comptes de démo » sur l'écran de connexion remplit le formulaire d'un toucher (widget `DemoAccountsPanel` dans `lib/screens/auth/auth_screens.dart`, à retirer pour la production).

| Rôle | E-mail | Mot de passe | Particularité |
|---|---|---|---|
| Super Admin | admin@gymflow.tn | Admin2026! | Propriétaire |
| Coach (yoga, pilates) | amira@gymflow.tn | Coach2026! | |
| Coach (force) | mehdi@gymflow.tn | Coach2026! | |
| Coach (cardio, boxe) | sarra@gymflow.tn | Coach2026! | |
| Abonnée | nour@gymflow.tn | Membre2026! | **Aucune séance** : idéale pour la démo du lecteur |
| Abonné | ahmed@gymflow.tn | Membre2026! | Historique riche, série de 3 jours, programme PPL |
| Abonnés | leila@, omar@, ines@, rami@, salma@gymflow.tn | Membre2026! | Profils variés |
| Abonné | hedi@gymflow.tn | Membre2026! | **Abonnement expiré** (réservation refusée) |
| Désactivé | walid@gymflow.tn | Membre2026! | **Connexion refusée** |

Créations de démo : *Circuit gainage express* d'Ines (publié), *Bras d'acier* de Rami (en attente : à valider avec un compte coach), *Cardio rapide* de Leila (refusé, avec motif), *Mon push maison* et l'exercice *Pompes diamant* d'Ahmed (privés).

Confidentialité dans la démo : **Ahmed**, **Rami** et **Ines** sont visibles avec des réseaux (identifiants fictifs `gymflow.demo.*`, e-mails en `example.com`) ; **Leila** est visible sans réseaux ; tous les autres sont privés. Chaque abonné ne partage qu'une partie de ses séances. À la première connexion, chaque compte passe par la présentation (bouton *Passer* puis *C'est parti*).

Parcours de démo conseillé : se connecter avec **Nour** → présentation → *Entraînement → Workouts → Full Body A* → **Lancer la séance** → valider des séries (minuteur de repos) → *Terminer* → récapitulatif → *Partager* (ou *Garder privée*) → la séance apparaît dans le fil, le profil et la progression. Puis *Membres de la salle* depuis l'accueil, et *Masquer les autres* sur le fil. Ensuite : réserver *Spinning Sunrise* (complet → liste d'attente), acheter en boutique.

Réinitialiser les données : désinstaller l'application (ou *Paramètres Android → Applications → GymFlow → Stockage → Effacer les données*).

## 7. Architecture
```
lib/
  main.dart, app.dart          # main() → runApp(), MaterialApp, routes
  core/      theme (palette, onColor), contrast (WCAG), routes (garde de rôle),
             config, validators, security (PBKDF2), formatters, errors,
             legal (CGU, politique, versions), responsive (téléphone / ordinateur)
  models/    user, exercise, workout (workout + programme), session_log,
             course (cours + réservation), shop, misc (notification, audit, annonce)
  repositories/ data_store (interface + mémoire), sqlite_data_store, repository<T>
  services/  backend (point d'accès), auth, user, exercise, workout, training_log,
             progress, course, reservation, notification, product, cart, order,
             payment/ (Stripe test + simulé), wger_api, media_storage, dashboard,
             announcement, audit, privacy (consentements, export, suppression),
             community (annuaire, signalement, modération), platform/ (notifications, agenda, stockage sécurisé),
             seed/ (jeu de démonstration)
  screens/   auth (dont intro_tour), shell (navigation par rôle : barre du bas ou
             latérale + Drawer), home, coach, training, courses, shop, profile,
             admin, community (annuaire, profil public), privacy (réglages, textes
             légaux), misc
  widgets/   cartes, animations, graphiques, médias (YouTube, vidéo), sélecteurs…
test/        règles métier, droits, sécurité, contraste, SQLite, widgets, parcours
integration_test/  parcours complet sur téléphone
```
Notions du cours utilisées : `main/runApp/MaterialApp`, `Scaffold/AppBar/Card…`, `ListView.builder`, `GridView.count/builder`, `TextField` (`onChanged/onSubmitted`), `Form` + `GlobalKey<FormState>` + `TextFormField` avec `validator`, `StatefulWidget/setState`, `GestureDetector`, `Navigator.push/pushReplacement/pop`, routes nommées avec `arguments`, `Drawer`, `BottomNavigationBar`, `TabBar`.

## 8. Qualité
```bash
flutter analyze
```

```bash
flutter test
```

Test d'intégration sur le téléphone branché :

```bash
flutter test integration_test/app_test.dart -d <id_appareil>
```
