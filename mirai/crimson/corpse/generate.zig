//! Generate Corpse Without Unbounded Memory Snapshots

const context = @import("mirai").crimson.context;
const cpu = @import("asm").cpu;
const types = @import("mirai").crimson.types;

const Corpse = types.corpse.Corpse;
const DebugState = types.flavor.DebugState;
const Exception = types.exception.Exception;
const FloatState = types.flavor.FloatState;

pub fn generate(exception: *const Exception) Corpse {
    var corpse: Corpse = undefined;
    corpse.clear();
    corpse.MemorySnapshotAddress = 0;

    corpse.KataId = exception.KataId;
    corpse.ThreadId = exception.ThreadId;
    corpse.ExceptionType = exception.ExceptionType;
    corpse.ExceptionCode = exception.Code;
    corpse.ExceptionSubcode = exception.Subcode;
    corpse.FaultAddress = exception.Address;

    corpse.Context = exception.Context.*;

    captureFloatState(&corpse.FloatState);
    captureDebugState(&corpse.DebugState);

    corpse.Timestamp = cpu.state.readTimeStampCounter();
    corpse.markValid();

    return corpse;
}

fn captureFloatState(state: *FloatState) void {
    context.float.capture(state);
}

fn captureDebugState(state: *DebugState) void {
    context.debug.capture(state);
}
