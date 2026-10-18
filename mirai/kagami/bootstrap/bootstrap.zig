//! Owned Kernel Root Preparation And Commit

const common = @import("common");
const cpu = @import("asm").cpu;
const errors = @import("mirai").kagami.errors.bootstrap;
const guard = @import("asm").interrupts.guard;
const image = @import("mirai").boot.image;
const imagetypes = @import("mirai").boot.types.image;
const limits = @import("mirai").kagami.constants.bootstrap;
const pmm = @import("mirai").pmm;
const sequence = @import("mirai").boot.types.sequence.info;
const stack = @import("mirai").memory.stack;
const stacklimits = @import("mirai").memory.constants.stack.limits;
const state = @import("mirai").kagami.state;
const types = @import("mirai").kagami.types;

const indices = common.constants.paging.indices;
const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;
const PreparedRoot = types.prepared.PreparedRoot;
const Region = imagetypes.Region;

pub const mapping = @import("mapping.zig");

var pending: PreparedRoot = .{ .Kagami = .{ .ReferenceCount = 0 } };

pub fn prepare(info: *const sequence.BootInfo) errors.BootError!*PreparedRoot {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (pending.Phase != .Empty or state.hasOwnedKernel()) return errors.BootError.BootstrapBusy;
    if (!pmm.state.isInitialized() or !stack.state.canCommitBoot()) return errors.BootError.NotInitialized;
    try validateCPU();
    const physical_bits = cpu.cpuid.physicalAddressBits() orelse return errors.BootError.UnsupportedCPU;
    if (physical_bits < limits.MIN_PHYSICAL_BITS or physical_bits > limits.MAX_PHYSICAL_BITS) {
        return errors.BootError.UnsupportedCPU;
    }
    const physical_limit = @as(u64, 1) << @as(u6, @intCast(physical_bits));
    const physmap_size = @min(physical_limit, layout.PHYSMAP_MAX_SIZE);
    try validateInfo(info, physmap_size);
    const manifest = try image.read(info);
    const framebuffer_start = info.FramebufferPhysicalAddress & ~sizes.LARGE_PAGE_MASK;
    const framebuffer_end = (info.FramebufferPhysicalAddress + info.FramebufferSize + sizes.LARGE_PAGE_MASK) & ~sizes.LARGE_PAGE_MASK;
    if (framebuffer_start < manifest.PhysicalEnd and manifest.PhysicalStart < framebuffer_end) {
        return errors.BootError.InvalidBootInfo;
    }
    const stack_base = stacklimits.AREA_BASE + stacklimits.GUARD_PAGES * sizes.PAGE_SIZE;
    pending.Phase = .Preparing;
    pending.PreviousCR3 = cpu.control.readCR3();
    pending.PreviousSearchStart = pmm.state.getState().SearchStart;
    pending.GigabytePages = cpu.cpuid.supportsGigabytePages();
    pending.Kagami = .{ .Ownership = .Kernel };
    pending.Policy = .{
        .Image = manifest,
        .PhysmapBase = info.PhysmapBase,
        .PhysmapSize = physmap_size,
        .PhysicalLimit = physical_limit,
        .FramebufferStart = framebuffer_start,
        .FramebufferEnd = framebuffer_end,
        .BootStackBase = stack_base,
        .BootStackTop = stack_base + stacklimits.STACK_SIZE,
    };
    errdefer abort(&pending);
    try mapping.initializeUpperHalf(&pending);
    try mapPhysmap(&pending);
    inline for (.{ manifest.Text, manifest.Rodata, manifest.Data, manifest.DoubleFault, manifest.NonMaskable, manifest.MachineCheck, manifest.Debug }) |region| {
        try mapImageRegion(&pending, region);
    }
    if (stacklimits.STACK_PAGES != limits.MAX_STACK_FRAMES) return errors.BootError.InvalidSize;
    while (pending.StackCount < limits.MAX_STACK_FRAMES) {
        const page_index = pending.StackCount;
        const physical_address = try mapping.allocateStack(&pending);
        try mapping.map(&pending, stack_base + page_index * sizes.PAGE_SIZE, physical_address, sizes.PAGE_SIZE, true, false, false);
    }
    if (cpu.control.readCR3() != pending.PreviousCR3 or !stack.state.canCommitBoot()) {
        return errors.BootError.InvalidCPUState;
    }
    pending.Phase = .Prepared;
    return &pending;
}

fn validateCPU() errors.BootError!void {
    if ((cpu.control.readCR4() & (cpu.constants.control.CR4_PCID_ENABLE | cpu.constants.control.CR4_LINEAR_ADDRESS_57_ENABLE)) != 0 or
        !cpu.cpuid.supportsNoExecute() or
        (cpu.msr.read(cpu.constants.msr.EFER) & cpu.constants.msr.EFER_NO_EXECUTE_ENABLE) == 0 or
        !cpu.msr.validateMemoryTypes())
    {
        return errors.BootError.InvalidCPUState;
    }
}

fn validateInfo(info: *const sequence.BootInfo, physmap_size: u64) errors.BootError!void {
    if (info.PhysmapBase != layout.PHYSMAP_BASE or info.PhysmapSize != physmap_size or
        info.PML4Physical == 0 or (info.PML4Physical & sizes.PAGE_MASK) != 0 or
        info.PML4Physical >= physmap_size or sizes.PAGE_SIZE > physmap_size - info.PML4Physical or
        cpu.control.readCR3() != info.PML4Physical or
        info.KernelPhysicalEnd <= info.KernelPhysicalBase or info.KernelPhysicalEnd > physmap_size or
        info.FramebufferSize == 0 or info.FramebufferPhysicalAddress >= physmap_size or
        info.FramebufferSize > physmap_size - info.FramebufferPhysicalAddress or
        info.FramebufferAddress != info.PhysmapBase + info.FramebufferPhysicalAddress or
        info.BootStackSize == 0 or (info.BootStackSize & sizes.PAGE_MASK) != 0 or
        (info.BootStackTop & sizes.PAGE_MASK) != 0 or info.BootStackTop < info.PhysmapBase or
        info.BootStackTop - info.PhysmapBase > physmap_size or
        info.BootStackSize > info.BootStackTop - info.PhysmapBase)
    {
        return errors.BootError.InvalidBootInfo;
    }
}

fn mapPhysmap(prepared: *PreparedRoot) errors.BootError!void {
    const policy = &prepared.Policy;
    const text_end = policy.Image.Text.PhysicalStart + (policy.Image.Text.VirtualEnd - policy.Image.Text.VirtualStart);
    const rodata_end = policy.Image.Rodata.PhysicalStart + (policy.Image.Rodata.VirtualEnd - policy.Image.Rodata.VirtualStart);
    var physical_address: u64 = 0;
    while (physical_address < policy.PhysmapSize) {
        const read_only = (physical_address >= policy.Image.Text.PhysicalStart and physical_address < text_end) or
            (physical_address >= policy.Image.Rodata.PhysicalStart and physical_address < rodata_end);
        const uncached = physical_address >= policy.FramebufferStart and physical_address < policy.FramebufferEnd;
        var boundary = policy.PhysmapSize;
        for ([_]u64{ policy.Image.Text.PhysicalStart, text_end, policy.Image.Rodata.PhysicalStart, rodata_end, policy.FramebufferStart, policy.FramebufferEnd }) |candidate| {
            const candidate_read_only = (candidate >= policy.Image.Text.PhysicalStart and candidate < text_end) or
                (candidate >= policy.Image.Rodata.PhysicalStart and candidate < rodata_end);
            const candidate_uncached = candidate >= policy.FramebufferStart and candidate < policy.FramebufferEnd;
            if (candidate > physical_address and (candidate_read_only != read_only or candidate_uncached != uncached)) boundary = @min(boundary, candidate);
        }
        var page_size = sizes.PAGE_SIZE;
        if (prepared.GigabytePages and (physical_address & sizes.HUGE_PAGE_MASK) == 0 and
            sizes.HUGE_PAGE_SIZE <= boundary - physical_address)
        {
            page_size = sizes.HUGE_PAGE_SIZE;
        } else if ((physical_address & sizes.LARGE_PAGE_MASK) == 0 and sizes.LARGE_PAGE_SIZE <= boundary - physical_address) {
            page_size = sizes.LARGE_PAGE_SIZE;
        }
        try mapping.map(prepared, policy.PhysmapBase + physical_address, physical_address, page_size, !read_only, false, uncached);
        physical_address += page_size;
    }
}

fn mapImageRegion(prepared: *PreparedRoot, region: Region) errors.BootError!void {
    var virtual_address = region.VirtualStart;
    while (virtual_address < region.VirtualEnd) : (virtual_address += sizes.PAGE_SIZE) {
        try mapping.map(prepared, virtual_address, region.PhysicalStart + (virtual_address - region.VirtualStart), sizes.PAGE_SIZE, region.Writable, region.Executable, false);
    }
}

pub fn abort(prepared: *PreparedRoot) void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (prepared != &pending or (prepared.Phase != .Preparing and prepared.Phase != .Prepared) or
        (prepared.Kagami.PML4Physical != 0 and (cpu.control.readCR3() & indices.ADDRESS_MASK) == prepared.Kagami.PML4Physical)) return;
    while (prepared.StackCount != 0) {
        prepared.StackCount -= 1;
        pmm.free.single.freePage(prepared.StackFrames[prepared.StackCount]);
        prepared.StackFrames[prepared.StackCount] = 0;
    }
    while (prepared.TableCount != 0) {
        prepared.TableCount -= 1;
        pmm.free.single.freePage(prepared.TableFrames[prepared.TableCount]);
        prepared.TableFrames[prepared.TableCount] = 0;
    }
    pmm.state.getState().SearchStart = prepared.PreviousSearchStart;
    prepared.Kagami = .{};
    prepared.Policy = .{};
    prepared.Phase = .Empty;
}

pub fn finishActivation(prepared: *PreparedRoot) void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const stack_pointer = cpu.state.readStackPointer();
    if (prepared != &pending or prepared.Phase != .Prepared or
        (cpu.control.readCR3() & indices.ADDRESS_MASK) != prepared.Kagami.PML4Physical or
        stack_pointer < prepared.Policy.BootStackBase or stack_pointer >= prepared.Policy.BootStackTop or
        (cpu.control.readCR0() & cpu.constants.control.CR0_WRITE_PROTECT) == 0 or
        !stack.state.canCommitBoot()) cpu.halt.haltLoop();
    if (!state.publishOwned(&prepared.Kagami, &prepared.Policy) or
        !stack.state.commitBoot(prepared.Policy.BootStackBase, prepared.Policy.BootStackTop)) cpu.halt.haltLoop();
    prepared.Phase = .Active;
}

pub fn rootPhysical(prepared: *const PreparedRoot) u64 {
    return prepared.Kagami.PML4Physical;
}

pub fn stackTop(prepared: *const PreparedRoot) u64 {
    return prepared.Policy.BootStackTop;
}

pub fn stackBase(prepared: *const PreparedRoot) u64 {
    return prepared.Policy.BootStackBase;
}
