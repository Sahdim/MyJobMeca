import SwiftUI
import UniformTypeIdentifiers

// MARK: - Accueil

struct VueAccueil: View {
    @EnvironmentObject var store: AppStore
    @Binding var onglet: Int

    var salut: String {
        let h = Calendar.current.component(.hour, from: Date())
        return (h >= 18 || h < 5 ? "Bonsoir" : "Salut") + " " + Profil.prenom
    }

    var body: some View {
        let actives = store.trier(store.data.offres.filter { ["a_traiter", "a_postuler"].contains(store.statut(.offre, $0.id)) })
        let st = store.data.offres.map { store.statut(.offre, $0.id) }
        let envoyees = st.filter { ["postule", "relance", "entretien", "refus"].contains($0) }.count
            + store.data.entreprises.filter { store.statut(.ent, $0.id) != "a_contacter" }.count
        let nouvelles = store.trier(store.data.offres.filter { publication($0).nouveau && store.statut(.offre, $0.id) != "ecartee" })
        let relances = store.relances

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(spacing: 8) {
                        Circle().fill(Color.vert).frame(width: 8, height: 8)
                        Text("Offres du \(Dates.maj(store.data.maj))").font(.system(size: 14, weight: .medium)).foregroundColor(.texte2)
                        Spacer()
                        if store.chargement { ProgressView().tint(.white) }
                    }

                    if let top = actives.first {
                        VStack(alignment: .leading, spacing: 12) {
                            TitreSection(titre: "Ta meilleure piste")
                            CarteOffre(offre: top, vedette: true)
                        }
                    }

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        Chiffre(n: st.filter { $0 == "a_traiter" }.count, label: "À traiter", couleur: .white) { onglet = 1 }
                        Chiffre(n: st.filter { $0 == "a_postuler" }.count, label: "À postuler", couleur: .accent) { onglet = 1 }
                        Chiffre(n: envoyees, label: "Envoyées", couleur: .ciel) { onglet = 3 }
                        Chiffre(n: st.filter { $0 == "entretien" }.count, label: "Entretiens", couleur: .vert) { onglet = 3 }
                    }

                    if !relances.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("\(relances.count) relance\(relances.count > 1 ? "s" : "") à faire", systemImage: "bell.badge.fill")
                                .font(.system(size: 16, weight: .bold)).foregroundColor(.jaune)
                            ForEach(Array(relances.prefix(4).enumerated()), id: \.offset) { _, r in
                                Text("• \(r.titre) (il y a \(r.jours) jours)").font(.system(size: 14)).foregroundColor(.texte2)
                            }
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.jaune.opacity(0.13))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    if !nouvelles.isEmpty {
                        Rangee(titre: "Nouveautés", offres: Array(nouvelles.prefix(10)))
                    }
                    if actives.count > 1 {
                        Rangee(titre: "À ne pas rater", offres: Array(actives.dropFirst().prefix(10)))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        TitreSection(titre: "Marché caché", sous: "\(store.data.entreprises.count) entreprises")
                        Text("Des concessions et garages près de chez toi, pour une candidature spontanée.")
                            .font(.system(size: 14)).foregroundColor(.texte2)
                        Button { onglet = 2 } label: { Label("Voir le marché caché", systemImage: "building.2.fill") }
                            .buttonStyle(BoutonGris())
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 30)
            }
            .background(Color.fond.ignoresSafeArea())
            .navigationTitle(salut)
            .refreshable { await store.actualiser(manuel: true) }
        }
    }
}

struct Chiffre: View {
    let n: Int
    let label: String
    let couleur: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(n)").font(.system(size: 40, weight: .bold, design: .rounded)).foregroundColor(couleur)
                Text(label).font(.system(size: 14, weight: .semibold)).foregroundColor(.texte3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.carte)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct Rangee: View {
    let titre: String
    let offres: [Offre]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TitreSection(titre: titre)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(offres) { o in MiniCarte(offre: o) }
                }
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, -16)
        }
    }
}

// MARK: - Offres

struct Filtre: Identifiable {
    let id: String
    let nom: String
}

struct VueOffres: View {
    @EnvironmentObject var store: AppStore
    @State private var filtre = "toutes"
    @State private var recherche = ""

    private let filtres: [Filtre] = [
        Filtre(id: "toutes", nom: "Toutes"), Filtre(id: "nouvelles", nom: "Nouvelles"), Filtre(id: "prio1", nom: "Prio 1"),
        Filtre(id: "concession", nom: "Concession"), Filtre(id: "cdi", nom: "CDI"), Filtre(id: "interim", nom: "Intérim"),
        Filtre(id: "postulees", nom: "Postulées"), Filtre(id: "ecartees", nom: "Écartées")]

    private func garde(_ o: Offre, _ f: String) -> Bool {
        let st = store.statut(.offre, o.id)
        switch f {
        case "nouvelles": return publication(o).nouveau && st != "ecartee"
        case "prio1": return o.prio == 1 && st != "ecartee"
        case "concession": return (o.type + " " + o.entreprise).lowercased().contains("concession") && st != "ecartee"
        case "cdi": return o.contrat.lowercased().contains("cdi") && st != "ecartee"
        case "interim": return o.contrat.lowercased().range(of: "int[ée]rim", options: .regularExpression) != nil && st != "ecartee"
        case "postulees": return ["postule", "relance", "entretien", "refus"].contains(st)
        case "ecartees": return st == "ecartee"
        default: return !["ecartee", "refus"].contains(st)
        }
    }

    private func correspond(_ o: Offre) -> Bool {
        let q = recherche.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return true }
        let t = [o.poste, o.entreprise, o.ville, o.contrat, o.type, o.note, o.experience].joined(separator: " ")
        return q.split(separator: " ").allSatisfy { t.range(of: String($0), options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    var body: some View {
        let liste = store.trier(store.data.offres.filter { garde($0, filtre) && correspond($0) })
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filtres) { f in
                                let n = store.data.offres.filter { garde($0, f.id) }.count
                                Button {
                                    withAnimation(.easeOut(duration: 0.2)) { filtre = f.id }
                                } label: {
                                    HStack(spacing: 5) {
                                        Text(f.nom).font(.system(size: 14, weight: .semibold))
                                        Text("\(n)").font(.system(size: 12, weight: .semibold)).opacity(0.55)
                                    }
                                    .foregroundColor(filtre == f.id ? .black : .white)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(filtre == f.id ? Color.white : Color.carte2)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.horizontal, -16)

                    Text("Expérience demandée : vert = ça colle, jaune = proche, rouge = demande plus.")
                        .font(.system(size: 13)).foregroundColor(.texte3)

                    if liste.isEmpty {
                        Vide(titre: "Aucune offre ici", texte: "Change de filtre ou efface la recherche.")
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(liste) { o in CarteOffre(offre: o) }
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 30)
            }
            .background(Color.fond.ignoresSafeArea())
            .navigationTitle("Offres")
            .searchable(text: $recherche, prompt: "Ville, marque, mot…")
            .refreshable { await store.actualiser(manuel: true) }
        }
    }
}

struct Vide: View {
    let titre: String
    let texte: String
    var body: some View {
        VStack(spacing: 6) {
            Text(titre).font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
            Text(texte).font(.system(size: 14)).foregroundColor(.texte3).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .background(Color.carte)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Marché caché

struct VueMarche: View {
    @EnvironmentObject var store: AppStore
    @State private var filtre = "tous"
    @State private var recherche = ""
    private let filtresMarche: [Filtre] = [
        Filtre(id: "tous", nom: "Toutes"), Filtre(id: "contacter", nom: "À contacter"), Filtre(id: "envoyees", nom: "Envoyées"),
        Filtre(id: "concessions", nom: "Concessions"), Filtre(id: "centres", nom: "Centres auto")]

    private func garde(_ e: Entreprise) -> Bool {
        let st = store.statut(.ent, e.id)
        let okF: Bool
        switch filtre {
        case "contacter": okF = st == "a_contacter"
        case "envoyees": okF = st != "a_contacter"
        case "concessions": okF = e.type.lowercased().contains("concession")
        case "centres": okF = e.type.lowercased().contains("centre")
        default: okF = true
        }
        let q = recherche.trimmingCharacters(in: .whitespaces)
        let t = [e.nom, e.marque, e.ville, e.type].joined(separator: " ")
        return okF && (q.isEmpty || t.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil)
    }

    var body: some View {
        let liste = store.data.entreprises.filter(garde).sorted { ($0.km ?? 99) < ($1.km ?? 99) }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Beaucoup de postes ne sont jamais publiés. Ces entreprises sont près de chez toi : candidature spontanée, ou passage sur place avec ton CV.")
                        .font(.system(size: 14)).foregroundColor(.texte2)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filtresMarche) { f in
                                Button { withAnimation(.easeOut(duration: 0.2)) { filtre = f.id } } label: {
                                    Text(f.nom).font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(filtre == f.id ? .black : .white)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(filtre == f.id ? Color.white : Color.carte2)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.horizontal, -16)
                    if liste.isEmpty {
                        Vide(titre: "Rien ici", texte: "Change de filtre.")
                    } else {
                        LazyVStack(spacing: 14) { ForEach(liste) { e in CarteEntreprise(ent: e) } }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 30)
            }
            .background(Color.fond.ignoresSafeArea())
            .navigationTitle("Marché caché")
            .searchable(text: $recherche, prompt: "Nom, marque, ville…")
        }
    }
}

// MARK: - Suivi

struct VueSuivi: View {
    @EnvironmentObject var store: AppStore

    struct Ligne: Identifiable {
        let id: String
        let kind: Kind
        let titre: String
        let sous: String
        let date: String
        let depuis: Int
        let statut: String
    }

    var lignes: [Ligne] {
        var out: [Ligne] = []
        for o in store.data.offres {
            guard let s = store.offres[o.id], !["a_traiter", "ecartee"].contains(s.statut) else { continue }
            out.append(Ligne(id: "o" + o.id, kind: .offre, titre: o.poste, sous: o.entreprise + " · " + o.ville,
                             date: s.dateCandidature ?? s.dates.values.sorted().last ?? "", depuis: Dates.daysSince(s.dates[s.statut]), statut: s.statut))
        }
        for e in store.data.entreprises {
            guard let s = store.ents[e.id], s.statut != "a_contacter" else { continue }
            out.append(Ligne(id: "e" + e.id, kind: .ent, titre: e.nom, sous: "Candidature spontanée · " + e.ville,
                             date: s.dates["envoyee"] ?? s.dates.values.sorted().last ?? "", depuis: Dates.daysSince(s.dates[s.statut]), statut: s.statut))
        }
        return out.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    let l = lignes
                    if l.isEmpty {
                        Vide(titre: "Pas encore de candidature", texte: "Appuie sur « Postuler » sur une offre : elle apparaîtra ici avec la date.")
                    }
                    ForEach(l) { x in
                        let c = conseil(kind: x.kind, statut: x.statut, jours: x.depuis)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(x.kind == .offre ? "OFFRE" : "SPONTANÉE").font(.system(size: 11, weight: .bold)).tracking(0.6).foregroundColor(.texte3)
                                    Text(x.titre).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                                    Text(x.sous).font(.system(size: 14)).foregroundColor(.texte2)
                                }
                                Spacer()
                                if Dates.parse(x.date) != nil {
                                    Text(Dates.court(x.date)).font(.system(size: 13, weight: .semibold)).foregroundColor(.texte3)
                                }
                            }
                            HStack {
                                MenuStatut(kind: x.kind, id: String(x.id.dropFirst()))
                                Spacer()
                                Text(x.depuis <= 0 ? "aujourd'hui" : "depuis \(x.depuis) j").font(.system(size: 13)).foregroundColor(.texte3)
                            }
                            if !c.texte.isEmpty {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: c.alerte ? "bell.badge.fill" : "lightbulb.fill").foregroundColor(c.alerte ? .jaune : .accent)
                                    Text(c.texte).font(.system(size: 14)).foregroundColor(.texte2).fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(12)
                                .background(c.alerte ? Color.jaune.opacity(0.13) : Color.carte2)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                        .padding(16)
                        .background(Color.carte)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 30)
            }
            .background(Color.fond.ignoresSafeArea())
            .navigationTitle("Suivi")
        }
    }
}

// MARK: - Profil

struct VueProfil: View {
    @EnvironmentObject var store: AppStore
    @State private var importCV = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Panneau {
                        HStack(spacing: 14) {
                            Text("IH").font(.system(size: 26, weight: .bold)).foregroundColor(.white)
                                .frame(width: 64, height: 64)
                                .background(LinearGradient(colors: [Color.carte2, Color.carte], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(Profil.nom).font(.system(size: 19, weight: .bold)).foregroundColor(.white)
                                Text("Mécanicien auto · CAP validé").font(.system(size: 14)).foregroundColor(.texte2)
                            }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Label(Profil.ville, systemImage: "house.fill")
                            Label(Profil.tel, systemImage: "phone.fill")
                            Label(Profil.mail, systemImage: "envelope.fill")
                            Label("Permis B", systemImage: "car.fill")
                        }
                        .font(.system(size: 15)).foregroundColor(.texte2)
                    }

                    Panneau(titre: "Ce que je sais faire") {
                        Flux(espace: 8) {
                            ForEach(Profil.competences, id: \.self) { c in
                                let ok = Profil.cochees.contains(c)
                                HStack(spacing: 6) {
                                    if ok { Image(systemName: "checkmark.circle.fill").foregroundColor(.vert) }
                                    Text(c).font(.system(size: 14, weight: ok ? .semibold : .medium))
                                }
                                .foregroundColor(ok ? .black : .texte2)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(ok ? Color.white : Color.carte2)
                                .clipShape(Capsule())
                            }
                        }
                        Text("Objectif : évoluer vers la grosse mécanique et le diagnostic.").font(.system(size: 14)).foregroundColor(.texte2)
                    }

                    Panneau(titre: "Mon parcours") {
                        Etape(icone: "wrench.and.screwdriver.fill", titre: "1 an et demi de mécanique perso", texte: "Vidanges, train avant, disques et plaquettes, berceau, kit embrayage.")
                        Etape(icone: "graduationcap.fill", titre: "CAP Maintenance des véhicules (validé)", texte: "Apprentissage dans un garage Range Rover / BMW : distributions, décaissage, dépose moteur, embrayage, boîte.")
                        Etape(icone: "star.fill", titre: "Autonome en fin de CAP", texte: "Décaissage et dépose moteur. 3 distributions seul : 1.7 CDTI, 1.4 HDi, 3.0 V6.")
                    }

                    Panneau(titre: "Mon CV") {
                        Text(store.cvNom.map { "Enregistré : \($0)" } ?? "Ajoute ton CV en PDF : il sera joint automatiquement aux candidatures envoyées depuis l'appli.")
                            .font(.system(size: 14)).foregroundColor(.texte2)
                        Button { importCV = true } label: { Label(store.cvNom == nil ? "Ajouter mon CV (PDF)" : "Remplacer mon CV", systemImage: "doc.badge.plus") }
                            .buttonStyle(BoutonBlanc())
                    }

                    Panneau(titre: "Ce que je cherche") {
                        Flux(espace: 8) {
                            ForEach(["Service rapide", "Débutant accepté / ~1 an", "CDI ou intérim", "Idéal : concession"], id: \.self) { t in
                                Text(t).font(.system(size: 14, weight: .medium)).foregroundColor(.texte2)
                                    .padding(.horizontal, 12).padding(.vertical, 7).background(Color.carte2).clipShape(Capsule())
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Profil.zone.indices, id: \.self) { i in
                                let z = Profil.zone[i]
                                HStack {
                                    Image(systemName: z.1 == "chez moi" ? "house.circle.fill" : "mappin.circle").foregroundColor(z.1 == "chez moi" ? .white : .texte3)
                                    Text(z.0).foregroundColor(.white)
                                    Spacer()
                                    Text(z.1).foregroundColor(.texte3)
                                }
                                .font(.system(size: 15))
                            }
                        }
                    }

                    Panneau(titre: "Offres") {
                        Text("Mises à jour chaque matin à 7 h 47. Dernière mise à jour : \(Dates.maj(store.data.maj)).")
                            .font(.system(size: 14)).foregroundColor(.texte2)
                        Button {
                            Task { await store.actualiser(manuel: true) }
                        } label: { Label("Actualiser maintenant", systemImage: "arrow.clockwise") }
                            .buttonStyle(BoutonGris())
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 30)
            }
            .background(Color.fond.ignoresSafeArea())
            .navigationTitle("Profil")
            .fileImporter(isPresented: $importCV, allowedContentTypes: [UTType.pdf]) { res in
                if case .success(let url) = res { store.importerCV(depuis: url) }
            }
        }
    }
}

struct Panneau<Contenu: View>: View {
    var titre: String? = nil
    @ViewBuilder let contenu: () -> Contenu
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let titre { Text(titre).font(.system(size: 20, weight: .bold)).foregroundColor(.white) }
            contenu()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.carte)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct Etape: View {
    let icone: String
    let titre: String
    let texte: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icone).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                .frame(width: 36, height: 36).background(Color.carte2).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(titre).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                Text(texte).font(.system(size: 14)).foregroundColor(.texte2).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Détail d'une offre

struct DetailOffre: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let offre: Offre
    @State private var note = ""
    @State private var lettre: Offre?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        BadgePrio(prio: offre.prio)
                        Text(offre.poste).font(.system(size: 28, weight: .bold)).foregroundColor(.white)
                        Text(offre.entreprise).font(.system(size: 17, weight: .medium)).foregroundColor(.texte2)
                        Label([offre.ville, distance(offre.km)].filter { !$0.isEmpty }.joined(separator: " · "), systemImage: "mappin.and.ellipse")
                            .font(.system(size: 14)).foregroundColor(.texte3)
                        LignePublication(offre: offre)
                    }
                    BlocXP(texte: offre.experience)
                    Flux {
                        if !offre.contrat.isEmpty { Pastille(texte: offre.contrat, icone: "doc.text") }
                        if !offre.type.isEmpty { Pastille(texte: offre.type, icone: "building.2") }
                        if !offre.salaire.isEmpty { Pastille(texte: offre.salaire, icone: "eurosign", couleur: .ciel, fond: Color.ciel.opacity(0.14)) }
                    }
                    if !offre.note.isEmpty { Text(offre.note).font(.system(size: 15)).foregroundColor(.texte2) }
                    HStack { MenuStatut(kind: .offre, id: offre.id); Spacer() }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mes notes").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                        TextField("Appel, nom du chef d'atelier, horaires…", text: $note, axis: .vertical)
                            .lineLimit(3...8)
                            .padding(12)
                            .background(Color.carte2)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundColor(.white)
                    }
                    Button { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { store.postuler(offre) } } label: {
                        Label("Postuler", systemImage: "paperplane.fill")
                    }.buttonStyle(BoutonBlanc())
                    Button { lettre = offre } label: { Label("Ma lettre", systemImage: "square.and.pencil") }.buttonStyle(BoutonGris())
                }
                .padding(16)
            }
            .background(Color.fond.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } } }
            .onAppear { note = store.offres[offre.id]?.note ?? "" }
            .onDisappear {
                if note != (store.offres[offre.id]?.note ?? "") { store.modifier(.offre, offre.id) { $0.note = note } }
            }
            .sheet(item: $lettre) { o in VueLettre(kind: .offre, id: o.id) }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Lettre de motivation

struct VueLettre: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let kind: Kind
    let id: String
    @State private var texte = ""
    @State private var regenerer = false

    private var titre: String {
        kind == .offre ? (store.data.offres.first { $0.id == id }?.entreprise ?? "Lettre") : (store.data.entreprises.first { $0.id == id }?.nom ?? "Lettre")
    }

    private func modele() -> String {
        if kind == .offre, let o = store.data.offres.first(where: { $0.id == id }) { return Lettre.pourOffre(o) }
        if kind == .ent, let e = store.data.entreprises.first(where: { $0.id == id }) { return Lettre.pourEntreprise(e) }
        return ""
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextEditor(text: $texte)
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                    .scrollContentBackground(.hidden)
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(16)
                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = texte
                        store.toast("Lettre copiée")
                    } label: { Label("Copier", systemImage: "doc.on.doc") }.buttonStyle(BoutonGris())
                    ShareLink(item: texte) { Label("Partager", systemImage: "square.and.arrow.up") }.buttonStyle(BoutonGris())
                }
                .padding(.horizontal, 16).padding(.bottom, 12)
            }
            .background(Color.fond.ignoresSafeArea())
            .navigationTitle(titre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        store.modifier(kind, id) { s in s.lettre = texte; s.lettreDate = Dates.today() }
                        store.toast("Lettre enregistrée")
                        dismiss()
                    }.fontWeight(.semibold)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Repartir du modèle") { regenerer = true }.foregroundColor(.texte2)
                }
            }
            .confirmationDialog("Remplacer ta lettre par le modèle ?", isPresented: $regenerer, titleVisibility: .visible) {
                Button("Repartir du modèle", role: .destructive) { texte = modele() }
            }
            .onAppear { texte = store.suivi(kind, id).lettre ?? modele() }
        }
        .preferredColorScheme(.dark)
    }
}
