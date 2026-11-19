//! Kernel Heap Regression Labels

pub const LARGE = "kernel allocations larger than one slab page are zeroed virtually contiguous RW NX and independently owned";
pub const FRAGMENTED = "virtually contiguous kernel allocation remains correct with fragmented physical backing";
pub const RELEASE = "large kernel allocations and ownership metadata return to the warmed physical baseline";
pub const ALIGNMENT = "kernel heap honors large alignments while preserving adjacent allocations";
pub const INVALID = "wrong-size interior foreign and duplicate heap frees preserve live mappings and data";
pub const PREFLIGHT = "heap release validates every payload mapping before freeing any owned frame";
pub const GEOMETRY = "invalid and overflowing kernel heap requests reject without allocating";
pub const FAILURE = "each partial heap allocation failure restores payload metadata extent mappings and search";
pub const RECOVERY = "failed heap construction leaves its virtual address and all backing reusable";
pub const ADAPTER = "standard allocator preserves alignment and contents across small large and reallocated blocks";
pub const ADAPTER_REFUSAL = "standard allocator explicitly refuses unsupported in-place resize and remap";
