import SwiftUI

// MARK: — Score gauge (circular ring or bars style)

struct ScoreGauge: View {
    let score: Double
    let tier: Int
    let size: CGFloat
    var stroke: CGFloat = 5
    var style: GaugeStyle = .ring

    enum GaugeStyle: String, CaseIterable {
        case ring
        case bars
    }

    private var color: Color { tier.tierColor }

    var body: some View {
        Group {
            if style == .bars {
                barsStyle
            } else {
                ringStyle
            }
        }
    }

    // MARK: Ring style — circular arc in tier color
    private var ringStyle: some View {
        let r = (size - stroke) / 2
        let c = 2 * Double.pi * r
        let off = c - (score / 100) * c

        return ZStack {
            // Track
            Circle()
                .stroke(DS.Color.ringTrack, lineWidth: stroke)

            // Filled arc
            Circle()
                .trim(from: 0, to: score / 100)
                .stroke(color, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Center score number
            Text("\(Int(score))")
                .font(DS.Font.mono(size * 0.32))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }

    // MARK: Bars style — just the number, no arc
    private var barsStyle: some View {
        VStack(spacing: 0) {
            Text("\(Int(score))")
                .font(DS.Font.mono(size * 0.42))
                .foregroundColor(color)
                .lineLimit(1)
            Text("/100")
                .font(DS.Font.caption(size * 0.14))
                .foregroundColor(DS.Color.textMuted)
        }
        .frame(width: size, height: size)
    }
}

// MARK: — Verdict chip (green BULL / red BEAR)

struct VerdictChip: View {
    let verdict: Verdict
    var label: String? = nil
    var size: ChipSize = .sm

    enum ChipSize { case sm, md }

    private var color: Color { verdict.color }
    private var height: CGFloat { size == .sm ? 24 : 28 }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .shadow(color: color.opacity(0.6), radius: 3)
            if let label {
                Text(label)
                    .font(DS.Font.caption(11))
                    .foregroundColor(DS.Color.textSecondary)
            }
            Text(verdict.label)
                .font(DS.Font.mono(11))
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .frame(height: height)
        .background(color.opacity(0.13))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

// MARK: — Tier badge (gold T1 / blue T2 capsule)

struct TierBadge: View {
    let tier: Int

    private var color: Color { tier.tierColor }

    var body: some View {
        HStack(spacing: 5) {
            Text(tier.tierShort)
                .font(DS.Font.mono(11))
                .foregroundColor(color)
            Text(tier.tierLabel)
                .font(DS.Font.caption(10))
                .foregroundColor(color.opacity(0.85))
        }
        .padding(.horizontal, 9)
        .frame(height: 22)
        .background(color.opacity(0.14))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(color.opacity(0.35), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: — Triple Signal badge (gold lightning bolt)

struct TripleSignalBadge: View {
    var pulse: Bool = true
    @State private var didPulse = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(DS.Color.tier1)
            Text("TRIPLE SIGNAL")
                .font(DS.Font.mono(10))
                .foregroundColor(DS.Color.tier1)
        }
        .padding(.horizontal, 9)
        .frame(height: 22)
        .background(DS.Color.tier1.opacity(0.16))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(DS.Color.tier1.opacity(0.45), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onAppear {
            if pulse && !didPulse {
                didPulse = true
            }
        }
    }
}

// MARK: — Lock badge (for pro-gated content)

struct LockBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.system(size: 9))
            Text("Pro")
                .font(DS.Font.caption(11))
        }
        .foregroundColor(DS.Color.textMuted)
    }
}

#Preview {
    VStack(spacing: 20) {
        ScoreGauge(score: 91, tier: 1, size: 58)
        ScoreGauge(score: 84, tier: 2, size: 58)
        ScoreGauge(score: 76, tier: 2, size: 58, style: .bars)

        HStack(spacing: 8) {
            TierBadge(tier: 1)
            TripleSignalBadge()
        }

        HStack(spacing: 8) {
            VerdictChip(verdict: .bull, label: "Gemini")
            VerdictChip(verdict: .bear, label: "DeepSeek")
            VerdictChip(verdict: .bull)
        }

        LockBadge()
    }
    .padding()
    .background(DS.Color.background)
}
