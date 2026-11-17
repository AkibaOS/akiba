//! Fixture Persona Exit Boundary

const instructions = @import("fixtureasm").strings.instructions;
const service = @import("fixtureasm").constants.service;

pub fn exit(result: u64) noreturn {
    asm volatile (instructions.EXIT
        :
        : [service] "{rax}" (service.EXIT),
          [result] "{rdi}" (result),
        : .{ .memory = true });
    unreachable;
}
