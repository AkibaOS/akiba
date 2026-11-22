//! Internal Invocation Register ABI Types

const provision = @import("shared").launch.constants.provision;

const Native = @import("sdk").persona.types.invocation.Service;

pub const Service = enum(u64) {
    Query = @intFromEnum(Native.Query),
    Yield = @intFromEnum(Native.Yield),
    Send = @intFromEnum(Native.Send),
    Receive = @intFromEnum(Native.Receive),
    Call = @intFromEnum(Native.Call),
    Reply = @intFromEnum(Native.Reply),
    CollectReply = @intFromEnum(Native.CollectReply),
    Close = @intFromEnum(Native.Close),
    FinishThread = @intFromEnum(Native.FinishThread),
    Exit = @intFromEnum(Native.Exit),
    ObserveCompletion = 10,
    WaitCompletion = 11,
    CollectCompletion = 12,
    BootstrapWeaver = 14,
    BootstrapDriver = 15,
    Ahci = 16,
    CallTimed = 17,
    ReceiveActivity = 18,
    StopChild = 19,
    WaitCompletionTimed = 20,
    Device = @intFromEnum(Native.Device),
    Provision = provision.SERVICE,
};

pub const Query = enum(u64) {
    ABI = 0,
    Kata = 1,
};

pub const Status = @import("sdk").persona.types.invocation.Status;
