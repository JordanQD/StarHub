import SwiftUI

// MARK: - Identité du compte, en pied de barre latérale

/// Qui est connecté, en bas de la colonne. Motif de la référence visuelle de
/// l'auteur (2026-11-19) : l'identité tient une ligne au pied, pas une carte
/// en tête — l'Accueil est une page de la liste comme les autres.
///
/// Ce que la carte précédente portait en plus (compte de mods actifs, version
/// de SMAPI, profil actif en pastille) n'est pas perdu, seulement déplacé :
/// les deux chiffres vivent sur l'Accueil et sur « Alertes système », qui les
/// expliquent. Le profil actif reste ici, en sous-titre, parce qu'il change
/// le parc.
///
/// Un `Button` à fond transparent : la règle « la ligne choisie se voit par
/// la `List` » vaut aussi ici, et l'identité n'est jamais « la page courante ».
struct SidebarAccountBar: View {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    /// Ramène à l'Accueil — la page que cette identité représente.
    let onTap: () -> Void

    /// Profil actif résolu depuis `activeProfileId`, ou `nil`.
    private var activeProfile: ModProfile? {
        vm.activeProfileId.flatMap { id in vm.modProfiles.first(where: { $0.id == id }) }
    }

    private var username: String {
        vm.steamUsername.isEmpty
            ? localization.L(L10n.Main.playerFallback)
            : vm.steamUsername
    }

    /// Le profil actif s'il y en a un — il change le parc, donc il mérite la
    /// ligne ; sinon la nature du compte, comme avant.
    private var subtitle: String {
        activeProfile?.name ?? localization.L(L10n.Main.steamAccount)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppDesign.Spacing.sm) {
                avatarView
                VStack(alignment: .leading, spacing: 1) {
                    Text(username)
                        .font(AppDesign.Font.body(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(subtitle)
                        .font(AppDesign.Font.iconXS)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppDesign.Spacing.md)
            .padding(.vertical, AppDesign.Spacing.sm)
            // Toute la ligne répond au clic, pas seulement le texte.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusRing(cornerRadius: AppDesign.Radius.md)
        .help(localization.L(L10n.Main.home))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    /// Avatar Steam s'il est connu, silhouette système sinon.
    @ViewBuilder
    private var avatarView: some View {
        if let avatarPath = vm.steamAvatarPath,
           let nsImage = NSImage(contentsOfFile: avatarPath) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 26, height: 26)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 26, height: 26)
                .foregroundStyle(.secondary)
        }
    }
}
