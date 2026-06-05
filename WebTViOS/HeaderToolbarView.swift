import CoreData
import SwiftUI

/// Scrollable header toolbar for playback, grid, and sheet actions.
struct HeaderToolbarView: View {
    let isIPhone: Bool
    let verticalSizeClass: UserInterfaceSizeClass?
    let horizontalSizeClass: UserInterfaceSizeClass?
    let currentChannelName: String
    @Binding var showChannelGrid: Bool
    @Binding var reduceDataUsage: Bool
    @Binding var isChannelDialogSheetPresented: Bool
    let headerColor: Color
    let onResetPlayers: () -> Void

    /// Renders the adaptive toolbar content.
    var body: some View {
    
            ScrollView(.horizontal) {
                HStack(spacing: isIPhone ? 6 : 12) {
                    Button(action: {
                        withAnimation {
                            isChannelDialogSheetPresented = true
                        }
                    }) {
                        toolbarLabel(text: "+/-", systemImage: "gear")
                    }
                    .toolbarCapsule(headerColor: headerColor)
                    Spacer()
                    if !(verticalSizeClass == .regular && horizontalSizeClass == .compact) && !showChannelGrid && !currentChannelName.isEmpty {
                        Text(currentChannelName)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .toolbarCapsule(headerColor: headerColor)
                    }
                    
                    Spacer(minLength: isIPhone ? 2 : 10)
                    
                    if showChannelGrid {
                        Toggle("Reset", isOn: $reduceDataUsage)
                            .toggleStyle(.button)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .toolbarCapsule(headerColor: headerColor)
                            .onChange(of: reduceDataUsage) {
                                if reduceDataUsage {
                                    onResetPlayers()
                                }
                            }
                    }
                    
                    if !showChannelGrid {
                        Button(action: {
                            withAnimation {
                                showChannelGrid.toggle()
                            }
                        }) {
                            HStack(spacing: 6) {
                                if !isIPhone {
                                    Image(systemName: "square.grid.3x3")
                                }
                                Text(Bundle.main.releaseVersionNumberPretty + "(" + (Bundle.main.buildVersionNumber ?? "0") + ")")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                        .toolbarCapsule(headerColor: headerColor)
                        .layoutPriority(1)
                    }
                }
                .padding(.vertical, 2)
                .padding(.leading,(isIPhone ? 4: 150))
                
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            
        
    }
        @ViewBuilder
        /// Builds a text or text-plus-icon label depending on device class.
        private func toolbarLabel(text: String, systemImage: String) -> some View {
            if isIPhone {
                Text(text)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                    Text(text)
                }
            }
        }
    
}

/// Applies the shared glass capsule style used by toolbar controls.
private extension View {
    /// Styles a control as a pill-shaped toolbar action.
    func toolbarCapsule(headerColor: Color) -> some View {
        buttonStyle(.plain)
            .foregroundStyle(headerColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule().stroke(Color.white.opacity(0.2))
            }
    }
}
