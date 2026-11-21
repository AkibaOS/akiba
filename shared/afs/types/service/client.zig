//! Authenticated AFS Client Transport

const Call = @import("shared").persona.types.call.Call;
const Result = @import("shared").persona.types.result.Result;

pub const Client = struct {
    Endpoint: u64,
    Timeout: u64,
    Invoke: *const fn (*const Call, u64) Result,
};

pub const Reply = struct {
    Kind: u64,
    Length: usize,
};
