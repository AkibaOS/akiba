//! Multiboot memory map parser

const boot_limits = @import("../../common/limits/boot.zig");
const serial = @import("../../drivers/serial/serial.zig");
const types = @import("types.zig");

var entries: [boot_limits.MAX_MEMORY_ENTRIES]types.MemoryEntry = undefined;

pub fn parse(addr: u64) []types.MemoryEntry {
    const total_size = @as(*u32, @ptrFromInt(addr)).*;
    var offset: u64 = 8;
    var count: usize = 0;

    while (offset < total_size) {
        const tag_addr = addr + offset;
        const tag_type = @as(*u32, @ptrFromInt(tag_addr)).*;
        const tag_size = @as(*u32, @ptrFromInt(tag_addr + 4)).*;

        if (tag_type == 0) break;

        if (tag_type == 6) {
            const entry_size = @as(*u32, @ptrFromInt(tag_addr + 8)).*;
            const entry_count = (tag_size - 16) / entry_size;

            for (0..entry_count) |i| {
                if (count >= boot_limits.MAX_MEMORY_ENTRIES) break;

                const entry_addr = tag_addr + 16 + (i * entry_size);
                const base = @as(*u64, @ptrFromInt(entry_addr)).*;
                const length = @as(*u64, @ptrFromInt(entry_addr + 8)).*;
                const entry_type = @as(*u32, @ptrFromInt(entry_addr + 16)).*;

                entries[count] = types.MemoryEntry{
                    .base = base,
                    .length = length,
                    .entry_type = entry_type,
                };
                count += 1;

                const status = if (entry_type == 1) "Available" else "Reserved";
                serial.printf("  {x}-{x} ({} MB) [{s}]\n", .{
                    base, base + length - 1, length / (1024 * 1024), status,
                });
            }
        }

        offset += (tag_size + 7) & ~@as(u64, 7);
    }

    return entries[0..count];
}
