import Foundation
import Testing
@testable import NotchPlayer

@Test func 버전은_숫자끼리_비교한다() {
    #expect(isNewer("0.1.4", than: "0.1.3"))
    #expect(isNewer("v0.1.4", than: "0.1.3"))
    #expect(isNewer("0.1.10", than: "0.1.9"))
    #expect(isNewer("0.2", than: "0.1.9"))
    #expect(isNewer("1.0.0", than: "0.9.9"))
}

// 같거나 낮은 버전으로 바꾸면 다시 실행할 때마다 또 받으므로 절대 새 버전으로 보면 안 된다
@Test func 같거나_낮거나_이상한_버전은_새_버전이_아니다() {
    #expect(!isNewer("0.1.3", than: "0.1.3"))
    #expect(!isNewer("v0.1.3", than: "0.1.3"))
    #expect(!isNewer("1.0", than: "1.0.0"))
    #expect(!isNewer("0.1.2", than: "0.1.3"))
    #expect(!isNewer("0.1.9", than: "0.1.10"))
    #expect(!isNewer("0.2.0-beta", than: "0.1.3"))
    #expect(!isNewer("", than: "0.1.3"))
    #expect(!isNewer("0..4", than: "0.1.3"))
}

@Test func 릴리스_응답에서_태그와_zip_주소와_해시를_읽는다() throws {
    let json = """
    {
      "tag_name": "v0.1.4",
      "name": "NotchPlayer v0.1.4",
      "assets": [
        {
          "name": "NotchPlayer-v0.1.4.zip",
          "browser_download_url": "https://github.com/Mm-767/NotchPlayer/releases/download/v0.1.4/NotchPlayer-v0.1.4.zip",
          "digest": "sha256:abc123",
          "size": 822338
        },
        {
          "name": "NotchPlayer-v0.1.4.dmg",
          "browser_download_url": "https://github.com/Mm-767/NotchPlayer/releases/download/v0.1.4/NotchPlayer-v0.1.4.dmg",
          "digest": null
        }
      ]
    }
    """

    let release = try JSONDecoder().decode(Release.self, from: Data(json.utf8))

    #expect(release.tagName == "v0.1.4")
    #expect(release.assets.count == 2)
    #expect(release.assets[0].name == "NotchPlayer-v0.1.4.zip")
    #expect(release.assets[0].browserDownloadURL.lastPathComponent == "NotchPlayer-v0.1.4.zip")
    #expect(release.assets[0].digest == "sha256:abc123")
    #expect(release.assets[1].digest == nil)
}
