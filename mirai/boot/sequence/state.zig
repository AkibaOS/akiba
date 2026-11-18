//! Published Boot Information

const types = @import("mirai").boot.types;

const BootInfo = types.sequence.info.BootInfo;

var boot_info: BootInfo = undefined;
var boot_info_ready: bool = false;

pub fn setBootInfo(info: *const BootInfo) void {
    boot_info = info.*;
    boot_info_ready = true;
}

pub fn getBootInfo() ?*const BootInfo {
    return if (boot_info_ready) &boot_info else null;
}

pub fn updateMemory(root_physical: u64, stack_top: u64, stack_size: u64) void {
    boot_info.PML4Physical = root_physical;
    boot_info.BootStackTop = stack_top;
    boot_info.BootStackSize = stack_size;
}
