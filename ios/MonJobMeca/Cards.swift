import SwiftUI

// MARK: - Expérience demandée

struct BlocXP: View {
    let texte: String
    var body: some View {
        let r = niveauXP(texte)
        let niveau = r.0
        let titre = r.1
        let c: Color = niveau == .ok ? .vert : niveau == .proche ? .jaune : niveau == .eleve ? .rouge : .texte2
        let icone = niveau == .ok ? "checkmark.circle.fill" : niveau == .eleve ? "exclamationmark.triangle.fill" : niveau == .proche ? "circle.lefthalf.filled" : "graduationcap.fill"
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icone).font(.system(size: 17, weight: .semibold)).foregroundColor(c).padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(titre.uppercased()).font(.system(size: 11, weight: .bold)).tracking(0.6).foregroundColor(c.opacity(0.85))
                Text(texte.isEmpty ? "Non précisée" : texte).font(.system(size: 15, weight: .semibold)).foregroundColor(niveau == .inconnu ? .white : c)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(niveau == .inconnu ? Color.carte2 : c.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct LignePublication: View {
    let offre: Offre
    var body: some View {
        let p = publication(offre)
        HStack(spacing: 6) {
            Image(systemName: "clock").font(.system(size: 12, weight: .semibold)).foregroundColor(.texte3)
            Text(p.texte).font(.system(size: 13, weight: p.connue ? .semibold : .regular)).foregroundColor(p.connue ? .texte2 : .texte3)
            if p.nouveau {
                Text("Nouveau").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Color.bleu).clipShape(Capsule())
            }
        }
    }
}

// MARK: - Carte d'une offre

struct CarteOffre: View {
    @EnvironmentObject var store: AppStore
    let offre: Offre
    var vedette = false
    @State private var lettre: Offre?
    @State private var detail: Offre?

    var body: some View {
        let st = store.statut(.offre, offre.id)
        VStack(alignment: .leading, spacing: 12) {
            Button { detail = offre } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        BadgePrio(prio: offre.prio).padding(.top, 3)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(offre.poste).font(.system(size: vedette ? 23 : 18, weight: .bold)).foregroundColor(.white)
                                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                            Text(offre.entreprise).font(.system(size: 15, weight: .medium)).foregroundColor(.texte2)
                            HStack(spacing: 5) {
                                Image(systemName: "mappin.and.ellipse").font(.system(size: 12))
                                Text([offre.ville, distance(offre.km)].filter { !$0.isEmpty }.joined(separator: " · "))
                            }.font(.system(size: 13)).foregroundColor(.texte3)
                            LignePublication(offre: offre).padding(.top, 2)
                        }
                        Spacer(minLength: 0)
                    }
                    BlocXP(texte: offre.experience)
                    Flux {
                        if !offre.contrat.isEmpty { Pastille(texte: offre.contrat, icone: "doc.text") }
                        if !offre.type.isEmpty { Pastille(texte: offre.type, icone: offre.type.lowercased().contains("concession") ? "building.2" : "wrench.and.screwdriver") }
                        if !offre.salaire.isEmpty { Pastille(texte: offre.salaire, icone: "eurosign", couleur: .ciel, fond: Color.ciel.opacity(0.14)) }
                    }
                    if !offre.note.isEmpty {
                        Text(offre.note).font(.system(size: 14)).foregroundColor(.texte2).multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .buttonStyle(.plain)

            HStack {
                MenuStatut(kind: .offre, id: offre.id)
                Spacer()
                if let d = store.offres[offre.id]?.dateCandidature {
                    Text("Envoyée le \(Dates.court(d))").font(.system(size: 12)).foregroundColor(.texte3)
                }
            }
            HStack(spacing: 10) {
                Button { store.postuler(offre) } label: { Label("Postuler", systemImage: "paperplane.fill") }
                    .buttonStyle(BoutonBlanc())
                Button { lettre = offre } label: { Label("Ma lettre", systemImage: "square.and.pencil") }
                    .buttonStyle(BoutonGris())
            }
        }
        .padding(16)
        .background(fondCarte)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .opacity(["ecartee", "refus"].contains(st) ? 0.55 : 1)
        .sheet(item: $lettre) { o in VueLettre(kind: .offre, id: o.id) }
        .sheet(item: $detail) { o in DetailOffre(offre: o) }
    }

    @ViewBuilder private var fondCarte: some View {
        if vedette {
            ZStack {
                LinearGradient(colors: [Color.carte2, Color.carte], startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [Color.accent.opacity(0.35), .clear], center: .topTrailing, startRadius: 0, endRadius: 320)
                RadialGradient(colors: [Color.bleu.opacity(0.25), .clear], center: .bottomLeading, startRadius: 0, endRadius: 300)
            }
        } else {
            Color.carte
        }
    }
}

// MARK: - Petite carte pour les rangées horizontales

struct MiniCarte: View {
    @EnvironmentObject var store: AppStore
    let offre: Offre
    @State private var detail: Offre?
    var body: some View {
        Button { detail = offre } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack { BadgePrio(prio: offre.prio); Spacer(); Circle().fill(couleurStatut(store.statut(.offre, offre.id))).frame(width: 8, height: 8) }
                Text(offre.poste).font(.system(size: 16, weight: .bold)).foregroundColor(.white).lineLimit(2).multilineTextAlignment(.leading)
                Text(offre.entreprise).font(.system(size: 13, weight: .medium)).foregroundColor(.texte2).lineLimit(1)
                Spacer(minLength: 0)
                Text([offre.ville.split(separator: "/").first.map { String($0) } ?? "", distance(offre.km)].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 12)).foregroundColor(.texte3).lineLimit(1)
                LignePublication(offre: offre)
            }
            .padding(14)
            .frame(width: 236, height: 168, alignment: .topLeading)
            .background(Color.carte)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .sheet(item: $detail) { o in DetailOffre(offre: o) }
    }
}

// MARK: - Carte entreprise (marché caché)

struct CarteEntreprise: View {
    @EnvironmentObject var store: AppStore
    let ent: Entreprise
    @State private var lettre: Entreprise?

    var initiales: String {
        let mots = Lettre.nomPropre(ent.nom).split(separator: " ").filter { $0.count > 2 && !["Garage", "Automobiles", "Centre"].contains(String($0)) }
        return String(mots.prefix(2).compactMap { $0.first }).uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text(initiales.isEmpty ? "?" : initiales)
                    .font(.system(size: 17, weight: .bold)).foregroundColor(ent.type.contains("Centre") ? .black : .white)
                    .frame(width: 46, height: 46)
                    .background(ent.type.contains("Centre") ? Color.white : Color.carte2)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(ent.nom).font(.system(size: 17, weight: .bold)).foregroundColor(.white).fixedSize(horizontal: false, vertical: true)
                    Text([ent.marque, ent.type].filter { !$0.isEmpty }.joined(separator: " · ")).font(.system(size: 14)).foregroundColor(.texte2)
                    Label([ent.adresse == ent.ville ? "" : ent.adresse, ent.ville, distance(ent.km)].filter { !$0.isEmpty }.joined(separator: ", "), systemImage: "mappin.and.ellipse")
                        .font(.system(size: 13)).foregroundColor(.texte3)
                }
                Spacer(minLength: 0)
            }
            if !ent.contact.isEmpty {
                if let m = ent.email, let u = URL(string: "mailto:\(m)") {
                    Link(destination: u) { Label(m, systemImage: "envelope.fill") }.font(.system(size: 14, weight: .medium)).foregroundColor(.bleu)
                } else if let t = ent.telephone, let u = URL(string: "tel:\(t.filter { $0.isNumber })") {
                    Link(destination: u) { Label(t, systemImage: "phone.fill") }.font(.system(size: 14, weight: .medium)).foregroundColor(.bleu)
                }
            }
            if !ent.note.isEmpty {
                Text(ent.note).font(.system(size: 14)).foregroundColor(.texte2).fixedSize(horizontal: false, vertical: true)
            }
            HStack { MenuStatut(kind: .ent, id: ent.id); Spacer() }
            HStack(spacing: 10) {
                Button { store.postuler(ent) } label: { Label(ent.email != nil ? "Postuler" : "Candidature", systemImage: "paperplane.fill") }
                    .buttonStyle(BoutonBlanc())
                Button { lettre = ent } label: { Label("Lettre", systemImage: "square.and.pencil") }
                    .buttonStyle(BoutonGris())
            }
        }
        .padding(16)
        .background(Color.carte)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .sheet(item: $lettre) { e in VueLettre(kind: .ent, id: e.id) }
    }
}
