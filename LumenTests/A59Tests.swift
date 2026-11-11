import Foundation
import Testing
@testable import Lumen

/// A59 (K36): Spotify through the server. `connections` goes with `/answer` only when connected; the callback's status
/// becomes a line; `done.server_tool` is read.
@MainActor
@Suite struct A59Tests {
    @Test func connectionsSurviveClampedAndGoInTheBody() throws {
        var context = AnswerContext()
        context.connections = ["spotify"]
        #expect(context.clamped.connections == ["spotify"], "A48's lesson: a new field must be in `clamped`")
        let data = CloudAnswerProvider.encodeBody(AnswerRequest(fragment: "spela plugg", mode: "auto", language: "sv", context: context.clamped))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["connections"] as? [String] == ["spotify"])
        let plain = try #require(try JSONSerialization.jsonObject(with: CloudAnswerProvider.encodeBody(
            AnswerRequest(fragment: "x", mode: "auto", language: "sv"))) as? [String: Any])
        #expect(plain["connections"] == nil)
    }

    @Test func onlyAConnectedSpotifyIsSent() {
        let defaults = UserDefaults(suiteName: "a59-\(UUID().uuidString)")!
        let spotify = SpotifyConnection(client: nil, defaults: defaults)
        #expect(spotify.connections.isEmpty)
        defaults.set(true, forKey: SpotifyConnection.connectedKey)
        #expect(SpotifyConnection(client: nil, defaults: defaults).connections == ["spotify"])
    }

    @Test func theCallbackSaysWhatHappened() throws {
        let ok = try #require(URL(string: "lumen://connect?provider=spotify&status=ok"))
        let premium = try #require(URL(string: "lumen://connect?provider=spotify&status=premium_required"))
        let denied = try #require(URL(string: "lumen://connect?provider=spotify&status=denied"))
        #expect(SpotifyConnection.notice(for: ok) == nil)
        #expect(SpotifyConnection.notice(for: premium)?.contains("Premium") == true)
        #expect(SpotifyConnection.notice(for: denied)?.contains("nej") == true)
    }

    @Test func doneSaysWhichServerToolRan() throws {
        let done = #"{"answered":true,"server_tool":{"name":"spotify_play","status":"ok","playing":"Plugg"}}"#
        guard case .done(let decoded)? = try AnswerSSEDecoder.decode(SSEEvent(name: "done", data: done)) else {
            Issue.record("not a done event")
            return
        }
        #expect(decoded.serverTool == ServerToolResult(name: "spotify_play", status: "ok", playing: "Plugg"))
    }

    @Test func theStatusDecodes() throws {
        let json = #"{"connections":[{"provider":"spotify","premium":true}],"available":{"spotify":true}}"#
        let status = try JSONDecoder().decode(ConnectClient.Status.self, from: Data(json.utf8))
        #expect(status.connections.first?.premium == true && status.available?["spotify"] == true)
    }
}
