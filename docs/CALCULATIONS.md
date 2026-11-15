# Conventions financières de la version 0.1

## Journal

Les comptes et cours pris en charge sont en EUR. Les montants, quantités et frais sont positifs ; le type détermine le signe. Les transactions sont rejouées par date comptable puis numéro d’ordre d’enregistrement. Les identifiants ou numéros d’ordre dupliqués sont refusés. L’import de fichiers n’est pas encore disponible : il n’existe pas de détection de doublons métier provenant d’un courtier.

L’interface accepte un point ou une virgule comme séparateur décimal, sans séparateur de milliers, jusqu’à douze décimales et vingt-huit chiffres. Aucun `Double` n’est utilisé comme source de vérité monétaire.

| Opération | Liquidités | Base de coût / apports |
| --- | --- | --- |
| Versement | + brut − frais | Versements nets + brut |
| Retrait | − brut − frais | Versements nets − brut |
| Achat | − brut − frais | Quantité + q ; coût + brut + frais |
| Vente | + brut − frais | Quantité − q ; coût moyen de la quantité vendue retiré |
| Dividende / intérêt | + brut − frais et retenues saisis | Revenu net, aucun apport externe |
| Frais seuls | − montant | Aucun apport externe |
| Fractionnement | Aucun changement | Quantité × coefficient ; coût inchangé |

Les liquidités négatives et ventes à découvert sont refusées. Un dividende sur ETF déclaré capitalisant est refusé. La distribution d’un instrument inconnu n’est pas déduite automatiquement.

## Coût moyen pondéré

Après achat : `coût = coût précédent + montant brut + frais d’achat`.

`PRU = coût / quantité détenue`.

Lors d’une vente partielle : `coût sorti = coût avant vente × quantité vendue / quantité avant vente`.

`gain réalisé = montant brut vendu − frais de vente − coût sorti`.

Une vente totale sort exactement toute la base restante pour éviter un résidu d’arrondi. La précision interne est celle de `Decimal` ; les valeurs affichées en devise sont arrondies par le formateur, sans arrondir le journal. Cette méthode n’est pas un calcul fiscal ou une déclaration d’impôts.

## Valorisation et gains

`valeur suivie = liquidités + somme(quantité × dernier cours observé déclaré)`.

Le dernier cours est choisi par date d’observation, puis date de saisie. Un cours enregistré tardivement mais observé avant un autre cours ne remplace pas celui-ci. Il n’y a pas de cotation fictive ni de remplacement par le PRU.

`plus-value latente = valeur des positions − coût restant`.

`gain net depuis l’origine = valeur suivie − versements nets`.

Ce gain englobe la variation de valeur, les revenus encaissés et les frais comptabilisés. Il n’est ni un rendement annualisé ni un TWR/MWR. Une nouvelle contribution augmente simultanément la valeur et les versements nets ; elle n’augmente donc pas le gain net.

Les instantanés de valorisation sont des observations ponctuelles enregistrées à la demande. Ils ne constituent pas un historique de cours et ne permettent pas à eux seuls de calculer un TWR ou une variation journalière fiable.

## Hors périmètre actuel

Change historique, TWR, XIRR, obligations, intérêts courus, conventions de jours, amortissement, dettes, revenus annoncés/estimés, fiscalité, transferts, fusions et changements d’instrument. Ces fonctions doivent recevoir leurs propres conventions et tests avant d’apparaître comme disponibles.
