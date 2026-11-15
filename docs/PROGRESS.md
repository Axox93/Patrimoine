# Rapport de progression

Date de démarrage : 15 novembre 2026. Version : 0.1.0, fondations natives iPhone.

## Code écrit

Projet Xcode, package local de calculs Decimal, navigation, composants SwiftUI, portefeuilles, actions/ETF, journal manuel, valorisations manuelles datées, allocation par compte, revenus encaissés, persistance SwiftData versionnée, archivage/corbeille, protection locale, verrouillage et workflow IPA.

Le répertoire initial était vide. Le dépôt public `Axox93/Patrimoine` a été créé à la demande du propriétaire. Aucune donnée patrimoniale personnelle n’a été publiée.

## Vérifications

La validation de syntaxe Node du générateur, la syntaxe Bash du script d’empaquetage, la génération du projet et le contrôle Git des espaces ont été exécutés sous Windows. Swift et Xcode ne sont pas disponibles localement. La compilation et les tests Swift ont réellement été exécutés sur le runner macOS GitHub avec Xcode 16.4.

**19 tests réussis, zéro échec** : 11 tests du moteur financier, 6 tests SwiftData et 2 parcours d’interface sur simulateur iPhone 16 Pro. Le moteur couvre achats fractionnés, coût moyen, vente partielle/totale, frais, réinvestissement par dividende puis achat, fractionnement, apport distinct du gain, cours manquant et erreurs de devise/doublon/ordre/montant. La persistance couvre notamment la réouverture d’un magasin sur disque et la restauration depuis la corbeille. Les parcours d’interface couvrent la création d’un PEA fictif avec versement et la sélection des cinq onglets.

Deux captures natives ont été inspectées : accueil sombre vide et PEA clair contenant un versement fictif. Un contraste insuffisant du bouton sombre a été corrigé puis revérifié. Le premier lancement a été rendu dépendant de l’activation de la scène, puis le parcours a été exécuté avec succès. Le [détail des tests et de leurs limites](TESTS.md) distingue ces contrôles d’une validation complète de l’application.

## Compilation GitHub vérifiée

| Élément | Résultat |
| --- | --- |
| Workflow | `.github/workflows/build-ios.yml` — Build iOS |
| Exécution | [Build 5 réussi](https://github.com/Axox93/Patrimoine/actions/runs/43751555994) |
| Commit du code compilé | `b16a2070c9a4fce28182a7491779ef4ca457ca2f` |
| Version / build | 0.1.0 / 5 |
| Date de compilation | 15 novembre 2026 à 20:25:53, Europe/Paris (19:25:53 UTC) |
| Archive iOS | Réussie pour appareil générique |
| Artefact | `Patrimoine-iOS-5-unsigned`, téléchargé et contrôlé |
| Fichier | `Patrimoine-iOS.ipa` |
| Signature | **Non signé**, une signature Apple valide est requise avant installation |
| Compatibilité | iPhone, iOS 17.0 minimum |
| SHA-256 | `66d73aeca487196130568a03953819d34bb9b58527dd6c96e2feee01eb40c03b` |

L’intégrité SHA-256 de l’IPA téléchargé correspond au fichier de contrôle publié. Le workflow a contrôlé le binaire appareil, le contenu du paquet et le mode unsigned avant publication. Les modifications documentaires postérieures ne changent pas le code contenu dans ce build.

Aucune installation sur iPhone physique, signature Apple configurée, validation Face ID sur appareil ou revue VoiceOver complète n’est revendiquée.

## Limitations

EUR uniquement ; valorisations et instruments déclarés manuellement. Pas d’API de marché, import CSV/Excel/PDF, connecteur courtier/banque, export/restauration, TWR/XIRR, fiscalité, simulation ou module spécialisé immobilier/obligataire. La sauvegarde chiffrée doit être réalisée avant de faire de l’application un registre principal.

## Suite prioritaire

1. Installer avec une signature Apple compatible et valider les écrans, la persistance et la confidentialité sur iPhone.
2. Ajouter une sauvegarde chiffrée avec tests de restauration.
3. Ajouter l’import CSV générique avec prévisualisation et rapprochement.
4. Valider puis intégrer les données de marché et le change historique.
5. Étendre progressivement les connecteurs et analyses, sans fonction factice.
