//! AHCI Register Window And Status Fields

const sizes = @import("common").constants.memory.sizes;

pub const CAP = 0x00;
pub const GHC = 0x04;
pub const PORTS = 0x0c;
pub const CAP2 = 0x24;
pub const AHCI_ENABLE: u32 = 1 << 31;
pub const GLOBAL_INTERRUPT: u32 = 1 << 1;
pub const BIOS_HANDOFF: u32 = 1;
pub const PORT_NUMBER_MASK: u32 = 0x1f;
pub const PORT_BASE = 0x100;
pub const PORT_STRIDE = 0x80;
pub const MAPPED_PORTS = (sizes.PAGE_SIZE - PORT_BASE) / PORT_STRIDE;
pub const LIST = 0x00;
pub const LIST_HIGH = 0x04;
pub const FIS = 0x08;
pub const FIS_HIGH = 0x0c;
pub const INTERRUPT_STATUS = 0x10;
pub const INTERRUPT_ENABLE = 0x14;
pub const COMMAND = 0x18;
pub const TASK_FILE = 0x20;
pub const SIGNATURE = 0x24;
pub const LINK = 0x28;
pub const SATA_ERROR = 0x30;
pub const ACTIVE = 0x34;
pub const ISSUE = 0x38;

pub const START: u32 = 1;
pub const RECEIVE_FIS: u32 = 1 << 4;
pub const RUNNING_FIS: u32 = 1 << 14;
pub const RUNNING_COMMAND: u32 = 1 << 15;
pub const TASK_BUSY: u32 = (1 << 7) | (1 << 3);
pub const TASK_ERROR: u32 = 1;
pub const TRANSFER_ERROR: u32 = 0x7d000000;
pub const SLOT_ZERO: u32 = 1;
