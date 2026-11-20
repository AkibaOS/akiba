//! GPT Integrity And Identity Refusals

pub const VerifyError = error{
    AmbiguousPartition,
    HeaderChecksum,
    InvalidHeader,
    InvalidTable,
    TableChecksum,
};
