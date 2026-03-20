//! Render Loaded Modules

const serial = @import("../../drivers/serial/serial.zig");

pub const ModuleInfo = struct {
    name: [64]u8,
    name_len: usize,
    base_address: u64,
    size: u64,
};

pub const max_modules = 32;

var loaded_modules: [max_modules]ModuleInfo = undefined;
var module_count: usize = 0;

pub fn register_module(name: []const u8, base_address: u64, size: u64) bool {
    if (module_count >= max_modules) {
        return false;
    }

    var module = &loaded_modules[module_count];
    const len = @min(name.len, 63);
    for (name[0..len], 0..) |c, i| {
        module.name[i] = c;
    }
    module.name[len] = 0;
    module.name_len = len;
    module.base_address = base_address;
    module.size = size;

    module_count += 1;
    return true;
}

pub fn render() void {
    if (module_count == 0) {
        serial.printf("Loaded Modules: (none registered)\n\n", .{});
        return;
    }

    serial.printf("Loaded Modules:\n", .{});

    for (0..module_count) |i| {
        const module = &loaded_modules[i];
        serial.printf("  %s: %x - %x (%d bytes)\n", .{
            module.name[0..module.name_len],
            module.base_address,
            module.base_address + module.size,
            module.size,
        });
    }

    serial.printf("\n", .{});
}

pub fn find_module_for_address(address: u64) ?*const ModuleInfo {
    for (0..module_count) |i| {
        const module = &loaded_modules[i];
        if (address >= module.base_address and address < module.base_address + module.size) {
            return module;
        }
    }
    return null;
}

pub fn clear_modules() void {
    module_count = 0;
}
