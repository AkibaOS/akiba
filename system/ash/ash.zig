//! Ash - Akiba Shell

const akiba = @import("akiba");

const MAX_INPUT = 256;
var input_buffer: [MAX_INPUT]u8 = undefined;
var input_len: usize = 0;

export fn _start() noreturn {
    while (true) {
        // Print prompt
        akiba.io.print("/ >>> ") catch {};

        // Read line
        input_len = 0;
        while (true) {
            const char = akiba.io.getchar() catch continue;

            if (char == '\n') {
                akiba.io.print("\n") catch {};
                break;
            } else if (char == '\x08') {
                // Backspace
                if (input_len > 0) {
                    input_len -= 1;
                    // Echo backspace to screen
                    akiba.io.print("\x08") catch {};
                }
            } else if (char >= 32 and char <= 126 and input_len < MAX_INPUT - 1) {
                input_buffer[input_len] = char;
                input_len += 1;
                // Echo character to screen
                const char_str = [_]u8{char};
                akiba.io.print(&char_str) catch {};
            }
        }

        // TODO: Parse and execute command
        if (input_len > 0) {
            akiba.io.print("Command \"") catch {};
            akiba.io.print(input_buffer[0..input_len]) catch {};
            akiba.io.print("\" not implemented yet\n") catch {};
        }
    }
}
