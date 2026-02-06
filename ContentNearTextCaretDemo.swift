
import SwiftUI

struct ContentNearTextCaretDemo: View {

    @State private var contentNearCaret: String? = nil

    var body: some View {
        VStack(spacing: 24) {
            Text(
                "Shift + Command + Space to get content near text cursor (Caret)"
            )
            .font(.headline)

            if let contentNearCaret {
                Divider()

                VStack(spacing: 12) {
                    Text("Content")
                        .font(.headline)
                    Text(contentNearCaret)
                }
            }
        }
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            NSEvent.addGlobalMonitorForEvents(
                matching: .keyDown,
                handler: { event in
                    if event.keyCode == 49,
                        event.modifierFlags.intersection(
                            .deviceIndependentFlagsMask
                        ) == [.command, .shift]
                    {
                        do {
                            self.contentNearCaret =
                                try CaretContextGetter.getContent()
                        } catch (let error) {
                            print(error)
                        }
                    }
                }
            )
        }
    }
}

nonisolated class CaretContextGetter {

    private init() {}

    static func getContent() throws -> String {
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]

        let accessEnabled = AXIsProcessTrustedWithOptions(options)

        if !accessEnabled {
            throw AccessibilityError.permissionNotGranted
        }

        let focusedAXElement = try self.getFocusedElement()
        let selectedTextRange = try self.getSelectedTextRange(focusedAXElement)
        var expandedRange = getRangeAroundSelectedText(selectedTextRange)
        guard let rangeValue = AXValueCreate(.cfRange, &expandedRange) else {
            throw AccessibilityError.generalFailure
        }
        let string = try self.getStringForRange(
            focusedAXElement,
            range: rangeValue
        )
        return string
    }

    // 200 before and after cursor position
    static private func getRangeAroundSelectedText(_ range: CFRange) -> CFRange
    {
        let expandLength = 200
        let start = max(0, range.location - expandLength)
        let end = range.location + range.length + expandLength
        return .init(location: start, length: end - start)
    }

    static private func getFocusedElement() throws -> AXUIElement {

        let systemWideElement = AXUIElementCreateSystemWide()

        var focusedElement: CFTypeRef?

        let error = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        try checkAXError(error)

        guard let focusedAXElement = focusedElement as! AXUIElement? else {
            throw AccessibilityError.failToGetFocusElement
        }

        return focusedAXElement

    }

    static private func getSelectedTextRange(
        _ element: AXUIElement
    ) throws -> CFRange {
        var value: CFTypeRef?

        let error = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &value
        )

        try checkAXError(error)
        guard let value else {
            throw AccessibilityError.failToGetTextRange
        }

        var range = CFRange(location: 0, length: 0)
        let result = AXValueGetValue(value as! AXValue, .cfRange, &range)
        if !result {
            throw AccessibilityError.failToGetTextRange
        }
        return range
    }

    static private func getStringForRange(
        _ element: AXUIElement,
        range: CFTypeRef
    ) throws -> String {
        var value: CFTypeRef?

        let error = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXStringForRangeParameterizedAttribute as CFString,
            range,
            &value
        )

        try checkAXError(error)
        guard let value else {
            throw AccessibilityError.failToGetTextRange
        }

        if let string = value as? String {
            return string
        }

        return ""
    }

    static private func checkAXError(_ error: AXError) throws {
        if let error = AccessibilityError(error) {
            throw error
        }
    }

}

private enum AccessibilityError: String, Error, LocalizedError {
    case permissionNotGranted

    case failToGetFocusElement
    case failToGetTextRange
    case failToGetBoundingRect

    // MARK: - AXError mapped
    // AXError.failure
    case generalFailure
    case illegalArgument
    case invalidUIElement
    case invalidUIElementObserver
    case cannotComplete
    case attributeUnsupported
    case actionUnsupported
    case notificationUnsupported
    case notImplemented
    case notificationAlreadyRegistered
    case notificationNotRegistered
    case apiDisabled
    case noValue
    case parameterizedAttributeUnsupported
    case notEnoughPrecision

    var errorDescription: String? {
        switch self {
        default:
            "Something went wrong with Accessibility API: \(self.rawValue)"
        }
    }

    init?(_ axError: AXError) {
        switch axError {
        case .success:
            return nil
        case .failure:
            self = .generalFailure
        case .illegalArgument:
            self = .illegalArgument
        case .invalidUIElement:
            self = .invalidUIElement
        case .invalidUIElementObserver:
            self = .invalidUIElementObserver
        case .cannotComplete:
            self = .cannotComplete
        case .attributeUnsupported:
            self = .attributeUnsupported
        case .actionUnsupported:
            self = .actionUnsupported
        case .notificationUnsupported:
            self = .notificationUnsupported
        case .notImplemented:
            self = .notImplemented
        case .notificationAlreadyRegistered:
            self = .notificationAlreadyRegistered
        case .notificationNotRegistered:
            self = .notificationNotRegistered
        case .apiDisabled:
            self = .apiDisabled
        case .noValue:
            self = .noValue
        case .parameterizedAttributeUnsupported:
            self = .parameterizedAttributeUnsupported
        case .notEnoughPrecision:
            self = .notEnoughPrecision
        @unknown default:
            self = .generalFailure
        }
    }

}
