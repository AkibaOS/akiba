//! Native Thread Switch Context Regressions

const cpu = @import("asm").cpu;
const drive = @import("tests").guest.support.drive;
const fixtures = @import("tests").types.context;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.context;
const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const labels = @import("tests").strings.context;
const probe = @import("testasm").context;
const sensei = @import("mirai").sensei;
const thread = @import("mirai").thread;
const tss = @import("mirai").boot.tss;
const verify = @import("tests").guest.support.verify;

var active: ?*[2]fixtures.Worker = null;

pub fn run() !void {
    const initial_flags = guard.acquire();
    const baseline = capture(initial_flags);
    guard.release(initial_flags);

    var workers = [_]fixtures.Worker{ .{}, .{} };
    for (&workers, 0..) |*worker, index| {
        worker.Cooperative.Seed = inputs.REGISTER_SEEDS[index];
        worker.Preemptive.SeedRegisters = inputs.REGISTER_SEEDS[index];
        worker.Preemptive.Seed = inputs.FLOATING_SEEDS[index];
        worker.Preemptive.Budget = inputs.PREEMPTION_BUDGET;
    }
    workers[0].Peer = &workers[1].Preemptive;
    workers[1].Peer = &workers[0].Preemptive;
    active = &workers;
    defer active = null;
    defer cleanup(&workers);

    try prepare(&workers);
    drive.run();

    const resumed_flags = guard.acquire();
    defer guard.release(resumed_flags);
    var completed = true;
    for (&workers) |*worker| {
        const outcome = kata.completion.lifetime.peek(worker.OwnerID);
        completed = completed and worker.Done and outcome != null and outcome.? == .Completed and
            kata.state.findByID(worker.OwnerID) == null;
    }
    cleanup(&workers);
    verifyResults(&workers, baseline, resumed_flags, completed);
}

fn capture(previous_flags: u64) fixtures.Baseline {
    const current = thread.state.getCurrent() orelse @panic(labels.INVALID_STATE);
    const scheduler = sensei.state.getState();
    if (active != null or !validFlags(previous_flags) or !scheduler.Initialized or
        scheduler.IRQDepth != 0 or scheduler.PreemptionDepth != 0 or scheduler.Ready.Count != 0 or
        scheduler.Retired.Count != 0 or !current.Managed or current.Status != .Running)
        @panic(labels.INVALID_STATE);
    return .{
        .Current = current,
        .AddressSpace = current.Owner.AddressSpace.?,
        .CR3 = cpu.control.readCR3(),
        .RSP0 = tss.state.getBootTSS().RSP0,
        .Flags = previous_flags,
        .RegisteredCount = scheduler.RegisteredCount,
        .OwnerThreadCount = current.Owner.ThreadCount,
        .Requests = scheduler.Requests,
        .Switches = scheduler.Switches,
    };
}

fn prepare(workers: *[2]fixtures.Worker) !void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    errdefer cleanup(workers);
    for (workers) |*worker| {
        const owner = try kata.create.create();
        worker.OwnerID = owner.ID;
        worker.ExpectedCR3 = owner.AddressSpace.?.PML4Physical;
        const target = try thread.create.create(owner, workerEntry, worker);
        worker.Target = target;
        worker.StackBase = target.Stack.Base;
        worker.StackTop = target.Stack.Top;
    }
    for (workers) |*worker| try sensei.control.start(worker.Target.?);
}

fn resolve(argument: ?*anyopaque) *fixtures.Worker {
    const workers = active orelse @panic(labels.INVALID_STATE);
    for (workers) |*worker| {
        if (argument == @as(?*anyopaque, @ptrCast(worker))) return worker;
    }
    @panic(labels.INVALID_STATE);
}

fn workerEntry(argument: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    const worker = resolve(argument);
    const current = thread.state.getCurrent() orelse @panic(labels.INVALID_STATE);
    worker.EntryCount += 1;
    worker.ArgumentMatched = current == worker.Target and current.Argument == argument and
        current.Started and current.Managed and current.Mode == .Kernel and current.Status == .Running;
    observe(worker);
    checkGuards(worker);

    var canaries = inputs.STACK_CANARIES;
    const words: [*]volatile u64 = @ptrCast(&canaries);
    var round: u32 = 0;
    while (round < inputs.YIELD_ROUNDS) : (round += 1) {
        probe.cooperative(&worker.Cooperative, yieldEntry, worker);
        worker.RegistersValid = worker.RegistersValid and sameRegisters(&worker.Cooperative.Seed, &worker.Cooperative.Actual);
        worker.StackValid = worker.StackValid and worker.Cooperative.BeforeRSP == worker.Cooperative.AfterRSP and
            worker.Cooperative.BeforeRSP >= worker.StackBase and worker.Cooperative.BeforeRSP < worker.StackTop and
            worker.Cooperative.BeforeRSP % inputs.STACK_ALIGNMENT == 0;
        worker.InterruptsValid = worker.InterruptsValid and validFlags(worker.Cooperative.BeforeFlags) and
            validFlags(worker.Cooperative.AfterFlags);
        for (inputs.STACK_CANARIES, 0..) |expected, index| {
            worker.StackValid = worker.StackValid and words[index] == expected;
        }
        observe(worker);
    }

    probe.preemptive(&worker.Preemptive, worker.Peer.?);
    observe(worker);
    worker.Done = true;
    thread.finish.complete();
}

fn yieldEntry(argument: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) void {
    const worker = resolve(argument);
    sensei.run.yield() catch |failure| verify.failure(failure);
    worker.YieldReturns += 1;
}

fn observe(worker: *fixtures.Worker) void {
    const current = thread.state.getCurrent() orelse @panic(labels.INVALID_STATE);
    const pointer = cpu.state.readStackPointer();
    worker.StackValid = worker.StackValid and current == worker.Target and
        pointer >= worker.StackBase and pointer < worker.StackTop;
    worker.InterruptsValid = worker.InterruptsValid and validFlags(cpu.state.readFlags());
    worker.CR3Valid = worker.CR3Valid and current.Owner.ID == worker.OwnerID and
        kagami.state.getCurrentKagami() == current.Owner.AddressSpace and
        current.Owner.AddressSpace.?.PML4Physical == worker.ExpectedCR3 and
        (cpu.control.readCR3() & inputs.PAGE_FRAME_MASK) == worker.ExpectedCR3;
    worker.TSSValid = worker.TSSValid and tss.state.getBootTSS().RSP0 == worker.StackTop;
}

fn checkGuards(worker: *fixtures.Worker) void {
    const outer_flags = guard.acquire();
    const inner_flags = guard.acquire();
    worker.InterruptsValid = worker.InterruptsValid and validFlags(outer_flags) and
        (inner_flags & inputs.INTERRUPT_ENABLE) == 0 and (cpu.state.readFlags() & inputs.INTERRUPT_ENABLE) == 0;
    guard.release(inner_flags);
    worker.InterruptsValid = worker.InterruptsValid and (cpu.state.readFlags() & inputs.INTERRUPT_ENABLE) == 0;
    guard.release(outer_flags);
    worker.InterruptsValid = worker.InterruptsValid and validFlags(cpu.state.readFlags());
}

fn validFlags(value: u64) bool {
    return (value & (inputs.INTERRUPT_ENABLE | inputs.RESERVED_FLAG)) ==
        (inputs.INTERRUPT_ENABLE | inputs.RESERVED_FLAG) and (value & inputs.DIRECTION_FLAG) == 0;
}

fn sameRegisters(expected: *const fixtures.Registers, actual: *const fixtures.Registers) bool {
    return expected.RBX == actual.RBX and expected.RBP == actual.RBP and expected.R12 == actual.R12 and
        expected.R13 == actual.R13 and expected.R14 == actual.R14 and expected.R15 == actual.R15;
}

fn cleanup(workers: *[2]fixtures.Worker) void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    for (workers) |*worker| {
        if (worker.OwnerID == 0) continue;
        if (kata.state.findByID(worker.OwnerID)) |owner| {
            switch (owner.State) {
                .Born => {
                    if (worker.Target) |target| {
                        if (thread.state.owns(target)) thread.destroy.destroy(target) catch |failure| verify.failure(failure);
                    }
                    kata.destroy.destroy(owner) catch |failure| verify.failure(failure);
                },
                .Alive, .Sleeping => kata.finish.terminate(owner, .Completed) catch |failure| verify.failure(failure),
                .Dead => kata.collect.collect(),
            }
        }
        if (kata.completion.lifetime.peek(worker.OwnerID) != null) {
            _ = kata.completion.lifetime.collect(worker.OwnerID) catch |failure| verify.failure(failure);
        }
    }
}

fn verifyResults(workers: *const [2]fixtures.Worker, baseline: fixtures.Baseline, resumed_flags: u64, completed: bool) void {
    var arguments = true;
    var registers = true;
    var stacks = true;
    var interrupts = true;
    var roots = workers[0].ExpectedCR3 != workers[1].ExpectedCR3;
    var stackswitch = workers[0].StackTop != workers[1].StackTop;
    var preempted = true;
    var x87 = true;
    var sse = true;
    var mxcsr = true;
    var reclaimed = completed;
    for (workers, 0..) |*worker, index| {
        const expected = &inputs.FLOATING_SEEDS[index];
        const actual = &worker.Preemptive.Actual;
        arguments = arguments and worker.ArgumentMatched and worker.EntryCount == 1;
        registers = registers and worker.RegistersValid and worker.YieldReturns == inputs.YIELD_ROUNDS and
            sameRegisters(&inputs.REGISTER_SEEDS[index], &worker.Cooperative.Actual) and
            sameRegisters(&inputs.REGISTER_SEEDS[index], &worker.Preemptive.ActualRegisters);
        stacks = stacks and worker.StackValid;
        interrupts = interrupts and worker.InterruptsValid and validFlags(worker.Preemptive.BeforeFlags) and
            validFlags(worker.Preemptive.AfterFlags);
        roots = roots and worker.CR3Valid;
        stackswitch = stackswitch and worker.TSSValid;
        preempted = preempted and worker.Preemptive.TimedOut == 0 and worker.Preemptive.Stage == inputs.PROGRESSED_STAGE;
        x87 = x87 and actual.Control == expected.Control and actual.X87[0] == expected.X87[0] and actual.X87[1] == expected.X87[1];
        sse = sse and actual.XMM0[0] == expected.XMM0[0] and actual.XMM0[1] == expected.XMM0[1] and
            actual.XMM15[0] == expected.XMM15[0] and actual.XMM15[1] == expected.XMM15[1];
        mxcsr = mxcsr and actual.MXCSR == expected.MXCSR;
        reclaimed = reclaimed and kata.state.findByID(worker.OwnerID) == null and
            kata.completion.storage.ownerOf(worker.OwnerID) == null and !thread.state.owns(worker.Target.?);
    }
    const scheduler = sensei.state.getState();
    const pointer = cpu.state.readStackPointer();
    const launcher = thread.state.getCurrent() == baseline.Current and kagami.state.getCurrentKagami() == baseline.AddressSpace and
        cpu.control.readCR3() == baseline.CR3 and tss.state.getBootTSS().RSP0 == baseline.RSP0 and
        pointer >= baseline.Current.Stack.Base and pointer < baseline.Current.Stack.Top and
        validFlags(baseline.Flags) and validFlags(resumed_flags);
    reclaimed = reclaimed and scheduler.RegisteredCount == baseline.RegisteredCount and scheduler.Ready.Count == 0 and
        scheduler.Retired.Count == 0 and baseline.Current.Owner.ThreadCount == baseline.OwnerThreadCount;
    verify.require(arguments, labels.ARGUMENT_TRANSFER);
    verify.require(registers, labels.CALLEE_REGISTERS);
    verify.require(stacks, labels.STACK_RESUME);
    verify.require(interrupts, labels.INTERRUPT_FLAGS);
    verify.require(roots, labels.KAGAMI_CR3);
    verify.require(stackswitch, labels.TSS_STACK);
    verify.require(preempted and scheduler.Requests > baseline.Requests and scheduler.Switches > baseline.Switches, labels.TIMER_PREEMPTION);
    verify.require(x87, labels.X87_STATE);
    verify.require(sse, labels.SSE_STATE);
    verify.require(mxcsr, labels.MXCSR_STATE);
    verify.require(launcher, labels.LAUNCHER_RESTORE);
    verify.require(reclaimed, labels.DISPOSABLE_CLEANUP);
}
