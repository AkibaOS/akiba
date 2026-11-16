//! Kata Retention Regression Labels

pub const GROUP = "CHECK GROUP Outcome retention\n";

pub const RACE_WINDOW = "completion interposition runs after observer registration and before any wait queue insertion";
pub const RACE_COLLECT = "target completion and owner collection retain the registered not-yet-queued observer";
pub const RACE_RETURN = "registered observer progresses immediately after completion before blocking";
pub const RACE_RELEASE = "registration-before-block completion releases target and observer ownership completely";
pub const CALLER = "Kata retention fixtures run from the live kernel owner";
pub const WAIT_INVALID = "completion wait rejects an unknown Kata ID";
pub const WAIT_BORN = "completion wait rejects an unpublished Born Kata";
pub const WAIT_SELF = "completion wait rejects the current Kata";
pub const WAIT_RECLAIMED = "already-reclaimed completion wait returns its copied result without queuing";
pub const OBSERVERS = "two real completion waiters retain independent observer registrations";
pub const IMMUTABLE = "committed reclaimed outcome rejects replacement";
pub const COLLECT_RETAINED = "owner collection retains the copied outcome for both registered observers";
pub const OBSERVERS_RELEASE = "both observers receive their copies and release collected completion storage";
pub const CAPACITY = "completion capacity rejects creation before allocating a PML4";
pub const CAPACITY_RECOVERY = "Born abort restores capacity and descriptor reuse gets a higher Kata ID";
pub const CAPACITY_UNWIND = "all capacity fixtures unwind to warmed PMM accounting";
pub const ADOPTION_KERNEL = "parent death adopts live children and retained results to the kernel";
pub const ADOPTION_PULSE = "Born Pulse designation adopts live children and retained results without adopting itself";
pub const ADOPTION_ROLLBACK = "Born Pulse abort restores kernel ownership and permits a fresh designation";
pub const ADOPTION_RESULTS = "live and retained child outcomes remain collectable after adoption rollback";
pub const PULSE_AVAILABLE = "Born Pulse retention case requires no existing Pulse and left that Pulse untouched";
pub const DRIVE_LIMIT = "Kata retention exceeded bounded scheduling after fixture cleanup";
pub const UNEXPECTED_RESUME = "retention target resumed without a satisfied predicate";
