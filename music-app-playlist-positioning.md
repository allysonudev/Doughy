---
topic: Music.app AppleScript playlist insertion
audience: AI agents
verified_by: local Music.app scripting dictionary via sdef
---

# Music.app Playlist Positioning With AppleScript

## Short Answer

Music.app can add or duplicate tracks into a playlist at a specific position using AppleScript location specifiers. It is not limited to adding only at the beginning or end.

## Key AppleScript Commands

- `duplicate`: Use this for an existing Music library track.
- `add`: Use this for adding one or more local audio files from disk.

The Music.app scripting dictionary exposes both commands with a `to` parameter whose type is `location specifier`, which supports locations such as:

- `beginning of <playlist>`
- `end of <playlist>`
- `before track N of <playlist>`
- `after track N of <playlist>`

## Existing Library Track Example

```applescript
tell application "Music"
    set targetPlaylist to user playlist "My Playlist"
    set sourceTrack to track 1 of library playlist 1 whose name is "Song Name"

    duplicate sourceTrack to before track 5 of targetPlaylist
end tell
```

## Other Existing-Track Placement Examples

```applescript
tell application "Music"
    set targetPlaylist to user playlist "My Playlist"
    set sourceTrack to track 1 of library playlist 1 whose name is "Song Name"

    duplicate sourceTrack to beginning of targetPlaylist
    duplicate sourceTrack to end of targetPlaylist
    duplicate sourceTrack to after track 10 of targetPlaylist
    duplicate sourceTrack to before track 1 of targetPlaylist
end tell
```

## Local File Example

```applescript
tell application "Music"
    add POSIX file "/path/to/song.mp3" to before track 5 of user playlist "My Playlist"
end tell
```

## Important Caveats

- Position refers to the playlist's manual order.
- If the Music UI is sorted by name, artist, album, date added, or another column, the insertion may appear to land somewhere else even if the manual playlist order changed correctly.
- For Apple Music or cloud/library items, prefer `duplicate`.
- For files on disk, prefer `add`.
- Smart playlists and some subscription-managed playlists may not be modifiable.

## Practical Agent Guidance

When asked to insert a song at a position:

1. Determine whether the source is already in the Music library or is a local file.
2. Resolve the target playlist as a `user playlist`.
3. Use `duplicate <track> to before/after track N of <playlist>` for library tracks.
4. Use `add <file> to before/after track N of <playlist>` for local files.
5. Warn the user that visible ordering depends on the playlist sort mode in Music.app.
