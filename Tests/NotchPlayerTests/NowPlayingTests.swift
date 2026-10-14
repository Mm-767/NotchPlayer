import Testing
@testable import NotchPlayer

@MainActor
@Test func 마지막으로_재생을_시작한_앱을_보여준다() {
    let nowPlaying = NowPlaying()

    nowPlaying.update(source: "spotify", state: "Playing", title: "A", artist: "a")
    nowPlaying.update(source: "music", state: "Playing", title: "B", artist: "b")
    #expect(nowPlaying.title == "B")

    // 표시 중이 아닌 Spotify가 멈춰도 Music 곡이 그대로 보인다
    nowPlaying.update(source: "spotify", state: "Paused", title: "A", artist: "a")
    #expect(nowPlaying.title == "B")

    // 표시 중인 Music이 멈추면 곡 정보는 남겨 둔다
    nowPlaying.update(source: "music", state: "Paused", title: "B", artist: "b")
    #expect(nowPlaying.title == "B")

    // 표시 중인 Music이 종료되면 비운다
    nowPlaying.update(source: "music", state: "Stopped", title: "", artist: "")
    #expect(nowPlaying.title == "")

    // 아무것도 표시 중이 아니면 일시정지 상태라도 보여준다
    nowPlaying.update(source: "spotify", state: "Paused", title: "A", artist: "a")
    #expect(nowPlaying.title == "A")
}
