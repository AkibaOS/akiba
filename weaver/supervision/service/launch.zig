//! Construct Installed Binaries For Their Authenticated Requester

const invoke = @import("personaasm").invoke;
const layout = @import("weaver").supervision.constants.service.layout;
const memory = @import("weaver").memory.arena;
const origin = @import("weaver").supervision.strings.origin;
const policy = @import("common").constants.memory;
const source = @import("weaver").library.ipc.source;
const transaction = @import("weaver").launch.transaction.run;
const wire = @import("shared").launch.types.provision;

const Channel = @import("weaver").launch.types.request.Channel;
const Request = @import("shared").launch.types.service.request.Request;

pub fn start(endpoint: u64, request: Request, ticket: u64) !u64 {
    const allocator = memory.reset();
    var afs = endpoint;
    const provider = source.source(&afs);
    const executable = (try provider.ReadFromOrigin(provider.Context, allocator, &origin.SYSTEM_BINARIES, request.Identity)) orelse return error.BinaryMissing;
    defer allocator.free(executable);
    const channel: Channel = .{ .Ticket = ticket, .Context = &afs, .Invoke = provision };
    return transaction.run(allocator, provider, executable, .{
        .Policy = .{
            .MinimumAddress = policy.sizes.PAGE_SIZE,
            .MaximumAddress = policy.layout.USER_SPACE_END,
            .MaximumPages = policy.layout.USER_SPACE_END / policy.sizes.PAGE_SIZE,
        },
        .StackBase = layout.STACK_BASE,
        .StackPages = layout.STACK_PAGES,
        .StartupBase = layout.STARTUP_BASE,
        .Identity = request.Identity,
        .Parameters = request.Parameters,
    }, channel);
}

fn provision(_: *anyopaque, ticket: u64, operation: wire.Operation, argument: u64, protection: wire.Protection) wire.Result {
    const result = invoke.call(.Provision, ticket, @intFromEnum(operation), argument, @intFromEnum(protection));
    return .{ .Status = result.Status, .Value = result.Value };
}
