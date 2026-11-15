# Portée des vérifications

La suite de la version 0.2 comporte **52 tests XCTest** : 29 tests du package sur macOS (11 financiers, 4 de chiffrement et 14 CSV), 19 tests sur simulateur iPhone (6 de persistance, 9 d’import et 4 de lecture de documents), puis 4 parcours d’interface. Les fixtures sont fictives. Les tests d’interface utilisent uniquement un magasin en mémoire et, pour le parcours d’import, un CSV fictif fourni par le lanceur XCTest. Ces mécanismes sont compilés uniquement en DEBUG ; la version Release les ignore.

| Groupe | Vérifications automatisées |
| --- | --- |
| Coût d’acquisition | Moyenne pondérée, frais d’achat capitalisés, coût restant après vente partielle |
| Ventes | Fraction de titre, vente totale, frais et gain réalisé, absence de résidu de coût |
| Revenus | Dividende net de retenues, réinvestissement représenté par un revenu puis un achat |
| Opérations sur titres | Fractionnement simple conservant la base de coût |
| Valorisation | Cours absent empêchant le total, cours déclaré le plus récent sélectionné |
| Contributions | Versement distinct du gain d’investissement |
| Rejets | Vente excessive, liquidités insuffisantes, montant négatif/NaN, doublon d’identifiant, ordre comptable ambigu, devise incompatible |
| Saisie | Décimales françaises et anglaises, rejet des formats ambigus ou partiellement numériques |
| Persistance | Création, modification, archivage, corbeille et restauration ; réouverture d’un magasin sur disque et relecture d’une opération |
| Intégrité | Achat rejeté non persisté, donnée monétaire illisible non remplacée par zéro, dividende d’ETF capitalisant refusé |
| Interface claire | Création d’un PEA fictif et enregistrement d’un versement de 1 000 EUR |
| Interface sombre | État vide et sélection des cinq onglets |
| CSV | UTF-8/BOM, fins de ligne CRLF, guillemets échappés, champs multilignes, séparateurs virgule/point-virgule/tabulation, colonnes répétées ou sans nom |
| Conventions CSV | Montant brut/net, frais, séparateur décimal explicite, date/heure séparées, montants et quantités signés, statuts en attente, opérations inconnues |
| Frais de change | Reconnaissance de « Currency conversion fee » comme frais, sans sélectionner la colonne de sa devise ; aucun change automatique |
| Imports des courtiers | Scénarios fictifs Trading 212, Trade Republic et DEGIRO, association explicite des libellés et contrôle de devise de cotation |
| Rapprochement | Import répété, historiques partiellement recouvrants, identifiant en conflit, correspondance sans identifiant avec réinclusion explicite, identifiants distincts préservés |
| Écriture atomique | Historique incomplet rejeté sans insertion partielle, achats/dividendes/vente partielle avec reconstruction des positions et des gains |
| Volumes | Lot de 1 000 identifiants distincts importé puis rapproché sans doublon |
| Destination | Courtier incompatible avec l’établissement connu du portefeuille rejeté |
| Lecture locale | Fichier CSV lu depuis le disque, UTF-16 avec BOM, limite de taille |
| PDF | Extraction du texte d’un PDF fictif généré nativement ; refus de PDF vide et invalide |
| Interface import | Accès à l’importateur, choix du compte, confirmation du brut et du fuseau, vérification, enregistrement effectif de deux mouvements fictifs puis réimportation avec doublons exclus et confirmation désactivée |
| Chiffrement | Aller-retour du conteneur AES-GCM, clé de récupération, mauvaise clé, altération/troncature et renouvellement du nonce ; aucune sauvegarde complète des modèles n’est revendiquée |

Cinq captures natives sont attachées aux tests : accueil sombre, PEA clair fictif, accès à l’import, confirmation d’import et exclusion des doublons. Le contrôle visuel porte sur ces écrans, pas sur l’intégralité des écrans et réglages possibles.

Le script de paquet vérifie la présence de l’exécutable Mach-O, la plateforme appareil iPhoneOS, la famille iPhone, les métadonnées et le mode de signature. La somme SHA-256 publiée doit correspondre au fichier téléchargé. Ces contrôles ne constituent pas une installation sur iPhone.

## Vérifications restant à faire

- Installation et relancement sur un iPhone physique avec profil de signature compatible.
- Face ID/code, annulation d’authentification, retour d’arrière-plan et protection des fichiers sur appareil.
- Parcours d’interface achat/vente et choix d’instrument pour un export personnel réel ; grands caractères, VoiceOver et préférences d’accessibilité.
- Variantes réelles des CSV/PDF des trois établissements : les tests de format sont synthétiques, aucune compatibilité exhaustive d’un export propriétaire n’est affirmée.
- Sauvegarde et restauration exportables : fonctionnalité non implémentée à cette version.
- Migrations depuis une ancienne version réellement utilisée : aucun schéma antérieur livré pour le moment.
- Réseau, conversion de devises et connecteurs : fonctionnalités non implémentées, donc aucun test d’API réussi revendiqué.
- Signature Apple configurée : chemin disponible dans les scripts, non testé sans certificat et profil fournis.

Le contraste des boutons principaux corrigés est calculé à partir des couleurs sRGB déclarées : 8,26:1 en clair, 11,31:1 en sombre au repos. Le calcul utilise la luminance relative et le rapport décrits dans la [documentation du W3C](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html). Cela ne certifie pas à lui seul l’accessibilité complète de l’application.
