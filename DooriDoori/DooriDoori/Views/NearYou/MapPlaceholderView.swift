import SwiftUI

struct MapPlaceholderView: View {
    var body: some View {
        ZStack {
            DooriStyle.softGray.ignoresSafeArea()

            gridLines

            fakePin(x: -100, y: -120)
            fakePin(x: 72, y: -64)
            fakePin(x: -46, y: 44)
            fakePin(x: 118, y: 88)
        }
    }

    private var gridLines: some View {
        Canvas { context, size in
            let color = Color.white.opacity(0.78)
            for x in stride(from: 0, through: size.width, by: 58) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(color), lineWidth: 1)
            }
            for y in stride(from: 0, through: size.height, by: 58) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(color), lineWidth: 1)
            }
        }
        .ignoresSafeArea()
    }

    private func fakePin(x: CGFloat, y: CGFloat) -> some View {
        Image(systemName: "mappin.circle.fill")
            .font(.system(size: 34, weight: .bold))
            .foregroundStyle(DooriStyle.accent)
            .background(.white, in: Circle())
            .offset(x: x, y: y)
    }
}
