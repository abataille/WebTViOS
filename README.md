# WebTViOS

WebTViOS is an open-source SwiftUI iOS app for watching multiple HLS video streams at once. Channels appear in a responsive grid; selecting a channel pauses the other previews and promotes the selected stream to fullscreen playback. Returning to the grid resumes muted live previews at the latest frame.

## What this repository includes

- A SwiftUI multi-stream grid built around `AVPlayer` and `AVPlayerLayer`.
- Fullscreen channel playback with swipe navigation.
- Local Core Data storage for user-managed channels.
- Safe demo HLS streams for development only.

## What this repository does not include

- No private TV channel URLs.
- No Mediathek integration.
- No CloudKit or iCloud sync.
- No license to rebroadcast or redistribute video content.

## Legal stream usage

This app is a player shell. Bring your own legally accessible HLS `.m3u8` URLs. Before adding a stream, make sure you have permission to access and use it in your context. Do not commit private, scraped, geo-restricted, paid, or otherwise unauthorized channel lists.

## Getting started

1. Open `WebTViOS.xcodeproj` in Xcode.
2. Build the `WebTViOS` scheme for an iPhone or iPad simulator.
3. Use the channel manager (`+/-`) to add your own legal HLS URLs.
4. Use Reset to restore the bundled demo streams.

## Channel format

Channels are stored as:

```swift
["Display Name": ["https://example.com/stream.m3u8", "", "1"]]
```

The third value controls whether the channel is included in the live preview grid (`"1"`) or shown as a non-preview entry (`"0"`). The middle value is kept empty for compatibility with older saved channel data.

## Notes for maintainers

- The default streams in `ImprovedChannelView.swift` and `ChannelView.swift` are public demo streams only.
- The project intentionally uses local Core Data (`NSPersistentContainer`) rather than CloudKit.
- Keep user-specific Xcode files, large media, and private stream lists out of git.

## License

MIT. See `LICENSE`.
