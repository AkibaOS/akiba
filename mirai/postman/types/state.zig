//! Postman Fixed Storage

const katas = @import("mirai").kata.constants.pool;
const limits = @import("mirai").postman.constants.limits;
const threads = @import("mirai").thread.constants.pool;

const Envelope = @import("mirai").postman.types.envelope.Envelope;
const Mailbox = @import("mirai").postman.types.mailbox.Mailbox;
const Record = @import("mirai").postman.types.record.Record;

pub const State = struct {
    Mailboxes: [katas.MAX_KATAS]Mailbox = [_]Mailbox{.{}} ** katas.MAX_KATAS,
    Records: [threads.MAX_THREADS]Record = [_]Record{.{}} ** threads.MAX_THREADS,
    Envelopes: [limits.MAX_ENVELOPES]Envelope = [_]Envelope{.{}} ** limits.MAX_ENVELOPES,
    NextTicket: u64 = 1,
    Initialized: bool = false,
};
