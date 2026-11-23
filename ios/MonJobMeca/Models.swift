import Foundation

// MARK: - Lecture tolérante du fichier d'offres

private struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ s: String) { stringValue = s }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

private extension KeyedDecodingContainer where K == AnyKey {
    func text(_ name: String) -> String {
        let k = AnyKey(name)
        if let s = try? decodeIfPresent(String.self, forKey: k) { return s }
        if let d = try? decodeIfPresent(Double.self, forKey: k) {
            return d == d.rounded() ? String(Int(d)) : String(d)
        }
        return ""
    }
    func number(_ name: String) -> Double? {
        let k = AnyKey(name)
        if let d = try? decodeIfPresent(Double.self, forKey: k) { return d }
        if let s = try? decodeIfPresent(String.self, forKey: k) {
            return Double(s.replacingOccurrences(of: ",", with: ".").filter { "0123456789.".contains($0) })
        }
        return nil
    }
}

struct Offre: Identifiable, Hashable, Decodable {
    var id: String
    var poste: String
    var entreprise: String
    var ville: String
    var km: Double?
    var contrat: String
    var type: String
    var salaire: String
    var experience: String
    var publiee: String
    var lien: String
    var note: String
    var prio: Int

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        id = c.text("id")
        poste = c.text("poste")
        entreprise = c.text("entreprise")
        ville = c.text("ville")
        km = c.number("km")
        contrat = c.text("contrat")
        type = c.text("type")
        salaire = c.text("salaire")
        experience = c.text("experience")
        publiee = c.text("publiee")
        lien = c.text("lien")
        note = c.text("note")
        let p = Int(c.number("prio") ?? 3)
        prio = [1, 2, 3].contains(p) ? p : 3
    }
}

struct Entreprise: Identifiable, Hashable, Decodable {
    var id: String
    var nom: String
    var marque: String
    var type: String
    var adresse: String
    var ville: String
    var km: Double?
    var contact: String
    var lienRecrutement: String
    var note: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        id = c.text("id")
        nom = c.text("nom")
        marque = c.text("marque")
        type = c.text("type")
        adresse = c.text("adresse")
        ville = c.text("ville")
        km = c.number("km")
        contact = c.text("contact")
        lienRecrutement = c.text("lienRecrutement")
        note = c.text("note")
    }

    var email: String? {
        let t = contact.trimmingCharacters(in: .whitespaces)
        return t.contains("@") ? t : nil
    }
    var telephone: String? {
        let digits = contact.filter { $0.isNumber }
        return digits.count >= 10 ? contact : nil
    }
}

private struct Lossy<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

struct DataFile: Decodable {
    var maj: String?
    var offres: [Offre] = []
    var entreprises: [Entreprise] = []

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        maj = try? c.decodeIfPresent(String.self, forKey: AnyKey("maj"))
        offres = (try? c.decodeIfPresent([Lossy<Offre>].self, forKey: AnyKey("offres")))?
            .compactMap { $0.value }.filter { !$0.id.isEmpty } ?? []
        entreprises = (try? c.decodeIfPresent([Lossy<Entreprise>].self, forKey: AnyKey("entreprises")))?
            .compactMap { $0.value }.filter { !$0.id.isEmpty } ?? []
    }
}

// MARK: - Ce que fait Imad (gardé sur l'iPhone)

struct Suivi: Codable, Hashable {
    var statut: String
    var dates: [String: String] = [:]
    var dateCandidature: String?
    var note: String = ""
    var lettre: String?
    var lettreDate: String?
}

enum Kind: String, Codable { case offre, ent }

struct Statut: Identifiable, Hashable {
    let id: String
    let label: String
}

let STATUTS_OFFRE: [Statut] = [
    .init(id: "a_traiter", label: "À traiter"), .init(id: "a_postuler", label: "À postuler"),
    .init(id: "postule", label: "Postulé"), .init(id: "relance", label: "Relancé"),
    .init(id: "entretien", label: "Entretien"), .init(id: "refus", label: "Refus"),
    .init(id: "ecartee", label: "Écartée")
]
let STATUTS_ENT: [Statut] = [
    .init(id: "a_contacter", label: "À contacter"), .init(id: "envoyee", label: "Envoyée"),
    .init(id: "relancee", label: "Relancée"), .init(id: "reponse", label: "Réponse")
]
func labelStatut(_ id: String) -> String {
    (STATUTS_OFFRE + STATUTS_ENT).first { $0.id == id }?.label ?? id
}

enum Profil {
    static let prenom = "Imad"
    static let nom = "Imad Eddine Hassainia"
    static let tel = "07 69 54 11 95"
    static let mail = "imad.h33@icloud.com"
    static let ville = "Villenave-d'Ornon"
    static let zone: [(String, String)] = [
        ("Villenave-d'Ornon", "chez moi"), ("Bègles", "~3 km"), ("Cadaujac", "~6 km"), ("Bouliac", "~8 km"),
        ("Floirac", "~9 km"), ("Cenon", "~12 km"), ("Lormont", "~15 km"), ("Pessac", "~10 km"), ("Mérignac", "~15 km")
    ]
    static let competences = ["Service rapide (autonome)", "Vidange / filtres", "Freinage disques & plaquettes", "Train avant",
                              "Distribution", "Kit embrayage", "Décaissage", "Dépose moteur", "Boîte de vitesses", "Berceau"]
    static let cochees: Set<String> = ["Vidange / filtres", "Freinage disques & plaquettes", "Train avant"]
}
