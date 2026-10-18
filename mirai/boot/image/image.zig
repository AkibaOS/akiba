//! Validated Kernel Image Manifest

const common = @import("common");
const errors = @import("mirai").kagami.errors.bootstrap;
const image = @import("mirai").boot.types.image;
const limits = @import("mirai").boot.constants.tss.limits;
const sequence = @import("mirai").boot.types.sequence.info;

const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;

extern var __kernel_image_start: u8;
extern var __kernel_image_end: u8;
extern var __kernel_text_start: u8;
extern var __kernel_text_end: u8;
extern var __kernel_rodata_start: u8;
extern var __kernel_rodata_end: u8;
extern var __kernel_data_start: u8;
extern var __kernel_data_end: u8;
extern var __kernel_bss_start: u8;
extern var __kernel_bss_end: u8;
extern var __boot_ist_df_start: u8;
extern var __boot_ist_df_end: u8;
extern var __boot_ist_nmi_start: u8;
extern var __boot_ist_nmi_end: u8;
extern var __boot_ist_mc_start: u8;
extern var __boot_ist_mc_end: u8;
extern var __boot_ist_debug_start: u8;
extern var __boot_ist_debug_end: u8;

pub fn read(info: *const sequence.BootInfo) errors.BootError!image.Manifest {
    const image_start = resolveLinkerAddress(&__kernel_image_start);
    const image_end = resolveLinkerAddress(&__kernel_image_end);
    if (image_start != info.KernelVirtualBase or image_start < ~layout.USER_SPACE_END or
        image_end <= image_start or (image_start & sizes.PAGE_MASK) != 0 or
        (image_end & sizes.PAGE_MASK) != 0 or
        (info.KernelPhysicalBase & sizes.PAGE_MASK) != 0 or
        (info.KernelPhysicalEnd & sizes.PAGE_MASK) != 0 or
        info.KernelPhysicalEnd <= info.KernelPhysicalBase or
        image_end - image_start != info.KernelPhysicalEnd - info.KernelPhysicalBase)
    {
        return errors.BootError.InvalidImage;
    }

    const data_end = resolveLinkerAddress(&__kernel_data_end);
    const bss_start = resolveLinkerAddress(&__kernel_bss_start);
    const bss_end = resolveLinkerAddress(&__kernel_bss_end);
    if (data_end != bss_start or bss_end < bss_start or
        (data_end & sizes.PAGE_MASK) != 0 or (bss_start & sizes.PAGE_MASK) != 0)
    {
        return errors.BootError.InvalidImage;
    }

    const manifest = image.Manifest{
        .VirtualStart = image_start,
        .VirtualEnd = image_end,
        .PhysicalStart = info.KernelPhysicalBase,
        .PhysicalEnd = info.KernelPhysicalBase + (image_end - image_start),
        .Text = try region(info, resolveLinkerAddress(&__kernel_text_start), resolveLinkerAddress(&__kernel_text_end), false, true),
        .Rodata = try region(info, resolveLinkerAddress(&__kernel_rodata_start), resolveLinkerAddress(&__kernel_rodata_end), false, false),
        .Data = try region(info, resolveLinkerAddress(&__kernel_data_start), bss_end, true, false),
        .DoubleFault = try region(info, resolveLinkerAddress(&__boot_ist_df_start), resolveLinkerAddress(&__boot_ist_df_end), true, false),
        .NonMaskable = try region(info, resolveLinkerAddress(&__boot_ist_nmi_start), resolveLinkerAddress(&__boot_ist_nmi_end), true, false),
        .MachineCheck = try region(info, resolveLinkerAddress(&__boot_ist_mc_start), resolveLinkerAddress(&__boot_ist_mc_end), true, false),
        .Debug = try region(info, resolveLinkerAddress(&__boot_ist_debug_start), resolveLinkerAddress(&__boot_ist_debug_end), true, false),
    };
    if (manifest.Text.VirtualStart != image_start or
        manifest.Text.VirtualEnd > manifest.Rodata.VirtualStart or
        manifest.Rodata.VirtualEnd > manifest.Data.VirtualStart or
        data_end < manifest.Data.VirtualStart)
    {
        return errors.BootError.InvalidImage;
    }

    var previous_end = manifest.Data.VirtualEnd;
    inline for (.{ manifest.DoubleFault, manifest.NonMaskable, manifest.MachineCheck, manifest.Debug }) |body| {
        if (body.VirtualStart <= previous_end or body.VirtualStart - previous_end < sizes.PAGE_SIZE or
            body.VirtualEnd - body.VirtualStart != limits.DEFAULT_STACK_SIZE)
        {
            return errors.BootError.InvalidImage;
        }
        previous_end = body.VirtualEnd;
    }
    if (image_end != previous_end or image_end > ~@as(u64, 0) - sizes.PAGE_SIZE) {
        return errors.BootError.InvalidImage;
    }
    return manifest;
}

fn resolveLinkerAddress(symbol: *const u8) u64 {
    var address = @intFromPtr(symbol);
    const observed: *const volatile usize = &address;
    return observed.*;
}

fn region(info: *const sequence.BootInfo, start: u64, end: u64, writable: bool, executable: bool) errors.BootError!image.Region {
    const image_end = resolveLinkerAddress(&__kernel_image_end);
    if (start < info.KernelVirtualBase or start >= end or end > image_end or
        (start & sizes.PAGE_MASK) != 0 or (end & sizes.PAGE_MASK) != 0)
    {
        return errors.BootError.InvalidImage;
    }
    return .{
        .VirtualStart = start,
        .VirtualEnd = end,
        .PhysicalStart = info.KernelPhysicalBase + (start - info.KernelVirtualBase),
        .Writable = writable,
        .Executable = executable,
    };
}
