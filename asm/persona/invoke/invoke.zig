//! Invoke One Private Persona Service

const instructions = @import("personaasm").strings.invoke.instructions;

const Result = @import("personaasm").types.invoke.result.Result;
const Service = @import("shared").persona.types.invocation.Service;

pub fn call(service: Service, first: u64, second: u64, third: u64, fourth: u64) Result {
    var status: u64 = undefined;
    var value: u64 = undefined;
    asm volatile (instructions.CALL
        : [status] "={rax}" (status),
          [value] "={rdx}" (value),
        : [service] "0" (@intFromEnum(service)),
          [first] "{rdi}" (first),
          [second] "{rsi}" (second),
          [third] "1" (third),
          [fourth] "{r10}" (fourth),
        : .{ .memory = true, .cc = true });
    return .{ .Status = status, .Value = value };
}
