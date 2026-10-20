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
flutter run -d chrome --release --web-port 8080
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

### Analyse de sentiment des avis (IA, facultatif)
Les avis commentés reçoivent un ton (😊 / 😐 / 😞). Fournisseurs, dans cet ordre, chacun facultatif dans `secrets.json` :

| Clé | Rôle |
|---|---|
| `GEMINI_API_KEY` | **Google Gemini**, fournisseur principal (gratuit, clé créée sur Google AI Studio) |
| `GEMINI_MODEL` | Modèle Gemini, facultatif ; par défaut `gemini-3.7-flash` |
| `GEMINI_FALLBACK_MODEL` | Modèle Gemini de secours, facultatif ; par défaut `gemini-flash-latest` |
| `HF_TOKEN` | **Hugging Face** `tabularisai/multilingual-sentiment-analysis`, secours (jeton *fine-grained* limité à « Inference Providers » ; nécessite des crédits, sinon HTTP 402) |

Gemini : sur 429 (quota), 503 (surcharge) ou délai dépassé, un nouvel essai est fait après une courte pause, puis le modèle de secours est essayé. Si aucun fournisseur ne répond, l'analyse se fait **localement** par mots-clés (français et anglais) et le badge indique « local ». Un appui ou un survol sur le badge affiche la raison (ex. « Gemini (gemini-3.7-flash) : quota dépassé (429) »), aussi en `--release` et jamais avec les clés. Le bouton **« Réanalyser avec l'IA »** relance l'analyse (pour l'auteur de l'avis, le coach du cours et l'admin). Démo sur le PC :

```bash
flutter run -d chrome --release --web-port 8080 --dart-define-from-file=secrets.json
```

⚠️ Ne **jamais** compiler la version web publique (`docs/`) avec `secrets.json` : les clés seraient lisibles dans `main.dart.js`.

### Email de confirmation et ticket QR (aucune clé nécessaire)
À chaque place confirmée (réservation directe ou promotion depuis la liste d'attente), un **email de confirmation** est envoyé en arrière-plan via **FormSubmit**. Ce service est gratuit et ne demande **aucune clé** : sa configuration est commitée dans `lib/core/email_config.dart`. L'email fonctionne donc aussi **sans `secrets.json`**, par exemple sur le PC d'un collègue.

- **Destinataire fixe** : tous les emails partent à `zouaoui.farah@esprit.tn`, puisque les comptes `@gymflow.tn` sont fictifs. Le message contient :
  - le sujet « ✅ Réservation confirmée – <cours> » ;
  - l'abonné, le cours, la date en français, le coach, la salle et le code de réservation ;
  - le lien de l'image QR (`api.qrserver.com`, avec le texte lisible du ticket).
- Aucun email n'est envoyé pour une simple inscription en liste d'attente, ni pour les réservations du jeu de démo.
- **Le web doit tourner sur le port 8080** : FormSubmit est activé pour l'origine `http://localhost:8080`. Sur un autre port, ou sur GitHub Pages, le ticket affiche « FormSubmit : origine non activée (…) » au lieu d'envoyer. Pour activer une nouvelle origine, voir DECISIONS.md.

```bash
# Avec secrets.json (IA, Stripe…)
flutter run -d chrome --release --web-port 8080 --dart-define-from-file=secrets.json
# Sans secrets.json (collègue) : l'email fonctionne quand même
flutter run -d chrome --release --web-port 8080
```
Dans VS Code, `.vscode/launch.json` propose ces deux lancements (« GymFlow web (port 8080…) »).

- **Android** : l'application envoie l'en-tête `Referer: http://localhost:8080/`, l'origine activée, puisqu'un client Dart n'en envoie aucun. Rien à configurer.
- **EmailJS, en option** : si `EMAILJS_SERVICE_ID`, `EMAILJS_TEMPLATE_ID` et `EMAILJS_PUBLIC_KEY` sont présentes dans `secrets.json`, EmailJS est utilisé à la place de FormSubmit (avec `EMAILJS_DEMO_RECIPIENT` facultatif). Sur Android, EmailJS exige l'option *Account → Security → « Allow EmailJS API for non-browser applications »*.
- Le **ticket** (« Mon ticket », depuis *Cours → Mes réservations* ou la fiche du cours) affiche le QR généré par `api.qrserver.com`, le statut de l'email et le bouton « Renvoyer l'email ». S'il ne charge pas (hors ligne), le code s'affiche en grand. Le coach valide la présence dans *Inscrits → « Valider par code (ticket QR) »*, en saisissant le code ou en collant le texte du QR.

### Démo de la soutenance : cours du jour
Le jeu de démo contient **« Pilates express (démo) »**, coaché par **Amira**, qui commence **20 min après le lancement de l'application** (arrondi au quart d'heure supérieur) et dure 60 min, avec **Ines** confirmée. La fenêtre de validation par code (de 30 min avant le début à 30 min après la fin) est donc ouverte dès le démarrage, quel que soit le jour.

- **Web** : les données sont recréées à chaque chargement de la page, donc le cours est toujours à la bonne heure.
- **Android** : la base est conservée. À chaque démarrage, si ce cours est passé (autre jour, ou terminé depuis plus de 30 min), il est **replacé aujourd'hui** et ses réservations sont remises à zéro (Ines confirmée, présence non validée). Tout se fait localement, sans réseau.
- Un **cours à venir** est aussi prêt : « Yoga Vinyasa » (Amira), demain à 18h00, avec Ines confirmée.

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
