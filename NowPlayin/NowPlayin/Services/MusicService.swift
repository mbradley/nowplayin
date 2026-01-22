import Foundation

enum MusicService {
    static func isMusicAppRunning() -> Bool {
        let script = """
        tell application "System Events"
            return (name of processes) contains "Music"
        end tell
        """

        guard let appleScript = NSAppleScript(source: script) else { return false }

        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)

        return result.booleanValue
    }

    static func getCurrentTrack() -> Track? {
        let script = """
        tell application "Music"
            if player state is playing then
                set trackName to name of current track
                set trackArtist to artist of current track
                return "playing|" & trackName & "|" & trackArtist
            else if player state is paused then
                set trackName to name of current track
                set trackArtist to artist of current track
                return "paused|" & trackName & "|" & trackArtist
            else
                return "stopped||"
            end if
        end tell
        """

        guard let appleScript = NSAppleScript(source: script) else { return nil }

        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)

        guard error == nil,
              let output = result.stringValue else {
            return nil
        }

        let parts = output.components(separatedBy: "|")
        guard parts.count == 3 else { return nil }

        let state: PlayerState
        switch parts[0] {
        case "playing": state = .playing
        case "paused": state = .paused
        default: state = .stopped
        }

        return Track(name: parts[1], artist: parts[2], state: state)
    }
}
