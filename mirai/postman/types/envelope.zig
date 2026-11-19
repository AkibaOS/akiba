//! Stable Copied Letter Header And Owner Membership

const limits = @import("mirai").postman.constants.limits;

const Header = @import("mirai").postman.types.letter.Header;
const Lease = @import("mirai").postman.types.lease.Lease;
const Mailbox = @import("mirai").postman.types.mailbox.Mailbox;
const Record = @import("mirai").postman.types.record.Record;
const Status = @import("mirai").postman.types.status.Status;

pub const Envelope = struct {
    Status: Status = .Free,
    Next: ?*Envelope = null,
    Previous: ?*Envelope = null,
    Queued: bool = false,
    SourcePrevious: ?*Envelope = null,
    SourceNext: ?*Envelope = null,
    HeldPrevious: ?*Envelope = null,
    HeldNext: ?*Envelope = null,
    Source: ?*Mailbox = null,
    Destination: ?*Mailbox = null,
    Client: ?*Record = null,
    Receiver: ?*Record = null,
    Ticket: u64 = 0,
    Lease: ?Lease = null,
    Header: Header = .{ .Sender = 0, .Type = 0, .Length = 0, .ReplyTicket = 0 },
    Payload: *[limits.MAX_PAYLOAD_BYTES]u8,
};
