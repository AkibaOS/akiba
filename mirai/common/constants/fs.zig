//! Filesystem Constants - Storage, AFS, and stack/unit related constants

// ============================================================================
// Sector and Cluster Sizes
// ============================================================================

/// Standard disk sector size
pub const SECTOR_SIZE: usize = 512;

/// Standard cluster size for AFS
pub const CLUSTER_SIZE: usize = 4096;

/// Sectors per cluster
pub const SECTORS_PER_CLUSTER: usize = CLUSTER_SIZE / SECTOR_SIZE;

// ============================================================================
// AFS (Akiba File System) Constants
// ============================================================================

/// AFS magic number "AFS1"
pub const AFS_MAGIC: u32 = 0x31534641;

/// AFS version
pub const AFS_VERSION: u32 = 1;

/// Entry type: Unit (regular file)
pub const ENTRY_TYPE_UNIT: u8 = 0x01;

/// Entry type: Stack (directory)
pub const ENTRY_TYPE_STACK: u8 = 0x02;

/// Entry type: Link (symlink)
pub const ENTRY_TYPE_LINK: u8 = 0x03;

// ============================================================================
// Permission Types
// ============================================================================

/// Owner-only access
pub const PERM_OWNER: u8 = 1;

/// World-accessible
pub const PERM_WORLD: u8 = 2;

/// Read-only (immutable)
pub const PERM_READ_ONLY: u8 = 3;

// ============================================================================
// Attachment (File Descriptor) Flags
// ============================================================================

/// View (read) only access
pub const VIEW_ONLY: u32 = 0x01;

/// Mark (write) only access
pub const MARK_ONLY: u32 = 0x02;

/// Both view and mark access
pub const BOTH: u32 = 0x03;

/// Create unit if doesn't exist
pub const CREATE: u32 = 0x0100;

/// Clear (truncate) on attach
pub const CLEAR: u32 = 0x0200;

/// Extend (start at end) on attach
pub const EXTEND: u32 = 0x0400;
