//! Native Binding And Graph Link Errors

const errors = @import("shared").elf.errors;

pub const LinkError = errors.dynamic.DynamicError || errors.relocation.RelocationError || error{
    AmbiguousSymbol,
    InvalidDefinition,
    InvalidLinkGraph,
    SymbolKindMismatch,
    UnsupportedLinkMetadata,
    UnsupportedSymbol,
    UnresolvedSymbol,
};
