import UIKit

/// Combines the two Camera + Camera shots into a single side-by-side image so
/// the food log row and edit page can show both angles through the entry's
/// one image slot (FoodEntry stores a single JPEG).
enum FoodImageComposer {
    /// Both halves are scaled to a common height (bounded by the smaller photo
    /// and this cap) so the pair lines up and the stored JPEG stays small.
    private static let maxHeight: CGFloat = 1200

    static func sideBySide(_ left: UIImage, _ right: UIImage) -> UIImage {
        let height = min(left.size.height, right.size.height, maxHeight)
        guard height > 0, left.size.height > 0, right.size.height > 0 else { return left }

        let leftWidth = (left.size.width * height / left.size.height).rounded()
        let rightWidth = (right.size.width * height / right.size.height).rounded()
        guard leftWidth > 0, rightWidth > 0 else { return left }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1 // render at exact pixel size, not the screen's 3x
        let size = CGSize(width: leftWidth + rightWidth, height: height)
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            left.draw(in: CGRect(x: 0, y: 0, width: leftWidth, height: height))
            right.draw(in: CGRect(x: leftWidth, y: 0, width: rightWidth, height: height))
        }
    }
}
