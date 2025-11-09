import Foundation
import SwiftUI

// MARK: - Onboarding Step
enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case userStatus = 1
    case termSetup = 2
    case capacitySetup = 3
    case completion = 4
}

// MARK: - Onboarding View Model
@MainActor
class OnboardingViewModel: ObservableObject {

    @Published var currentStep: OnboardingStep = .welcome
    @Published var userStatus: UserStatus? = nil

    // Term Setup
    @Published var termYear: String = ""
    @Published var termSemester: String = "1"
    @Published var termStartDate: Date = Date()
    @Published var termEndDate: Date = Date().addingTimeInterval(60 * 60 * 24 * 120) // ~4 months

    // Capacity Setup
    @Published var weekdayCapacity: Int = 180 // 3 hours default
    @Published var weekendCapacity: Int = 240 // 4 hours default

    // Services
    private let profileService = UserProfileService.shared
    private let termService = TermService.shared

    // MARK: - Computed Properties

    var progress: Double {
        let totalSteps = userStatus == .currentStudent ? 5 : 4
        let currentIndex = currentStep.rawValue + 1
        return Double(currentIndex) / Double(totalSteps)
    }

    var canGoBack: Bool {
        return currentStep.rawValue > 0
    }

    var canGoNext: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .userStatus:
            return userStatus != nil
        case .termSetup:
            return !termYear.isEmpty && !termSemester.isEmpty
        case .capacitySetup:
            return true
        case .completion:
            return false
        }
    }

    var isLastStep: Bool {
        return currentStep == .completion
    }

    // MARK: - Navigation

    func nextStep() {
        guard canGoNext else { return }

        withAnimation {
            // Skip term setup if not a current student
            if currentStep == .userStatus && userStatus != .currentStudent {
                currentStep = .capacitySetup
            } else {
                if let nextRawValue = currentStep.rawValue + 1,
                   let nextStep = OnboardingStep(rawValue: nextRawValue) {
                    currentStep = nextStep
                }
            }
        }
    }

    func previousStep() {
        withAnimation {
            // Skip term setup when going back if not a current student
            if currentStep == .capacitySetup && userStatus != .currentStudent {
                currentStep = .userStatus
            } else {
                if let prevRawValue = currentStep.rawValue - 1,
                   let prevStep = OnboardingStep(rawValue: prevRawValue) {
                    currentStep = prevStep
                }
            }
        }
    }

    // MARK: - Complete Onboarding

    func completeOnboarding(userId: String) async {
        do {
            // Create or get user profile
            let profile = try await profileService.getOrCreateProfile(userId: userId)

            // Update capacity
            var updatedProfile = profile
            updatedProfile.weekdayCapacityMin = weekdayCapacity
            updatedProfile.weekendCapacityMin = weekendCapacity

            // Create term
            let termId: String
            if userStatus == .currentStudent {
                // Create academic term
                let term = try await termService.createAcademicTerm(
                    userId: userId,
                    year: termYear,
                    semester: termSemester,
                    startDate: termStartDate,
                    endDate: termEndDate
                )
                termId = term.termId
            } else {
                // Create personal default term
                let term = try await termService.createPersonalDefaultTerm(userId: userId)
                termId = term.termId
            }

            // Complete onboarding
            try await profileService.completeOnboarding(
                profile: updatedProfile,
                termId: termId,
                userStatus: userStatus ?? .currentStudent
            )

            print("✅ Onboarding completed!")

        } catch {
            print("❌ Error completing onboarding: \(error.localizedDescription)")
        }
    }
}
