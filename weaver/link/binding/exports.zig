//! Index Visible Definitions And Deduplicate Direct ELF Dependencies

const std = @import("std");

const elf = @import("shared").elf;
const link = @import("weaver").link;

const Direct = link.types.link.Direct;
const Exports = link.types.link.Exports;
const Graph = @import("weaver").library.types.graph.Graph;
const LinkError = link.errors.link.LinkError;
const Metadata = elf.types.dynamic.Metadata;
const fields = elf.constants.symbol;

pub fn index(allocator: std.mem.Allocator, metadata: Metadata) LinkError!Exports {
    var exports: Exports = .empty;
    errdefer exports.deinit(allocator);
    for (metadata.Symbols, 0..) |symbol, number| {
        const visibility = symbol.Other & fields.VISIBILITY_MASK;
        if (symbol.Section == fields.SECTION_UNDEFINED or symbol.Info >> fields.BINDING_SHIFT == fields.BINDING_LOCAL or
            (visibility != fields.VISIBILITY_DEFAULT and visibility != fields.VISIBILITY_PROTECTED)) continue;
        const name = try metadata.string(symbol.NameOffset);
        if (name.len == 0) continue;
        const slot = try exports.getOrPut(allocator, name);
        slot.value_ptr.* = if (slot.found_existing) null else number;
    }
    return exports;
}

pub fn direct(allocator: std.mem.Allocator, graph: *const Graph, metadata: Metadata) LinkError!Direct {
    var result: Direct = .empty;
    errdefer result.deinit(allocator);
    for (metadata.Entries) |entry| {
        if (entry.Tag != elf.constants.dynamic.NEEDED) continue;
        const name = try metadata.string(entry.Value);
        const library = graph.Names.get(name) orelse return error.InvalidLinkGraph;
        try result.put(allocator, library, {});
    }
    return result;
}
