# PROGRESS — avancement par module

Cycle suivi pour chaque module : produit → UI/UX → développement → QA (format, analyze, tests, build) → relecture (sécurité, droits, contraste) → corrections.

## Socle
- [x] Projet Flutter Android, dépendances, configuration Android (minSdk 24, desugaring, permissions, icônes, splash natif)
- [x] Thème (palette imposée, Poppins/Inter embarquées), `onColor`, tests de contraste
- [x] Stockage SQLite + mémoire, dépôts, services avec contrôle de rôle
- [x] Sécurité (PBKDF2, session sécurisée, verrouillage, audit)
- [x] Routes nommées centralisées avec garde de rôle, transitions personnalisées

## 7. Données de démonstration
- [x] 1 super admin, 3 coachs (2 femmes, 1 homme), 8 abonnés variés, 1 compte désactivé
- [x] 58 exercices réels (images wger, 58 vidéos YouTube vérifiées, 3 MP4 wger)
- [x] 11 workouts, 6 programmes calibrés ACSM/NSCA
- [x] 20 cours (6 terminés avec présences et notes, 11 programmés dont 1 complet avec liste d'attente possible, 3 à planifier)
- [x] 16 produits, 6 commandes, 3 annonces
- [x] Historiques de séances (8 semaines), pesées, records ; la 1re abonnée (Nour) n'a aucune séance

## 6.1 Utilisateurs & espace personnel
- [x] Splash animé, onboarding 3 pages, connexion, inscription (essai 7 j), mot de passe oublié (simulé)
- [x] Profil + édition (photo `image_picker`), abonnement (jours restants), historique, cours suivis, achats
- [x] Progression : IMC, courbe de poids, volume hebdo, records, série, anneau d'objectif, badges
- [x] Paramètres (changement de mot de passe, notifications, déconnexion)

## 6.2 Exercices, workouts, programmes
- [x] CRUD exercices (images upload/URL, vidéo upload, lien YouTube), recherche, filtres animés, favoris
- [x] Import wger (API réelle, cache SQLite, repli hors-ligne)
- [x] CRUD workouts (séries/reps ou durée, repos, tempo, charge, notes, réordonnancement) et programmes (semaine type)
- [x] Lecteur de séance : vidéo, séries à cocher, charge/reps, minuteur de repos animé + vibration, pause, abandon, progression
- [x] Récapitulatif (durée, volume, séries, records, confettis) → historique, progression, fil

## 6.3 Cours & événements
- [x] Statuts À planifier / Programmé / Terminé automatiques, onglets + filtres coach/jour/catégorie
- [x] Création coach (ses cours) et admin (affectation), modification/annulation avec notification
- [x] Réservation : complet, abonnement expiré, chevauchement, liste d'attente + promotion, annulation 2 h
- [x] Présence (coach), notation étoiles, rappels 24 h/1 h, agenda, centre de notifications + pastille
- [x] Bannière auto-défilante de l'accueil (nouveaux cours, promos, annonces)

## 6.4 Boutique
- [x] Grille, catégories, recherche, détail, panier, achat direct
- [x] Paiement Stripe test (WebView) ou simulé ; stock vérifié et revérifié ; commandes + reçu
- [x] Gestion admin : CRUD produits (upload image), stock, promos, commandes, CA

## 6.5 Dashboards
- [x] Super admin : compteurs animés, inscriptions/semaine, remplissage, CA/semaine, top cours/produits, gestion utilisateurs (activer, rôle, abonnement, créer coach, supprimer), audit
- [x] Coach : prochains cours, inscrits, présence, notes, contenus, fil
- [x] Abonné : accueil Strava (salutation, bannière, anneau, série, prochain cours, programme, fil + Bravo, cours conseillés, produits)

## 6.6 Modules enrichis
- [x] Favoris, séries/objectifs, badges, records, calculateur IMC/calories, avis, annonces, recherche globale, règlement/à propos
- [x] Écartés et justifiés dans DECISIONS.md : QR check-in, planificateur personnel séparé, mode hors-ligne « complet »

## QA
- [x] `flutter analyze` : 0 problème
- [x] `flutter test` : 135 tests verts (unitaires, SQLite réel, widgets, parcours complet, confidentialité, version ordinateur, bibliothèque)
- [x] `flutter build apk --debug` : OK
- [x] Revue visuelle écran par écran (prévisualisation 375 × 812) et corrections
- [x] Essai sur téléphone réel (vivo V2332, Android 16) : APK release installé
- [x] Revue visuelle de la version ordinateur (1440 × 900 et 1366 × 768)

## V1 : communauté, partage et confidentialité (branche `GymFlow-V1`)
- [x] Branche `GymFlow-V1` avec tout l'historique ; `main` vidée
- [x] Réglages de confidentialité, tous désactivés par défaut, et historique des consentements
- [x] Partage de séance avec accord (récapitulatif + détail), retrait possible
- [x] Accueil : masquer l'activité des autres ; carte « Membres de la salle »
- [x] Annuaire des membres visibles, profil public, réseaux sociaux (opt-in), signalement
- [x] Modération par l'admin (masquer de la communauté)
- [x] Présentation verticale au premier lancement + choix + CGU
- [x] Inscription : âge (18 ans et plus) et acceptation des CGU obligatoires
- [x] Workouts personnels des abonnés
- [x] Export des données, suppression du compte avec anonymisation des commandes
- [x] Version ordinateur (navigation latérale, colonnes, largeur lisible)
- [x] `SECURITE_CONFIDENTIALITE.md` : cadre légal, mesures, limites, audit à venir
- [ ] Audit de sécurité complet : après validation de la base de données par le professeur

## V1.1 : bibliothèque collaborative, recherche bilingue, filtres
- [x] Création par les abonnés : exercices (médias), workouts, programmes, privés par défaut
- [x] Proposition → validation ou refus motivé par un coach / l'admin, file « Propositions à valider »
- [x] Copie personnelle de n'importe quel contenu visible
- [x] Recherche bilingue FR ↔ EN (glossaire + noms anglais du contenu + traduction facultative)
- [x] Langue de saisie au début des formulaires ; affichage des noms en FR ou EN
- [x] Filtres en feuille, mémorisés avec le compte : Programmes, Workouts, Exercices, Cours, Boutique, Utilisateurs
- [x] Cours : Quand ?, jours en tuiles datées, moment de la journée, discipline, coach, niveau, places
- [x] Favoris en tête avec animation
- [x] Photo de couverture depuis le téléphone pour workouts et programmes
- [x] CGU : clause sur les créations des membres (version 2026-10-b)
- [ ] Traduction complète de l'interface en anglais (hors périmètre, voir DECISIONS.md)

## V1.2 : analyse de sentiment des avis (Cours & Événements)
- [x] `SentimentService` (via `Backend.I`, `requireUser`) : modèle Hugging Face `tabularisai/multilingual-sentiment-analysis`, délai de 10 s, réponses `[…]` et `[[…]]`
- [x] Jeton `HF_TOKEN` lu dans `secrets.json` comme la clé Stripe ; `secrets.example.json` complété
- [x] Secours local par mots-clés FR/EN (négations, expressions, émojis) : sans jeton, sans réseau, délai dépassé, erreur HTTP, 503, réponse illisible
- [x] Ton enregistré avec l'avis (label, score, source `ia`/`local`), aucun nouvel appel tant que le commentaire ne change pas ; envoi de l'avis jamais bloqué
- [x] Compatibilité des anciennes données sans migration (stockage JSON) ; avis déjà publiés analysés localement à la mise à niveau
- [x] Badges 😊 / 😐 / 😞 : avis de l'abonné juste après l'envoi, avis du cours (coach/admin), dernières notes du coach
- [x] « Score de satisfaction IA » : coach (ses cours) et admin (par cours et par coach) avec histogramme
- [x] Avis « Very Negative » signalés automatiquement (audit + notification des admins)
- [x] Correction : contrôleur du champ de la fenêtre de notation libéré trop tôt
- [x] `flutter analyze` : 0 problème ; `flutter test` : 167 tests verts (137 existants + 30 nouveaux : client HTTP simulé, secours, données, satisfaction, badges, parcours)

## V1.3 : Gemini en fournisseur IA principal
- [x] Constat : Hugging Face renvoie 402 (compte sans crédits), le badge restait « local »
- [x] Modèles listés (`v1beta/models`) et testés ; défaut `gemini-3.7-flash`, remplaçable par `GEMINI_MODEL`
- [x] `GEMINI_API_KEY` / `GEMINI_MODEL` lus dans `secrets.json` comme `HF_TOKEN` ; `secrets.example.json` et README à jour
- [x] Ordre Gemini → Hugging Face → local ; repli sur erreur HTTP, délai de 10 s, 404, 503, JSON invalide ; jamais d'exception
- [x] Requête Gemini : température 0, réponse JSON avec schéma, consigne système, avis traité comme une donnée (anti-injection)
- [x] Fournisseur (`gemini` / `huggingface`) enregistré avec le résultat ; le badge reste « IA »
- [x] Traces de repli en mode debug uniquement, sans aucune clé ; 404 signalé clairement
- [x] Tests : 10 nouveaux (Gemini OK, 429/500 → HF, 429 + 402 → local, 404, JSON invalide, délai, sans clé, fournisseur enregistré) ; `flutter analyze` 0 problème, 177 tests verts

## Correctif : démarrage web en mode debug
- [x] Diagnostic : fil JS bloqué par le hachage PBKDF2 des comptes de démo (antérieur au module sentiment), aucun appel réseau en cause
- [x] Empreinte partagée par mot de passe de démo public (3 calculs au lieu de 13) + PBKDF2 asynchrone qui ne gèle plus la page ; inscriptions inchangées
- [x] `test/startup_test.dart` : init sans aucun appel HTTP (clés IA présentes), mise à niveau des avis locale, connexion des comptes de démo, empreinte asynchrone = synchrone
- [x] `flutter analyze` : 0 problème ; `flutter test` : 182 tests verts

## Correctifs : score de satisfaction et fiabilité de l'IA
- [x] Carte « Score de satisfaction IA » recalculée en direct (écoute du bus de données ; le widget `const` n'était jamais reconstruit), admin et coach, + bouton « Actualiser »
- [x] Tous les cours notés listés (plus de limite à 8 ; le graphique montre les 8 plus commentés)
- [x] Gemini : nouvel essai sur 429 / 503 / délai, puis modèle de secours `GEMINI_FALLBACK_MODEL` (défaut `gemini-flash-latest`), puis Hugging Face, puis local
- [x] Raison du repli enregistrée avec l'avis et affichée dans l'infobulle du badge (release comprise, sans clé)
- [x] Bouton « Réanalyser avec l'IA » (auteur, coach du cours, admin ; contrôlé dans le service)
- [x] Tests : score mis à jour pendant l'affichage (admin et coach), cours anciens et nombreux inclus, nouvel essai puis succès, bascule sur le modèle de secours, raison du repli, droits de la réanalyse ; `flutter analyze` 0 problème, 195 tests verts

## V1.4 : réservation par email (EmailJS) et ticket QR (QR Code Server)
- [x] Code de réservation `GF-XXXX-XXXX` (`Random.secure()`, sans caractère ambigu, unique), attribué aux anciennes réservations au démarrage sans réseau ; invalide si annulée
- [x] `EmailService` (`Backend.I.email`) : EmailJS REST en arrière-plan, délai de 10 s, 1 nouvel essai sur réseau ou 5xx, destinataire de démo, statut enregistré sans clé, renvoi limité à 1/min (dans le service)
- [x] Email à la confirmation et à la promotion depuis la liste d'attente ; aucun pour la liste d'attente ni le jeu de démo
- [x] Écran « Mon ticket » : QR via api.qrserver.com (vérifié sur le web, CanvasKit), code en secours, détails du cours, statut de l'email, « Renvoyer l'email », « ✅ Présence validée », mise en page ordinateur
- [x] Message après la réservation : « 📧 Email de confirmation envoyé à … » ou « Email non envoyé : raison »
- [x] `CheckInService` : validation par code (coach du cours ou admin, fenêtre -30/+30 min, déjà validé, annulée, liste d'attente, audit) ; écran « Valider par code » avec point d'extension pour un futur scanner ; pointage manuel inchangé
- [x] Cours de démo du jour (Amira, +20 min, Ines confirmée), recalé localement sur Android
- [x] Documentation : README, `secrets.example.json`, DECISIONS, SECURITE_CONFIDENTIALITE (sous-traitants EmailJS et QR Code Server)
- [x] Tests : 37 nouveaux (EmailJS simulé, codes, validation, ticket, parcours) ; `flutter analyze` 0 problème ; 232 tests verts

## Correctif : contenu du QR et email
- [x] QR = texte lisible (réservation, cours, date, coach, salle ; sans donnée de l'abonné), 300×300, encodé UTF-8 ; décodage réel vérifié (application et email)
- [x] Validation coach : code seul ou texte complet collé (extraction par regex insensible à la casse)
- [x] Email sans modifier le modèle : `booking_code` = texte du QR encodé pour l'URL ; `qr_data` et `booking_code_text` envoyés pour un futur modèle (voir DECISIONS.md)
- [x] Tests : contenu du QR, extraction du code, paramètres EmailJS et URL finale

## Email : FormSubmit par défaut (sans clé)
- [x] Comparatif réel FormSubmit / Web3Forms / Formspree (CORS, clé, client Android) ; FormSubmit retenu et activé pour http://localhost:8080
- [x] `EmailService` : même interface ; FormSubmit par défaut (configuration commitée `lib/core/email_config.dart`), EmailJS en option si ses clés sont présentes
- [x] Contenu : sujet « ✅ Réservation confirmée – <cours> », abonné, cours, date, coach, salle, code, lien de l'image QR
- [x] Android : en-têtes Origin/Referer de l’origine activée ; web : port fixe 8080 (README, `.vscode/launch.json`), raison claire si l’origine n’est pas activée
- [x] Tests sans aucun vrai réseau (client par défaut simulé) ; tests FormSubmit : contenu, en-têtes, origine non activée, 5xx, réponse illisible, EmailJS en option
