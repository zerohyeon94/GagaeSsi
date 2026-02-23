//
//  SetupSalaryView.swift
//  GagaeSsi
//
//  초기 설정 - 월급 입력 화면
//

import SwiftUI

struct SetupSalaryView: View {
    // MARK: - Properties
    @State private var viewModel = SetupViewModel()
    @FocusState private var isSalaryFocused: Bool
    @State private var pigBouncing = false

    enum Field { case salary }

    // MARK: - Body
    var body: some View {
        ZStack {
            // 그라디언트 배경
            LinearGradient(
                colors: [Color.gagaePinkGradientTop, Color.gagaePinkGradientBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 상단 영역: 캐릭터 + 인사말
                heroSection
                    .padding(.top, 60)

                // 입력 폼
                inputFormCard
                    .padding(.top, GagaeSpacing.xl)
                    .padding(.horizontal, GagaeSpacing.md)

                Spacer()

                // 다음 버튼
                nextButton
                    .padding(.horizontal, GagaeSpacing.md)
                    .padding(.bottom, GagaeSpacing.xl)
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pigBouncing = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isSalaryFocused = true
            }
        }
        .onTapGesture {
            isSalaryFocused = false
        }
    }
}

// MARK: - Subviews
extension SetupSalaryView {

    /// 히어로 섹션: 캐릭터 + 환영 메시지
    private var heroSection: some View {
        VStack(spacing: GagaeSpacing.md) {
            // 돼지 캐릭터
            ZStack {
                Circle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 110, height: 110)
                    .scaleEffect(pigBouncing ? 1.06 : 1.0)

                if UIImage(named: "characterPig") != nil {
                    Image("characterPig")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .offset(y: pigBouncing ? -4 : 0)
                } else {
                    Text("🐷")
                        .font(.system(size: 66))
                        .offset(y: pigBouncing ? -4 : 0)
                }
            }

            // 텍스트
            VStack(spacing: GagaeSpacing.xs) {
                Text("안녕하세요!")
                    .font(.gagaeTitle2)
                    .foregroundStyle(.gagaePinkDark)

                Text("저는 가계씨예요 🐽")
                    .font(.gagaeTitle3)
                    .foregroundStyle(.gagaePinkDark.opacity(0.85))

                Text("월급을 알려주시면\n오늘 쓸 수 있는 금액을 계산해드릴게요")
                    .font(.gagaeSubheadline)
                    .foregroundStyle(.gagaeTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// 입력 폼 카드
    private var inputFormCard: some View {
        GagaeCard {
            VStack(spacing: GagaeSpacing.lg) {
                // 월급 입력
                VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                    Label("월급", systemImage: "wonsign.circle.fill")
                        .font(.gagaeCalloutMedium)
                        .foregroundStyle(.gagaePinkDark)

                    HStack(spacing: GagaeSpacing.sm) {
                        Text("₩")
                            .font(.gagaeTitle3)
                            .foregroundStyle(.gagaePinkDark)

                        TextField("예: 3,000,000", text: $viewModel.tempSalaryText)
                            .font(.gagaeTitle3)
                            .keyboardType(.numberPad)
                            .focused($isSalaryFocused)
                            .onChange(of: viewModel.tempSalaryText) { _, newValue in
                                viewModel.updateSalaryFromText(newValue)
                            }
                    }
                    .padding(GagaeSpacing.md)
                    .background(Color.gagaeSurface)
                    .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: GagaeRadius.md)
                            .stroke(
                                isSalaryFocused ? Color.gagaePinkDark : Color.gagaeDivider,
                                lineWidth: isSalaryFocused ? 2 : 0.5
                            )
                    )
                }

                GagaeDivider()

                // 급여일 선택
                VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                    Label("급여일", systemImage: "calendar.circle.fill")
                        .font(.gagaeCalloutMedium)
                        .foregroundStyle(.gagaePinkDark)

                    HStack {
                        Text("매월")
                            .font(.gagaeCallout)
                            .foregroundStyle(.gagaeTextSecondary)

                        Picker("급여일", selection: $viewModel.tempPayday) {
                            ForEach(1...31, id: \.self) { day in
                                Text("\(day)일").tag(day)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.gagaePinkDark)

                        Text("에 월급을 받아요")
                            .font(.gagaeCallout)
                            .foregroundStyle(.gagaeTextSecondary)

                        Spacer()
                    }
                    .padding(GagaeSpacing.md)
                    .background(Color.gagaeSurface)
                    .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: GagaeRadius.md)
                            .stroke(Color.gagaeDivider, lineWidth: 0.5)
                    )
                }
            }
        }
    }

    /// 다음 버튼
    private var nextButton: some View {
        NavigationLink {
            SetupFixedCostView(viewModel: viewModel)
        } label: {
            HStack(spacing: GagaeSpacing.sm) {
                Text("다음")
                    .font(.gagaeHeadline)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                viewModel.isValid
                    ? LinearGradient(colors: [.gagaePinkDark, .gagaePink], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.full))
            .gagaeShadow(color: viewModel.isValid ? .gagaePink.opacity(0.4) : .clear, radius: 8, y: 4)
        }
        .disabled(!viewModel.isValid)
        .simultaneousGesture(TapGesture().onEnded {
            viewModel.confirmSalaryInfo()
        })
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        SetupSalaryView()
    }
    .environment(AppState())
    .environment(AppEventBus())
}
