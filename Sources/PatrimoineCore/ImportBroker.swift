import Foundation

public enum ImportBroker: String, CaseIterable, Sendable {
    case trading212 = "Trading 212", tradeRepublic = "Trade Republic", degiro = "DEGIRO"
    public var helpURL: URL {
        switch self {
        case .trading212: return URL(string: "https://helpcentre.trading212.com/hc/en-us/articles/360016898917-Can-I-export-the-trading-data-from-my-account")!
        case .tradeRepublic: return URL(string: "https://support.traderepublic.com/fr-fr/845")!
        case .degiro: return URL(string: "https://www.degiro.fr/helpdesk/fiscalite/quels-types-de-rapports-sont-disponibles-et-ou-puis-je-les-trouver")!
        }
    }
    public var guidance: String {
        switch self {
        case .trading212: return "Choisissez l’historique Invest, avec ordres, versements, retraits, dividendes et intérêts. Le suivi CFD n’est pas pris en charge."
        case .tradeRepublic: return "Utilisez l’export de transactions disponible dans votre compte ou vos documents de transaction. Vérifiez les statuts : les opérations en attente, les paiements carte, Saveback et les transferts de titres ne sont pas assimilés automatiquement à des investissements."
        case .degiro: return "Le relevé de compte contient les liquidités et revenus ; le relevé Transactions couvre les achats et ventes. Vérifiez la période et les frais : importer les mêmes frais dans ces deux rapports les compterait deux fois. Les colonnes répétées sont conservées pour association manuelle."
        }
    }
}
