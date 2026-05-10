import Foundation
import Combine

final class AppState: ObservableObject {
    @Published var selectedTab: MainTab = .forYou
}
