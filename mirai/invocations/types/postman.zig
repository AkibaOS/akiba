//! Postman Invocation Argument And Result Types

const abi = @import("mirai").invocations.types.abi;
const strings = @import("mirai").invocations.strings.postman;

const Header = @import("mirai").postman.types.letter.Header;

pub const Call = extern struct {
    Destination: u64,
    Type: u64,
    Request: u64,
    RequestLength: u64,
    Reply: u64,
    ReplyCapacity: u64,
    Metadata: u64,
};

pub const Result = struct {
    Status: abi.Status = .Success,
    Value: u64 = 0,
};

comptime {
    if (@sizeOf(Call) != 7 * @sizeOf(u64) or @sizeOf(Header) != 4 * @sizeOf(u64)) @compileError(strings.INVALID_ABI);
}
