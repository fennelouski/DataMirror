import SwiftUI

/// A reusable yellow banner displayed at the top of data-revealing screens.
struct DataMirrorPrivacyBanner: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "eye.fill")
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}
