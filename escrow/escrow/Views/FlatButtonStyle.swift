//
//  FlatButtonStyle.swift
//  escrow
//
//  A button style with no press animation — renders the label as-is, ignoring
//  `isPressed`. Applied app-wide so our custom buttons don't get the default
//  fade/scale on tap. Buttons keep their own backgrounds (those are view
//  modifiers on the button, not part of the label).
//

import SwiftUI

struct FlatButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
