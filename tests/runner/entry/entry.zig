//! Manual Guest Check Host Entry

const std = @import("std");

const execute = @import("tests").runner.session.execute;
const strings = @import("tests").runner.strings.runner;

pub fn main() void {
    launch() catch |failure| {
        if (failure != error.GuestChecksCancelled and failure != error.GuestSuiteFailed) std.debug.print(strings.RESULT_FAIL, .{@errorName(failure)});
        std.process.exit(1);
    };
}

fn launch() !void {
    var arguments = try std.process.argsWithAllocator(std.heap.page_allocator);
    defer arguments.deinit();
    _ = arguments.next();
    if (arguments.next()) |argument| {
        if (arguments.next() != null) return error.InvalidRunnerArguments;
        if (std.mem.eql(u8, argument, strings.UNATTENDED)) return execute.run(true, false);
        if (std.mem.eql(u8, argument, strings.AHCI)) return execute.run(false, true);
        return error.InvalidRunnerArguments;
    }
    return execute.run(false, false);
}
