//! Bounded Crimson Corpse Capture And Pool Checks

const crimson = @import("mirai").crimson;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.crimson;
const labels = @import("tests").guest.strings.crimson;
const verify = @import("tests").guest.support.verify;

const Context = crimson.types.context.frame.Context;
const Corpse = crimson.types.corpse.snapshot.Corpse;
const Exception = crimson.types.exception.Exception;
const Frame = crimson.types.frame.Frame;

pub fn run() void {
    const flags = guard.acquire();
    defer guard.release(flags);
    var context = Context{ .RAX = inputs.CONTEXT_RAX, .CR2 = inputs.FAULT_ADDRESS };
    var frame: Frame = undefined;
    const exception = Exception{
        .ExceptionType = .Breach,
        .Code = inputs.EXCEPTION_CODE,
        .Subcode = 0,
        .Vector = 14,
        .Address = inputs.FAULT_ADDRESS,
        .Context = &context,
        .Frame = &frame,
        .KataId = inputs.KATA_ID,
        .ThreadId = inputs.THREAD_ID,
        .Recoverable = false,
    };
    verify.require(@alignOf(crimson.types.flavor.FloatState) >= 16 and
        @sizeOf(crimson.types.flavor.FloatState) == 512, labels.FLOAT_ALIGNMENT);
    const corpse = crimson.corpse.generate.generate(&exception);
    context.RAX = 0;
    verify.require(corpse.isValid() and corpse.KataId == inputs.KATA_ID and corpse.ThreadId == inputs.THREAD_ID and
        corpse.ExceptionType == .Breach and corpse.ExceptionCode == inputs.EXCEPTION_CODE and
        corpse.FaultAddress == inputs.FAULT_ADDRESS and corpse.Context.RAX == inputs.CONTEXT_RAX and
        corpse.Context.CR2 == inputs.FAULT_ADDRESS and corpse.Timestamp != 0, labels.CORPSE_COPY);
    verify.require(corpse.StackSnapshotSize == 0 and corpse.MemorySnapshotSize == 0 and corpse.MemorySnapshotAddress == 0 and
        crimson.corpse.inspect.getStackSnapshot(&corpse).len == 0 and
        crimson.corpse.inspect.getMemorySnapshot(&corpse).len == 0, labels.CORPSE_BOUNDS);
    pool();
}

fn pool() void {
    const release = crimson.corpse.release;
    verify.require(release.getActiveCount() == 0, labels.CORPSE_POOL);
    var entries: [crimson.constants.limits.MAX_CORPSES]*Corpse = undefined;
    var count: usize = 0;
    defer for (entries[0..count]) |entry| release.release(entry);
    for (&entries, 0..) |*slot, index| {
        slot.* = release.allocate() orelse {
            verify.require(false, labels.CORPSE_POOL);
            unreachable;
        };
        count += 1;
        slot.*.KataId = inputs.KATA_ID;
        slot.*.ThreadId = inputs.THREAD_ID;
        var unique = true;
        for (entries[0..index]) |previous| unique = unique and previous != slot.*;
        verify.require(unique and !slot.*.isValid() and slot.*.StackSnapshotSize == 0 and slot.*.MemorySnapshotSize == 0 and
            release.getActiveCount() == index + 1, labels.CORPSE_POOL);
    }
    verify.require(release.allocate() == null and release.getActiveCount() == entries.len, labels.CORPSE_POOL);
    const first = entries[0];
    first.markValid();
    release.release(first);
    const reused = release.allocate().?;
    entries[0] = reused;
    reused.KataId = inputs.KATA_ID;
    verify.require(reused == first and !reused.isValid() and reused.StackSnapshotSize == 0 and
        release.getActiveCount() == entries.len, labels.CORPSE_REUSE);
    release.releaseAllForKata(inputs.KATA_ID);
    count = 0;
    verify.require(release.getActiveCount() == 0, labels.CORPSE_POOL);
}
