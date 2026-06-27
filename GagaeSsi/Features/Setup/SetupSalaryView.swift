//
//  SetupSalaryView.swift
//  GagaeSsi
//
//  초기 설정 - 월급 & 급여일 입력 (Claude Design 적용)
//

import SwiftUI

// MARK: - Progress Dots (공용)
struct SetupProgressDots: View {
    let step: Int  // 1 또는 2
    var body: some View {
        HStack(spacing: 7) {
            ForEach(1...2, id: \.self) { i in
                Capsule()
                    .fill(i == step ? Color.gagaePinkDark : Color.gagaePinkLight)
                    .frame(width: i == step ? 20 : 7, height: 7)
                    .animation(.easeInOut(duration: 0.3), value: step)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

struct SetupSalaryView: View {
    // MARK: - Properties
    @State private var viewModel = SetupViewModel()
    @FocusState private var isSalaryFocused: Bool
    @State private var pigBouncing = false

    // MARK: - Body
    var body: some View {
        ZStack {
            GagaeBackground()

            VStack(spacing: 0) {
                SetupProgressDots(step: 1)

                heroSection
                    .padding(.top, 28)
                    .padding(.bottom, 32)

                inputCard

                Spacer()

                nextButton
                Text("설정은 나중에 언제든 바꿀 수 있어요")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.gagaeTextTertiary)
                    .padding(.top, 12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pigBouncing = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isSalaryFocused = true
            }
        }
        .onTapGesture { isSalaryFocused = false }
    }
}

// MARK: - Subviews
extension SetupSalaryView {

    private var heroSection: some View {
        VStack(spacing: 0) {
            pigContent
                .font(.system(size: 72))
                .offset(y: pigBouncing ? -6 : 0)
                .padding(.bottom, 18)

            Text("안녕하세요!")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.gagaePinkDark)
                .padding(.bottom, 8)

            Text("월급과 급여일을 알려주세요")
                .font(.system(size: 17, design: .rounded))
                .foregroundStyle(.gagaeTextSecondary)
        }
    }

    @ViewBuilder
    private var pigContent: some View {
        if UIImage(named: "characterPig") != nil {
            Image("characterPig").resizable().scaledToFit().frame(width: 90, height: 90)
        } else {
            Text("🐷")
        }
    }

    private var inputCard: some View {
        VStack(spacing: 0) {
            // 월 급여
            VStack(alignment: .leading, spacing: 8) {
                setupLabel("월 급여")
                salaryInput
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)

            Rectangle().fill(Color.gagaeDivider).frame(height: 0.5)
                .padding(.horizontal, 16)

            // 급여일
            VStack(alignment: .leading, spacing: 8) {
                setupLabel("급여일")
                HStack(spacing: 8) {
                    Text("매월")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.gagaeTextSecondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(1...31, id: \.self) { day in
                                paydayChip(day)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                    Text("일")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.gagaeTextSecondary)
                }

                HStack {
                    Text("매월 \(viewModel.tempPayday)일에 급여 입금 📅")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.gagaePinkDark)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 5)
                        .background(Color.gagaePinkLight)
                        .clipShape(Capsule())
                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 18)
        }
        .background(Color.gagaeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .gagaeCardShadow()
    }

    private func setupLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .bold, design: .rounded))
            .foregroundStyle(.gagaeTextSecondary)
            .textCase(.uppercase)
            .kerning(0.6)
    }

    private var salaryInput: some View {
        HStack(spacing: 0) {
            Text("₩")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.gagaePinkDark)
                .frame(width: 48, height: 48)
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(isSalaryFocused ? Color.gagaePinkLight : Color.gagaeDivider)
                        .frame(width: 1.5)
                }

            TextField("0", text: $viewModel.tempSalaryText)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.gagaeText)
                .keyboardType(.numberPad)
                .focused($isSalaryFocused)
                .padding(.horizontal, 12)
                .onChange(of: viewModel.tempSalaryText) { _, newValue in
                    viewModel.updateSalaryFromText(newValue)
                }

            if viewModel.tempSalary > 0 {
                Text("원")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.gagaeTextSecondary)
                    .padding(.trailing, 14)
            }
        }
        .frame(height: 48)
        .background(Color.gagaeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSalaryFocused ? Color.gagaePinkDark : Color.gagaeDivider,
                        lineWidth: 1.8)
        )
    }

    private func paydayChip(_ day: Int) -> some View {
        let isOn = viewModel.tempPayday == day
        return Button {
            viewModel.tempPayday = day
        } label: {
            Text("\(day)")
                .font(.system(size: 12, weight: isOn ? .heavy : .medium, design: .rounded))
                .foregroundStyle(isOn ? .white : .gagaeTextSecondary)
                .frame(width: 34, height: 34)
                .background(isOn ? Color.gagaePinkDark : Color(hex: "#F2F2F2"))
                .clipShape(Circle())
                .gagaeShadow(color: isOn ? .gagaePinkDark.opacity(0.38) : .clear, radius: 5, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var nextButton: some View {
        NavigationLink {
            SetupFixedCostView(viewModel: viewModel)
        } label: {
            Text("다음")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(viewModel.isValid ? .white : .gagaeTextTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    viewModel.isValid
                        ? AnyShapeStyle(LinearGradient(colors: [.gagaePinkDark, .gagaePink],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(Color(hex: "#E8E8E8"))
                )
                .clipShape(Capsule())
                .gagaeShadow(color: viewModel.isValid ? .gagaePinkDark.opacity(0.32) : .clear, radius: 14, y: 10)
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
