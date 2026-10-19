# RAPPORT ACADÉMIQUE : MODULE ENTRAÎNEMENT (EXERCISE & WORKOUT)

**Projet :** GymFlow — Application mobile Flutter de salle de sport  
**Branche :** `GymFlow-V1`  
**Périmètre :** Partie Entraînement UNIQUEMENT (`Exercise`, `Workout`, `Session Player`) — *La partie « Cours » (courses) n'a subi aucune modification*.

---

## 1. Périmètre & Respect Strict des Contraintes

* **Ciblage exclusif :** Seules les briques relatives aux exercices (`Exercise`), aux workouts (`Workout`) et à l'exécution de séance (`SessionPlayer`) ont été enrichies.
* **Aucun impact sur les Cours :** Le module des cours collectifs (`lib/screens/courses/`, `lib/models/course.dart`, `lib/services/course_service.dart`) est resté **100% intact**.
* **Base de données SQLite & Auth :** Aucune modification de structure de base de données. Tous les ajouts dans `SessionLog` sont des champs optionnels rétro-compatibles.

---

## 2. Justification des 2 API Externes (Exercise & Workout)

### API 1 : Wger Exercise Manager REST API (`https://wger.de/api/v2/`)
* **Usage dans Exercise & Workout :**
  * Fourniture d'un catalogue mondial d'exercices avec schémas anatomiques des muscles primaires et secondaires, types d'équipements requis et vidéos techniques libres (licence CC-BY-SA).
  * Intégration dans le moteur d'importation et de recherche bilingue (FR / EN).
  * Architecture **Cache local SQLite + Offline-First** (`lib/services/wger_api.dart`) : stockage local dans la table `wger_cache` pour consultation hors-ligne sans latence.

### API 2 : Open-Meteo Weather REST API (`https://api.open-meteo.com/v1/forecast`)
* **Usage dans Exercise & Workout :**
  * Récupération des conditions météorologiques réelles au Club GymFlow (Lac 2, Tunis : 36.8347° N, 10.2407° E) : température ambiante, température ressentie, humidité relative.
  * **Justification biomécanique & métabolique :** En ambiance chaude et humide, le phénomène physiologique de **dérive cardio-vasculaire** (*cardiac drift*) et la thermorégulation augmentent la fréquence cardiaque et la dépense énergétique pour un même effort. L'API injecte un **facteur de stress thermique** ($\gamma \in [1.00, 1.15]$) dans l'algorithme de calcul des calories du workout.
  * API 100% ouverte, sans clé API requise, avec cache de 30 minutes et repli nominal d'intérieur (22°C, 45% HR).

---

## 3. Justification des 2 Métiers Avancés (Exercise & Workout)

### Métier Avancé 1 : Moteur Physiologique de Calcul de Dépense Calorique (Keytel & METs)
* **Localisation :** [`lib/services/calorie_service.dart`](file:///c:/Users/hp/Desktop/Projet%20mobile/ProjetDevMobile-5SAE6-GymFlow/lib/services/calorie_service.dart) & [`lib/services/smartwatch_service.dart`](file:///c:/Users/hp/Desktop/Projet%20mobile/ProjetDevMobile-5SAE6-GymFlow/lib/services/smartwatch_service.dart).
* **Complexité algorithmique & physiologique :**
  * Au lieu d'une estimation forfaitaire imprécise, le moteur calcule la dépense énergétique ($EE$ en kcal/min) seconde par seconde via les équations de **Keytel et al. (Journal of Sports Sciences, 2005)** :
    $$\text{Homme : } EE = \frac{-55{,}0969 + (0{,}6309 \times FC) + (0{,}1988 \times \text{Poids}) + (0{,}2017 \times \text{Âge})}{4{,}184}$$
    $$\text{Femme : } EE = \frac{-20{,}4022 + (0{,}4472 \times FC) - (0{,}1263 \times \text{Poids}) + (0{,}0740 \times \text{Âge})}{4{,}184}$$
  * Intégration des **Équivalents Métaboliques (METs)** du *Compendium of Physical Activities* selon le type d'exercice (Cardio : 8.5 METs, Force : 5.5 METs, Mobilité : 2.8 METs).
  * Segmentation en temps réel des **zones cardiaques selon Tanaka** ($FC_{\max} = 208 - 0{,}7 \times \text{Âge}$) : Échauffement, Brûlage de graisses, Aérobie, Anaérobie, Effort Maximal.
  * Télémétrie Bluetooth Low Energy (profil GATT Heart Rate `0x180D`, podomètre, BPM) réagissant dynamiquement aux séries et aux temps de repos.

### Métier Avancé 2 : Moteur de Recommandation & Générateur Intelligent de Workout (ACSM & Surcharge Progressive)
* **Localisation :** [`lib/services/workout_generator_service.dart`](file:///c:/Users/hp/Desktop/Projet%20mobile/ProjetDevMobile-5SAE6-GymFlow/lib/services/workout_generator_service.dart) & [`lib/screens/training/workout_generator_dialog.dart`](file:///c:/Users/hp/Desktop/Projet%20mobile/ProjetDevMobile-5SAE6-GymFlow/lib/screens/training/workout_generator_dialog.dart).
* **Complexité algorithmique & sportive :**
  * Algorithme d'optimisation générant automatiquement une séance d'entraînement complète et individualisée d'après les standards de l'**ACSM** (*American College of Sports Medicine*) et de la **NSCA** :
    1. **Équilibrage agoniste / antagoniste** selon le ciblage musculaire (*Full Body*, *Haut du corps*, *Bas du corps*, *Cardio & Abdos*), éliminant les redondances articulaires.
    2. **Périodisation du volume et de l'intensité** :
       * Hypertrophie / Prise de masse : 3–4 séries de 10 reps, repos 90 s, tempo contrôlé (3-0-1).
       * Perte de poids / Définition : 3 séries de 15 reps, repos court 45 s.
       * Force / Puissance : repos long 120–180 s (Schoenfeld et al., 2016).
    3. **Calcul individualisé des charges suggérées** : pondération automatique des charges de départ (haltères et barres) calculées selon le poids corporel de l'utilisateur (`user.weightKg`) et son niveau (`Level.beginner`, `Level.intermediate`, `Level.advanced`).
    4. **Prévisionnel énergétique** : calcul de la durée estimée et des kilocalories prévisionnelles avant même le démarrage de la séance.
    5. **Intégration en 1 clic** : possibilité d'enregistrer le workout dans ses créations ou de lancer immédiatement la séance dans le lecteur interactif.

---

## 4. Synthèse des Éléments Développés

1. **Services & Métier :**
   * [`lib/services/smartwatch_service.dart`](file:///c:/Users/hp/Desktop/Projet%20mobile/ProjetDevMobile-5SAE6-GymFlow/lib/services/smartwatch_service.dart) : Simulation Bluetooth Low Energy (GATT `0x180D`, `0x2A37`), streaming réactif de la FC, des pas et des calories.
   * [`lib/services/calorie_service.dart`](file:///c:/Users/hp/Desktop/Projet%20mobile/ProjetDevMobile-5SAE6-GymFlow/lib/services/calorie_service.dart) : Formules physiologiques Keytel, METs, zones Tanaka.
   * [`lib/services/weather_service.dart`](file:///c:/Users/hp/Desktop/Projet%20mobile/ProjetDevMobile-5SAE6-GymFlow/lib/services/weather_service.dart) : Consommation de l'API REST Open-Meteo avec cache et stress thermique.
   * [`lib/services/workout_generator_service.dart`](file:///c:/Users/hp/Desktop/Projet%20mobile/ProjetDevMobile-5SAE6-GymFlow/lib/services/workout_generator_service.dart) : Générateur algorithmique ACSM/NSCA de workouts.
2. **Écrans & Composants UI :**
   * [`lib/screens/training/smartwatch_dialog.dart`](file:///c:/Users/hp/Desktop/Projet%20mobile/ProjetDevMobile-5SAE6-GymFlow/lib/screens/training/smartwatch_dialog.dart) : Modal Bluetooth pour scanner, appairer et superviser la montre.
   * [`lib/screens/training/workout_generator_dialog.dart`](file:///c:/Users/hp/Desktop/Projet%20mobile/ProjetDevMobile-5SAE6-GymFlow/lib/screens/training/workout_generator_dialog.dart) : Modal d'assistance intelligente de génération de séance.
   * [`lib/screens/training/training_screen.dart`](file:///c:/Users/hp/Desktop/Projet%20mobile/ProjetDevMobile-5SAE6-GymFlow/lib/screens/training/training_screen.dart) : Boutons d'accès rapide Smartwatch et Assistant dans l'AppBar.
   * [`lib/screens/training/player_screens.dart`](file:///c:/Users/hp/Desktop/Projet%20mobile/ProjetDevMobile-5SAE6-GymFlow/lib/screens/training/player_screens.dart) :
     * Télémétrie en temps réel dans le lecteur de séance (cœur pulsant, BPM, zones d'effort, calories, pas).
     * Enregistrement automatique des statistiques de montre dans `SessionLog`.
     * Affichage dans le récapitulatif (`SessionSummaryScreen`) et le détail (`SessionDetailScreen`).
   * [`lib/screens/training/workout_screens.dart`](file:///c:/Users/hp/Desktop/Projet%20mobile/ProjetDevMobile-5SAE6-GymFlow/lib/screens/training/workout_screens.dart) : Affichage des calories estimées sur chaque fiche de workout.
3. **Tests de Validation :**
   * [`test/smartwatch_training_test.dart`](file:///c:/Users/hp/Desktop/Projet%20mobile/ProjetDevMobile-5SAE6-GymFlow/test/smartwatch_training_test.dart) : Couverture complète des calculs Keytel, du générateur de workout, du service météo et de la sérialisation des logs.
