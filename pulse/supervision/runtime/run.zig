//! Load And Supervise The Installed Pulse World

const drive = @import("pulse").supervision.runtime.drive;
const inbox = @import("pulse").supervision.runtime.inbox;
const invoke = @import("personaasm").invoke;
const memory = @import("pulse").supervision.memory;
const names = @import("pulse").supervision.strings.world;
const parser = @import("pulse").world.parse.document;
const policy = @import("pulse").supervision.plan.model;
const pulse = @import("pulse").supervision.inbox;
const storage = @import("pulse").supervision.client.storage;

const Context = @import("pulse").supervision.types.runtime.context.Context;
const Operation = @import("shared").pulse.types.boot.control.Operation;
const Query = @import("shared").persona.types.invocation.Query;
const Status = @import("shared").persona.types.invocation.Status;

pub fn start(weaver: u64, afs: u64, disk: u64) noreturn {
    run(weaver, afs, disk) catch {
        report(false);
        pulse.listen();
    };
}

fn run(weaver: u64, afs: u64, disk: u64) !noreturn {
    const owner = invoke.call(.Query, @intFromEnum(Query.Kata), 0, 0, 0);
    if (owner.Status != @intFromEnum(Status.Success) or owner.Value == 0) return error.InvalidOwner;
    const allocator = memory.allocator();
    const source = try storage.read(afs, allocator, names.PATH);
    defer allocator.free(source);
    var world = try parser.parse(allocator, source);
    defer world.deinit();
    var plan = try policy.init(allocator, &world);
    defer policy.deinit(&plan);
    var context: Context = .{ .Allocator = allocator, .Plan = &plan, .PulseID = owner.Value, .WeaverID = weaver, .AfsID = afs, .DiskID = disk };
    drive.run(&context) catch {
        context.Phase = .Degraded;
        policy.shutdown(&plan);
    };
    const ready = drive.startupReady(&context);
    report(ready);
    if (context.Phase == .Starting) context.Phase = if (drive.degraded(&context)) .Degraded else .Running;
    inbox.listen(&context);
}

fn report(ready: bool) void {
    const operation: Operation = if (ready) .StartupReady else .StartupFailed;
    const result = invoke.call(.BootstrapWeaver, @intFromEnum(operation), 0, 0, 0);
    if (result.Status != @intFromEnum(Status.Success)) pulse.stop(result.Status);
}
