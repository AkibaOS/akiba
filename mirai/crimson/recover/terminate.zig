//! Terminate Kata

const corpse = @import("mirai").crimson.corpse;
const serial = @import("mirai").drivers.serial;
const strings = @import("mirai").crimson.strings;
const types = @import("mirai").crimson.types;

const messages = strings.messages;

const Corpse = types.corpse.Corpse;
const Exception = types.exception.Exception;

pub fn terminate(exception: *const Exception) void {
    serial.write.printf(messages.TERMINATE_KATA_THREAD, .{
        exception.KataId,
        exception.ThreadId,
    });

    cleanupThread(exception.ThreadId);
    cleanupKataIfLast(exception.KataId);
}

pub fn terminateWithCorpse(exception: *const Exception) ?*Corpse {
    serial.write.printf(messages.TERMINATE_KATA_CORPSE, .{exception.KataId});

    const allocated = corpse.release.allocate();
    if (allocated) |new_corpse| {
        new_corpse.* = corpse.generate.generate(exception);
    }

    terminate(exception);

    return allocated;
}

fn cleanupThread(thread_id: u64) void {
    _ = thread_id;
}

fn cleanupKataIfLast(kata_id: u64) void {
    _ = kata_id;
}

pub fn isLastThread(kata_id: u64) bool {
    _ = kata_id;
    return true;
}
