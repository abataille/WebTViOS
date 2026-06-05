import AVKit
import SwiftUI

/// Displays the multi-stream grid and sizes tiles to best fill the screen.
struct ChannelGridView: View {
    let channels: [String]
    let livePreviewLimit: Int
    let previewImages: [String: UIImage]
    let selectChannel: (String) -> Void

    private let itemSpacing: CGFloat = 4
    private let contentPadding: CGFloat = 2
    private let tileAspectRatio: CGFloat = 16.0 / 9.0

    /// Renders the responsive grid for the currently available channels.
    var body: some View {
        GeometryReader { geometry in
            let layout = bestLayout(for: geometry.size)
            let gridRows = rows(for: layout.columnCount)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: itemSpacing) {
                    ForEach(Array(gridRows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: itemSpacing) {
                            ForEach(Array(row.enumerated()), id: \.element) { _, name in
                                SenderCell(
                                    name: name,
                                    isLive: livePreviewNames.contains(name) &&
                                        (channelList[name]?[2] == "1" &&
                                        (channelList[name]?[0].hasSuffix("m3u8") ?? false)),
                                    player: PlayerManager.shared.players[name],
                                    previewImage: previewImages[name],
                                    action: { selectChannel(name) }
                                )
                                .frame(width: layout.tileWidth, height: layout.tileHeight)
                                .clipped()
                            }

                            if row.count < layout.columnCount {
                                ForEach(0..<(layout.columnCount - row.count), id: \.self) { _ in
                                    Color.clear
                                        .frame(width: layout.tileWidth, height: layout.tileHeight)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .top)
                .padding(.horizontal, contentPadding)
                .padding(.vertical, contentPadding)
            }
        }
    }

    private var livePreviewNames: Set<String> {
        Set(channels.prefix(max(livePreviewLimit, 0)))
    }

    /// Chooses the row and column count that uses the available space best.
    private func bestLayout(for size: CGSize) -> GridLayout {
        let itemCount = max(channels.count, 1)
        let availableWidth = max(size.width - (contentPadding * 2), 1)
        let availableHeight = max(size.height - (contentPadding * 2), 1)

        var bestFit: GridLayout?
        var bestOverflow: GridLayout?

        for columns in 1...itemCount {
            let rows = Int(ceil(Double(itemCount) / Double(columns)))
            let totalHorizontalSpacing = itemSpacing * CGFloat(max(columns - 1, 0))
            let tileWidth = floor((availableWidth - totalHorizontalSpacing) / CGFloat(columns))

            guard tileWidth > 0 else { continue }

            let tileHeight = floor(tileWidth / tileAspectRatio)
            guard tileHeight > 0 else { continue }

            let totalVerticalSpacing = itemSpacing * CGFloat(max(rows - 1, 0))
            let contentHeight = (CGFloat(rows) * tileHeight) + totalVerticalSpacing
            let layout = GridLayout(
                columnCount: columns,
                rowCount: rows,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
                contentHeight: contentHeight
            )

            if contentHeight <= availableHeight {
                if bestFit == nil || layout.contentHeight > bestFit!.contentHeight {
                    bestFit = layout
                }
            } else if bestOverflow == nil || layout.contentHeight < bestOverflow!.contentHeight {
                bestOverflow = layout
            }
        }

        return bestFit ?? bestOverflow ?? GridLayout(
            columnCount: 1,
            rowCount: itemCount,
            tileWidth: availableWidth,
            tileHeight: availableWidth / tileAspectRatio,
            contentHeight: CGFloat(itemCount) * (availableWidth / tileAspectRatio)
        )
    }

    /// Splits the flat channel list into stable row groups to avoid lazy view recycling.
    private func rows(for columnCount: Int) -> [[String]] {
        stride(from: 0, to: channels.count, by: columnCount).map { startIndex in
            Array(channels[startIndex..<min(startIndex + columnCount, channels.count)])
        }
    }
}

/// Stores the computed grid dimensions for the current viewport.
private struct GridLayout {
    let columnCount: Int
    let rowCount: Int
    let tileWidth: CGFloat
    let tileHeight: CGFloat
    let contentHeight: CGFloat
}
