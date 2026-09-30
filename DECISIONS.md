# DECISIONS — choix techniques et fonctionnels

Toutes les décisions prises sans question après le démarrage, avec leur justification.

## Réponses aux questions de départ
| Sujet | Décision |
|---|---|
| Persistance | **SQLite local** (`sqflite`) derrière une interface `DataStore` ; implémentation `MemoryDataStore` pour les tests et la prévisualisation web. Une implémentation Firebase peut être ajoutée sans toucher services ni écrans. |
| Paiement | **Stripe mode test** si une clé `sk_test_…` est fournie au lancement (`--dart-define-from-file=secrets.json`, fichier ignoré par git) : création d'une *Checkout Session* par l'API REST, page Stripe dans un `WebView`, interception de l'URL de succès puis **revérification** du statut `paid`. Sans clé : passerelle **simulée** (Luhn, date, CVC, cartes de test Stripe `4242…` acceptée, `…0002` refusée, `…9995` fonds insuffisants). Les clés *live* sont refusées. |
| Devise | TND affiché partout. Stripe ne gère pas le TND : conversion en EUR à taux fixe (1 EUR = 3,40 TND) **uniquement** pour la session Stripe de test. |
| Identité | « GymFlow », logo vectoriel généré, français. |
| Vidéos | Liens YouTube réels choisis par recherche puis **vérifiés par oEmbed** ; + vidéos MP4 libres de wger (voir ASSETS.md). |

## Architecture
- `lib/core` (thème, contraste, routes + garde, config, validateurs, sécurité, formats), `models`, `repositories` (interface `DataStore`, SQLite, mémoire, `Repository<T>` générique avec cache), `services` (logique métier = « API internes »), `screens` (par module), `widgets` réutilisables.
- **Stockage document dans SQLite** : une table par collection `(id, data JSON, updated_at)`. Les relations sont résolues par les services. Justification : schéma évolutif sans migrations lourdes, lecture instantanée via cache mémoire, volumétrie d'une salle (quelques milliers de lignes) largement compatible.
- **État partagé** (exception assumée au « setState seulement ») : `ChangeNotifier` minimal + `ListenableBuilder` pour la session (`AuthService`), le panier (`CartService`), les notifications non lues (`NotificationService`) et un bus « données modifiées » (`DataBus`). Pas de Provider/Bloc/Riverpod.
- Services testables : horloge injectable (`Backend.clock`), notifications/agenda/stockage sécurisé derrière des interfaces avec versions de test.
- `Backend` : point d'accès unique ; **chaque méthode de service vérifie la session et le rôle** (`requireUser`, `requireRole`), en plus de la garde des routes nommées (`Routes.onGenerateRoute`).

## Sécurité
- Mots de passe : **PBKDF2-HMAC-SHA256**, 12 000 itérations, sel aléatoire 128 bits par compte, comparaison en temps constant ; vérifié contre le vecteur RFC 7914. `crypto` suffit (pas de `bcrypt` natif).
- Les empreintes sont dans une collection séparée (`credentials`) jamais exposée à l'interface ; le modèle `AppUser` ne contient aucun secret (testé).
- Session : jeton aléatoire 256 bits dans `flutter_secure_storage` ; seule son **empreinte SHA-256** est en base. Un compte désactivé perd sa session (effacée côté serveur) et est refusé au relancement avec un message clair.
- Verrouillage : 5 échecs → 15 min. Messages d'erreur génériques (« e-mail ou mot de passe incorrect »).
- Mot de passe oublié : code à 6 chiffres, haché, valable 15 min, usage unique ; l'envoi d'e-mail est **simulé** (boîte de dialogue « E-mail simulé »). Limite connue : le flux simulé révèle si un e-mail existe (acceptable en démo, à remplacer par un vrai envoi).
- Super admin : aucune API ne renvoie de mot de passe, pas de « se connecter en tant que ». Journal d'audit pour désactivation, suppression, rôle, abonnement, produits, annulation de cours, annonces.
- Uploads : extensions autorisées + taille max (images 10 Mo, vidéos 100 Mo), copie dans le dossier privé de l'app.
- Aucune clé dans le code ; `secrets.json` ignoré par git.

## Règles métier retenues
- **Statuts de cours calculés** : pas de date → *À planifier* ; date future → *Programmé* ; fin passée → *Terminé* (transition automatique, aucune tâche planifiée nécessaire) ; *Annulé* si annulé.
- Réservation refusée si : cours non programmé, abonnement inactif **à la date du cours**, déjà inscrit, **chevauchement** avec une autre réservation active, cours complet (sauf inscription volontaire en **liste d'attente**). Promotion automatique de la liste d'attente (annulation d'un inscrit ou hausse de capacité).
- Annulation libre jusqu'à **2 h** avant (liste d'attente : à tout moment). Présence pointée par le coach du cours/admin à partir de 15 min avant. Notation 1-5 étoiles par un participant confirmé non absent, après le cours.
- Rappels : notifications locales 24 h et 1 h avant, en mode **inexact** (évite la permission `SCHEDULE_EXACT_ALARM`, refusée par défaut sur Android 14) ; + ajout à l'agenda (`add_2_calendar`) ; + centre de notifications in-app.
- Nouvelle inscription : **essai gratuit de 7 jours** (sinon un nouvel abonné ne pourrait rien réserver) ; l'admin attribue ensuite l'abonnement.
- Boutique : stock vérifié à l'ajout au panier, avant paiement et **revérifié** à l'enregistrement de la commande ; décrément à la commande ; produit déjà commandé → archivé (pas supprimé) ; numéros `GF-AAAA-NNNN` ; statuts payée → préparée → remise avec notification au client.
- Records personnels : meilleure charge par exercice (1RM estimé par Epley) ; la première charge enregistrée compte comme record (effet motivant pour la démo).
- Série (streak) : jours consécutifs avec au moins une séance, jusqu'à aujourd'hui (ou hier).

## Programmes : sources scientifiques
Paramètres des workouts (séries, répétitions, repos, tempo) et structure des programmes :
- ACSM Position Stand, *Progression Models in Resistance Training for Healthy Adults*, Med Sci Sports Exerc 2009;41(3):687-708 — hypertrophie 1-3 (débutant) à 3-6 séries de 8-12 reps, repos 1-2 min ; force 1-6 reps, repos 3-5 min sur les exercices lourds ; débutants : corps entier 2-3 ×/semaine.
- NSCA, *Essentials of Strength Training and Conditioning*, 4e éd. (Haff & Triplett, 2016), tableaux des temps de repos : force 2-5 min, hypertrophie 30-90 s, endurance musculaire ≤ 30 s.
- Schoenfeld B. et al., *Longer Interset Rest Periods Enhance Muscle Strength and Hypertrophy in Resistance-Trained Men*, J Strength Cond Res 2016;30(7):1805-1812 — justification des 120 s sur les gros polyarticulaires.
- Garber C.E. et al. (ACSM), *Quantity and Quality of Exercise…*, Med Sci Sports Exerc 2011;43(7):1334-1359 — étirements maintenus 10-30 s (30-60 s chez les plus âgés), 2-4 répétitions → maintiens de 30-45 s.
- Calculateur : métabolisme de base Mifflin-St Jeor (Am J Clin Nutr 1990) × facteur d'activité, ±300/400 kcal selon l'objectif ; catégories d'IMC de l'OMS.

Exemple : *Push Day* = développé couché 4×8 (120 s), incliné haltères 3×10 (90 s), écartés 3×12 (60 s), développé militaire 3×8 (120 s), élévations latérales 3×15 (60 s), poulie triceps 3×12 (60 s), dips 3×10 (90 s).

## Packages
Tous issus de la liste autorisée : `google_fonts` (polices **embarquées** en assets, `allowRuntimeFetching = false` → hors-ligne), `intl`, `sqflite`, `path_provider`, `path`, `shared_preferences` (onboarding vu), `flutter_secure_storage`, `crypto`, `http`, `image_picker`, `file_picker`, `video_player`, `chewie`, `youtube_player_iframe` (bâti sur `webview_flutter`), `webview_flutter` (Stripe Checkout), `cached_network_image`, `shimmer`, `fl_chart`, `flutter_local_notifications`, `timezone`, `add_2_calendar`, `url_launcher`.
Ajouts justifiés : `flutter_localizations` (SDK, dates/boutons Material en français), `sqflite_common_ffi` (dev : tester le vrai dépôt SQLite sur PC), `integration_test` (SDK).
Écartés : `lottie` (célébration réalisée en `CustomPainter`, sans fichier JSON à licence incertaine), `flutter_stripe` (inutile avec Checkout en WebView, et exige un backend pour le PaymentSheet), Firebase (non retenu), `qr_flutter`/scanner (voir modules enrichis).

## Modules enrichis (6.6)
Implémentés : favoris (exercices, workouts, programmes), série + objectif hebdomadaire en anneau, badges/succès (6), records personnels, calculateur IMC & calories, avis sur les cours (étoiles + commentaire), annonces du club (publication admin → notification à tous + bannière), recherche globale, « Règlement & à propos », import d'exercices **wger** avec cache hors-ligne, « Reprendre mon programme », Bravo (kudos) avec notification.
Écartés :
- **QR code d'accès / check-in** : afficher un QR est simple, mais sans scanner côté accueil (paquet de lecture caméra non autorisé) la fonction serait décorative. Écarté plutôt que livré à moitié.
- **Planificateur hebdomadaire personnel** : couvert par la semaine type du programme suivi + les réservations ; un agenda supplémentaire aurait dupliqué ces données.
- **Mode hors-ligne complet** : l'application est locale par conception (SQLite) ; seuls les médias distants et l'import wger nécessitent Internet (images en cache, cache wger, messages d'erreur clairs).

## Autres choix
- Mode clair uniquement ; `values-night/styles.xml` identique au mode clair (aucun écran noir au démarrage).
- Règle de lisibilité : `onColor(fond)` + suite de tests de contraste WCAG (≥ 4,5:1 pour le texte, ≥ 3:1 pour les éléments graphiques) ; voiles sombres (`TopScrim`, dégradés) sous tout texte/icône blanc posé sur une photo ; étoiles dorées cerclées de marine.
- Formulaires dans un `SingleChildScrollView` (et non un `ListView` paresseux) : tous les champs restent montés, donc tous validés et leurs erreurs visibles.
- Animations de cascade sans `Timer` (intervalle d'animation), minuteur de repos piloté par un seul `Timer.periodic` libéré au `dispose`.
- Prévisualisation web (développement uniquement) : même code, données en mémoire (`kIsWeb`). Les images wger ne s'y affichent pas (CORS du serveur wger) mais s'affichent sur Android ; la miniature YouTube sert alors de repli.
- `.claude/`, `build/`, `secrets.json` hors du dépôt.
