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

## Boutique : fiche produit intelligente (API Open Food Facts + IA Gemini)
- [x] Formulaire produit (admin) : champ « Code-barres » et « Remplir depuis Open Food Facts » (nom, image, marque, valeurs pour 100 g, portion, poids net, Nutri-Score, allergènes), erreurs claires, saisie manuelle toujours possible
- [x] « Rédiger avec l'IA » : description en français et nom anglais (recherche bilingue), à relire avant d'enregistrer
- [x] Calculs faits par l'application : protéines par portion, prix du gramme de protéine (TND/g, prix promo pris en compte)
- [x] « Résumé pour le sportif » rédigé par l'IA dans le formulaire, enregistré avec le produit (aucun appel à l'affichage) ; « données insuffisantes » sans appel si les valeurs manquent
- [x] Carte « Nutrition » sur la fiche produit (abonné), source affichée ; nutrition de démonstration sur 3 produits
- [x] Client Gemini commun au chatbot et à la boutique (`gemini_client.dart`), réponses JSON validées
- [x] Tests sans réseau (`test/smart_product_test.dart`) : lecture Open Food Facts, erreurs, calculs, validation du JSON, droits admin, compatibilité des anciens produits, chatbot
