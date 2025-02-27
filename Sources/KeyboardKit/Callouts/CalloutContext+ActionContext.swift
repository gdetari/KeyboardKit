//
//  CalloutContext+ActionContext.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2021-01-06.
//  Copyright © 2021-2024 Daniel Saidi. All rights reserved.
//

import Combine
import SwiftUI

public extension CalloutContext {
    
    /// This class has observable action callout state.
    class ActionContext: ObservableObject {
        
        /// Create an action callout context instance.
        ///
        /// - Parameters:
        ///   - service: The action service to use, if any.
        ///   - tapAction: The action to perform when tapping an action.
        public init(
            service: CalloutService?,
            tapAction: @escaping (KeyboardAction) -> Void
        ) {
            self.service = service
            self.tapAction = tapAction
        }
        
        
        /// The coordinate space to use for callout.
        public let coordinateSpace = "com.keyboardkit.coordinate.ActionCallout"

        /// The service to use for resolving callout actions.
        public var service: CalloutService?

        /// The action handler to use when tapping buttons.
        public var tapAction: (KeyboardAction) -> Void

        public var actionSize = CGSize.zero
        
        /// The currently active actions.
        @Published
        public private(set) var actions: [KeyboardAction] = []
        
        /// The callout bubble alignment.
        @Published
        public private(set) var alignment: HorizontalAlignment = .leading
        
        /// The frame of the currently pressed button.
        @Published
        public private(set) var buttonFrame: CGRect = .zero
        
        /// The currently selected action index.
        @Published
        public private(set) var selectedIndex: Int = -1


        // MARK: - Deprecated

        @available(*, deprecated, renamed: "init(service:tapAction:)")
        public convenience init(
            actionProvider: CalloutActionProvider?,
            tapAction: @escaping (KeyboardAction) -> Void
        ) {
            self.init(service: actionProvider, tapAction: tapAction)
        }

        @available(*, deprecated, renamed: "service")
        public var actionProvider: CalloutService? {
            get { service }
            set { service = newValue }
        }
    }
}


// MARK: - Public functionality

public extension CalloutContext.ActionContext {
    
    /// Whether or not the context has a selected action.
    var hasSelectedAction: Bool { selectedAction != nil }
    
    /// Whether or not the context currently has actions.
    var isActive: Bool { !actions.isEmpty }
    
    /// Whether or not the action callout is leading.
    var isLeading: Bool { !isTrailing }
    
    /// Whether or not the action callout is trailing.
    var isTrailing: Bool { alignment == .trailing }
    
    /// The currently selected callout action, if any.
    var selectedAction: KeyboardAction? {
        isIndexValid(selectedIndex) ? actions[selectedIndex] : nil
    }
    
    
    /// End the drag gesture by commiting and resetting.
    func endDragGesture() {
        handleSelectedAction()
        reset()
    }
    
    /// Handle the currently selected action, if any.
    func handleSelectedAction() {
        guard let action = selectedAction else { return }
        tapAction(action)
    }
    
    /// Reset the context. This will dismiss the callout.
    func reset() {
        actions = []
        selectedIndex = -1
        buttonFrame = .zero
    }
    
    /// Trigger haptic feedback for selection change.
    func triggerHapticFeedbackForSelectionChange() {
        service?.triggerFeedbackForSelectionChange()
    }
    
    /// Update the input actions for a certain action.
    func updateInputs(for action: KeyboardAction?, in geo: GeometryProxy, alignment: HorizontalAlignment? = nil) {
        guard let action = action else { return reset() }
        guard let actions = service?.calloutActions(for: action) else { return }
        self.buttonFrame = geo.frame(in: .named(coordinateSpace))
        self.alignment = alignment ?? getAlignment(for: geo)
        self.actions = isLeading ? actions : actions.reversed()
        self.selectedIndex = startIndex
        guard isActive else { return }
        triggerHapticFeedbackForSelectionChange()
    }
    
    /// Update the selected action for a drag gesture.
    func updateSelection(with value: DragGesture.Value) {
        guard buttonFrame != .zero else { return }
        guard actionSize != .zero else { return }
        if shouldReset(for: value.translation) { return reset() }
        guard shouldUpdateSelection(for: value.translation) else { return }
        let translation = value.translation.width
        let standardStyle = Callouts.ActionCalloutStyle.standard
        let maxButtonSize = standardStyle.maxButtonSize
        let offset = isLeading ? Int(value.location.x / actionSize.width) : Int(abs(value.location.x - actionSize.width) / actionSize.width)
        let index = isLeading ? offset : actions.count - offset - 1
        let newIndex = isIndexValid(index) ? index : startIndex
        if selectedIndex != newIndex { triggerHapticFeedbackForSelectionChange() }
        self.selectedIndex = newIndex
    }
}


// MARK: - Context builders

public extension CalloutContext.ActionContext {
    
    /// This context can be used to disable action callouts.
    static var disabled: CalloutContext.ActionContext {
        .init(
            service: nil,
            tapAction: { _ in }
        )
    }
}


// MARK: - Private functionality

private extension CalloutContext.ActionContext {
    
    var startIndex: Int {
        isLeading ? 0 : actions.count - 1
    }
    
    func isIndexValid(_ index: Int) -> Bool {
        index >= 0 && index < actions.count
    }
    
    func getAlignment(for geo: GeometryProxy) -> HorizontalAlignment {
        #if os(iOS)
        let center = UIScreen.main.bounds.size.width / 2
        let isTrailing = buttonFrame.origin.x > center
        return isTrailing ? .trailing : .leading
        #else
        return .leading
        #endif
    }
    
    func shouldReset(for dragTranslation: CGSize) -> Bool {
        dragTranslation.height > buttonFrame.height
    }
    
    func shouldUpdateSelection(for dragTranslation: CGSize) -> Bool {
        let translation = dragTranslation.width
        if translation == 0 { return true }
        return isLeading ? translation > 0 : translation < 0
    }
}
