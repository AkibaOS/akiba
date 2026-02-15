//! rd - Read unit contents
//!
//! rd <location>    - Display contents of a unit (file)
//! rd               - Error: no location specified

const akiba = @import("akiba");

const Color = struct {
    const white: u32 = 0x00FFFFFF;
    const red: u32 = 0x00FF4444;
    const gray: u32 = 0x00888888;
};

// Buffer for file contents (64KB max)
var file_buffer: [64 * 1024]u8 = undefined;

export fn main(pc: u32, pv: [*]const [*:0]const u8) u8 {
    // No arguments - show error
    if (pc <= 1) {
        _ = akiba.io.mark(akiba.io.stream, "rd: missing unit location.\n", Color.red) catch 0;
        return 1;
    }

    // Get location from argument
    const arg = pv[1];
    var location_len: usize = 0;
    while (arg[location_len] != 0) : (location_len += 1) {}
    const location = arg[0..location_len];

    // Open the file
    const fd = akiba.io.attach(location, akiba.io.VIEW_ONLY) catch {
        _ = akiba.io.mark(akiba.io.stream, "rd: cannot access '", Color.red) catch 0;
        _ = akiba.io.mark(akiba.io.stream, location, Color.white) catch 0;
        _ = akiba.io.mark(akiba.io.stream, "': No such unit.\n", Color.red) catch 0;
        return 1;
    };

    // Read contents
    const bytes_read = akiba.io.view(fd, &file_buffer) catch {
        _ = akiba.io.mark(akiba.io.stream, "rd: cannot read '", Color.red) catch 0;
        _ = akiba.io.mark(akiba.io.stream, location, Color.white) catch 0;
        _ = akiba.io.mark(akiba.io.stream, "'.\n", Color.red) catch 0;
        akiba.io.seal(fd);
        return 1;
    };

    // Display contents
    if (bytes_read > 0) {
        _ = akiba.io.mark(akiba.io.stream, file_buffer[0..bytes_read], Color.white) catch 0;

        // Add newline if file doesn't end with one
        if (file_buffer[bytes_read - 1] != '\n') {
            _ = akiba.io.mark(akiba.io.stream, "\n", Color.white) catch 0;
        }
    }

    // Close file
    akiba.io.seal(fd);

    return 0;
}
