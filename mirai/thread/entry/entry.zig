//! Fresh Kernel Thread Entry

const flags = @import("asm").interrupts.flags;
const messages = @import("mirai").thread.strings.shift.messages;
const shift = @import("mirai").thread.shift;
const state = @import("mirai").thread.state;
const types = @import("mirai").thread.types;

const Thread = types.thread.Thread;

pub fn start(thread: *Thread) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    if (state.getCurrent() != thread or thread.Started or !shift.finish()) @panic(messages.INVALID_CONTEXT);
    thread.Started = true;
    const entry = thread.EntryPoint orelse @panic(messages.INVALID_CONTEXT);
    const argument = thread.Argument;
    if (thread.EnableInterrupts and thread.Mode == .Kernel) flags.enableInterrupts();
    entry(argument);
}
