import Foundation

/// Tiny EN / FR-CA resolver. Content lives next to the code, matching NATURaL.
public enum L10n: Sendable {
    public static var prefersFrench: Bool {
        Locale.current.language.languageCode?.identifier.hasPrefix("fr") == true
    }

    public static func pick(en: String, fr: String) -> String {
        prefersFrench ? fr : en
    }
}

public struct LocalizedCopy: Equatable, Sendable, Hashable, Codable {
    public var en: String
    public var fr: String

    public init(en: String, fr: String) {
        self.en = en
        self.fr = fr
    }

    public var resolved: String { L10n.pick(en: en, fr: fr) }
}

public enum ExergyCopy: Sendable {
    public static let usage = LocalizedCopy(en: "Usage", fr: "Usage")
    public static let accounts = LocalizedCopy(en: "Accounts", fr: "Comptes")
    public static let addAccount = LocalizedCopy(en: "Add account", fr: "Ajouter un compte")
    public static let settings = LocalizedCopy(en: "Settings", fr: "Réglages")
    public static let remaining = LocalizedCopy(en: "Remaining", fr: "Restant")
    public static let remainingPlenty = LocalizedCopy(en: "Plenty remaining", fr: "Beaucoup restant")
    public static let remainingWatch = LocalizedCopy(en: "Running down", fr: "Ça descend")
    public static let remainingLow = LocalizedCopy(en: "Low remaining", fr: "Peu restant")
    public static let used = LocalizedCopy(en: "Used", fr: "Utilisé")
    public static let pace = LocalizedCopy(en: "Pace", fr: "Rythme")
    public static let provider = LocalizedCopy(en: "Provider", fr: "Fournisseur")
    public static let nickname = LocalizedCopy(en: "Nickname", fr: "Surnom")
    public static let oauthUnavailable = LocalizedCopy(
        en: "OAuth client ID is not in this build. Paste an API key, or wait for App Store credentials.",
        fr: "L’identifiant OAuth n’est pas dans cette build. Collez une clé API, ou attendez les identifiants App Store."
    )
    public static let floatingHUD = LocalizedCopy(en: "Floating remaining HUD", fr: "HUD flottant du restant")
    public static let floatingHUDHint = LocalizedCopy(
        en: "Always-on-top remaining meters. Hide when you want only the menu bar.",
        fr: "Jauges restantes toujours au premier plan. Masquez pour ne garder que la barre de menus."
    )
    public static let refresh = LocalizedCopy(en: "Refresh meters", fr: "Actualiser les jauges")
    public static let keyRequired = LocalizedCopy(en: "Paste a key before saving.", fr: "Collez une clé avant d’enregistrer.")
    public static let saveKey = LocalizedCopy(en: "Save key", fr: "Enregistrer la clé")
    public static let glanceTitle = LocalizedCopy(en: "Remaining", fr: "Restant")
    public static let ahead = LocalizedCopy(en: "Ahead of pace", fr: "En avance")
    public static let onPace = LocalizedCopy(en: "On pace", fr: "Dans les temps")
    public static let behind = LocalizedCopy(en: "Behind pace", fr: "En retard")
    public static let unknown = LocalizedCopy(en: "No reading", fr: "Aucune lecture")
    public static let iCloudOn = LocalizedCopy(en: "iCloud sync on", fr: "Sync iCloud activée")
    public static let iCloudOff = LocalizedCopy(en: "On this device only", fr: "Sur cet appareil seulement")
    public static let signInICloud = LocalizedCopy(
        en: "Sign in to iCloud in System Settings to sync meters.",
        fr: "Connectez-vous à iCloud dans Réglages pour synchroniser les jauges."
    )
    public static let secretsStayHere = LocalizedCopy(
        en: "Tokens stay in the Keychain. Meters sync. Secrets never do.",
        fr: "Les jetons restent dans le Trousseau. Les jauges se synchronisent. Les secrets, jamais."
    )
    public static let demoMode = LocalizedCopy(en: "Demo meters", fr: "Jauges de démonstration")
    public static let demoModeHint = LocalizedCopy(
        en: "Sample rings for App Review and first launch. Not your accounts.",
        fr: "Anneaux d’exemple pour la revue et le premier lancement. Pas vos comptes."
    )
    public static let connectWithOAuth = LocalizedCopy(en: "Connect with OAuth", fr: "Connecter avec OAuth")
    public static let pasteAPIKey = LocalizedCopy(en: "Paste API key", fr: "Coller une clé API")
    public static let importLocal = LocalizedCopy(en: "Import from this Mac", fr: "Importer depuis ce Mac")
    public static let emptyTitle = LocalizedCopy(en: "Nothing to burn yet", fr: "Rien à mesurer encore")
    public static let emptyBody = LocalizedCopy(
        en: "Add an account. Exergy watches remaining quota and syncs the meters through your iCloud — never the keys.",
        fr: "Ajoutez un compte. Exergie surveille le quota restant et synchronise les jauges via votre iCloud — jamais les clés."
    )
    public static let privacy = LocalizedCopy(en: "Privacy", fr: "Confidentialité")
    public static let noServer = LocalizedCopy(
        en: "No Exergy server. No analytics. Apple iCloud is the only sync path, and it is your private database.",
        fr: "Pas de serveur Exergie. Pas d’analytique. iCloud d’Apple est le seul chemin de sync, et c’est votre base privée."
    )
    public static let focus = LocalizedCopy(en: "Focus", fr: "Focus")
    public static let session = LocalizedCopy(en: "Session", fr: "Session")
    public static let week = LocalizedCopy(en: "Week", fr: "Semaine")
    public static let month = LocalizedCopy(en: "Month", fr: "Mois")
    public static let signOut = LocalizedCopy(en: "Remove account", fr: "Retirer le compte")
    public static let syncTokens = LocalizedCopy(
        en: "Sync sign-ins with iCloud Keychain",
        fr: "Synchroniser les connexions avec le Trousseau iCloud"
    )
    public static let syncTokensHint = LocalizedCopy(
        en: "Off by default. When on, OAuth tokens use Apple’s iCloud Keychain (end-to-end), not CloudKit records.",
        fr: "Désactivé par défaut. Activé, les jetons OAuth utilisent le Trousseau iCloud d’Apple (chiffré de bout en bout), pas CloudKit."
    )
}
