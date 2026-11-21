//! Timed Postman Guest Assertion Failures

pub const DeadlineError = error{
    DeadlineDidNotWake,
    InvalidDeadlineWinner,
    RetainedDeadline,
    UnexpectedTimeoutResult,
    RetainedTimedOutClient,
    UnexpectedLateReply,
    RetainedTimedOutLetter,
    TimedOutClientNotReady,
};
