import Testing
@testable import NotchPlayer

// 실제 앱 이름(Spotify, Music)을 쓰면 AppleScript로 앨범아트를 물으러 가므로 가짜 이름을 쓴다
@MainActor
@Test func 마지막으로_재생을_시작한_앱을_보여준다() {
    let nowPlaying = NowPlaying()

    nowPlaying.update(source: "app1", state: "Playing", title: "A", artist: "a")
    nowPlaying.update(source: "app2", state: "Playing", title: "B", artist: "b")
    #expect(nowPlaying.title == "B")

    // 표시 중이 아닌 app1이 멈춰도 app2 곡이 그대로 보인다
    nowPlaying.update(source: "app1", state: "Paused", title: "A", artist: "a")
    #expect(nowPlaying.title == "B")

    #expect(nowPlaying.isPlaying)

    // 표시 중인 app2가 멈추면 곡 정보는 남겨 둔다
    nowPlaying.update(source: "app2", state: "Paused", title: "B", artist: "b")
    #expect(nowPlaying.title == "B")
    #expect(!nowPlaying.isPlaying)

    // 표시 중인 app2가 종료되면 비운다
    nowPlaying.update(source: "app2", state: "Stopped", title: "", artist: "")
    #expect(nowPlaying.title == "")

    // 아무것도 표시 중이 아니면 일시정지 상태라도 보여준다
    nowPlaying.update(source: "app1", state: "Paused", title: "A", artist: "a")
    #expect(nowPlaying.title == "A")
}
