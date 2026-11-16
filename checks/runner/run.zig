//! Manual Guest Check Host Entry

const std = @import("std");

const execute = @import("checks").runner.execute;
const strings = @import("checks").strings.runner;

pub fn main() void {
    execute.run() catch |failure| {
        std.debug.print(strings.RESULT_FAIL, .{@errorName(failure)});
        std.process.exit(1);
    };
}
