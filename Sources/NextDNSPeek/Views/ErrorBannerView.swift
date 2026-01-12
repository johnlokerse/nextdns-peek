import SwiftUI

struct ErrorBannerView: View {
  let error: AppError

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundColor(.orange)
      Text(error.message)
        .font(.caption)
        .foregroundColor(.primary)
      Spacer()
    }
    .padding(8)
    .background(Color.orange.opacity(0.15))
    .cornerRadius(6)
  }
}
