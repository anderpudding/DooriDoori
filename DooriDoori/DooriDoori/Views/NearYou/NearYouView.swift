import SwiftUI

struct NearYouView: View {
    @Environment(\.dismiss) private var dismiss

    let items: [ContentItem]

    var body: some View {
        ZStack(alignment: .topLeading) {
            MapPlaceholderView()

            IconCircleButton(symbolName: "chevron.left", background: .white.opacity(0.94), size: 46) {
                dismiss()
            }
            .padding(.leading, 20)
            .padding(.top, 58)

            VStack {
                Spacer()
                NearYouBottomSheet(items: items)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationBarBackButtonHidden()
    }
}
