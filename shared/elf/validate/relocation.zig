//! Checked Native ELF Relocation Write Plans

const std = @import("std");

const dynamic = @import("shared").elf.constants.dynamic;
const kinds = @import("shared").elf.constants.relocation;
const types = @import("shared").elf.types;

const Entry = types.dynamic.Entry;
const Layout = types.dynamic.Layout;
const Plan = types.relocation.Plan;
const Program = types.format.Elf64ProgramHeader;
const Relocation = types.dynamic.Relocation;
const RelocationError = @import("shared").elf.errors.relocation.RelocationError;
const Write = types.relocation.Write;

const WORD_BYTES = @sizeOf(u64);

pub fn plan(allocator: std.mem.Allocator, layout: *const Layout, bindings: []const ?u64) RelocationError!Plan {
    try checkEncoding(layout.Metadata.Entries);
    const tables = [_][]const Relocation{ layout.Metadata.Relocations, layout.Metadata.ProcedureRelocations };
    const count = std.math.add(usize, tables[0].len, tables[1].len) catch return error.InvalidRelocation;
    const writes = try allocator.alloc(Write, count);
    errdefer allocator.free(writes);
    var index: usize = 0;
    for (tables) |table| {
        for (table) |entry| {
            const address = std.math.add(u64, layout.Bias, entry.Offset) catch return error.InvalidRelocationTarget;
            if (!writable(layout.Image.Segments, address)) return error.InvalidRelocationTarget;
            writes[index] = .{ .Address = address, .Value = try valueFor(layout, entry, bindings) };
            index += 1;
        }
    }
    std.mem.sort(Write, writes, {}, earlier);
    if (writes.len > 1) {
        for (writes[0 .. writes.len - 1], writes[1..]) |previous, next| {
            if (next.Address - previous.Address < WORD_BYTES) return error.OverlappingRelocation;
        }
    }
    return .{ .Allocator = allocator, .Writes = writes };
}

fn checkEncoding(entries: []const Entry) RelocationError!void {
    for (entries) |entry| {
        switch (entry.Tag) {
            dynamic.REL, dynamic.REL_BYTES, dynamic.REL_ENTRY_BYTES, dynamic.RELR, dynamic.RELR_BYTES, dynamic.RELR_ENTRY_BYTES, dynamic.TEXT_RELOCATIONS => return error.UnsupportedRelocation,
            dynamic.FLAGS => if (entry.Value & dynamic.FLAG_TEXT_RELOCATIONS != 0) return error.UnsupportedRelocation,
            else => {},
        }
    }
}

fn writable(segments: []const Program, address: u64) bool {
    var left: usize = 0;
    var right = segments.len;
    while (left < right) {
        const middle = left + (right - left) / 2;
        const segment = segments[middle];
        if (address < segment.VirtualAddress) {
            right = middle;
            continue;
        }
        const offset = address - segment.VirtualAddress;
        if (offset >= segment.MemorySize) {
            left = middle + 1;
            continue;
        }
        return segment.isWritable() and !segment.isExecutable() and WORD_BYTES <= segment.MemorySize - offset;
    }
    return false;
}

fn valueFor(layout: *const Layout, entry: Relocation, bindings: []const ?u64) RelocationError!u64 {
    const symbol = entry.Info >> @bitSizeOf(u32);
    const kind: u32 = @truncate(entry.Info);
    const value = switch (kind) {
        kinds.RELATIVE => relative: {
            if (symbol != 0) return error.InvalidRelocation;
            const address = @as(i128, layout.Bias) + entry.Addend;
            break :relative std.math.cast(u64, address) orelse return error.InvalidRelocationValue;
        },
        kinds.GLOBAL_DATA, kinds.JUMP_SLOT => bound: {
            if (symbol == 0 or symbol >= layout.Metadata.Symbols.len or entry.Addend != 0) return error.InvalidRelocation;
            if (symbol >= bindings.len) return error.MissingBinding;
            break :bound bindings[@intCast(symbol)] orelse return error.MissingBinding;
        },
        else => return error.UnsupportedRelocation,
    };
    if (value < layout.Policy.MinimumAddress or value > layout.Policy.MaximumAddress) return error.InvalidRelocationValue;
    return value;
}

fn earlier(_: void, left: Write, right: Write) bool {
    return left.Address < right.Address;
}
