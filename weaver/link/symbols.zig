//! Validate Native Symbol Kind And Mapped Definition Extent

const std = @import("std");

const elf = @import("shared").elf;

const Layout = elf.types.dynamic.Layout;
const LinkError = @import("weaver").link.errors.link.LinkError;
const Symbol = elf.types.dynamic.Symbol;
const fields = elf.constants.symbol;

pub fn reference(symbol: Symbol, operation: u32) LinkError!u8 {
    const kind = try kindOf(symbol);
    if (operation == elf.constants.relocation.JUMP_SLOT and kind != fields.TYPE_FUNCTION) return error.SymbolKindMismatch;
    if (symbol.Section == fields.SECTION_UNDEFINED and symbol.Value != 0) return error.UnsupportedSymbol;
    return kind;
}

pub fn address(layout: *const Layout, symbol: Symbol, reference_kind: u8, required: u64) LinkError!u64 {
    const kind = try kindOf(symbol);
    if (kind != reference_kind) return error.SymbolKindMismatch;
    if (symbol.Section == fields.SECTION_UNDEFINED or symbol.Section >= fields.SECTION_RESERVED or
        (kind == fields.TYPE_OBJECT and symbol.Size < required)) return error.InvalidDefinition;
    const placed = std.math.add(u64, layout.Bias, symbol.Value) catch return error.InvalidDefinition;
    const extent = @max(1, symbol.Size);
    var left: usize = 0;
    var right = layout.Image.Segments.len;
    while (left < right) {
        const middle = left + (right - left) / 2;
        const segment = layout.Image.Segments[middle];
        if (placed < segment.VirtualAddress) {
            right = middle;
            continue;
        }
        const offset = placed - segment.VirtualAddress;
        if (offset >= segment.MemorySize) {
            left = middle + 1;
            continue;
        }
        const execute = kind == fields.TYPE_FUNCTION;
        const bound = if (execute) segment.UnitSize else segment.MemorySize;
        if (segment.isExecutable() != execute or !segment.isReadable() or offset >= bound or extent > bound - offset) break;
        return placed;
    }
    return error.InvalidDefinition;
}

fn kindOf(symbol: Symbol) LinkError!u8 {
    const kind = symbol.Info & fields.TYPE_MASK;
    if (symbol.Other != fields.VISIBILITY_DEFAULT or symbol.Info >> fields.BINDING_SHIFT != fields.BINDING_GLOBAL or
        (kind != fields.TYPE_FUNCTION and kind != fields.TYPE_OBJECT)) return error.UnsupportedSymbol;
    return kind;
}
