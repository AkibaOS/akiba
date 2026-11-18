//! Kernel Entry

const std = @import("std");

const boot = @import("shared").boot;
const common = @import("common");
const cpu = @import("asm").cpu;
const early = @import("mirai").boot.early;
const halt = @import("asm").cpu.halt;
const options = @import("options");
const print = @import("mirai").boot.sequence.print;
const regions = @import("mirai").boot.regions;
const retirement = @import("mirai").boot.retirement.layout;
const screen = if (options.GUEST_CHECKS) @import("tests").guest.screen.control else null;
const sequence = @import("mirai").boot.sequence;
const splash = @import("mirai").boot.splash;
const strings = @import("mirai").boot.strings.sequence.messages;
const types = @import("mirai").boot.types;

const BootInfo = types.sequence.info.BootInfo;
const BootParams = boot.types.params.BootParams;
const indices = common.constants.paging.indices;
const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;

pub export fn mirai_entry(boot_params: *const BootParams) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    if (!early.setup.initialize()) halt.haltLoop();
    main(boot_params);
}

pub fn main(boot_params: *const BootParams) noreturn {
    const info = snapshot(boot_params) orelse {
        print.fail(strings.INVALID_BOOT_INFO);
        halt.haltLoop();
    };
    sequence.state.setBootInfo(&info);
    var framebuffer = boot_params.Framebuffer;
    framebuffer.Base = info.FramebufferAddress;
    if (options.GUEST_CHECKS) screen.bind(framebuffer);
    _ = splash.adopt(framebuffer, boot_params.Splash);
    sequence.run.execute(sequence.state.getBootInfo().?);
}

fn snapshot(params: *const BootParams) ?BootInfo {
    const physical_bits = cpu.cpuid.physicalAddressBits() orelse return null;
    const coverage = @min(layout.PHYSMAP_MAX_SIZE, @as(u64, 1) << @as(u6, @intCast(physical_bits)));
    const params_address = @intFromPtr(params);
    if (params_address < layout.PHYSMAP_BASE or params_address & sizes.PAGE_MASK != 0) return null;
    const params_offset = params_address - layout.PHYSMAP_BASE;
    if (params_offset >= coverage or @sizeOf(BootParams) > coverage - params_offset or !params.isValid()) return null;
    const kernel = params.Kernel;
    if (kernel.PhysmapBase != layout.PHYSMAP_BASE or kernel.PhysmapSize != coverage or
        kernel.PhysicalBase == 0 or kernel.Size == 0 or kernel.PhysicalBase >= coverage or kernel.Size > coverage - kernel.PhysicalBase or
        ((kernel.PhysicalBase | kernel.VirtualBase | kernel.Size) & sizes.PAGE_MASK) != 0 or
        kernel.VirtualBase < layout.KERNEL_BASE or kernel.Size > std.math.maxInt(u64) - kernel.VirtualBase or
        kernel.EntryPoint < kernel.VirtualBase or kernel.EntryPoint - kernel.VirtualBase >= kernel.Size or
        kernel.PML4Address == 0 or (kernel.PML4Address & sizes.PAGE_MASK) != 0 or kernel.PML4Address > coverage - sizes.PAGE_SIZE or
        (cpu.control.readCR3() & indices.ADDRESS_MASK) != kernel.PML4Address or
        kernel.StackTop <= layout.PHYSMAP_BASE or kernel.StackSize != layout.KERNEL_STACK_SIZE or
        ((kernel.StackTop | kernel.StackSize) & sizes.PAGE_MASK) != 0)
    {
        return null;
    }
    const stack_end = kernel.StackTop - layout.PHYSMAP_BASE;
    if (stack_end > coverage or kernel.StackSize >= stack_end) return null;
    const current_stack = cpu.state.readStackPointer();
    if (current_stack < kernel.StackTop - kernel.StackSize or current_stack >= kernel.StackTop) return null;
    const framebuffer = params.Framebuffer;
    if (!framebuffer.isValid() or framebuffer.Base >= coverage or framebuffer.Size > coverage - framebuffer.Base) {
        return null;
    }
    const map = params.MemoryMap;
    const parameter_pages = (@sizeOf(BootParams) + sizes.PAGE_MASK) / sizes.PAGE_SIZE;
    const map_range = retirement.pageRange(map.Entries, params.Retirement.MapPages, coverage) orelse return null;
    if (@as(u64, map.EntryCount) * map.EntrySize > params.Retirement.MapPages * sizes.PAGE_SIZE) return null;
    var info: BootInfo = .{
        .MemoryMap = &.{},
        .Retirement = .{
            .Tables = params.Retirement,
            .Root = retirement.pageRange(kernel.PML4Address, 1, coverage) orelse return null,
            .Stack = retirement.pageRange(stack_end - kernel.StackSize, kernel.StackSize / sizes.PAGE_SIZE, coverage) orelse return null,
            .Parameters = retirement.pageRange(params_offset, parameter_pages, coverage) orelse return null,
            .Map = map_range,
        },
        .FramebufferAddress = layout.PHYSMAP_BASE + framebuffer.Base,
        .FramebufferPhysicalAddress = framebuffer.Base,
        .FramebufferSize = framebuffer.Size,
        .KernelPhysicalBase = kernel.PhysicalBase,
        .KernelPhysicalEnd = kernel.PhysicalBase + kernel.Size,
        .KernelVirtualBase = kernel.VirtualBase,
        .PML4Physical = kernel.PML4Address,
        .LoaderPML4Physical = kernel.PML4Address,
        .PhysmapBase = kernel.PhysmapBase,
        .PhysmapSize = coverage,
        .BootStackTop = kernel.StackTop,
        .BootStackSize = kernel.StackSize,
    };
    if (!retirement.aliases(&info, map_range)) return null;
    const raw = regions.convert.inspect(map, coverage) orelse return null;
    if (!retirement.canCompact(&info, raw)) return null;
    info.MemoryMap = regions.convert.consume(map, coverage) orelse return null;
    return info;
}
