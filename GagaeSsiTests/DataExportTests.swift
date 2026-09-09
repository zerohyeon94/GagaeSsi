//
//  DataExportTests.swift
//  GagaeSsi
//
//  CSV 내보내기 · 피드백 메일 테스트
//

import XCTest
@testable import GagaeSsi

final class DataExportTests: XCTestCase {
    private let cal = Calendar.current

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 30) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }
    private func record(_ title: String, _ amount: Int, _ date: Date,
                        payback: Int = 0, received: Bool = false) -> SpendingRecordModel {
        SpendingRecordModel(title: title, amount: amount, date: date, category: .cafe,
                            expectedPayback: payback, paybackReceived: received)
    }

    // MARK: - CSV 형식

    func test_헤더와_행이_최신순으로_생성된다() {
        let csv = SpendingCSVExporter.makeCSV(from: [
            record("어제 것", 1_000, date(2026, 8, 6)),
            record("오늘 것", 2_000, date(2026, 8, 7)),
        ])
        let lines = csv.components(separatedBy: "\r\n")

        XCTAssertTrue(lines[0].hasSuffix("날짜,시각,카테고리,항목,금액,내 몫,환급 예정,환급 받음"))
        XCTAssertTrue(lines[1].contains("오늘 것"), "최신 기록이 먼저")
        XCTAssertTrue(lines[2].contains("어제 것"))
    }

    /// BOM이 없으면 Excel에서 한글이 전부 깨진다
    func test_UTF8_BOM으로_시작한다() {
        let csv = SpendingCSVExporter.makeCSV(from: [record("커피", 4_000, date(2026, 8, 7))])
        XCTAssertTrue(csv.hasPrefix(SpendingCSVExporter.byteOrderMark))
        XCTAssertEqual(SpendingCSVExporter.byteOrderMark, "\u{FEFF}")
    }

    func test_날짜와_시각이_분리되어_들어간다() {
        let csv = SpendingCSVExporter.makeCSV(from: [record("점심", 9_000, date(2026, 8, 7, 13, 5))])
        XCTAssertTrue(csv.contains("2026-08-07,13:05,"))
    }

    func test_환급_정보는_있을_때만_채워진다() {
        let withPayback = SpendingCSVExporter.makeCSV(from: [
            record("교통비", 21_000, date(2026, 8, 7), payback: 5_000, received: true)])
        XCTAssertTrue(withPayback.contains("21000,21000,5000,Y"))

        let without = SpendingCSVExporter.makeCSV(from: [record("커피", 4_000, date(2026, 8, 7))])
        XCTAssertTrue(without.contains("4000,4000,,"), "환급이 없으면 두 칸은 빈 값")
    }

    /// 8만을 결제했어도 4명이 나눴으면 내 몫은 2만 — 금액과 내 몫은 다른 열이다
    func test_공용_소비는_금액과_내_몫이_따로_들어간다() {
        let shared = SpendingRecordModel(title: "저녁", amount: 80_000, date: date(2026, 8, 7),
                                         tripId: UUID(), participants: 4, paidByMe: true)
        let csv = SpendingCSVExporter.makeCSV(from: [shared])
        XCTAssertTrue(csv.contains("80000,20000,,"))
    }

    // MARK: - 이스케이프

    func test_쉼표가_있는_항목명은_따옴표로_감싼다() {
        XCTAssertEqual(SpendingCSVExporter.escape("콜라, 과자"), "\"콜라, 과자\"")
    }

    func test_따옴표는_두_번_써서_이스케이프한다() {
        XCTAssertEqual(SpendingCSVExporter.escape("이른바 \"할인\""), "\"이른바 \"\"할인\"\"\"")
    }

    func test_줄바꿈이_있는_항목명도_감싼다() {
        XCTAssertEqual(SpendingCSVExporter.escape("첫 줄\n둘째 줄"), "\"첫 줄\n둘째 줄\"")
    }

    func test_특수문자가_없으면_그대로_둔다() {
        XCTAssertEqual(SpendingCSVExporter.escape("스타벅스 커피"), "스타벅스 커피")
    }

    func test_쉼표가_든_항목명이_열을_밀지_않는다() {
        let csv = SpendingCSVExporter.makeCSV(from: [record("콜라, 과자", 5_000, date(2026, 8, 7))])
        XCTAssertTrue(csv.contains("\"콜라, 과자\",5000"))
    }

    // MARK: - 기간

    func test_전체는_시작일_제한이_없다() {
        XCTAssertNil(SpendingCSVExporter.Range.all.startDate())
    }

    func test_이번달은_1일부터() {
        let now = date(2026, 8, 8)
        let start = SpendingCSVExporter.Range.thisMonth.startDate(from: now)
        XCTAssertEqual(cal.component(.day, from: start!), 1)
        XCTAssertEqual(cal.component(.month, from: start!), 8)
    }

    func test_최근3개월은_3개월_전부터() {
        let now = date(2026, 8, 8)
        let start = SpendingCSVExporter.Range.last3Months.startDate(from: now)
        XCTAssertEqual(cal.component(.month, from: start!), 5)
    }

    func test_파일명에_기간과_날짜가_들어간다() {
        let name = SpendingCSVExporter.fileName(for: .thisMonth, now: date(2026, 8, 8))
        XCTAssertEqual(name, "가계씨_소비내역_이번 달_2026-08-08.csv")
        XCTAssertTrue(name.hasSuffix(".csv"))
    }

    func test_기록이_없으면_헤더만_남는다() {
        let csv = SpendingCSVExporter.makeCSV(from: [])
        let lines = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 1)
    }

    // MARK: - 피드백 메일

    func test_mailto_URL이_주소와_제목을_담는다() {
        let url = FeedbackMail.makeURL(to: "test@example.com", subject: "제목", body: "본문")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "mailto")
        XCTAssertTrue(url!.absoluteString.hasPrefix("mailto:test@example.com?"))
    }

    /// & 가 인코딩되지 않으면 메일 앱이 본문을 잘라 읽는다
    func test_앰퍼샌드와_더하기가_인코딩된다() {
        let url = FeedbackMail.makeURL(to: "a@b.com", subject: "A&B", body: "1+1")
        XCTAssertNotNil(url)
        XCTAssertFalse(url!.absoluteString.contains("A&B"))
        XCTAssertFalse(url!.absoluteString.contains("1+1"))
        XCTAssertTrue(url!.absoluteString.contains("%26"))
        XCTAssertTrue(url!.absoluteString.contains("%2B"))
    }

    func test_주소가_비면_URL을_만들지_않는다() {
        XCTAssertNil(FeedbackMail.makeURL(to: "", subject: "제목", body: "본문"))
    }

    func test_본문에_앱과_기기_정보가_들어간다() {
        let body = FeedbackMail.body(appVersion: "1.0", build: "3",
                                     systemVersion: "18.0", deviceModel: "iPhone16,1")
        XCTAssertTrue(body.contains("앱 버전: 1.0 (3)"))
        XCTAssertTrue(body.contains("iOS: 18.0"))
        XCTAssertTrue(body.contains("iPhone16,1"))
    }

    func test_문의_주소가_비어있지_않다() {
        XCTAssertFalse(FeedbackMail.supportEmail.isEmpty)
        XCTAssertTrue(FeedbackMail.supportEmail.contains("@"))
    }
}
