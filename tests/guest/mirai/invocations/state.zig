//! Real Persona Invocation Return State Preservation

const std = @import("std");

const common = @import("common");
const drive = @import("tests").guest.support.drive;
const harness = @import("tests").guest.mirai.postman.harness;
const inputs = @import("tests").constants.persona;
const kata = @import("mirai").kata;
const labels = @import("tests").strings.persona;
const limits = @import("tests").constants.guest;
const probe = @import("testasm").persona;
const sensei = @import("mirai").sensei;
const thread = @import("mirai").thread;
const types = @import("tests").types.persona;
const user = @import("mirai").user;
const verify = @import("tests").verify;

var captured: types.Frame = undefined;
var completed: bool = false;
var switched: bool = false;
var user_id: u64 = 0;
var user_thread: ?*thread.types.thread.Thread = null;
var user_stack: u64 = 0;

pub fn run() !void {
    captured = .{ .FirstSeed = inputs.SEEDS[0], .SecondSeed = inputs.SEEDS[1] };
    completed = false;
    switched = false;
    user_id = 0;
    user_thread = null;
    const registered = sensei.state.getState().RegisteredCount;
    const owner = try kata.create.create();
    const identifier = owner.ID;
    defer harness.dispose(identifier);
    const controller = try thread.create.create(owner, entry, null);
    try sensei.control.start(controller);
    drive.run();
    const outcome = try kata.completion.lifetime.collect(identifier);
    verify.require(captured.Query.Status == 0 and captured.Query.Value == 1 and
        captured.Yield.Status == 0 and captured.Yield.Value == 0, labels.STATUS);
    verify.require(std.meta.eql(captured.Query.Registers, inputs.SEEDS[0].Registers) and
        std.meta.eql(captured.Yield.Registers, inputs.SEEDS[1].Registers) and
        captured.Query.Input == 0 and captured.Yield.Input == 0, labels.REGISTERS);
    verify.require(std.meta.eql(captured.Query.Float, inputs.SEEDS[0].Float) and
        std.meta.eql(captured.Yield.Float, inputs.SEEDS[1].Float), labels.FLOAT);
    verify.require((captured.Query.Flags & inputs.CHECKED_FLAGS) == inputs.QUERY_FLAGS and
        (captured.Yield.Flags & inputs.CHECKED_FLAGS) == inputs.YIELD_FLAGS and
        (captured.Query.Flags & ~inputs.ALLOWED_FLAGS) == 0 and
        (captured.Yield.Flags & ~inputs.ALLOWED_FLAGS) == 0, labels.FLAGS);
    verify.require(captured.Query.Stack == user_stack and captured.Yield.Stack == user_stack, labels.STACK);
    verify.require(completed and switched and captured.Finished == 1 and outcome == .Completed and
        kata.state.findByID(identifier) == null and kata.state.findByID(user_id) == null and
        kata.completion.storage.ownerOf(identifier) == null and kata.completion.storage.ownerOf(user_id) == null and
        !thread.state.owns(controller) and !thread.state.owns(user_thread.?) and
        sensei.state.getState().RegisteredCount == registered, labels.CLEANUP);
}

fn entry(_: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    execute() catch |failure| verify.failure(failure);
    completed = true;
    thread.finish.complete();
}

fn execute() !void {
    var actor = try harness.create();
    user_id = actor.ID;
    defer harness.dispose(actor.ID);
    const frame = types.Frame{ .FirstSeed = inputs.SEEDS[0], .SecondSeed = inputs.SEEDS[1] };
    try user.copy.transfer.write(actor.Owner, actor.Data, std.mem.asBytes(&frame));
    const image = probe.image();
    try user.memory.load.load(actor.Owner, actor.Code, image);
    try user.memory.finalize.finalize(actor.Owner, actor.Code, .ReadExecute);
    const target = try thread.user.create(actor.Owner, actor.Code, actor.Stack, common.constants.memory.sizes.PAGE_SIZE, 0);
    actor.Target = target;
    user_thread = target;
    user_stack = target.User.RSP;
    const switches = sensei.state.getState().Switches;
    try harness.start(&actor);
    var attempts: usize = 0;
    while (attempts < limits.DRIVE_LIMIT) : (attempts += 1) {
        var finished: u64 = 0;
        try user.copy.transfer.read(actor.Owner, std.mem.asBytes(&finished), actor.Data + @offsetOf(types.Frame, labels.FINISHED_FIELD));
        if (finished == 1) {
            try user.copy.transfer.read(actor.Owner, std.mem.asBytes(&captured), actor.Data);
            switched = sensei.state.getState().Switches > switches + 1;
            return;
        }
        try sensei.run.yield();
    }
    return error.DriveLimit;
}
