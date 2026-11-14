import SwiftUI

/// A88 (D161): "Vilken årskurs?" in Nytt prov, with Hoppa över. The choice is saved in the profile and chosen again
/// next time; it goes to K45 as `grade` (K52: the profile's codes, "y8", "gy1" …). Skipped = the server reads the
/// level from the material.
struct GradeChoice: View {
    @Binding var grade: StudyProfile.Grade?

    static let choices: [StudyProfile.Grade] = [.y7, .y8, .y9, .gy1, .gy2, .gy3, .university]

    static func label(_ grade: StudyProfile.Grade) -> String {
        switch grade {
        case .y6: "åk 6"
        case .y7: "åk 7"
        case .y8: "åk 8"
        case .y9: "åk 9"
        case .gy1: "Gy 1"
        case .gy2: "Gy 2"
        case .gy3: "Gy 3"
        case .university: "Högskola"
        case .other: "Annan"
        }
    }

    var body: some View {
        Section {
            Picker("Vilken årskurs?", selection: $grade) {
                Text("Hoppa över").tag(StudyProfile.Grade?.none)
                ForEach(Self.choices, id: \.self) { Text(Self.label($0)).tag(StudyProfile.Grade?.some($0)) }
            }
        } footer: {
            Text(grade == nil ? "EarMind läser nivån ur materialet." : "Frågorna och svaren passar årskursen.")
        }
    }
}
