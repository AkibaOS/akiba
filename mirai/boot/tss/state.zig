//! Boot TSS State

const types = @import("mirai").boot.types;

const TSS = types.tss.structure.TSS;

var boot_tss: TSS = .{};
var initialized: bool = false;

pub fn getBootTSS() *TSS {
    return &boot_tss;
}

pub fn isInitialized() bool {
    return initialized;
}

pub fn setInitialized() void {
    initialized = true;
}
