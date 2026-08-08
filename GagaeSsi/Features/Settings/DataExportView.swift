//
//  DataExportView.swift
//  GagaeSsi
//
//  소비 기록 CSV 내보내기 — 기기에만 있는 기록을 파일로 빼둘 수 있게 한다.
//

import SwiftUI

struct DataExportView: View {
    @State private var range: SpendingCSVExporter.Range = .all
    @State private var records: [SpendingRecordModel] = []
    @State private var exportedFile: URL?
    @State private var errorMessage: String?

    private var total: Int { records.reduce(0) { $0 + $1.amount } }

    var body: some View {
        ZStack {
            GagaeBackground()

            ScrollView {
                VStack(spacing: GagaeSpacing.md) {
                    introCard
                    rangeCard
                    previewCard
                    shareButton
                }
                .padding(.horizontal, GagaeSpacing.md)
                .padding(.vertical, GagaeSpacing.md)
            }
        }
        .navigationTitle("데이터 내보내기")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .onChange(of: range) { _, _ in load() }
        .alert("내보내기 실패", isPresented: .constant(errorMessage != nil)) {
            Button("확인") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Cards

    private var introCard: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                Text("소비 기록을 CSV 파일로 저장해요.")
                    .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                Text("가계씨는 기록을 기기에만 보관해요. 앱을 지우거나 기기를 바꾸면 되살릴 수 없으니, 가끔 파일로 빼두시면 안심이에요.")
                    .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var rangeCard: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                Text("기간").font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                Picker("", selection: $range) {
                    ForEach(SpendingCSVExporter.Range.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var previewCard: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                HStack {
                    Text("내보낼 기록")
                        .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                    Spacer()
                    Text("\(records.count)건 · \(FormatterUtils.currencyString(from: total))")
                        .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                }

                GagaeDivider()

                Text("포함되는 항목")
                    .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                Text(SpendingCSVExporter.header.joined(separator: " · "))
                    .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Excel·구글 시트에서 바로 열려요 (한글 깨짐 방지 처리됨).")
                    .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
            }
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        if records.isEmpty {
            GagaeCard {
                Text("이 기간에는 내보낼 기록이 없어요")
                    .font(.gagaeCallout).foregroundStyle(.gagaeTextTertiary)
                    .frame(maxWidth: .infinity).padding(.vertical, GagaeSpacing.sm)
            }
        } else if let exportedFile {
            ShareLink(item: exportedFile) {
                Text("파일 내보내기")
                    .font(.gagaeHeadline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(LinearGradient(colors: [.gagaePinkDark, .gagaePink],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Actions

    private func load() {
        let all = CoreDataManager.shared.fetchAllSpendingRecords()
        if let start = range.startDate() {
            records = all.filter { $0.date >= start }
        } else {
            records = all
        }
        prepareFile()
    }

    /// ShareLink는 URL을 미리 받아야 해서 파일을 먼저 만들어 둔다
    private func prepareFile() {
        guard !records.isEmpty else { exportedFile = nil; return }
        do {
            let csv = SpendingCSVExporter.makeCSV(from: records)
            exportedFile = try SpendingCSVExporter.writeTemporaryFile(
                csv: csv, fileName: SpendingCSVExporter.fileName(for: range))
        } catch {
            exportedFile = nil
            errorMessage = "파일을 만들지 못했어요. 잠시 후 다시 시도해 주세요."
        }
    }
}

#Preview {
    NavigationStack { DataExportView() }
}
