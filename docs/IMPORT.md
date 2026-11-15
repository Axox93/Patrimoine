# Importer Trading 212, Trade Republic et DEGIRO

L’import est **manuel et assisté**, depuis **Plus → Importer un compte**. Il n’établit pas de connexion au courtier. Aucun fichier personnel n’est envoyé à un serveur ni à GitHub.

## Parcours CSV

1. Créer le portefeuille de destination, puis sélectionner l’établissement et ce portefeuille dans l’importateur.
2. Choisir le fichier CSV dans Fichiers, ou coller son contenu dans l’éditeur.
3. Lire les colonnes et vérifier leur correspondance : date, heure éventuelle, type, montant, devise, quantité, ticker/ISIN et identifiant.
4. Choisir brut ou mouvement net de liquidités, le séparateur décimal, le format de date et le fuseau horaire des dates sans décalage.
5. Vérifier toutes les colonnes de frais et retenues. Les montants et frais doivent déjà être dans la devise comptable EUR ; aucun change n’est inventé.
6. Prévisualiser. Une ligne inconnue, incohérente ou en attente est signalée. La corriger dans l’éditeur, associer son libellé explicitement ou l’exclure volontairement.
7. Associer les titres aux instruments enregistrés, ou créer les instruments en vérifiant ISIN, place et devise de cotation. Une devise de cotation présente dans le CSV doit correspondre à celle de l’instrument choisi.
8. Vérifier les doublons et le journal complet. Comparer le mouvement de liquidités affiché aux mouvements du courtier.
9. Confirmer. Toutes les nouvelles opérations sont validées avant l’écriture ; un journal incohérent bloque l’ensemble du lot.

Après un nouvel export, refaire ce parcours sur le **même portefeuille**. Les identifiants de source déjà importés sont rapprochés. En leur absence, les mouvements similaires dans une fenêtre de 60 secondes sont signalés comme correspondances possibles, exclues par défaut. Une opération réellement distincte peut être réincluse explicitement.

Deux identifiants source différents restent deux opérations distinctes, même avec les mêmes montants. Un identifiant déjà présent avec des données différentes bloque l’import ; aucune transaction historique n’est écrasée. Le contrôle est recalculé au moment de la confirmation, pas seulement lors de la prévisualisation.

## Courtiers

### Trading 212

Utiliser l’export de l’historique Invest, avec ordres, transactions, dividendes et intérêts. La procédure officielle est décrite dans le [centre d’aide Trading 212](https://helpcentre.trading212.com/hc/en-us/articles/360016898917-Can-I-export-the-trading-data-from-my-account). Les CFD, conversions de devises et opérations sur titres complexes ne sont pas assimilés à des achats ou versements.

Les intitulés courants sont proposés pour la correspondance des colonnes. Le montant « Total » n’est pas présumé brut : son sens doit être confirmé pour le fichier effectivement importé. Les frais ne doivent pas être déduits deux fois.

### Trade Republic

Choisir Trade Republic et sélectionner le CSV disponible dans son compte, ou les documents PDF de transaction pour une transcription assistée. Le [centre d’aide officiel](https://support.traderepublic.com/fr-fr/845) explique l’accès aux documents de chaque transaction. La disponibilité et les colonnes d’un export CSV dépendent du document réellement fourni ; aucune compatibilité exhaustive d’un format propriétaire n’est revendiquée sans exemple vérifié.

Les libellés particuliers doivent être associés explicitement. Une colonne de statut reconnue est contrôlée : les statuts inconnus et opérations en attente sont refusés. Les paiements carte, Saveback, remboursements, transferts de titres et produits non pris en charge ne sont pas automatiquement transformés en investissements.

### DEGIRO

Le [centre d’aide DEGIRO](https://www.degiro.fr/helpdesk/fiscalite/quels-types-de-rapports-sont-disponibles-et-ou-puis-je-les-trouver) distingue le relevé de compte et le relevé Transactions, avec exports CSV et PDF. Le premier comprend notamment les mouvements de liquidités et revenus ; le second les achats/ventes. Sélectionner une période couvrant l’historique nécessaire.

Les colonnes répétées ou sans nom sont conservées, avec un numéro pour les distinguer. Associer la colonne des montants **en EUR**, pas une valeur en devise étrangère. Les colonnes Date et Heure peuvent être combinées. Pour un relevé d’achats/ventes, le mode « quantité positive = achat, négative = vente » doit être activé explicitement. Il ne convient pas à un relevé de compte mélangeant revenus et mouvements d’espèces.

Les frais liés aux ordres doivent être associés au bon ordre pour entrer dans son coût d’acquisition. Un frais importé comme opération « Frais » reste une charge indépendante. Ne pas additionner les frais du relevé Transactions avec les mêmes frais déjà importés du relevé de compte. Sans échantillon du relevé, aucun rapprochement automatique de ces deux formats n’est affirmé.

## PDF

PDFKit extrait le texte **localement**. Le texte est présenté à l’utilisateur qui transcrit les opérations utiles dans le tableau CSV, puis utilise le même parcours de validation. Aucun achat, vente ou solde n’est déduit automatiquement d’un PDF arbitraire.

Les documents scannés sans couche texte, protégés, trop longs ou non lisibles sont refusés. Il n’y a pas d’OCR dans cette version. L’extraction de texte ne garantit pas l’ordre des colonnes ou la validité des montants d’un relevé ; une validation manuelle est indispensable. Cette fonction n’est pas un parseur automatique des relevés des trois courtiers.

## Limites

- 5 Mo et 10 000 opérations maximum par CSV ; PDF de 100 pages maximum avec texte exploitable.
- CSV UTF-8 ou UTF-16 avec BOM ; séparateurs virgule, point-virgule ou tabulation ; champs entre guillemets et fins de ligne Windows pris en charge.
- Un seul séparateur décimal choisi pour le fichier ; aucun séparateur de milliers.
- Comptabilité en EUR, pas de conversion automatique. La devise de cotation d’un titre peut être USD ou une autre devise proposée, mais les coûts et frais importés doivent déjà être en EUR. Les valorisations manuelles doivent également être des valeurs équivalentes en EUR, explicitement déclarées par l’utilisateur.
- Les prix unitaires d’origine et taux de change ne sont pas enregistrés par cet import : conserver le fichier original. Un montant comptable en USD ne sera pas assimilé à un montant EUR.
- Historique incomplet, liquidités négatives ou vente dépassant les titres détenus : import bloqué. Aucun versement fictif ni solde de départ inventé.
- La lecture du fichier et sa préparation sont effectuées hors du fil d’interface. Les données ne sont écrites qu’après confirmation explicite.
- Les tests utilisent uniquement des données fictives. Les variantes d’exports personnels des trois établissements ne sont pas toutes validées. Un petit exemple anonymisé permettrait de compléter les adaptateurs, sans publier le relevé personnel.
