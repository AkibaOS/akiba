//! Resolve A Placed Graph And Plan All Eager Writes

const std = @import("std");

const elf = @import("shared").elf;
const link = @import("weaver").link;

const Direct = link.types.link.Direct;
const Exports = link.types.link.Exports;
const Layout = elf.types.dynamic.Layout;
const LinkError = link.errors.link.LinkError;
const Placement = @import("weaver").image.types.layout.Placement;
const Plan = link.types.link.Plan;
const Relocation = elf.types.dynamic.Relocation;
const Writes = elf.types.relocation.Plan;
const kinds = elf.constants.relocation;

pub fn plan(allocator: std.mem.Allocator, placement: *const Placement) LinkError!Plan {
    if (placement.Libraries.len != placement.Graph.Libraries.len) return error.InvalidLinkGraph;
    try link.profile.check(placement.Executable.Metadata, .Executable);
    const indices = try allocator.alloc(Exports, placement.Libraries.len);
    defer allocator.free(indices);
    var indexed: usize = 0;
    defer for (indices[0..indexed]) |*index| index.deinit(allocator);
    for (placement.Libraries) |layout| {
        try link.profile.check(layout.Metadata, .Library);
        indices[indexed] = try link.binding.exports.index(allocator, layout.Metadata);
        indexed += 1;
    }
    var executable = try planImage(allocator, placement, &placement.Executable, indices);
    errdefer executable.deinit();
    const libraries = try allocator.alloc(Writes, placement.Libraries.len);
    errdefer allocator.free(libraries);
    var planned: usize = 0;
    errdefer for (libraries[0..planned]) |*writes| writes.deinit();
    for (placement.Libraries) |*layout| {
        libraries[planned] = try planImage(allocator, placement, layout, indices);
        planned += 1;
    }
    return .{ .Allocator = allocator, .Placement = placement, .Executable = executable, .Libraries = libraries };
}

fn planImage(allocator: std.mem.Allocator, placement: *const Placement, layout: *const Layout, indices: []const Exports) LinkError!Writes {
    var direct = try link.binding.exports.direct(allocator, placement.Graph, layout.Metadata);
    defer direct.deinit(allocator);
    const bindings = try allocator.alloc(?u64, layout.Metadata.Symbols.len);
    defer allocator.free(bindings);
    @memset(bindings, null);
    const tables = [_][]const Relocation{ layout.Metadata.Relocations, layout.Metadata.ProcedureRelocations };
    for (tables) |table| {
        for (table) |entry| {
            const operation: u32 = @truncate(entry.Info);
            if (operation != kinds.GLOBAL_DATA and operation != kinds.JUMP_SLOT) continue;
            const number = entry.Info >> @bitSizeOf(u32);
            if (number == 0 or number >= bindings.len) return error.InvalidRelocation;
            const symbol = layout.Metadata.Symbols[@intCast(number)];
            const kind = try link.binding.symbols.reference(symbol, operation);
            if (bindings[@intCast(number)] != null) continue;
            if (symbol.Section != elf.constants.symbol.SECTION_UNDEFINED) {
                bindings[@intCast(number)] = try link.binding.symbols.address(layout, symbol, kind, 0);
                continue;
            }
            const name = try layout.Metadata.string(symbol.NameOffset);
            bindings[@intCast(number)] = try resolve(placement.Libraries, indices, &direct, name, kind, symbol.Size);
        }
    }
    return elf.validate.relocation.plan(allocator, layout, bindings);
}

fn resolve(layouts: []const Layout, indices: []const Exports, direct: *const Direct, name: []const u8, kind: u8, required: u64) LinkError!u64 {
    var provider: ?usize = null;
    var number: usize = undefined;
    var dependencies = direct.keyIterator();
    while (dependencies.next()) |index| {
        if (index.* >= layouts.len) return error.InvalidLinkGraph;
        const definition = indices[index.*].get(name) orelse continue;
        if (provider != null) return error.AmbiguousSymbol;
        number = definition orelse return error.AmbiguousSymbol;
        provider = index.*;
    }
    const layout = &layouts[provider orelse return error.UnresolvedSymbol];
    return link.binding.symbols.address(layout, layout.Metadata.Symbols[number], kind, required);
}
