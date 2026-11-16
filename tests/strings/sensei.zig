//! Scheduler Regression Labels

pub const GROUP = "CHECK GROUP Sensei scheduling\n";

pub const ADMISSION_FIFO = "Sensei appends newly admitted Threads in FIFO order";
pub const ADMISSION_DUPLICATE = "Sensei duplicate admission preserves the ready queue";
pub const DETACH = "Sensei detaches a nonlast ready Thread and releases its record";
pub const DETACH_REJECTION = "Sensei rejects duplicate detach and withdrawal of the last live Thread";
pub const RETIREMENT = "Sensei retires completed Threads off CPU and restores fixture registration count";
pub const WAIT_IMMEDIATE = "Sensei satisfied predicates return without joining their wait queue";
pub const WAIT_YIELD = "Sensei cooperative yields resume real managed Threads with ready peers";
pub const WAIT_BLOCK = "Sensei unsatisfied predicates block both real Threads";
pub const WAIT_OLDEST = "Sensei wakes the oldest waiter once without duplicate ready insertion";
pub const WAIT_RECHECK = "Sensei woken false predicate rechecks and rejoins the wait queue tail";
pub const WAIT_ALL = "Sensei wake-all moves every waiter into ready state";
pub const WAIT_REBLOCK = "Sensei wake-all does not bypass false predicates";
pub const WAIT_COMPLETE = "Sensei opened predicates resume both waiters and retire their owner";
pub const WAIT_RELEASE = "Sensei empty wakes are no-ops after waiter and completion cleanup";
pub const DEFERRAL_DEPTH = "Sensei nested preemption disable rejects cooperative yield";
pub const DEFERRAL_INNER = "Sensei inner preemption enable retains a pending scheduling request";
pub const DEFERRAL_OUTER = "Sensei outer preemption enable with interrupts disabled does not dispatch";
pub const DEFERRAL_RELEASE = "Sensei deferred work completes after safe scheduling resumes";
pub const DRIVE_LIMIT = "Sensei fixture exceeded bounded scheduling after resource cleanup";
pub const CLEANUP_FAILED = "Sensei fixture cleanup did not release its owner";
