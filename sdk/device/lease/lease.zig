//! Operate On This Kata's Assigned Device

const invoke = @import("sdk").persona.call.invoke;

const Operation = @import("sdk").device.types.operation.Operation;
const Result = @import("sdk").persona.types.invocation.Result;

pub fn assigned() Result {
    return perform(.Lease, 0);
}

pub fn probeStream(handle: u64) Result {
    return perform(.StreamProbe, handle);
}

pub fn readStream(handle: u64) Result {
    return perform(.StreamNext, handle);
}

fn perform(operation: Operation, handle: u64) Result {
    return invoke.call(.Device, @intFromEnum(operation), handle, 0, 0);
}
