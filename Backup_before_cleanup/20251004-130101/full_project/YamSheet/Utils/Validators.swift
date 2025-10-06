import Foundation

struct Validators {
    /// Allowed values for upper section: [0, 1*face, 2*face, 3*face, 4*face, 5*face]
    static func allowedUpperValues(face: Int) -> [Int] {
        precondition((1...6).contains(face), "Face must be 1...6")
        return [0] + (1...5).map { $0 * face }
    }
}
