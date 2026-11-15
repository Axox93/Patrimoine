# Portée des vérifications

Le workflow exécute 19 tests XCTest : 11 tests du package financier sur macOS, 6 tests de persistance sur simulateur iPhone et 2 parcours d’interface sur simulateur iPhone. Les fixtures sont fictives. Les tests d’interface utilisent uniquement un magasin en mémoire via un argument interprété en configuration DEBUG ; la version Release ignore cet argument.

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

Deux captures natives sont attachées aux tests puis exportées dans l’artefact de diagnostics. Le contrôle visuel porte sur ces deux écrans, pas sur l’intégralité des écrans et réglages possibles.

Le script de paquet vérifie la présence de l’exécutable Mach-O, la plateforme appareil iPhoneOS, la famille iPhone, les métadonnées et le mode de signature. La somme SHA-256 publiée doit correspondre au fichier téléchargé. Ces contrôles ne constituent pas une installation sur iPhone.

## Vérifications restant à faire

- Installation et relancement sur un iPhone physique avec profil de signature compatible.
- Face ID/code, annulation d’authentification, retour d’arrière-plan et protection des fichiers sur appareil.
- Parcours d’interface complet achat/vente, grands caractères, VoiceOver et préférences d’accessibilité.
- Sauvegarde et restauration exportables : fonctionnalité non implémentée à cette version.
- Migrations depuis une ancienne version réellement utilisée : aucun schéma antérieur livré pour le moment.
- Réseau, devises, connecteurs et imports : fonctionnalités non implémentées, donc aucun test d’API réussi revendiqué.
- Signature Apple configurée : chemin disponible dans les scripts, non testé sans certificat et profil fournis.

Le contraste des boutons principaux corrigés est calculé à partir des couleurs sRGB déclarées : 8,26:1 en clair, 11,31:1 en sombre au repos. Le calcul utilise la luminance relative et le rapport décrits dans la [documentation du W3C](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html). Cela ne certifie pas à lui seul l’accessibilité complète de l’application.
