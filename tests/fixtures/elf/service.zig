//! Native Service Probe For Real Pulse Supervision

const inputs = @import("tests").fixtures.constants.service;
const invocation = @import("fixtureasm").invocation;
const labels = @import("tests").fixtures.strings.service;

const Header = @import("tests").fixtures.types.weaver.Header;

pub fn recognizes(address: u64) bool {
    const header: *const [3]u64 = @ptrFromInt(address);
    if (header[0] != 1 or header[1] != labels.IDENTITY.len or header[2] < inputs.PARAMETER_PREFIX) return false;
    const identity: [*]const u8 = @ptrFromInt(address + inputs.HEADER_BYTES);
    for (labels.IDENTITY, 0..) |expected, index| if (identity[index] != expected) return false;
    return true;
}

pub fn run(address: u64) noreturn {
    const header: *const [3]u64 = @ptrFromInt(address);
    const parameters: [*]const u8 = @ptrFromInt(address + inputs.HEADER_BYTES + header[1]);
    var pulse: u64 = 0;
    for (0..@sizeOf(u64)) |index| pulse |= @as(u64, parameters[index]) << @intCast(index * 8);
    const text = parameters[inputs.PARAMETER_PREFIX..@intCast(header[2])];
    if (equal(text, labels.FAILURE)) invocation.exit(inputs.EXIT_RESULT);
    var incoming: Header = undefined;
    while (true) {
        const arrived = invocation.call(inputs.RECEIVE, 0, 0, @intFromPtr(&incoming), 0);
        if (arrived.Status != 0) invocation.exit(inputs.EXIT_RESULT);
        if (incoming.Type == inputs.FAIL) invocation.exit(inputs.EXIT_RESULT);
        if (incoming.Sender == pulse and incoming.Type == inputs.QUERY and equal(text, labels.SILENT)) {
            while (true) _ = invocation.call(inputs.YIELD, 0, 0, 0, 0);
        }
        var kind: u64 = 0;
        var stopped = false;
        if (incoming.Sender == pulse and incoming.Type == inputs.QUERY) kind = inputs.READY;
        if (incoming.Sender == pulse and incoming.Type == inputs.STOP) {
            kind = inputs.STOPPED;
            stopped = true;
        }
        if (incoming.Type == inputs.TRIGGER_SHUTDOWN and equal(text, labels.CONTROLLER)) {
            const sent = invocation.call(inputs.SEND, pulse, 0, 0, inputs.SHUTDOWN);
            if (sent.Status != 0) invocation.exit(inputs.EXIT_RESULT);
            kind = inputs.ACK;
        }
        if (incoming.ReplyTicket != 0) {
            const replied = invocation.call(inputs.REPLY, incoming.ReplyTicket, 0, 0, kind);
            if (replied.Status != 0 and replied.Status != 11 and replied.Status != 12) invocation.exit(inputs.EXIT_RESULT);
        }
        if (stopped) invocation.exit(0);
    }
}

fn equal(first: []const u8, second: []const u8) bool {
    if (first.len != second.len) return false;
    for (first, second) |actual, expected| if (actual != expected) return false;
    return true;
}
