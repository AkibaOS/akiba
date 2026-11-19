//! File-Backed ELF64 Dynamic Views

const std = @import("std");

const DynamicError = @import("shared").elf.errors.dynamic.DynamicError;
const Plan = @import("shared").elf.types.image.Plan;

pub const Role = enum { Executable, Library };

pub const Relro = struct {
    Start: u64,
    End: u64,
};

pub const Layout = struct {
    Image: Plan,
    Metadata: Metadata,
    Bias: u64,
    Relro: ?Relro,
};

pub const Entry = extern struct {
    Tag: i64 align(1),
    Value: u64 align(1),
};

pub const Symbol = extern struct {
    NameOffset: u32 align(1),
    Info: u8,
    Other: u8,
    Section: u16 align(1),
    Value: u64 align(1),
    Size: u64 align(1),
};

pub const Relocation = extern struct {
    Offset: u64 align(1),
    Info: u64 align(1),
    Addend: i64 align(1),
};

pub const Metadata = struct {
    Entries: []const Entry,
    Strings: []const u8,
    Symbols: []const Symbol,
    Relocations: []const Relocation,
    ProcedureRelocations: []const Relocation,

    pub fn string(self: Metadata, offset: u64) DynamicError![]const u8 {
        if (offset >= self.Strings.len) return error.InvalidDynamicString;
        const rest = self.Strings[@intCast(offset)..];
        const end = std.mem.indexOfScalar(u8, rest, 0) orelse return error.InvalidDynamicString;
        return rest[0..end];
    }
};
