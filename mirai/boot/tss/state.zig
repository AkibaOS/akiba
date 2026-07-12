//! TSS State

const types = @import("../types/tss/tss.zig");
const constants = @import("../constants/tss/tss.zig");

const CoreTss = types.CoreTss;
const Tss = types.Tss;

var boot_tss: Tss = Tss{};

var core_tss_array: [constants.max_cores]CoreTss = undefined;
var core_count: u16 = 0;
var initialized: bool = false;

pub fn get_boot_tss() *Tss {
    return &boot_tss;
}

pub fn get_boot_tss_address() u64 {
    return @intFromPtr(&boot_tss);
}

pub fn get_core_tss(core_id: u16) ?*CoreTss {
    if (core_id >= core_count) {
        return null;
    }
    return &core_tss_array[core_id];
}

pub fn register_core(core_id: u16) ?*CoreTss {
    if (core_id >= constants.max_cores) {
        return null;
    }
    if (core_id >= core_count) {
        core_count = core_id + 1;
    }
    core_tss_array[core_id] = CoreTss.init(core_id);
    return &core_tss_array[core_id];
}

pub fn get_core_count() u16 {
    return core_count;
}

pub fn is_initialized() bool {
    return initialized;
}

pub fn set_initialized() void {
    initialized = true;
}
