//! Bounded Native Dynamic Metadata Reading, Not Loader Policy

const std = @import("std");

const dynamic = @import("shared").elf.constants.dynamic;
const format = @import("shared").elf.constants.format;
const header = @import("shared").elf.read.header;
const programs = @import("shared").elf.read.programs;
const types = @import("shared").elf.types.dynamic;
const virtual = @import("shared").elf.read.virtual;

const DynamicError = @import("shared").elf.errors.dynamic.DynamicError;
const Program = @import("shared").elf.types.format.Elf64ProgramHeader;

pub fn read(data: []const u8) DynamicError!types.Metadata {
    const value = try header.read(data);
    if (!value.isX8664()) return error.UnsupportedArchitecture;
    if (value.ElfType != format.TYPE_DYNAMIC) return error.UnsupportedImage;
    const loads = try programs.read(data, value);
    const entries = try entriesFrom(data, loads);
    const strings = try virtual.bytes(data, loads, try required(entries, dynamic.STRING_TABLE), try required(entries, dynamic.STRING_BYTES));
    if (strings[0] != 0 or strings[strings.len - 1] != 0) return error.InvalidDynamicString;
    if (try required(entries, dynamic.SYMBOL_ENTRY_BYTES) != @sizeOf(types.Symbol)) return error.InvalidDynamic;
    const count = try symbolsCount(data, loads, entries);
    const metadata: types.Metadata = .{
        .Entries = entries,
        .Strings = strings,
        .Symbols = try rows(types.Symbol, data, loads, try required(entries, dynamic.SYMBOL_TABLE), count * @sizeOf(types.Symbol)),
        .Relocations = try relocations(data, loads, entries),
        .ProcedureRelocations = try procedures(data, loads, entries),
    };
    try checkReferences(metadata);
    return metadata;
}

fn entriesFrom(data: []const u8, loads: []const Program) DynamicError![]const types.Entry {
    var selected: ?Program = null;
    for (loads) |program| {
        switch (program.SegmentType) {
            format.SEGMENT_INTERP => return error.UnsupportedDynamic,
            format.SEGMENT_DYNAMIC => {
                if (selected != null) return error.InvalidDynamic;
                selected = program;
            },
            else => {},
        }
    }
    const segment = selected orelse return error.MissingDynamic;
    if (segment.UnitSize > segment.MemorySize) return error.InvalidDynamic;
    const table = try rows(types.Entry, data, loads, segment.VirtualAddress, segment.UnitSize);
    if (table.len == 0 or @intFromPtr(table.ptr) - @intFromPtr(data.ptr) != segment.Offset) return error.InvalidDynamic;
    for (table, 0..) |entry, index| {
        if (entry.Tag == dynamic.NULL) return table[0..index];
    }
    return error.InvalidDynamic;
}

fn symbolsCount(data: []const u8, loads: []const Program, entries: []const types.Entry) DynamicError!u64 {
    const address = (try singleton(entries, dynamic.HASH)) orelse return error.UnsupportedDynamic;
    const word = @sizeOf(u32);
    const prefix = try virtual.bytes(data, loads, address, dynamic.HASH_HEADER_WORDS * word);
    const buckets: u64 = std.mem.readInt(u32, prefix[0..word], .little);
    const count: u64 = std.mem.readInt(u32, prefix[word..][0..word], .little);
    if (buckets == 0 or count == 0) return error.InvalidDynamic;
    const table = try virtual.bytes(data, loads, address, (dynamic.HASH_HEADER_WORDS + buckets + count) * word);
    var index: usize = dynamic.HASH_HEADER_WORDS * word;
    while (index < table.len) : (index += word) {
        if (std.mem.readInt(u32, table[index..][0..word], .little) >= count) return error.InvalidDynamic;
    }
    return count;
}

fn relocations(data: []const u8, loads: []const Program, entries: []const types.Entry) DynamicError![]const types.Relocation {
    const address = try singleton(entries, dynamic.RELA);
    const size = try singleton(entries, dynamic.RELA_BYTES);
    const stride = try singleton(entries, dynamic.RELA_ENTRY_BYTES);
    if (stride) |entry| if (entry != @sizeOf(types.Relocation)) return error.InvalidDynamic;
    if (address == null and size == null) return &.{};
    if (stride == null) return error.InvalidDynamic;
    return rows(types.Relocation, data, loads, address orelse return error.InvalidDynamic, size orelse return error.InvalidDynamic);
}

fn procedures(data: []const u8, loads: []const Program, entries: []const types.Entry) DynamicError![]const types.Relocation {
    const address = try singleton(entries, dynamic.JUMP_RELOCATIONS);
    const size = try singleton(entries, dynamic.PLT_RELOCATION_BYTES);
    const kind = try singleton(entries, dynamic.PLT_RELOCATION_KIND);
    if (address == null and size == null and kind == null) return &.{};
    if ((kind orelse return error.InvalidDynamic) != dynamic.RELA) return error.UnsupportedDynamic;
    return rows(types.Relocation, data, loads, address orelse return error.InvalidDynamic, size orelse return error.InvalidDynamic);
}

fn singleton(entries: []const types.Entry, tag: i64) DynamicError!?u64 {
    var found: ?u64 = null;
    for (entries) |entry| {
        if (entry.Tag != tag) continue;
        if (found != null) return error.InvalidDynamic;
        found = entry.Value;
    }
    return found;
}

fn required(entries: []const types.Entry, tag: i64) DynamicError!u64 {
    return (try singleton(entries, tag)) orelse error.InvalidDynamic;
}

fn rows(comptime Row: type, data: []const u8, loads: []const Program, address: u64, size: u64) DynamicError![]const Row {
    const stride = @sizeOf(Row);
    if (size == 0) return &.{};
    if (size % stride != 0) return error.InvalidDynamic;
    const bytes = try virtual.bytes(data, loads, address, size);
    const entries: [*]const Row = @ptrCast(bytes.ptr);
    return entries[0 .. bytes.len / stride];
}

fn checkReferences(metadata: types.Metadata) DynamicError!void {
    _ = try singleton(metadata.Entries, dynamic.SONAME);
    for (metadata.Entries) |entry| {
        if (entry.Tag != dynamic.NEEDED and entry.Tag != dynamic.SONAME) continue;
        if ((try metadata.string(entry.Value)).len == 0) return error.InvalidDynamicString;
    }
    for (metadata.Symbols) |symbol| _ = try metadata.string(symbol.NameOffset);
    if (overlap(metadata.Relocations, metadata.ProcedureRelocations)) return error.InvalidDynamic;
    for (metadata.Relocations) |entry| if (entry.Info >> @bitSizeOf(u32) >= metadata.Symbols.len) return error.InvalidDynamic;
    for (metadata.ProcedureRelocations) |entry| if (entry.Info >> @bitSizeOf(u32) >= metadata.Symbols.len) return error.InvalidDynamic;
}

fn overlap(left: []const types.Relocation, right: []const types.Relocation) bool {
    if (left.len == 0 or right.len == 0) return false;
    const left_start = @intFromPtr(left.ptr);
    const right_start = @intFromPtr(right.ptr);
    return if (left_start <= right_start)
        right_start - left_start < left.len * @sizeOf(types.Relocation)
    else
        left_start - right_start < right.len * @sizeOf(types.Relocation);
}
