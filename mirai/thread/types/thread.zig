//! Owned Kernel Execution Context

const Context = @import("asm").cpu.types.context.frame.Context;
const Entry = @import("mirai").thread.types.entry.callback.Entry;
const Kata = @import("mirai").kata.types.kata.Kata;
const KernelStack = @import("mirai").memory.types.stack.kernel.KernelStack;
const Mode = @import("mirai").thread.types.mode.Mode;
const State = @import("mirai").thread.types.state.lifecycle.State;
const User = @import("mirai").thread.types.user.context.User;

pub const Thread = struct {
    Owner: *Kata,
    Stack: KernelStack,
    Context: Context = .{},
    Mode: Mode = .Kernel,
    User: User = .{},
    EntryPoint: ?Entry = null,
    Argument: ?*anyopaque = null,
    EnableInterrupts: bool = false,
    Admitted: bool = false,
    Managed: bool = false,
    Started: bool = false,
    Status: State = .Ready,
    Permanent: bool = false,
};
