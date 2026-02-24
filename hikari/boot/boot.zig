//! Hikari Boot Subsystem

pub const params = @import("params.zig");

pub const BootParams = params.BootParams;
pub const FramebufferInfo = params.FramebufferInfo;
pub const MemoryMapInfo = params.MemoryMapInfo;
pub const MemoryRegion = params.MemoryRegion;
pub const MemoryType = params.MemoryType;
pub const KernelInfo = params.KernelInfo;
pub const AcpiInfo = params.AcpiInfo;
pub const PixelFormat = params.PixelFormat;

pub const boot_params_magic = params.boot_params_magic;
pub const boot_params_version = params.boot_params_version;
