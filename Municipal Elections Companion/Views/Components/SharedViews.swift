//
//  SharedViews.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import SwiftUI

/// A circular candidate photo with a placeholder while loading or if the URL fails.
struct CandidatePhoto: View {
    let url: URL?
    /// Callers pass a `@ScaledMetric` so photos grow with Dynamic Type.
    let size: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

/// A municipality logo, falling back to a civic symbol.
struct MunicipalityLogo: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "building.columns.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.tint)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// "City: Burnaby", shown wherever the user needs to know which municipality they're viewing.
struct CityLabel: View {
    let city: String

    var body: some View {
        Label("City: \(city)", systemImage: "mappin.and.ellipse")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.tint)
    }
}

/// Header for an office section, e.g. "Councillor · Choose up to 6 · 2 chosen".
struct OfficeHeader: View {
    let name: String
    let seats: Int?
    let chosen: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name)
                .font(.headline)
            Spacer()
            if let seats {
                Text("\(chosen) of \(seats) chosen")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(chosen >= seats ? Color.green : Color.secondary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Inline, dismissible error banner for non-blocking failures (e.g. a refresh that failed).
struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Dismiss", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
        }
        .padding()
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}
