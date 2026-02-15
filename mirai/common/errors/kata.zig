//! Kata errors

pub const KataError = error{
    TooManyKatas,
    KataNotFound,
    InvalidState,
    NotChild,
    WaitingSelf,
};
