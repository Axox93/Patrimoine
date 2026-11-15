# Données externes et connecteurs

## État de cette livraison

**Aucun appel réseau financier n’est activé.** `MarketDataProvider` et `ReadOnlyBrokerConnector` sont des contrats de code, pas des intégrations opérationnelles. L’application fonctionne sans connexion et valorise avec les cours réels recopiés manuellement et datés par l’utilisateur. Une donnée déclarée n’est pas présentée comme vérifiée par une API.

La phase 1 ne prétend pas avoir vérifié les offres, quotas, tarifs ou conditions de l’ensemble des fournisseurs demandés. Avant chaque intégration, consigner la date de vérification, les conditions d’utilisation, l’accès gratuit réellement accordé, les marchés couverts, les unités, devises, places, dates, erreurs et tests d’endpoints. Une documentation consultée seule n’est pas un test d’API.

## Priorités de recherche

| Fournisseur | Documentation officielle à examiner | État |
| --- | --- | --- |
| Trading 212 | https://docs.trading212.com/api | Non intégré, clé lecture seule et droits à vérifier sur le compte réel |
| Twelve Data | https://twelvedata.com/docs | Non intégré, marchés/licences/quotas gratuits à vérifier |
| CoinGecko | https://docs.coingecko.com/ | Non intégré, accès Demo et limites à vérifier |
| OpenFIGI | https://www.openfigi.com/api | Non intégré, mapping ISIN/place et limites à vérifier |
| BCE | https://data.ecb.europa.eu/help/api/overview | Non intégré, conventions de taux et dates à tester |
| Interactive Brokers | https://www.interactivebrokers.com/campus/ibkr-api-page/ | Non intégré, Flex lecture seule à étudier |

Ces liens sont des points de départ documentaires, pas une promesse de gratuité ou de disponibilité pour un compte donné.

Pour DEGIRO, Trade Republic et les banques françaises, privilégier les exports effectivement fournis tant qu’aucune méthode officielle adaptée n’est validée. Aucun wrapper privé, scraping d’authentification bancaire ou mot de passe bancaire stocké dans l’application. L’accès DSP2 aux comptes de paiement ne garantit pas l’accès aux positions PEA/CTO. Enable Banking, Powens et Bridge doivent faire l’objet d’une étude de prix, droits, accès personnel et couverture avant toute proposition de connexion.

## Contrat attendu pour les futures sources

- HTTPS et validation de chaque réponse, sans désactivation TLS.
- Identité comprenant ticker, place MIC, ISIN si disponible et devise.
- Prix décimal avec date d’observation et provenance.
- Conservation du dernier résultat valide en cas d’échec, sans le présenter comme récent.
- Cache local, quotas et pagination, backoff borné et annulation des tâches.
- Secrets dans Keychain, jamais dans le dépôt, les logs ou les préférences ordinaires.
- Aucun endpoint de passage d’ordres, même si le fournisseur en propose.
- Tests de succès, timeout, HTTP, quota, absence de données, identité ambiguë et réponse invalide.

## Import à venir

L’import CSV générique sera la première étape, avec prévisualisation, mapping, validation stricte, rapprochement et confirmation avant écriture atomique. Le schéma métier doit préserver l’identifiant fournisseur, la source, l’empreinte, la devise et le compte. Deux opérations financières identiques ne sont pas nécessairement un doublon : toute incertitude exige une revue.

Excel et PDF nécessitent un choix de parseur et une validation sur des exemples anonymisés d’exports réels. Ils ne doivent pas être présentés comme disponibles dans cette tranche. Aucun fichier personnel ne doit être envoyé vers GitHub pour construire ces parseurs.
