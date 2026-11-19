//! Address Space Owning Kata

const Kagami = @import("mirai").kagami.types.kagami.Kagami;
const State = @import("mirai").kata.types.state.State;

pub const Kata = struct {
    ID: u64,
    AddressSpace: ?*Kagami,
    ThreadCount: u64 = 0,
    LiveThreadCount: u64 = 0,
    RunnableThreadCount: u64 = 0,
    State: State = .Born,
    Permanent: bool = false,
    CanProvision: bool = false,
};
