//! Boot-Independent Processor and Exception Initialization

const boot = @import("mirai").boot;
const control = @import("asm").cpu.control;
const efer = @import("asm").cpu.constants.msr;
const floating = @import("asm").cpu.constants.fpu;
const fpu = @import("asm").cpu.fpu;
const gdt = @import("asm").gdt;
const interrupt = @import("asm").interrupts;
const interrupts = @import("mirai").interrupts;
const msr = @import("asm").cpu.msr;
const processor = @import("mirai").boot.constants.early.processor;
const registers = @import("asm").cpu.constants.control;
const serial = @import("mirai").drivers.serial;

var initialized: bool = false;

pub fn initialize() bool {
    interrupt.flags.disableInterrupts();
    if (initialized) return isInitialized();

    initializeProcessor();
    const serial_available = serial.init.initializeDefault();

    if (!boot.tss.setup.initializeBoot()) return false;
    if (!boot.gdt.state.isInitialized()) {
        boot.gdt.setup.initialize(boot.tss.state.getBootTSSAddress(), boot.constants.tss.limits.TSS_SIZE);
    }

    interrupts.setup.initializeExceptions();

    if (!msr.enableNoExecute() or !control.enableWriteProtect() or !serial_available) return false;

    initialized = true;
    return isInitialized();
}

fn initializeProcessor() void {
    const required = processor.CR0_REQUIRED & ~registers.CR0_WRITE_PROTECT;
    control.writeCR0((control.readCR0() | required) & ~processor.CR0_FORBIDDEN);
    control.writeCR4((control.readCR4() | processor.CR4_REQUIRED) & ~processor.CR4_FORBIDDEN);
    fpu.initializeFpu();
    fpu.loadMXCSR(&floating.DEFAULT_MXCSR);
}

fn isProcessorReady() bool {
    const cr0 = control.readCR0();
    const cr4 = control.readCR4();
    return (cr0 & processor.CR0_REQUIRED) == processor.CR0_REQUIRED and
        (cr0 & processor.CR0_FORBIDDEN) == 0 and
        (cr4 & processor.CR4_REQUIRED) == processor.CR4_REQUIRED and
        (cr4 & processor.CR4_FORBIDDEN) == 0 and
        (msr.read(efer.EFER) & efer.EFER_NO_EXECUTE_ENABLE) != 0;
}

fn isGDTReady() bool {
    if (!boot.gdt.state.isInitialized()) return false;

    const descriptor = gdt.table.storeGlobalDescriptorTable();
    const expected = boot.gdt.state.getGDTR();
    return descriptor.Base == expected.Base and descriptor.Limit == expected.Limit and
        gdt.segment.readCodeSegment() == boot.constants.gdt.selectors.KERNEL_CODE_SELECTOR and
        gdt.segment.readStackSegment() == boot.constants.gdt.selectors.KERNEL_DATA_SELECTOR;
}

pub fn isInitialized() bool {
    return initialized and serial.state.isAvailable() and boot.tss.setup.isBootReady() and
        isGDTReady() and interrupts.setup.isExceptionsInitialized() and isProcessorReady();
}
