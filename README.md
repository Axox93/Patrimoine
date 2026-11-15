# Patrimoine

Application personnelle **native iPhone**, SwiftUI et SwiftData, iOS 17 minimum. Pas de backend, abonnement, passage d’ordres ni dépendance tierce dans l’application.

**Version de fondations 0.1.0** : le suivi est manuel et en euros. Les cours automatiques, connexions bancaires, imports, sauvegardes et analyses avancées ne sont pas encore disponibles. Les prix doivent être recopiés depuis une source réelle ; ils sont affichés comme saisies manuelles datées. Aucune donnée de démonstration n’est injectée dans l’application.

## Périmètre écrit

- Navigation à cinq onglets, modes clair et sombre, montants masquables.
- Création et modification de portefeuilles, archivage et corbeille réversible.
- Instruments actions et ETF identifiés par ticker et place, ISIN facultatif déclaré.
- Journal des versements, retraits, achats, ventes, frais, dividendes, intérêts et fractionnements.
- Coût moyen pondéré avec Decimal, ventes fractionnées et distinction des apports et gains.
- Valorisation manuelle datée, cours manquants explicitement signalés, instantanés enregistrés à la demande.
- Persistance locale versionnée ; protection des fichiers, verrouillage Face ID/code et masquage en arrière-plan.
- Moteur financier en package Swift local et tests d’intégration SwiftData.
- Workflow macOS de tests, archive iOS, IPA non signé par défaut ; mode signé configurable.

Le type de compte est un classement, sans moteur fiscal ou actuariel propre aux assurances-vie, PER, obligations ou biens immobiliers.

## Compiler depuis Windows

1. Modifier le code et pousser sur `main`.
2. Ouvrir **Actions → Build iOS** et consulter l’exécution.
3. Après succès, télécharger l’artefact `Patrimoine-iOS-<build>-unsigned` en bas de la page.
4. Extraire `Patrimoine-iOS.ipa`, `build-info.json` et `SHA256SUMS.txt`.

**Un IPA non signé ne s’installe pas directement sur iPhone.** Une signature Apple et un profil compatibles sont nécessaires. Le fichier de métadonnées indique sa signature ; aucune installation sur appareil n’est présumée.

Le workflow exécute d’abord `swift test`, puis les tests SwiftData sur un simulateur iPhone, puis archive et vérifie le paquet. Un échec de test bloque la publication de l’IPA. Les diagnostics d’un échec sont conservés séparément. La branche par défaut doit être `main`.

Pour lancer manuellement : **Actions → Build iOS → Run workflow**, choisir `unsigned` (défaut) ou `signed` (configuration préalable indispensable).

## Développer avec Xcode

Ouvrir `Patrimoine.xcodeproj`, choisir le schéma partagé `Patrimoine` et un simulateur iPhone iOS 17 ou plus récent. Aucun générateur ni gestionnaire de dépendances externe n’est requis. Le package Swift local est résolu automatiquement.

Après ajout ou suppression d’un fichier Swift dans l’application ou les tests d’intégration, exécuter `node scripts/generate-project.mjs` et committer le projet régénéré. Le code du moteur utilise la découverte standard de Swift Package Manager.

## Premier essai manuel

Créer un PEA → enregistrer un versement en euros → ajouter un instrument dans le compte ou dans Plus → enregistrer un achat avec quantité et montant brut total → toucher la position pour saisir un cours réel observé et sa date. Répéter pour un CTO. Les dividendes sont saisis comme opérations ; les frais et retenues sont déduits des revenus nets affichés.

Le suivi refuse les liquidités négatives et les ventes à découvert. Il ne calcule ni fiscalité, ni TWR/XIRR, ni variation journalière. Le « gain net depuis l’origine » correspond à la valeur actuelle moins les versements nets. Ce montant n’est pas un taux de rendement.

## Confidentialité

Le dépôt est public à la demande du propriétaire. **N’y placer aucune donnée financière personnelle, clé API, certificat, relevé ou sauvegarde.** Les fichiers financiers et secrets usuels sont exclus par `.gitignore` ; cela ne remplace pas une vérification avant chaque commit.

Les données locales sont exclues de la sauvegarde iCloud. L’export/restauration chiffrés ne sont pas encore réalisés : conserver les relevés originaux et ne pas utiliser cette version comme unique registre. Une erreur d’ouverture ne déclenche jamais de recréation ou d’effacement automatique du magasin.

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Compilation, signature et coûts](docs/BUILD.md)
- [Calculs financiers](docs/CALCULATIONS.md)
- [Fournisseurs et limites](docs/API.md)
- [Vérifications et avancement](docs/PROGRESS.md)

Code écrit, compilation réussie, test en simulateur et validation sur iPhone sont des états distincts. Consulter l’exécution GitHub et le rapport d’avancement pour les preuves disponibles.
