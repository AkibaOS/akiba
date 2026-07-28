//! Generate Corpse

const common = @import("common");

const cpu = @import("asm").cpu;

const constants = @import("mirai").crimson.constants;
const context = @import("mirai").crimson.context;
const types = @import("mirai").crimson.types;

const math = @import("utils").math;

const limits = constants.limits;
const sizes = common.constants.memory.sizes;

const Corpse = types.corpse.Corpse;
const DebugState = types.flavor.DebugState;
const Exception = types.exception.Exception;
const FloatState = types.flavor.FloatState;

pub fn generate(exception: *const Exception) Corpse {
    var corpse: Corpse = undefined;
    corpse.clear();

    corpse.KataId = exception.KataId;
    corpse.ThreadId = exception.ThreadId;
    corpse.ExceptionType = exception.ExceptionType;
    corpse.ExceptionCode = exception.Code;
    corpse.ExceptionSubcode = exception.Subcode;
    corpse.FaultAddress = exception.Address;

    corpse.Context = exception.Context.*;

    captureFloatState(&corpse.FloatState);
    captureDebugState(&corpse.DebugState);

    captureStackSnapshot(&corpse, exception.Context.RSP);

    if (exception.Address != 0) {
        captureMemorySnapshot(&corpse, exception.Address);
    }

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

fn captureStackSnapshot(corpse: *Corpse, rsp: u64) void {
    if (rsp == 0) {
        corpse.StackSnapshotSize = 0;
        return;
    }

    const stack_pointer: [*]const u8 = @ptrFromInt(rsp);
    @memcpy(corpse.StackSnapshot[0..limits.SNAPSHOT_SIZE], stack_pointer[0..limits.SNAPSHOT_SIZE]);
    corpse.StackSnapshotSize = limits.SNAPSHOT_SIZE;
}

fn captureMemorySnapshot(corpse: *Corpse, address: u64) void {
    const page_start = math.integer.alignDown(address, sizes.PAGE_SIZE);
    const offset = address - page_start;

    const half_snapshot = limits.SNAPSHOT_SIZE / 2;
    const start = if (offset >= half_snapshot) address - half_snapshot else page_start;

    const memory_pointer: [*]const u8 = @ptrFromInt(start);
    @memcpy(corpse.MemorySnapshot[0..limits.SNAPSHOT_SIZE], memory_pointer[0..limits.SNAPSHOT_SIZE]);
    corpse.MemorySnapshotAddress = start;
    corpse.MemorySnapshotSize = limits.SNAPSHOT_SIZE;
}
