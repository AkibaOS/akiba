const ash = @import("ash/ash.zig");
const crimson = @import("crimson/panic.zig");
const serial = @import("drivers/serial.zig");
const sequence = @import("boot/sequence.zig");

export fn mirai(multiboot_info_addr: u64) noreturn {
    serial.init();

    serial.print("\n═══════════════════════════════════\n");
    serial.print("          Welcome to Akiba          \n");
    serial.print("═══════════════════════════════════\n\n");

    // Run boot sequence
    sequence.run(multiboot_info_addr);

    // Initialize shell
    ash.init(sequence.get_filesystem());

    serial.print("\n** Boot Complete **\n");

    while (true) {
        asm volatile ("hlt");
    }
}

pub fn panic(message: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    crimson.collapse(message, null);
}

export fn on_key_typed(char: u8) void {
    ash.on_key_press(char);
}
