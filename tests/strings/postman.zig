//! Persona Postman Regression Labels

pub const GROUP = "CHECK GROUP Postman Persona transport\n";
pub const COPIED_FIFO = "Postman Send copies bytes and Receive preserves FIFO headers and releases charges";
pub const EMPTY_LETTER = "Postman zero-length letters permit null payload pointers and consume once";
pub const SEND_REJECTIONS = "Postman invocation rejects invalid peers oversized payloads and invalid input without charges";
pub const QUEUE_CAPACITY = "Postman full queue rejects an extra letter and consumption restores capacity";
pub const RECEIVE_NONCONSUMPTION = "Postman invalid overlapping and too-small receive outputs preserve queued bytes and metadata";
pub const RECEIVE_HANDOFF = "Postman too-small awakened receiver wakes the next real receiver without another Send";
pub const CALL_DELIVERY = "Postman Call delivers copied request and holds source and destination charges while serving";
pub const TICKET_THREAD = "Postman reply ticket is bound to the receiving Thread rather than its sibling Kata membership";
pub const SERVING_BUSY = "Postman invalid reply ticket and Receive while serving preserve the delivered call";
pub const REPLY_ONESHOT = "Postman Reply copies bytes clears serving ownership and rejects ticket reuse while retaining charges";
pub const COLLECT_RETRY = "Postman pending calls and failed CollectReply outputs retain replies until one successful collection";
pub const CLOSE_WAKE = "Postman Close is idempotent wakes both blocked receivers and rejects later delivery";
pub const PEER_QUEUED = "Postman queued call reports PeerGone and releases charges after peer shutdown";
pub const PEER_DELIVERED = "Postman delivered call reports PeerGone when its serving peer shuts down";
pub const PEER_REPLIED = "Postman replied bytes remain collectable after peer shutdown with destination charge detached";
pub const CALLER_QUEUED = "Postman caller shutdown removes its queued call and releases destination charges";
pub const CALLER_DELIVERED = "Postman caller shutdown detaches a delivered call until the server observes PeerGone";
pub const CALLER_REPLIED = "Postman caller shutdown releases an uncollected reply and destination charge";
pub const ONEWAY_SURVIVES = "Postman queued one-way copy survives sender shutdown without a dangling source charge";
pub const CLEANUP = "Postman fixture completes and restores envelope mailbox record and completion ownership";
pub const DRIVE_LIMIT = "Postman Persona fixture exceeded bounded scheduling";
pub const CLEANUP_FAILED = "Postman fixture failed to dispose its owned Kata";
