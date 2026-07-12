//! Hikari GPT Parse Errors

pub const ParseError = error{
    ReadFailed,
    InvalidProtectiveMbr,
    InvalidSignature,
    InvalidRevision,
    InvalidHeaderSize,
    InvalidHeaderCRC,
    InvalidEntriesCRC,
    NoPartitions,
    PartitionNotFound,
};
