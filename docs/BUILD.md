# Compilation et livraison iPhone

## Workflow

`.github/workflows/build-ios.yml` utilise un runner GitHub standard `macos-15`. Il conserve le Xcode stable par défaut de l’image ; la variable de dépôt `XCODE_VERSION` permet de sélectionner explicitement une version installée. La version effective est inscrite dans les journaux. Le projet cible iOS 17 et le schéma partagé `Patrimoine`.

Ordre obligatoire : validation structurelle → résolution du package local → tests du moteur avec `swift test` → tests de persistance sur un simulateur iPhone disponible → archive générique iOS → paquet → vérification du contenu et de la signature → artefact.

Un test ou une construction en échec interrompt le paquet et sa publication. Les diagnostics sont téléchargeables séparément, sans IPA présenté comme réussi. Le workflow ne s’exécute automatiquement que sur les modifications pertinentes poussées sur `main`, avec annulation des constructions dépassées. Les changements de documentation seuls ne le déclenchent pas.

Sources officielles consultées le 15 novembre 2026 : [images macOS GitHub](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md), [règles de facturation GitHub Actions](https://docs.github.com/en/billing/concepts/product-billing/github-actions), [distribution Apple](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases). Les images et offres évoluent ; ne pas supposer une version précise de Xcode ou un quota fixe.

## Mode A : unsigned

Mode automatique et manuel par défaut. L’archive est produite avec signature désactivée. Le binaire appareil est empaqueté sous `Payload/Patrimoine.app` dans `Patrimoine-iOS.ipa`. Le script vérifie le Mach-O, la plateforme iPhoneOS, la famille iPhone et l’absence de profil de signature. Un IPA non signé nécessite une signature Apple valide avant installation.

Le fichier `build-info.json` contient version, build, date UTC, commit, signature et compatibilité minimale iOS. `SHA256SUMS.txt` permet de contrôler l’intégrité du téléchargement. Aucun marquage « testé sur iPhone » n’est émis automatiquement.

### Installer avec une signature personnelle

La resignature personnelle peut se faire sous Windows avec un outil de sideload reconnu, compatible avec les conditions Apple et votre compte. Utiliser exclusivement son site officiel, vérifier sa politique de confidentialité et ne jamais communiquer les identifiants Apple dans ce dépôt ou dans une conversation. L’éligibilité, la durée de validité et les limites dépendent du compte et du profil Apple ; cette livraison ne promet aucun contournement ni installation permanente gratuite. Cette voie n’a pas été validée sur votre appareil.

L’autre possibilité est le mode signé ci-dessous avec un profil de développement ou ad hoc contenant l’UDID de l’iPhone. Une signature cryptographiquement valide n’établit pas à elle seule que votre téléphone peut installer l’application.

## Mode B : signed

Ce mode reste désactivé tant que les secrets compatibles n’ont pas été fournis. Ne jamais créer un abonnement payant automatiquement.

Dans **Settings → Secrets and variables → Actions**, configurer :

| Secret / variable | Usage |
| --- | --- |
| Secret `IOS_CERTIFICATE_BASE64` | Certificat et clé privée exportés en `.p12`, encodés en base64 |
| Secret `IOS_CERTIFICATE_PASSWORD` | Mot de passe du `.p12` |
| Secret `IOS_PROFILE_BASE64` | Profil `.mobileprovision` encodé en base64 |
| Variable `IOS_BUNDLE_ID` | Identifiant correspondant exactement au profil, défaut `fr.patrimoine.personal` |
| Variable `IOS_EXPORT_METHOD` | `release-testing` pour un profil ad hoc, `debugging` pour un profil de développement compatible |
| Variable facultative `XCODE_VERSION` | Version installée sur l’image macOS, par exemple `16.4` si elle y figure encore |

Le script refuse les profils expirés, sans appareils enregistrés ou dont l’identifiant ne correspond pas exactement. Il crée un trousseau éphémère, importe la clé, archive avec signature manuelle puis exporte via Xcode. Il vérifie la signature du paquet exporté avec `codesign --verify --deep --strict`. Certificat, profil et trousseau temporaires sont supprimés en fin de script. Les secrets ne sont pas inclus dans les artefacts.

La présence de `ProvisionedDevices` est contrôlée ; le fait que votre UDID particulier y figure et l’installation réelle doivent être vérifiés par vous sur l’iPhone. Le mode signé nécessite un essai dédié et n’est pas déclaré validé par la réussite du mode unsigned.

## Télécharger

Ouvrir le dépôt → **Actions** → **Build iOS** → une exécution verte → section **Artifacts** → `Patrimoine-iOS-<numéro>-unsigned` (ou `signed`). Extraire le ZIP téléchargé. Les artefacts applicatifs sont conservés sept jours, les diagnostics trois jours. Télécharger rapidement l’IPA ou relancer manuellement si l’artefact a expiré.

## Coûts

Le dépôt est public à la demande du propriétaire. Les runners GitHub hébergés standards sont gratuits pour les dépôts publics selon la documentation officielle consultée. Les limites d’usage et de stockage restent applicables. Ce workflow n’utilise ni grand runner ni option payante et ne modifie pas les réglages de facturation. Si le dépôt devient privé, contrôler l’allocation incluse et les budgets avant de multiplier les builds. Les quotas ne garantissent pas une compilation gratuite illimitée sur dépôt privé.

## Diagnostiquer

Consulter l’étape rouge, puis les journaux et `Tests.xcresult`. Corriger la cause, pousser la correction, attendre le nouveau résultat et contrôler l’artefact. Un workflow écrit ou une archive partielle ne constitue pas une compilation validée.
