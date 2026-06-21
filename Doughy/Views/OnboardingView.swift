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
            title: "Welcome to Doughy",
            body: "The offline recipe calculator for precise bakers. Make sourdough, pizza, cupcakes, jam, tacos, or anything you want!"
        ),
        Slide(
            symbol: "scalemass",
            title: "Scale Any Batch",
            body: "Enter how much you're making and Doughy tells you exactly how much of each ingredient you need."
        ),
        Slide(
            symbol: "flask",
            title: "Convert to Volume",
            body: "Not everything is easily weighed. Common ingredients have standard mass to volume conversions. Add your own any time."
        ),
        Slide(
            symbol: "camera.viewfinder",
            title: "Create or Scan Recipes",
            body: "Type a recipe by percentage or by weight — or use Apple Intelligence On-Device models to photograph a recipe or scan a screenshot and create your recipe in seconds. Requires iPhone 15 or later."
        ),
        Slide(
            symbol: "lock",
            title: "Totally Free. Totally Private.",
            body: "Doughy isn't interested in taking your money or your information. Doughy doesn't track your usage or use the internet."
        ),
        Slide(
            symbol: "square.and.arrow.up",
            title: "Share & Back Up",
            body: "Export recipes and send them to other Doughy users with a personal note. Backup and restore your entire library to a file any time."
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
                    Text(currentPage < slides.count - 1 ? "Next" : "Get Started")
                        .bold()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.bottom, 40)
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
    }
}
