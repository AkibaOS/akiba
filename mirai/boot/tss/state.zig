//! TSS State

const constants = @import("../constants/constants.zig");
const types = @import("../types/types.zig");

const limits = constants.tss.limits;

const CoreTSS = types.tss.core.CoreTSS;
const TSS = types.tss.structure.TSS;

var boot_tss: TSS = TSS{};

var core_tss_array: [limits.MAX_CORES]CoreTSS = undefined;
var core_count: u16 = 0;
var initialized: bool = false;

pub fn getBootTSS() *TSS {
    return &boot_tss;
}

pub fn getBootTSSAddress() u64 {
    return @intFromPtr(&boot_tss);
}

pub fn getCoreTSS(core_id: u16) ?*CoreTSS {
    if (core_id >= core_count) {
        return null;
    }
    return &core_tss_array[core_id];
}

pub fn registerCore(core_id: u16) ?*CoreTSS {
    if (core_id >= limits.MAX_CORES) {
        return null;
    }
    if (core_id >= core_count) {
        core_count = core_id + 1;
    }
    core_tss_array[core_id] = CoreTSS.init(core_id);
    return &core_tss_array[core_id];
}

pub fn getCoreCount() u16 {
    return core_count;
}

pub fn isInitialized() bool {
    return initialized;
}

pub fn setInitialized() void {
    initialized = true;
}

pub fn getCurrentRSP0(core_id: u16) u64 {
    if (getCoreTSS(core_id)) |core_tss| {
        return core_tss.TSS.RSP0;
    }
    return boot_tss.RSP0;
}

pub fn setCurrentRSP0(core_id: u16, stack_top: u64) void {
    if (getCoreTSS(core_id)) |core_tss| {
        core_tss.TSS.setRSP0(stack_top);
    } else {
        boot_tss.setRSP0(stack_top);
    }
}
