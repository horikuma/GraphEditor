import Foundation

enum AddableShapeKind: String, CaseIterable, Identifiable {
    case circle
    case rectangle

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .circle:
            return "円"
        case .rectangle:
            return "矩形"
        }
    }
}
