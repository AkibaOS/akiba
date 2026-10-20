//! Controlled User Invocation Dispatch

const constants = @import("mirai").invocations.constants.abi;
const cpu = @import("asm").cpu;
const ipc = @import("mirai").invocations.postman;
const messages = @import("mirai").thread.strings.shift.messages;
const selectors = @import("mirai").boot.constants.gdt.selectors;
const sensei = @import("mirai").sensei;
const thread = @import("mirai").thread;
const types = @import("mirai").invocations.types.abi;

const InterruptFrame = @import("mirai").interrupts.types.frame.InterruptFrame;

export fn invocation_dispatch(frame: *InterruptFrame) void {
    if ((frame.CS & cpu.constants.user.SELECTOR_RPL_MASK) != cpu.constants.user.SELECTOR_RPL_USER) {
        frame.RAX = @intFromEnum(types.Status.InvalidCaller);
        frame.RDX = 0;
        return;
    }
    const current = thread.state.getCurrent() orelse @panic(messages.INVALID_CONTEXT);
    if (current.Mode != .User or !current.Managed or current.Status != .Running or
        (cpu.state.readFlags() & cpu.constants.control.RFLAGS_INTERRUPT_ENABLE) != 0) @panic(messages.INVALID_CONTEXT);
    if (frame.CS != (@as(u64, selectors.USER_CODE_SELECTOR) | selectors.RING_3) or
        frame.SS != (@as(u64, selectors.USER_DATA_SELECTOR) | selectors.RING_3) or
        !thread.user.validReturn(current, frame.RIP, frame.RSP))
        thread.user.fault(constants.INVALID_RETURN_VECTOR, 0, frame.RIP, frame.RIP, frame.RSP);
    frame.RFLAGS = (frame.RFLAGS & constants.USER_FLAGS_MASK) | constants.USER_FLAGS_REQUIRED;
    const service = frame.RAX;
    if (service >= @intFromEnum(types.Service.Send) and service <= @intFromEnum(types.Service.Close)) {
        ipc.dispatch(current, frame, service);
        return;
    }
    frame.RAX = @intFromEnum(types.Status.Success);
    frame.RDX = 0;
    switch (service) {
        @intFromEnum(types.Service.Query) => switch (frame.RDI) {
            @intFromEnum(types.Query.ABI) => frame.RDX = constants.VERSION,
            @intFromEnum(types.Query.Kata) => frame.RDX = current.Owner.ID,
            else => frame.RAX = @intFromEnum(types.Status.InvalidArgument),
        },
        @intFromEnum(types.Service.Yield) => sensei.run.reschedule(false),
        else => frame.RAX = @intFromEnum(types.Status.Unsupported),
    }
}
