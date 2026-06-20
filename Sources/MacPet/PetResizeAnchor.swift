import CoreGraphics

enum PetResizeAnchor: Equatable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    static func corner(for imageFrame: CGRect, in screenFrame: CGRect) -> PetResizeAnchor {
        let isLeft = imageFrame.midX < screenFrame.midX
        let isBottom = imageFrame.midY < screenFrame.midY

        switch (isLeft, isBottom) {
        case (true, true):
            return .bottomLeft
        case (true, false):
            return .topLeft
        case (false, true):
            return .bottomRight
        case (false, false):
            return .topRight
        }
    }

    func resizedFrame(from frame: CGRect, to size: CGSize) -> CGRect {
        let origin: CGPoint

        switch self {
        case .topLeft:
            origin = CGPoint(x: frame.minX, y: frame.maxY - size.height)
        case .topRight:
            origin = CGPoint(x: frame.maxX - size.width, y: frame.maxY - size.height)
        case .bottomLeft:
            origin = frame.origin
        case .bottomRight:
            origin = CGPoint(x: frame.maxX - size.width, y: frame.minY)
        }

        return CGRect(origin: origin, size: size)
    }
}
