import Foundation
import Testing
@testable import Lumen

/// A58 (K36): `call_contact` finds the contact the spoken name means and dials only a real number; `music_open` builds
/// Spotify's search.
@MainActor
@Suite struct A58Tests {
    private static let contacts = [
        PhoneCall.Contact(given: "Anna", family: "Stenlund", nickname: "Mamma", organization: "",
                          numbers: [(label: "_$!<Home>!$_", number: "08-123 45 67"), (label: "_$!<Mobile>!$_", number: "070-111 22 33")]),
        PhoneCall.Contact(given: "Elin", family: "Svensson", nickname: "", organization: "", numbers: [(label: "iPhone", number: "+46 70 222 33 44")]),
        PhoneCall.Contact(given: "Elin", family: "Berg", nickname: "", organization: "", numbers: [(label: "", number: "0703334455")]),
        PhoneCall.Contact(given: "", family: "", nickname: "", organization: "Tandläkare Centrum", numbers: [(label: "work", number: "08-555 00 00")]),
    ]

    @Test func theNicknameFindsMumAndHerMobile() {
        let found = PhoneCall.matches("mamma", in: Self.contacts)
        #expect(found.count == 1)
        #expect(found.first?.bestNumber == "0701112233", "the mobile number first")
        #expect(PhoneCall.matches("min mamma", in: Self.contacts).count == 1)
    }

    @Test func twoElinsAreAskedAbout() {
        let found = PhoneCall.matches("Elin", in: Self.contacts)
        #expect(found.count == 2)
        #expect(Set(found.map(\.displayName)) == ["Elin Svensson", "Elin Berg"])
        #expect(PhoneCall.matches("Elin Berg", in: Self.contacts).count == 1)
    }

    @Test func theDefiniteFormFindsTheOrganisation() {
        let found = PhoneCall.matches("tandläkaren", in: Self.contacts)
        #expect(found.count == 1 && found.first?.bestNumber == "085550000")
        #expect(PhoneCall.matches("pappa", in: Self.contacts).isEmpty)
    }

    @Test func onlyRealNumbersAreDialled() {
        #expect(PhoneCall.dialable("070-123 45 67") == "0701234567")
        #expect(PhoneCall.dialable("+46 70 123") == "+4670123")
        #expect(PhoneCall.dialable("ab") == nil)
        #expect(PhoneCall.dialable("12") == nil)
        #expect(PhoneCall.url("0701234567")?.absoluteString == "tel://0701234567")
    }

    @Test func musicOpensASearch() {
        #expect(MusicSearch.spotifyURL("lugn pluggmusik")?.absoluteString == "spotify:search:lugn%20pluggmusik")
        #expect(MusicSearch.webURL("lugn pluggmusik")?.absoluteString == "https://open.spotify.com/search/lugn%20pluggmusik")
    }

    @Test func bothToolsAreOffered() {
        #expect(PhoneTool(rawValue: "call_contact") == .callContact)
        #expect(PhoneTool(rawValue: "music_open") == .musicOpen)
    }
}
