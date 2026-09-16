//
//  FeedbackMail.swift
//  GagaeSsi
//
//  피드백 보내기 — 기본 메일 앱을 여는 mailto 링크 구성 (순수 로직)
//

import Foundation
import UIKit

enum FeedbackMail {
    /// 문의 받을 주소.
    ///
    /// ⚠️ 앱에 포함되어 배포되므로 **사용자에게 공개되는 주소**다.
    /// 개인 메일과 분리하고 싶으면 이 한 줄만 바꾸면 된다.
    static let supportEmail = "joyh0808@gmail.com"

    static let subject = "[가계씨] 피드백"

    /// 답장할 때 필요한 환경 정보를 미리 채워둔다.
    /// 사용자가 직접 적게 하면 대부분 빠뜨려서 재문의가 필요해진다.
    static func body(appVersion: String, build: String,
                     systemVersion: String, deviceModel: String) -> String {
        """


        ──────────────
        아래 정보는 문제 확인에 사용돼요. 지우셔도 됩니다.
        앱 버전: \(appVersion) (\(build))
        iOS: \(systemVersion)
        기기: \(deviceModel)
        """
    }

    /// 현재 기기 정보로 mailto URL을 만든다. 만들 수 없으면 nil.
    static func url(bundle: Bundle = .main, device: UIDevice = .current) -> URL? {
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return makeURL(to: supportEmail,
                       subject: subject,
                       body: body(appVersion: version, build: build,
                                  systemVersion: device.systemVersion,
                                  deviceModel: modelIdentifier()))
    }

    /// mailto URL 조립. 제목·본문은 퍼센트 인코딩한다.
    static func makeURL(to email: String, subject: String, body: String) -> URL? {
        // mailto 파라미터는 쿼리 규칙보다 좁아서, & 와 + 까지 직접 인코딩해야 메일 앱이 제대로 읽는다
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+")

        guard !email.isEmpty,
              let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: allowed),
              let encodedBody = body.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }
        return URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)")
    }

    /// 기기 모델 식별자 (예: iPhone16,1). 사람이 읽는 이름은 아니지만 문제 재현에 충분하다.
    static func modelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) { String(validatingUTF8: $0) }
        }
        return identifier ?? UIDevice.current.model
    }
}
