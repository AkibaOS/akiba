//! Copy And Seal A Private Linked Draft Before Start

const launch = @import("weaver").launch;
const shared = @import("shared").launch;
const sizes = @import("common").constants.memory.sizes;
const weaver = @import("weaver");

const Channel = launch.types.request.Channel;
const Options = launch.types.request.Options;
const Plan = weaver.link.types.link.Plan;
const RequestError = launch.errors.request.RequestError;
const Spans = launch.types.request.Spans;
const wire = shared.types.provision;

pub fn stage(channel: Channel, plan: *const Plan, options: Options, spans: Spans) RequestError!u64 {
    try image(channel, plan);
    const stack_end = options.StackBase + spans.StackLength;
    var address = options.StackBase;
    while (address < stack_end) : (address += sizes.PAGE_SIZE) {
        _ = try invoke(channel, .Allocate, address, .ReadOnly);
        _ = try invoke(channel, .Seal, address, .ReadWrite);
    }
    try startup(channel, options, spans);
    const request: wire.Start = .{
        .Entry = plan.Placement.Executable.Image.Entry,
        .StackBase = options.StackBase,
        .StackLength = spans.StackLength,
        .Startup = options.StartupBase,
    };
    return invoke(channel, .Start, @intFromPtr(&request), .ReadOnly);
}

pub fn invoke(channel: Channel, operation: wire.Operation, argument: u64, protection: wire.Protection) RequestError!u64 {
    const result = channel.Invoke(channel.Context, channel.Ticket, operation, argument, protection);
    if (result.Status != shared.constants.provision.SUCCESS) return error.ProvisionRefused;
    return result.Value;
}

fn image(channel: Channel, plan: *const Plan) RequestError!void {
    var bytes: [sizes.PAGE_SIZE]u8 = undefined;
    var stream: weaver.stage.types.page.Stream = .{ .Link = plan };
    while (weaver.stage.next.next(&stream, &bytes)) |page| {
        _ = try invoke(channel, .Allocate, page.Address, .ReadOnly);
        try copy(channel, page.Address, &bytes);
        _ = try invoke(channel, .Seal, page.Address, switch (page.Access) {
            .ReadOnly => .ReadOnly,
            .ReadWrite => .ReadWrite,
            .ReadExecute => .ReadExecute,
        });
    }
}

fn startup(channel: Channel, options: Options, spans: Spans) RequestError!void {
    var address = spans.Startup.Start;
    while (address < spans.Startup.End) : (address += sizes.PAGE_SIZE) _ = try invoke(channel, .Allocate, address, .ReadOnly);
    const header = shared.startup.encode(options.Identity.len, options.Parameters.len);
    const identity = spans.Startup.Start + header.len;
    try copy(channel, spans.Startup.Start, &header);
    try copy(channel, identity, options.Identity);
    try copy(channel, identity + options.Identity.len, options.Parameters);
    address = spans.Startup.Start;
    while (address < spans.Startup.End) : (address += sizes.PAGE_SIZE) _ = try invoke(channel, .Seal, address, .ReadOnly);
}

fn copy(channel: Channel, destination: u64, bytes: []const u8) RequestError!void {
    var offset: usize = 0;
    while (offset < bytes.len) {
        const length = @min(sizes.PAGE_SIZE, bytes.len - offset);
        const descriptor: wire.Load = .{
            .Destination = destination + offset,
            .Source = @intFromPtr(bytes[offset..].ptr),
            .Length = length,
        };
        _ = try invoke(channel, .Load, @intFromPtr(&descriptor), .ReadOnly);
        offset += length;
    }
}
