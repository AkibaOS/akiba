//! PIC I/O Ports

const common = @import("common");

const vectors = common.constants.interrupts.vectors;

pub const PIC1_COMMAND: u16 = 0x20;
pub const PIC1_DATA: u16 = 0x21;
pub const PIC2_COMMAND: u16 = 0xA0;
pub const PIC2_DATA: u16 = 0xA1;

pub const ICW1_ICW4: u8 = 0x01;
pub const ICW1_INIT: u8 = 0x10;
pub const ICW3_MASTER_SLAVE_ON_IRQ2: u8 = 0x04;
pub const ICW3_SLAVE_CASCADE_IDENTITY: u8 = 0x02;
pub const ICW4_8086: u8 = 0x01;

pub const EOI: u8 = 0x20;

pub const IRQS_PER_PIC: u8 = 8;

pub const VECTOR_OFFSET_MASTER: u8 = vectors.VECTOR_OFFSET;
pub const VECTOR_OFFSET_SLAVE: u8 = vectors.VECTOR_OFFSET + IRQS_PER_PIC;

pub const MASK_ALL: u8 = 0xFF;
pub const MASK_NONE: u8 = 0x00;
