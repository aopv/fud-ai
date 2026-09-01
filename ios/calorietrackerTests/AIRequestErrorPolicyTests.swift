import Foundation
import Testing
@testable import calorietracker

struct AIRequestErrorPolicyTests {
    private enum TestError: Error, Equatable {
        case primary
        case fallback
    }

    @Test func localPrimaryFailureIsNotHiddenByRemoteFallbackFailure() {
        let surfaced = AIRequestErrorPolicy.errorToSurface(
            primaryProvider: .gemma4Local,
            primaryError: TestError.primary,
            fallbackError: TestError.fallback
        )

        #expect(surfaced as? TestError == .primary)
    }

    @Test func remotePrimaryStillSurfacesFallbackFailure() {
        let surfaced = AIRequestErrorPolicy.errorToSurface(
            primaryProvider: .gemini,
            primaryError: TestError.primary,
            fallbackError: TestError.fallback
        )

        #expect(surfaced as? TestError == .fallback)
    }
}
