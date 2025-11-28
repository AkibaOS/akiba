//! Multiboot2 boot protocol parser

const serial = @import("../drivers/serial.zig");

pub const MemoryEntry = struct {
    base: u64,
    length: u64,
    entry_type: u32,
};

const MAX_MEMORY_ENTRIES = 32;
var memory_entries: [MAX_MEMORY_ENTRIES]MemoryEntry = undefined;

pub fn parse_memory_map(addr: u64) []MemoryEntry {
    serial.print("\n=== Multiboot2 Memory Map ===\n");

    const total_size = @as(*u32, @ptrFromInt(addr)).*;
    var offset: u64 = 8;
    var mem_count: usize = 0;

    while (offset < total_size) {
        const tag_addr = addr + offset;
        const tag_type = @as(*u32, @ptrFromInt(tag_addr)).*;
        const tag_size = @as(*u32, @ptrFromInt(tag_addr + 4)).*;

        if (tag_type == 0) break;

        // Memory map tag (type 6)
        if (tag_type == 6) {
            const entry_size = @as(*u32, @ptrFromInt(tag_addr + 8)).*;
            const entry_count = (tag_size - 16) / entry_size;

            var i: usize = 0;
            while (i < entry_count and mem_count < MAX_MEMORY_ENTRIES) : (i += 1) {
                const entry_addr = tag_addr + 16 + (i * entry_size);
                const base = @as(*u64, @ptrFromInt(entry_addr)).*;
                const length = @as(*u64, @ptrFromInt(entry_addr + 8)).*;
                const entry_type = @as(*u32, @ptrFromInt(entry_addr + 16)).*;

                memory_entries[mem_count] = MemoryEntry{
                    .base = base,
                    .length = length,
                    .entry_type = entry_type,
                };
                mem_count += 1;

                serial.print("  ");
                serial.print_hex(base);
                serial.print(" - ");
                serial.print_hex(base + length - 1);
                serial.print(" (");
                serial.print_hex(length / (1024 * 1024));
                serial.print(" MB)");
                if (entry_type == 1) {
                    serial.print(" [Available]");
                } else {
                    serial.print(" [Reserved]");
                }
                serial.print("\n");
            }
        }

        offset += (tag_size + 7) & ~@as(u64, 7);
    }

    return memory_entries[0..mem_count];
}
