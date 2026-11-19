//! Persona Mode Completion And Exit Regressions

const common = @import("common");
const drive = @import("tests").guest.support.drive;
const fixtures = @import("tests").guest.constants.invocations;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.guest;
const kata = @import("mirai").kata;
const labels = @import("tests").strings.guest;
const sensei = @import("mirai").sensei;
const thread = @import("mirai").thread;
const user = @import("mirai").user;
const verify = @import("tests").guest.support.verify;

const Thread = thread.types.thread.Thread;
const Queue = sensei.types.queue.Queue;
const PAGE_SIZE = common.constants.memory.sizes.PAGE_SIZE;

var sibling_ran: bool = false;
var sibling_blocked: bool = false;
var blocked: Queue = .{};

fn image(bytes: []const u8, offset: u64) !*Thread {
    const owner = try kata.create.create();
    errdefer kata.destroy.destroy(owner) catch @panic(labels.INVALID_STATE);
    try user.memory.allocate.allocate(owner, inputs.CODE_ADDRESS);
    try user.memory.allocate.allocate(owner, inputs.STACK_ADDRESS);
    try user.memory.load.load(owner, inputs.CODE_ADDRESS + offset, bytes);
    try user.memory.finalize.finalize(owner, inputs.CODE_ADDRESS, .ReadExecute);
    try user.memory.finalize.finalize(owner, inputs.STACK_ADDRESS, .ReadWrite);
    return thread.user.create(owner, inputs.CODE_ADDRESS + offset, inputs.STACK_ADDRESS, PAGE_SIZE, inputs.ENTRY_ARGUMENT);
}

fn companion(_: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    const current = thread.state.getCurrent().?;
    var attempts: usize = 0;
    while (current.Owner.LiveThreadCount > 1 and attempts < inputs.DRIVE_LIMIT) : (attempts += 1)
        sensei.run.yield() catch |failure| verify.failure(failure);
    verify.require(current.Owner.State == .Alive and current.Owner.LiveThreadCount == 1 and
        current.Owner.ThreadCount == 1, labels.PERSONA_FINISH_SIBLING);
    sibling_ran = true;
    thread.finish.complete();
}

fn never(_: ?*anyopaque) bool {
    return false;
}

fn blocker(_: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    sibling_blocked = true;
    sensei.wait.blockUntil(&blocked, never, null) catch |failure| verify.failure(failure);
    @panic(labels.INVALID_STATE);
}

fn lastThread() !void {
    const target = try image(&fixtures.FINISH_THREAD, 0);
    const id = target.Owner.ID;
    try sensei.control.start(target);
    drive.run();
    const result = try kata.completion.lifetime.collect(id);
    verify.require(result == .Completed and kata.state.findByID(id) == null, labels.PERSONA_FINISH_LAST);
}

fn nonlastThread() !void {
    sibling_ran = false;
    const target = try image(&fixtures.FINISH_THREAD, 0);
    const owner = target.Owner;
    const id = owner.ID;
    const sibling = try thread.create.create(owner, companion, null);
    const flags = guard.acquire();
    try sensei.control.start(target);
    try sensei.control.start(sibling);
    guard.release(flags);
    drive.run();
    const result = try kata.completion.lifetime.collect(id);
    verify.require(sibling_ran and result == .Completed and kata.state.findByID(id) == null, labels.PERSONA_FINISH_NONLAST);
}

fn explicitExit() !void {
    sibling_blocked = false;
    const target = try image(&fixtures.EXIT, 0);
    const owner = target.Owner;
    const id = owner.ID;
    const sibling = try thread.create.create(owner, blocker, null);
    try sensei.control.start(sibling);
    drive.run();
    if (!sibling_blocked or owner.State != .Sleeping) @panic(labels.INVALID_STATE);
    try sensei.control.start(target);
    drive.run();
    const result = try kata.completion.lifetime.collect(id);
    verify.require(result == .Exited and result.Exited == fixtures.EXIT_RESULT and kata.state.findByID(id) == null, labels.PERSONA_EXIT_SIBLING);
}

fn boundaryFinish() !void {
    const target = try image(&fixtures.BOUNDARY_FINISH, PAGE_SIZE - fixtures.BOUNDARY_FINISH.len);
    const id = target.Owner.ID;
    try sensei.control.start(target);
    drive.run();
    const result = try kata.completion.lifetime.collect(id);
    verify.require(result == .Completed and kata.state.findByID(id) == null, labels.PERSONA_FINISH_BOUNDARY);
}

fn boundaryExit() !void {
    const target = try image(&fixtures.BOUNDARY_EXIT, PAGE_SIZE - fixtures.BOUNDARY_EXIT.len);
    const id = target.Owner.ID;
    try sensei.control.start(target);
    drive.run();
    const result = try kata.completion.lifetime.collect(id);
    verify.require(result == .Exited and result.Exited == fixtures.EXIT_RESULT and kata.state.findByID(id) == null, labels.PERSONA_EXIT_BOUNDARY);
}

fn returningValidation() !void {
    const target = try image(&fixtures.INVALID_QUERY, PAGE_SIZE - fixtures.INVALID_QUERY.len);
    const id = target.Owner.ID;
    try sensei.control.start(target);
    drive.run();
    const result = try kata.completion.lifetime.collect(id);
    verify.require(result == .Faulted and result.Faulted.Vector == fixtures.INVALID_RETURN_VECTOR, labels.PERSONA_RETURN_VALIDATION);
}

pub fn run() !void {
    try lastThread();
    try nonlastThread();
    try explicitExit();
    try boundaryFinish();
    try boundaryExit();
    try returningValidation();
}
