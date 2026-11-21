import SwiftUI

/// A88 (D161): "Vilken årskurs?" in Nytt prov, with Hoppa över. The choice is saved in the profile and chosen again
/// next time; it goes to K45 as `grade` (K52: the profile's codes, "y8", "gy1" …). Skipped = the server reads the
/// level from the material.
struct GradeChoice: View {
    @Binding var grade: StudyProfile.Grade?

    static let choices: [StudyProfile.Grade] = [.y7, .y8, .y9, .gy1, .gy2, .gy3, .university]

    static func label(_ grade: StudyProfile.Grade) -> String {
        switch grade {
        case .y6: String(localized: "åk 6")
        case .y7: String(localized: "åk 7")
        case .y8: String(localized: "åk 8")
        case .y9: String(localized: "åk 9")
        case .gy1: String(localized: "Gy 1")
        case .gy2: String(localized: "Gy 2")
        case .gy3: String(localized: "Gy 3")
        case .university: String(localized: "Högskola")
        case .other: String(localized: "Annan")
        }
    }

    var body: some View {
        Section {
            Picker("Vilken årskurs?", selection: $grade) {
                Text("Hoppa över").tag(StudyProfile.Grade?.none)
                ForEach(Self.choices, id: \.self) { Text(Self.label($0)).tag(StudyProfile.Grade?.some($0)) }
            }
        } footer: {
            Text(grade == nil ? String(localized: "EarMind läser nivån ur materialet.") : String(localized: "Frågorna och svaren passar årskursen."))
        }
    }
}
