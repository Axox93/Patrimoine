# Rapport de progression

Date de démarrage : 15 novembre 2026. Version : 0.1.0, fondations natives iPhone.

## Code écrit

Projet Xcode, package local de calculs Decimal, navigation, composants SwiftUI, portefeuilles, actions/ETF, journal manuel, valorisations manuelles datées, allocation par compte, revenus encaissés, persistance SwiftData versionnée, archivage/corbeille, protection locale, verrouillage et workflow IPA.

Le répertoire initial était vide. Le dépôt public `Axox93/Patrimoine` a été créé à la demande du propriétaire. Aucune donnée patrimoniale personnelle n’a été publiée.

## Vérifications

La validation de syntaxe Node du générateur, la génération du projet et le contrôle Git des espaces ont été exécutés sous Windows. Swift et Xcode ne sont pas disponibles localement. Les vérifications Swift sont déléguées au workflow macOS ; consulter les exécutions du dépôt pour leur résultat réel.

Tests préparés : achats fractionnés, coût moyen, vente partielle/totale, frais, réinvestissement par dividende puis achat, fractionnement, apport distinct du gain, cours manquant, erreurs de devise/doublon/ordre/montant, persistance après réouverture, corbeille/restauration, transaction refusée non persistée, cours le plus récent et données illisibles.

Le résultat exact de la première compilation et les liens d’artefacts seront ajoutés après son achèvement. Aucune validation sur iPhone physique, du mode signé, de VoiceOver ou du rendu visuel n’est présumée.

## Limitations

EUR uniquement ; valorisations et instruments déclarés manuellement. Pas d’API de marché, import CSV/Excel/PDF, connecteur courtier/banque, export/restauration, TWR/XIRR, fiscalité, simulation ou module spécialisé immobilier/obligataire. La sauvegarde chiffrée doit être réalisée avant de faire de l’application un registre principal.

## Suite prioritaire

1. Obtenir un workflow vert et contrôler l’IPA non signé.
2. Installer avec une signature Apple compatible et valider les écrans, la persistance et la confidentialité sur iPhone.
3. Ajouter une sauvegarde chiffrée avec tests de restauration.
4. Ajouter l’import CSV générique avec prévisualisation et rapprochement.
5. Valider puis intégrer les données de marché et le change historique.
6. Étendre progressivement les connecteurs et analyses, sans fonction factice.
