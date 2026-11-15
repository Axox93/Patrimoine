# Architecture cible et première tranche

## Principes

Application exclusivement iPhone, iOS 17+, Swift 5.9 ou plus récent en mode Swift 5, SwiftUI, SwiftData, Swift Charts. Le moteur Swift est compilé sur macOS pour ses tests ; aucune application macOS n’est produite. Aucun service distant, suivi analytique ou package tiers.

| Emplacement | Responsabilité |
| --- | --- |
| `Patrimoine/App` | Cycle de vie, navigation, ouverture du magasin, écran verrouillé |
| `Patrimoine/Design` | Cartes, valeurs monétaires, états vides, avertissements |
| `Patrimoine/Features` | Comptes, opérations, instruments, valorisations, analyses, revenus |
| `Patrimoine/Storage` | Schéma versionné, écritures explicites, reconstitution et consolidation |
| `Patrimoine/Security` | Authentification locale et adaptateur Keychain réservé aux futurs secrets |
| `Sources/PatrimoineCore` | Domaine financier pur Foundation, sans dépendance à SwiftUI/SwiftData |
| `Tests` | Tests unitaires du moteur |
| `PatrimoineTests` | Tests SwiftData sur simulateur iPhone |
| `PatrimoineUITests` | Parcours natifs et captures sur simulateur iPhone |
| `scripts` | Génération déterministe du projet, contrôles et empaquetage |

## Données

`Account` porte l’établissement, le type, la devise et les états archivé/corbeille. `Instrument` identifie un titre par place et ticker, avec ISIN facultatif. `Movement` conserve les opérations et un numéro d’ordre stable par compte. `Price` conserve chaque cours déclaré avec date d’observation, date de saisie et source. `Snapshot` conserve les valorisations réellement enregistrées et leur périmètre de comptes.

Les montants persistés sont des chaînes décimales canoniques, décodées strictement vers `Decimal`. Une donnée invalide produit une erreur explicite, jamais un zéro de remplacement. `Double` sert uniquement au dessin des graphiques.

La source de vérité des positions et liquidités est le journal transactionnel. Un cours inconnu empêche le total concerné ; le coût d’acquisition n’est jamais utilisé comme cours implicite. Les actifs à quantité nulle n’exigent pas de cours.

L’archivage retire un compte de la liste courante mais le conserve dans les totaux. La corbeille le retire des totaux sans effacer ses opérations. Les instantanés affichés doivent correspondre exactement au périmètre actuel, ce qui évite de raccorder les courbes de périmètres différents. Les corrections antidatées ne réécrivent pas les instantanés précédents : ils restent des observations faites à leur date.

## Persistance et migrations

Schéma `PatrimoineSchemaV1` et `PatrimoineMigrationPlan` déclarés dès la première version. Toute évolution exige une nouvelle version du schéma, une migration adaptée et un test de réouverture d’un magasin de la version précédente. Ne pas modifier en place la définition V1 après une livraison utilisée.

Le conteneur ne synchronise pas avec CloudKit. Les écritures sont explicites, avec rollback si la sauvegarde échoue. L’ouverture d’un magasin invalide ne déclenche jamais de suppression ou de repli vers un magasin vide. Les tests en mémoire sont limités au code de test.

Le répertoire et les fichiers existants reçoivent `FileProtectionType.complete`, avec entitlement de protection par défaut. Les nouveaux fichiers héritent de la protection du répertoire. La vérification réelle de cette protection sur appareil reste obligatoire avant un usage sensible.

## Sécurité

Le verrouillage utilise `deviceOwnerAuthentication` (biométrie ou code du téléphone), avec invalidation d’une tentative lors du passage en arrière-plan. Une protection visuelle recouvre l’application dès qu’elle devient inactive. Le verrouillage est optionnel, désactivé au premier lancement et activé seulement après authentification réussie.

L’ouverture du magasin est déclenchée lorsque la scène devient active. Les protections visuelles s’affichent au-dessus de l’interface pour préserver sa navigation ; les vues recouvertes sont exclues de l’accessibilité et des interactions.

Les futures clés seront exclusivement stockées dans Keychain, accessibilité `WhenUnlockedThisDeviceOnly`. Aucun secret n’est actuellement demandé ni transmis. Le masquage des montants couvre les montants, quantités et graphiques ; les noms d’établissements restent visibles.

## Design

Identité originale : vert sauge et vert forêt, typographie système, valeurs à chiffres tabulaires, cartes de 24 points de rayon et espacements de 20–24 points. SF Symbols, icône géométrique originale, couleurs adaptatives clair/sombre. Dynamic Type et composants sémantiques natifs ; les montants possèdent un libellé accessible. Les animations du graphique et du mode confidentialité respectent Réduire les animations.

La validation visuelle en simulateur et sur iPhone, VoiceOver, grands caractères et contrastes est distincte des tests de compilation. Elle n’est pas présumée réussie.

## Extensions prévues

`MarketDataProvider` et `ReadOnlyBrokerConnector` définissent les frontières des fournisseurs. Aucun faux fournisseur n’est installé en production. Les futurs modules ImportExport, Backups, FX, Bonds, Property et Simulations doivent conserver ce découplage. Les transferts liés entre comptes devront être atomiques et conserver les bases de coût ; aucune simple paire de mouvements n’est actuellement présentée comme transfert pris en charge.
