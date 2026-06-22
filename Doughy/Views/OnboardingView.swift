//
//  OnboardingView.swift
//  Doughy

import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    private struct Slide {
        let symbol: String
        let title: LocalizedStringKey
        let body: LocalizedStringKey
    }

    private let slides: [Slide] = [
        Slide(
            symbol: "fork.knife",
            title: "onboarding_welcome_title",
            body: "onboarding_welcome_body"
        ),
        Slide(
            symbol: "scalemass",
            title: "onboarding_scale_title",
            body: "onboarding_scale_body"
        ),
        Slide(
            symbol: "flask",
            title: "onboarding_volume_title",
            body: "onboarding_volume_body"
        ),
        Slide(
            symbol: "camera.viewfinder",
            title: "onboarding_scan_title",
            body: "onboarding_scan_body"
        ),
        Slide(
            symbol: "lock",
            title: "onboarding_private_title",
            body: "onboarding_private_body"
        ),
        Slide(
            symbol: "square.and.arrow.up",
            title: "onboarding_share_title",
            body: "onboarding_share_body"
        ),
    ]

    var body: some View {
        ZStack {
            TabView(selection: $currentPage) {
                ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                    slideView(slide)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Close")
                    .padding()
                }
                Spacer()

                pageDots
                    .padding(.bottom, 12)

                Button {
                    if currentPage < slides.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        dismiss()
                    }
                } label: {
                    Text(currentPage < slides.count - 1 ? "onboarding_next" : "onboarding_get_started")
                        .bold()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.bottom, 40)
                .accessibilityValue("Page \(currentPage + 1) of \(slides.count)")
            }
        }
    }

    private func slideView(_ slide: Slide) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: slide.symbol)
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            Text(slide.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(slide.body)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
            Spacer()
        }
        .padding(.horizontal)
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<slides.count, id: \.self) { i in
                Circle()
                    .fill(i == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut, value: currentPage)
            }
        }
        .accessibilityHidden(true)
    }
}
