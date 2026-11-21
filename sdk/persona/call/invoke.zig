//! Invoke A Supported Persona Service

const Result = @import("sdk").persona.types.invocation.Result;
const Service = @import("sdk").persona.types.invocation.Service;

extern fn persona_invoke(service: u64, first: u64, second: u64, third: u64, fourth: u64) callconv(.{ .x86_64_sysv = .{} }) Result;

pub fn call(service: Service, first: u64, second: u64, third: u64, fourth: u64) Result {
    return persona_invoke(@intFromEnum(service), first, second, third, fourth);
}
