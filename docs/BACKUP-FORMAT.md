# Conteneur chiffré de sauvegarde — étape technique

Validation du 15 novembre 2026 : [build 6 réussi](https://github.com/Axox93/Patrimoine/actions/runs/43754928640), commit `51e0cbd02b038e7562227df8b314f7521ca9f037`. Les 4 nouveaux tests de chiffrement et les 19 tests existants passent, soit 23 tests sans échec. Archive iOS et IPA non signé produits ; empreinte SHA-256 vérifiée après téléchargement. Aucune restauration de portefeuille ni installation sur iPhone physique n’est revendiquée.

Le module `EncryptedBackup` est disponible dans le package local. Il ne sérialise pas encore les modèles SwiftData et aucun export ou import de sauvegarde n’est proposé dans l’application. L’état « À venir » reste correct dans les paramètres.

Le fichier commence par les octets UTF-8 `PATRIMOINE-BACKUP-1` suivis d’un saut de ligne. La suite utilise la représentation combinée CryptoKit AES-GCM : nonce de 12 octets, texte chiffré et tag de 16 octets. Le préfixe est également authentifié comme donnée associée.

Chaque chiffrement crée un nouveau nonce. La clé aléatoire de 256 bits est générée par CryptoKit. Sa représentation de récupération est un encodage base64 des 32 octets ; ce n’est pas un mot de passe. Elle ne doit jamais être enregistrée dans le même fichier que la sauvegarde, ni dans les journaux ou GitHub. Sans cette clé, le déchiffrement est impossible.

Le module accepte un maximum de 25 Mio de données avant chiffrement. Les tailles dépassées, formats inconnus, clés mal formées, mauvaises clés, fichiers tronqués et modifications du contenu sont refusés. Une erreur d’authentification ne retourne aucun texte déchiffré.

Les tests couvrent la récupération de clé, l’aller-retour de données fictives, l’absence de texte clair, le rejet d’une mauvaise clé, les modifications et troncatures, les formats inconnus et la variation du nonce.

La prochaine étape doit ajouter un schéma documentaire versionné pour tous les modèles, valider les références et journaux avant restauration, puis proposer une prévisualisation et une confirmation. Les identifiants et historiques devront être préservés et toute écriture devra être atomique. La validation du conteneur chiffré seule ne valide pas une restauration de portefeuille.
