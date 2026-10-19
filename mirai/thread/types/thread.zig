//! Owned Kernel Execution Context

const Context = @import("asm").cpu.types.context.Context;
const Entry = @import("mirai").thread.types.entry.Entry;
const Kata = @import("mirai").kata.types.kata.Kata;
const KernelStack = @import("mirai").memory.types.stack.kernel.KernelStack;
const Mode = @import("mirai").thread.types.mode.Mode;
const State = @import("mirai").thread.types.state.State;
const User = @import("mirai").thread.types.user.User;

pub const Thread = struct {
    Owner: *Kata,
    Stack: KernelStack,
    Context: Context = .{},
    Mode: Mode = .Kernel,
    User: User = .{},
    EntryPoint: ?Entry = null,
    Argument: ?*anyopaque = null,
    EnableInterrupts: bool = false,
    Managed: bool = false,
    Started: bool = false,
    Status: State = .Ready,
    Permanent: bool = false,
};
