/// Textes et constantes juridiques affichés dans l'application.
///
/// Rédigés pour un service proposé en SaaS à des salles de sport en Tunisie
/// et à l'étranger : loi organique tunisienne n° 2004-63 du 27 juillet 2004
/// (protection des données à caractère personnel, contrôle de l'INPDP),
/// Convention 108 du Conseil de l'Europe (ratifiée par la Tunisie) et
/// RGPD (UE 2016/679) pour les salles européennes.
/// À faire valider par un juriste avant toute commercialisation.
class Legal {
  Legal._();

  /// Version des CGU et de la politique : tout changement de version
  /// redemande le consentement.
  static const String version = '2026-10-b';

  /// Version du tour de présentation (le revoir après une évolution majeure).
  static const int introVersion = 1;

  /// Âge minimum pour créer un compte soi-même. Les mineurs sont inscrits
  /// à l'accueil avec l'accord d'un représentant légal et ne sont jamais
  /// visibles dans la communauté.
  static const int minimumAge = 18;

  /// Durées de conservation appliquées.
  static const String retention =
      'Compte : durée de l\'abonnement + 3 ans d\'inactivité, puis suppression. '
      'Séances, pesées, réservations : supprimées avec le compte. '
      'Factures et commandes : 10 ans (obligation comptable), anonymisées si le compte est supprimé. '
      'Journal d\'audit de sécurité : 1 an.';

  static const List<(String, String)> privacyPolicy = [
    (
      'Qui traite vos données ?',
      'Votre salle de sport est responsable du traitement de vos données. '
          'L\'éditeur de GymFlow agit comme sous-traitant : il héberge et fait '
          'fonctionner le service pour le compte de la salle, selon ses '
          'instructions écrites, et n\'utilise jamais vos données pour son '
          'propre compte (ni publicité, ni revente).',
    ),
    (
      'Quelles données ?',
      'Compte : nom, e-mail, mot de passe (stocké uniquement sous forme '
          'chiffrée irréversible). Profil facultatif : photo, âge, taille, '
          'poids, objectif, téléphone. Activité : séances, records, '
          'réservations, notes de cours, achats. Réseaux sociaux : uniquement '
          'ceux que vous saisissez vous-même.',
    ),
    (
      'Pourquoi ?',
      'Gérer votre abonnement, vos réservations et vos achats (exécution du '
          'contrat) ; suivre votre progression (votre demande) ; afficher '
          'votre profil et vos séances aux autres membres uniquement si vous '
          'l\'avez activé (votre consentement, retirable à tout moment) ; '
          'sécuriser le service (intérêt légitime).',
    ),
    (
      'Données de santé',
      'Poids, taille et IMC sont des données sensibles : ils restent privés, '
          'ne sont jamais partagés avec les autres membres et ne servent qu\'à '
          'votre suivi. Vous pouvez les laisser vides.',
    ),
    (
      'Qui voit quoi ?',
      'Par défaut, personne d\'autre que la salle ne voit votre profil. Les '
          'coachs voient les inscrits de leurs cours. Les autres membres ne '
          'voient votre profil, vos séances partagées et vos réseaux sociaux '
          'que si vous l\'activez dans « Confidentialité ». Chaque séance n\'est '
          'publiée sur le fil du club qu\'après votre accord explicite.',
    ),
    ('Durée de conservation', retention),
    (
      'Hébergement et transferts',
      'Les données sont hébergées dans le pays choisi par la salle. Tout '
          'transfert hors de ce pays n\'a lieu qu\'avec les garanties exigées '
          'par la loi (autorisation de l\'INPDP en Tunisie, clauses '
          'contractuelles types de la Commission européenne pour l\'UE).',
    ),
    (
      'Vos droits',
      'Accès, rectification, opposition, retrait du consentement, '
          'effacement et portabilité. Dans l\'application : '
          'Paramètres → Confidentialité → « Télécharger mes données » ou '
          '« Supprimer mon compte ». Vous pouvez aussi écrire à votre salle et '
          'saisir l\'INPDP (Tunisie) ou l\'autorité de protection des données '
          'de votre pays.',
    ),
    (
      'Sécurité',
      'Mots de passe hachés et salés (PBKDF2), session chiffrée sur le '
          'téléphone, contrôle des droits sur chaque action, verrouillage après '
          'plusieurs échecs, journal des actions d\'administration. En cas de '
          'violation de données, la salle et les autorités sont prévenues '
          'dans les délais légaux (72 h pour le RGPD).',
    ),
    (
      'Mineurs',
      'L\'inscription en ligne est réservée aux personnes majeures. Les '
          'mineurs sont inscrits à l\'accueil avec l\'accord d\'un représentant '
          'légal et ne sont jamais visibles dans la communauté.',
    ),
    (
      'Permissions du téléphone',
      'Appareil photo et galerie : seulement quand vous ajoutez une photo ou '
          'une vidéo. Notifications : rappels de cours. Agenda : seulement '
          'quand vous ajoutez un cours. Aucune localisation, aucun contact, '
          'aucun micro, aucun pistage publicitaire.',
    ),
  ];

  static const List<(String, String)> terms = [
    (
      'Objet',
      'GymFlow permet aux membres d\'une salle de sport de réserver des cours, '
          'suivre leurs entraînements, acheter en boutique et, s\'ils le '
          'souhaitent, échanger avec les autres membres.',
    ),
    (
      'Compte',
      'Vous êtes responsable de la confidentialité de votre mot de passe. Un '
          'compte est personnel et ne peut pas être prêté.',
    ),
    (
      'Contenus partagés',
      'Vous restez propriétaire de ce que vous publiez (séances, photo, liens) '
          'et vous pouvez le retirer à tout moment. Il est interdit de publier '
          'un contenu illicite, haineux, à caractère sexuel ou portant atteinte '
          'aux droits d\'autrui, et d\'utiliser les informations des autres '
          'membres à des fins commerciales ou de harcèlement. Tout profil peut '
          'être signalé ; la salle peut le masquer ou suspendre le compte.',
    ),
    (
      'Exercices, workouts et programmes créés par les membres',
      'Vos créations restent privées tant que vous ne les proposez pas. En '
          'proposant une création, vous déclarez en être l\'auteur (ou avoir le '
          'droit d\'utiliser ses photos et vidéos) et vous autorisez la salle, '
          'gratuitement et pour la durée du service, à la proposer à ses '
          'membres. Un coach ou l\'administrateur la vérifie avant publication '
          'et peut la refuser, la modifier pour la sécurité des pratiquants ou '
          'la retirer. Une création publiée est signée par votre prénom et '
          'l\'initiale de votre nom ; si vous supprimez votre compte, elle reste '
          'disponible de façon anonyme. Les consignes publiées par des membres '
          'ne remplacent pas l\'avis d\'un coach.',
    ),
    (
      'Santé',
      'Les programmes et vidéos sont fournis à titre informatif et ne '
          'remplacent pas l\'avis d\'un médecin ou d\'un coach. Consultez un '
          'professionnel avant de reprendre une activité physique intense.',
    ),
    (
      'Liens externes',
      'Les vidéos YouTube et les réseaux sociaux des membres ouvrent des '
          'services tiers soumis à leurs propres conditions.',
    ),
    (
      'Responsabilité',
      'L\'éditeur fournit le service à la salle ; la salle reste responsable de '
          'la relation avec ses membres. Le service peut être interrompu pour '
          'maintenance.',
    ),
    (
      'Droit applicable',
      'Droit tunisien pour les salles établies en Tunisie ; pour une salle '
          'établie à l\'étranger, le droit de son pays et, dans l\'Union '
          'européenne, le RGPD.',
    ),
  ];
}
