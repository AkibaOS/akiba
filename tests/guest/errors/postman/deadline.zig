//! Timed Postman Guest Assertion Failures

pub const DeadlineError = error{
    CallDriveLimit,
    ActivityDriveLimit,
    InvalidDeadlineWinner,
    RetainedDeadline,
    UnexpectedTimeoutResult,
    RetainedTimedOutClient,
    UnexpectedLateReply,
    RetainedTimedOutLetter,
    TimedOutClientNotReady,
};
