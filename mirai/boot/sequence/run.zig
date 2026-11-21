//! Boot Sequence Runner

const bootstrap = @import("mirai").kagami.bootstrap;
const checks = if (options.GUEST_CHECKS) @import("tests").guest.run else null;
const control = @import("asm").cpu.control;
const cpu = @import("mirai").boot.sequence.cpu;
const halt = @import("asm").cpu.halt;
const interrupts = @import("mirai").boot.sequence.interrupts;
const invocations = @import("mirai").invocations;
const kagami = @import("mirai").kagami;
const memory = @import("mirai").boot.sequence.memory;
const options = @import("options");
const postman = @import("mirai").postman;
const print = @import("mirai").boot.sequence.print;
const pulse = @import("mirai").boot.sequence.pulse;
const registers = @import("asm").cpu.state;
const rootchecks = if (options.GUEST_CHECKS) @import("tests").guest.support.root else null;
const selector = if (options.GUEST_CHECKS) @import("tests").guest.support.selector else null;
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
const PreparedRoot = kagami.types.prepared.PreparedRoot;

var prepared_root: ?*PreparedRoot = null;

pub fn execute(boot_info: *const BootInfo) noreturn {
    print.printBanner();
    print.log(messages.STARTING, .{});
    print.log(messages.POWERED, .{});
    if (!cpu.execute()) {
        print.fail(status.ERROR_PROCESSOR);
        haltOnFailure();
    }
    print.log(messages.NEWLINE, .{});
    if (!memory.prepare(boot_info)) {
        print.fail(status.ERROR_MEMORY);
        haltOnFailure();
    }
    if (options.GUEST_CHECKS) {
        const selected = selector.selectEarly();
        checks.beginPhase(selected);
        if (selected == .Standard) {
            @call(.never_inline, rootchecks.run, .{boot_info});
            checks.finishBootstrap();
        }
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
    tss.state.getBootTSS().setRSP0(top);
    const info = state.getBootInfo() orelse halt.haltLoop();
    const retired = (if (options.GUEST_CHECKS) @call(.never_inline, rootchecks.retire, .{info}) else memory.retireLoader(info)) orelse {
        print.fail(status.ERROR_RETIREMENT);
        haltOnFailure();
    };
    state.finishRetirement();
    print.log(messages.RETIRED_FRAMES, .{retired});
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
    print.log(messages.NEWLINE, .{});
    if (!interrupts.execute()) {
        print.fail(status.ERROR_SERVICES);
        haltOnFailure();
    }
    if (!options.GUEST_CHECKS) {
        pulse.activate(info) catch |failure| {
            print.log(messages.PULSE_FAILED, .{@errorName(failure)});
            print.fail(status.ERROR_PULSE);
            halt.haltLoop();
        };
    }
    const diagnostic_screen = if (options.GUEST_CHECKS) checks.execute() else false;
    if (diagnostic_screen) {
        print.log(messages.LINE, .{status.READY});
    } else {
        print.phase(status.READY);
    }
    sensei.idle.runIdle();
}

pub fn haltOnFailure() noreturn {
    print.fail(status.ERROR_HALTED);
    halt.haltLoop();
}
