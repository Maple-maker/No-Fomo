import SwiftUI

// MARK: - Ticker Logo (company logo with monogram fallback)

struct TickerLogo: View {
    let ticker: String
    var size: CGFloat = 36

    private var logoURL: URL? {
        URL(string: "https://companiesmarketcap.com/img/company-logos/64/\(ticker.uppercased()).png")
    }

    private var initial: String {
        String(ticker.prefix(1))
    }

    private var color: Color {
        // Deterministic color from ticker
        let colors: [Color] = [
            Color(hex: "#7B61FF"), // purple
            Color(hex: "#3B82F6"), // blue
            Color(hex: "#10B981"), // emerald
            Color(hex: "#F59E0B"), // amber
            Color(hex: "#EF4444"), // red
            Color(hex: "#EC4899"), // pink
            Color(hex: "#06B6D4"), // cyan
            Color(hex: "#8B5CF6"), // violet
        ]
        let hash = abs(ticker.unicodeScalars.reduce(0) { $0 + Int($1.value) })
        return colors[hash % colors.count]
    }

    private var cornerRadius: CGFloat { size * 0.22 }
    private var inset: CGFloat { size * 0.12 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.white)
                .frame(width: size, height: size)

            AsyncImage(url: logoURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size - inset * 2, height: size - inset * 2)
                case .failure:
                    fallbackContent
                case .empty:
                    fallbackContent
                @unknown default:
                    fallbackContent
                }
            }
        }
    }

    private var fallbackContent: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius - inset)
                .fill(color.opacity(0.15))
                .frame(width: size - inset * 2, height: size - inset * 2)
            Text(initial)
                .font(.system(size: (size - inset * 2) * 0.5, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        TickerLogo(ticker: "PLTR", size: 40)
        TickerLogo(ticker: "AAPL", size: 40)
        TickerLogo(ticker: "ZZXX", size: 40) // fallback test
    }
    .padding()
    .background(Color.black)
}
