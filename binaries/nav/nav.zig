//! nav - Navigate the filesystem
//!
//! nav          - Print current location
//! nav <path>   - Navigate to path
//! nav ^        - Navigate to parent
//! nav /        - Navigate to root

const akiba = @import("akiba");

const Color = struct {
    const white: u32 = 0x00FFFFFF;
    const green: u32 = 0x0088FF88;
    const red: u32 = 0x00FF4444;
};

// Global buffer
var location_buf: [256]u8 = undefined;

export fn main(pc: u32, pv: [*]const [*:0]const u8) u8 {
    // No arguments - print current location
    if (pc <= 1) {
        const location = akiba.io.getlocation(&location_buf) catch {
            _ = akiba.io.mark(akiba.io.stream, "nav: cannot get current location.\n", Color.red) catch 0;
            return 1;
        };
        _ = akiba.io.mark(akiba.io.stream, location, Color.green) catch 0;
        _ = akiba.io.mark(akiba.io.stream, "\n", Color.white) catch 0;
        return 0;
    }

    // Get target path from argument
    const arg = pv[1];
    var target_len: usize = 0;
    while (arg[target_len] != 0) : (target_len += 1) {}
    const target = arg[0..target_len];

    // Navigate - setlocation auto-sends letter to parent
    akiba.io.setlocation(target) catch {
        _ = akiba.io.mark(akiba.io.stream, "nav: cannot navigate to '", Color.red) catch 0;
        _ = akiba.io.mark(akiba.io.stream, target, Color.white) catch 0;
        _ = akiba.io.mark(akiba.io.stream, "': No such stack.\n", Color.red) catch 0;
        return 1;
    };

    return 0;
}
