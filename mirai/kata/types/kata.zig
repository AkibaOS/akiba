//! Address Space Owning Kata

const Kagami = @import("mirai").kagami.types.kagami.Kagami;

pub const Kata = struct {
    ID: u64,
    AddressSpace: *Kagami,
    ThreadCount: u64 = 0,
    Permanent: bool = false,
};
