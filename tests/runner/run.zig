//! Manual Guest Check Host Entry

const std = @import("std");

const execute = @import("tests").runner.execute;
const strings = @import("tests").strings.runner;

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
        if (!std.mem.eql(u8, argument, strings.UNATTENDED) or arguments.next() != null) return error.InvalidRunnerArguments;
        return execute.run(true);
    }
    return execute.run(false);
}
