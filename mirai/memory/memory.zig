//! Kernel Memory Management

pub const constants = @import("constants/constants.zig");
pub const types = @import("types/types.zig");
pub const strings = @import("strings/strings.zig");

pub const zone = @import("zone/zone.zig");
pub const kalloc = @import("kalloc/kalloc.zig");
pub const convert = @import("convert/convert.zig");
pub const stack = @import("stack/stack.zig");

pub const Zone = zone.Zone;

pub const zone_init = zone.init;
pub const zone_create = zone.zone_create;
pub const zalloc = zone.zalloc;
pub const zalloc_zeroed = zone.zalloc_zeroed;
pub const zfree = zone.zfree;
pub const zone_gc = zone.collect;

pub const kalloc_init = kalloc.init;
pub const kmalloc = kalloc.kalloc;
pub const kmalloc_zeroed = kalloc.kalloc_zeroed;
pub const kfree = kalloc.kfree;

pub const phys_to_virt = convert.phys_to_virt;
pub const virt_to_phys = convert.virt_to_phys;
