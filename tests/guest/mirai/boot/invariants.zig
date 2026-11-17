//! Active Boot And CPU Invariants

const common = @import("common");
const construction = @import("tests").guest.support.root;
const cpu = @import("asm").cpu;
const guard = @import("asm").interrupts.guard;
const interrupts = @import("mirai").interrupts;
const kagami = @import("mirai").kagami;
const labels = @import("tests").strings.boot;
const ownership = @import("tests").strings.tables;
const selectors = @import("mirai").boot.constants.gdt.selectors;
const thread = @import("mirai").thread;
const tss = @import("mirai").boot.tss;
const types = @import("mirai").boot.types;
const verify = @import("tests").verify;

const control = cpu.constants.control;
const layout = common.constants.memory.layout;
const msr = cpu.constants.msr;
const sizes = common.constants.memory.sizes;
const Region = types.image.Region;
const TSS = types.tss.structure.TSS;

pub fn run() void {
    const flags = guard.acquire();
    verify.require(construction.passed(), ownership.EARLY_ROLLBACK);
    const current = thread.state.getCurrent().?;
    const root = kagami.state.getKernelKagami();
    const policy = kagami.state.getPolicy();
    const pointer = cpu.state.readStackPointer();
    verify.require(kagami.state.getCurrentKagami() == root and cpu.control.readCR3() == root.PML4Physical and
        pointer >= current.Stack.Base and pointer < current.Stack.Top and pointer >= layout.KERNEL_STACK_AREA_BASE, labels.ROOT);
    verify.require(kagami.tables.ownership.reset(root) and kagami.tables.ownership.owns(root, root.PML4Physical) and
        root.Frames != null, labels.FRAMES);
    verify.require(kagami.tables.walk.lookup(root.PML4Physical, layout.KERNEL_PHYSICAL_BASE) == null, labels.LOW);
    verify.require(cpu.control.readCR0() & control.CR0_WRITE_PROTECT != 0 and
        cpu.msr.read(msr.EFER) & msr.EFER_NO_EXECUTE_ENABLE != 0, labels.PROTECTION);
    verify.require(cpu.control.readCR0() & (control.CR0_EMULATION | control.CR0_TASK_SWITCHED) == 0 and
        cpu.control.readCR4() & (control.CR4_OS_FXSAVE | control.CR4_OS_XMM_EXCEPTION) ==
            (control.CR4_OS_FXSAVE | control.CR4_OS_XMM_EXCEPTION) and cpu.control.readCR4() & control.CR4_OS_XSAVE == 0, labels.FPU);
    verify.require(cpu.control.readCR4() & (control.CR4_PCID_ENABLE | control.CR4_LINEAR_ADDRESS_57_ENABLE) == 0, labels.PAGE_MODE);
    const text = kagami.tables.walk.lookup(root.PML4Physical, policy.Image.Text.VirtualStart).?;
    const text_alias = kagami.tables.walk.lookup(root.PML4Physical, policy.PhysmapBase + policy.Image.Text.PhysicalStart).?;
    verify.require(text.Executable and !text.Writable and !text.UserAccessible and
        !text_alias.Executable and !text_alias.Writable and !text_alias.UserAccessible, labels.TEXT);
    const rodata = kagami.tables.walk.lookup(root.PML4Physical, policy.Image.Rodata.VirtualStart).?;
    const rodata_alias = kagami.tables.walk.lookup(root.PML4Physical, policy.PhysmapBase + policy.Image.Rodata.PhysicalStart).?;
    verify.require(!rodata.Executable and !rodata.Writable and !rodata.UserAccessible and
        !rodata_alias.Executable and !rodata_alias.Writable and !rodata_alias.UserAccessible, labels.RODATA);
    if (policy.FramebufferEnd > policy.FramebufferStart) {
        const framebuffer = kagami.tables.walk.lookup(root.PML4Physical, policy.PhysmapBase + policy.FramebufferStart).?;
        verify.require(!framebuffer.UserAccessible and !framebuffer.Executable and framebuffer.Entry.CacheDisabled, labels.FRAMEBUFFER);
    }
    const active_tss = tss.state.getBootTSS();
    verify.require(active_tss.RSP0 == current.Stack.Top and active_tss.IOPBOffset == @sizeOf(@TypeOf(active_tss.*)), labels.TSS_STACK);
    const regions = [_]Region{
        policy.Image.DoubleFault, policy.Image.NonMaskable, policy.Image.MachineCheck, policy.Image.Debug,
    };
    for (regions, 0..) |region, index| {
        const body = kagami.tables.walk.lookup(root.PML4Physical, region.VirtualStart).?;
        verify.require(active_tss.getIST(@intCast(index + 1)) == region.VirtualEnd and body.Writable and
            !body.Executable and !body.UserAccessible and
            kagami.tables.walk.lookup(root.PML4Physical, region.VirtualStart - sizes.PAGE_SIZE) == null, labels.IST);
    }
    const gate = interrupts.table.entries.entries[common.constants.interrupts.vectors.INVOCATION_VECTOR];
    verify.require(gate.Present and gate.DPL == .Ring3 and gate.GateType == .Interrupt and gate.IST == 0 and
        gate.Selector == selectors.KERNEL_CODE_SELECTOR, labels.INVOCATION);
    const nested = guard.acquire();
    guard.release(nested);
    verify.require(cpu.state.readFlags() & control.RFLAGS_INTERRUPT_ENABLE == 0, labels.GUARD);
    guard.release(flags);
    verify.require((cpu.state.readFlags() & control.RFLAGS_INTERRUPT_ENABLE) == (flags & control.RFLAGS_INTERRUPT_ENABLE), labels.GUARD);
    var local: TSS = .{};
    local.setRSP0(current.Stack.Top);
    local.setIST(1, current.Stack.Top);
    local.setIST(0, current.Stack.Base);
    verify.require(local.RSP0 == current.Stack.Top and local.getIST(1) == current.Stack.Top and local.getIST(0) == 0 and
        local.getIST(8) == 0, labels.TSS_DATA);
    local.clear();
    verify.require(local.RSP0 == 0 and local.getIST(1) == 0 and local.IOPBOffset == @sizeOf(@TypeOf(local)), labels.TSS_DATA);
}
