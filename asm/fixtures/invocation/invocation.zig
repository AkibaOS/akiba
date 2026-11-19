//! Compiler Fixture Persona Invocations

const constants = @import("fixtureasm").constants.invocation;
const instructions = @import("fixtureasm").strings.invocation;

const Result = @import("fixtureasm").types.invocation.Result;

pub fn call(service: u64, first: u64, second: u64, third: u64, fourth: u64) Result {
    var status: u64 = undefined;
    var value: u64 = undefined;
    asm volatile (instructions.INVOKE
        : [status] "={rax}" (status),
          [value] "={rdx}" (value),
        : [service] "0" (service),
          [first] "{rdi}" (first),
          [second] "{rsi}" (second),
          [third] "1" (third),
          [fourth] "{r10}" (fourth),
        : .{ .memory = true, .cc = true });
    return .{ .Status = status, .Value = value };
}

pub fn exit(result: u64) noreturn {
    asm volatile (instructions.EXIT
        :
        : [service] "{rax}" (constants.EXIT),
          [result] "{rdi}" (result),
        : .{ .memory = true });
    unreachable;
}
