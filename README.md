# GymFlow

Application mobile Flutter de la salle de sport **GymFlow** (super admin, coachs, abonnés), style Strava, en français, devise TND.
Données stockées localement (SQLite) : aucune configuration serveur n'est nécessaire, un jeu de démonstration réaliste est chargé au premier lancement.

- `PROGRESS.md` : avancement par module · `DECISIONS.md` : choix et sources · `ASSETS.md` : origine et licence des médias.

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

Parcours de démo conseillé : se connecter avec **Nour** → *Entraînement → Workouts → Full Body A* → **Lancer la séance** → valider des séries (minuteur de repos) → *Terminer* → récapitulatif → la séance apparaît dans le fil, le profil et la progression. Ensuite : réserver *Spinning Sunrise* (complet → liste d'attente), acheter en boutique.

Réinitialiser les données : désinstaller l'application (ou *Paramètres Android → Applications → GymFlow → Stockage → Effacer les données*).

## 7. Architecture
```
lib/
  main.dart, app.dart          # main() → runApp(), MaterialApp, routes
  core/      theme (palette, onColor), contrast (WCAG), routes (garde de rôle),
             config, validators, security (PBKDF2), formatters, errors
  models/    user, exercise, workout (workout + programme), session_log,
             course (cours + réservation), shop, misc (notification, audit, annonce)
  repositories/ data_store (interface + mémoire), sqlite_data_store, repository<T>
  services/  backend (point d'accès), auth, user, exercise, workout, training_log,
             progress, course, reservation, notification, product, cart, order,
             payment/ (Stripe test + simulé), wger_api, media_storage, dashboard,
             announcement, audit, platform/ (notifications, agenda, stockage sécurisé),
             seed/ (jeu de démonstration)
  screens/   auth, shell (navigation par rôle + Drawer), home, coach, training,
             courses, shop, profile, admin, misc
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
