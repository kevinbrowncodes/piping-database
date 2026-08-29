import SwiftUI

/// Live dimensioned cross-section drawing — the reference app's signature UX,
/// redrawn natively with Canvas so it adapts to any size, theme, and unit system.
struct PipeCrossSectionView: View {
    let entry: PipeScheduleEntry
    let unit: UnitSystem

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2 + 10)
            let outerR = min(size.width, size.height) * 0.34
            let ratio = entry.odInches > 0 ? entry.idInches / entry.odInches : 0.8
            let innerR = outerR * ratio

            let wallColor = Color.primary.opacity(0.85)
            let dimColor = Color.green
            let centerlineColor = Color.cyan.opacity(0.7)

            // Wall annulus
            var annulus = Path()
            annulus.addArc(center: center, radius: outerR, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
            annulus.addArc(center: center, radius: innerR, startAngle: .zero, endAngle: .degrees(360), clockwise: true)
            ctx.fill(annulus, with: .color(.primary.opacity(0.12)))
            ctx.stroke(Path(ellipseIn: CGRect(x: center.x - outerR, y: center.y - outerR, width: outerR * 2, height: outerR * 2)),
                       with: .color(wallColor), lineWidth: 1.5)
            ctx.stroke(Path(ellipseIn: CGRect(x: center.x - innerR, y: center.y - innerR, width: innerR * 2, height: innerR * 2)),
                       with: .color(wallColor), lineWidth: 1.5)

            // Centerlines
            var crosshair = Path()
            crosshair.move(to: CGPoint(x: center.x - outerR - 14, y: center.y))
            crosshair.addLine(to: CGPoint(x: center.x + outerR + 14, y: center.y))
            crosshair.move(to: CGPoint(x: center.x, y: center.y - outerR - 14))
            crosshair.addLine(to: CGPoint(x: center.x, y: center.y + outerR + 14))
            ctx.stroke(crosshair, with: .color(centerlineColor),
                       style: StrokeStyle(lineWidth: 0.8, dash: [10, 3, 2, 3]))

            // OD dimension line above the pipe
            let dimY = center.y - outerR - 26
            var dim = Path()
            dim.move(to: CGPoint(x: center.x - outerR, y: dimY))
            dim.addLine(to: CGPoint(x: center.x + outerR, y: dimY))
            // extension lines
            dim.move(to: CGPoint(x: center.x - outerR, y: dimY - 4))
            dim.addLine(to: CGPoint(x: center.x - outerR, y: center.y - outerR))
            dim.move(to: CGPoint(x: center.x + outerR, y: dimY - 4))
            dim.addLine(to: CGPoint(x: center.x + outerR, y: center.y - outerR))
            ctx.stroke(dim, with: .color(dimColor), lineWidth: 1)
            arrowhead(&ctx, at: CGPoint(x: center.x - outerR, y: dimY), pointing: .left, color: dimColor)
            arrowhead(&ctx, at: CGPoint(x: center.x + outerR, y: dimY), pointing: .right, color: dimColor)

            let odText = unit == .imperial
                ? String(format: "%.3f", entry.odInches)
                : String(format: "%.1f", entry.odInches * 25.4)
            ctx.draw(Text(odText).font(.system(.footnote, design: .monospaced)).foregroundStyle(dimColor),
                     at: CGPoint(x: center.x, y: dimY - 10))

            // Wall thickness leader (lower-left, 45°)
            let angle = 5 * CGFloat.pi / 4
            let midWallR = (outerR + innerR) / 2
            let wallPoint = CGPoint(x: center.x + cos(angle) * midWallR, y: center.y - sin(angle) * midWallR)
            let leaderEnd = CGPoint(x: wallPoint.x - 30, y: wallPoint.y + 30)
            var leader = Path()
            leader.move(to: wallPoint)
            leader.addLine(to: leaderEnd)
            ctx.stroke(leader, with: .color(dimColor), lineWidth: 1)

            let wallText = unit == .imperial
                ? String(format: "%.3f", entry.wallInches)
                : String(format: "%.2f", entry.wallInches * 25.4)
            ctx.draw(Text(wallText).font(.system(.footnote, design: .monospaced)).foregroundStyle(dimColor),
                     at: CGPoint(x: leaderEnd.x - 4, y: leaderEnd.y + 10))
        }
    }

    private enum Direction { case left, right }

    private func arrowhead(_ ctx: inout GraphicsContext, at point: CGPoint, pointing: Direction, color: Color) {
        let dx: CGFloat = pointing == .left ? 7 : -7
        var path = Path()
        path.move(to: point)
        path.addLine(to: CGPoint(x: point.x + dx, y: point.y - 3))
        path.addLine(to: CGPoint(x: point.x + dx, y: point.y + 3))
        path.closeSubpath()
        ctx.fill(path, with: .color(color))
    }
}
