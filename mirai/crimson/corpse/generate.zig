//! Generate Corpse

const asm_cpu = @import("asm").cpu;
const types = @import("../types/types.zig");
const context_ops = @import("../context/context.zig");

const Corpse = types.Corpse;
const Exception = types.Exception;
const Context = types.Context;
const FloatState = types.FloatState;
const DebugState = types.DebugState;
const Identity = types.Identity;

pub fn generate(exception: *const Exception) Corpse {
    var corpse: Corpse = undefined;
    corpse.clear();

    corpse.kata_id = exception.kata_id;
    corpse.thread_id = exception.thread_id;
    corpse.exception_type = exception.exception_type;
    corpse.exception_code = exception.code;
    corpse.exception_subcode = exception.subcode;
    corpse.fault_address = exception.address;

    corpse.context = exception.context.*;

    capture_float_state(&corpse.float_state);
    capture_debug_state(&corpse.debug_state);

    capture_stack_snapshot(&corpse, exception.context.rsp);

    if (exception.address != 0) {
        capture_memory_snapshot(&corpse, exception.address);
    }

    corpse.timestamp = asm_cpu.rdtsc();
    corpse.mark_valid();

    return corpse;
}

fn capture_float_state(state: *FloatState) void {
    context_ops.capture_float(state);
}

fn capture_debug_state(state: *DebugState) void {
    context_ops.capture_debug(state);
}

fn capture_stack_snapshot(corpse: *Corpse, rsp: u64) void {
    if (rsp == 0) {
        corpse.stack_snapshot_size = 0;
        return;
    }

    const stack_ptr: [*]const u8 = @ptrFromInt(rsp);
    const copy_size: usize = 4096;

    for (0..copy_size) |i| {
        corpse.stack_snapshot[i] = stack_ptr[i];
    }
    corpse.stack_snapshot_size = copy_size;
}

fn capture_memory_snapshot(corpse: *Corpse, address: u64) void {
    const page_start = address & ~@as(u64, 0xFFF);
    const offset = address - page_start;

    const start = if (offset >= 2048) address - 2048 else page_start;
    const copy_size: usize = 4096;

    const mem_ptr: [*]const u8 = @ptrFromInt(start);
    for (0..copy_size) |i| {
        corpse.memory_snapshot[i] = mem_ptr[i];
    }
    corpse.memory_snapshot_address = start;
    corpse.memory_snapshot_size = copy_size;
}
