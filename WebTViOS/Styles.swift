//
//  Styles.swift
//  WebTViOS
//
//  Created by Raymund Vorwerk on 19.11.20.
//  Copyright © 2020 Raymund Vorwerk. All rights reserved.
//

import Foundation
import SwiftUI

/// Filled primary button style used across action buttons.
struct FilledButton: ButtonStyle {
    /// Creates the filled button appearance for the current state.
    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(configuration.isPressed ? .gray : .white)
            .padding()
            .background(Color.accentColor)
            .cornerRadius(8)
    }
}
/// Outline button style with accent-colored text.
struct OutlineButton: ButtonStyle {
    /// Creates the outline appearance for the current button state.
    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(configuration.isPressed ? .gray : .accentColor)
            .padding(5)
            .background(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                ).stroke(Color.primary)
            )
    }
}

/// Compact outline button style used in forms.
struct OutlineButton1: ButtonStyle {
    /// Creates the compact outline appearance for the current state.
    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
           // .foregroundColor(configuration.isPressed ? .black : .black)
            .padding(2)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                ).stroke(Color.primary)
            )
    }
}

/// Destructive-looking outline button style.
struct OutlineButton2: ButtonStyle {
    /// Creates the red outline appearance for the current state.
    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(configuration.isPressed ? .gray : .red)
            .padding(2)
           // .font(.system(size: 16))
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                ).stroke(Color.primary)
            )
           
          
    }
}


/// Borderless text button style with standard padding.
struct NoOutlineButton: ButtonStyle {
    /// Creates the plain padded button appearance.
    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
           // .foregroundColor(configuration.isPressed ? .black : .black)
            .padding(10)
            .font(.system(size: 16))
    }
}
/// Smaller borderless text button style.
struct NoOutlineButton1: ButtonStyle {
    /// Creates the compact plain button appearance.
    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
           // .foregroundColor(configuration.isPressed ? .black : .black)
            .padding(5)
    }
}

/// Adds an inline clear button to text fields.
struct TextFieldClearButton: ViewModifier {
    @Binding var text: String
    
    /// Wraps content with a trailing button that clears the bound text.
    func body(content: Content) -> some View {
        HStack() {
            content
            if !text.isEmpty {
                Button(
                    action: {
                        self.text = "" },
                    label: {
                        Image(systemName: "multiply.circle")
                            .foregroundColor(Color.accentColor)
                            .frame(width: 12, height: 12)
                    }
                )
                .padding(.trailing, 8)
                .buttonStyle(NoOutlineButton())
                
            }
        }
    }
}

