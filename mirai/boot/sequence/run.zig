//! Boot Sequence Runner

const bootstrap = @import("mirai").kagami.bootstrap;
const control = @import("asm").cpu.control;
const cpu = @import("mirai").boot.sequence.cpu;
const halt = @import("asm").cpu.halt;
const interrupts = @import("mirai").boot.sequence.interrupts;
const invocations = @import("mirai").invocations;
const kagami = @import("mirai").kagami;
const memory = @import("mirai").boot.sequence.memory;
const postman = @import("mirai").postman;
const print = @import("mirai").boot.sequence.print;
const registers = @import("asm").cpu.state;
const sensei = @import("mirai").sensei;
const state = @import("mirai").boot.sequence.state;
const strings = @import("mirai").boot.strings;
const thread = @import("mirai").thread;
const transition = @import("asm").cpu.transition.activate;
const tss = @import("mirai").boot.tss;
const types = @import("mirai").boot.types;

const messages = strings.sequence.messages;
const status = strings.sequence.status;
const BootInfo = types.sequence.info.BootInfo;
const Phase = types.sequence.phase.Phase;
const PreparedRoot = kagami.types.prepared.PreparedRoot;

var prepared_root: ?*PreparedRoot = null;

pub fn execute(boot_info: *const BootInfo) noreturn {
    print.printBanner();
    print.log(messages.STARTING, .{});
    print.log(messages.POWERED, .{});
    state.setCurrentPhase(Phase.CPU);
    if (!cpu.execute()) {
        print.fail(status.ERROR_PROCESSOR);
        haltOnFailure();
    }
    state.advancePhase();
    print.log(messages.NEWLINE, .{});
    state.setCurrentPhase(Phase.Memory);
    if (!memory.prepare(boot_info)) {
        print.fail(status.ERROR_MEMORY);
        haltOnFailure();
    }
    const prepared = bootstrap.prepare(boot_info) catch |failure| {
        print.log(messages.ROOT_PREPARE_FAILED, .{@errorName(failure)});
        haltOnFailure();
    };
    if (!control.enableWriteProtect()) {
        bootstrap.abort(prepared);
        haltOnFailure();
    }
    prepared_root = prepared;
    transition.enterKernel(bootstrap.rootPhysical(prepared), bootstrap.stackTop(prepared), continueBoot, @ptrCast(boot_info));
}

fn continueBoot(context: *const anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    const previous_info: *const BootInfo = @ptrCast(@alignCast(context));
    const prepared = prepared_root orelse halt.haltLoop();
    bootstrap.finishActivation(prepared);
    const top = bootstrap.stackTop(prepared);
    const base = bootstrap.stackBase(prepared);
    state.updateMemory(bootstrap.rootPhysical(prepared), top, top - base);
    tss.state.setCurrentRSP0(0, top);
    const info = state.getBootInfo() orelse halt.haltLoop();
    print.log(messages.OWNED_ROOT, .{ info.PML4Physical, previous_info.LoaderPML4Physical, prepared.TableCount });
    print.log(messages.HIGH_STACK_ACTIVE, .{registers.readStackPointer()});
    print.log(messages.LOW_IDENTITY_REMOVED, .{});
    if (!memory.finish(info)) {
        print.fail(status.ERROR_MEMORY);
        haltOnFailure();
    }
    if (!thread.boot.initialize() or !sensei.control.initialize() or !invocations.setup.initialize() or !postman.control.initialize()) {
        print.fail(status.ERROR_SERVICES);
        haltOnFailure();
    }
    state.advancePhase();
    print.log(messages.NEWLINE, .{});
    state.setCurrentPhase(Phase.Interrupts);
    if (!interrupts.execute()) {
        print.fail(status.ERROR_SERVICES);
        haltOnFailure();
    }
    state.advancePhase();
    print.phase(status.READY);
    state.setCurrentPhase(Phase.Complete);
    sensei.idle.runIdle();
}

pub fn haltOnFailure() noreturn {
    print.fail(status.ERROR_HALTED);
    halt.haltLoop();
}
