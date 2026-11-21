//! Postman Invocation Argument And Result Types

const abi = @import("shared").persona.types.invocation;
const strings = @import("mirai").invocations.strings.postman.diagnostic;

const Header = @import("shared").persona.types.letter.Header;

const Call = @import("shared").persona.types.call.Call;

pub const Result = struct {
    Status: abi.Status = .Success,
    Value: u64 = 0,
};

comptime {
    if (@sizeOf(Call) != 7 * @sizeOf(u64) or @sizeOf(Header) != 4 * @sizeOf(u64)) @compileError(strings.INVALID_ABI);
}
