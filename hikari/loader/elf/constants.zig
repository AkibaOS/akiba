//! Hikari ELF Constants

pub const magic: [4]u8 = .{ 0x7F, 'E', 'L', 'F' };

pub const class_none: u8 = 0;
pub const class_32: u8 = 1;
pub const class_64: u8 = 2;

pub const data_none: u8 = 0;
pub const data_little_endian: u8 = 1;
pub const data_big_endian: u8 = 2;

pub const version_none: u8 = 0;
pub const version_current: u8 = 1;

pub const osabi_none: u8 = 0;
pub const osabi_sysv: u8 = 0;
pub const osabi_linux: u8 = 3;
pub const osabi_freebsd: u8 = 9;
pub const osabi_standalone: u8 = 255;

pub const type_none: u16 = 0;
pub const type_relocatable: u16 = 1;
pub const type_executable: u16 = 2;
pub const type_shared: u16 = 3;
pub const type_core: u16 = 4;

pub const machine_none: u16 = 0;
pub const machine_386: u16 = 3;
pub const machine_x86_64: u16 = 62;
pub const machine_aarch64: u16 = 183;
pub const machine_riscv: u16 = 243;

pub const segment_null: u32 = 0;
pub const segment_load: u32 = 1;
pub const segment_dynamic: u32 = 2;
pub const segment_interp: u32 = 3;
pub const segment_note: u32 = 4;
pub const segment_shlib: u32 = 5;
pub const segment_phdr: u32 = 6;
pub const segment_tls: u32 = 7;
pub const segment_gnu_eh_frame: u32 = 0x6474E550;
pub const segment_gnu_stack: u32 = 0x6474E551;
pub const segment_gnu_relro: u32 = 0x6474E552;

pub const segment_flag_execute: u32 = 0x1;
pub const segment_flag_write: u32 = 0x2;
pub const segment_flag_read: u32 = 0x4;

pub const section_null: u32 = 0;
pub const section_progbits: u32 = 1;
pub const section_symtab: u32 = 2;
pub const section_strtab: u32 = 3;
pub const section_rela: u32 = 4;
pub const section_hash: u32 = 5;
pub const section_dynamic: u32 = 6;
pub const section_note: u32 = 7;
pub const section_nobits: u32 = 8;
pub const section_rel: u32 = 9;
pub const section_shlib: u32 = 10;
pub const section_dynsym: u32 = 11;
pub const section_init_array: u32 = 14;
pub const section_fini_array: u32 = 15;
pub const section_preinit_array: u32 = 16;
pub const section_group: u32 = 17;
pub const section_symtab_shndx: u32 = 18;

pub const section_flag_write: u64 = 0x1;
pub const section_flag_alloc: u64 = 0x2;
pub const section_flag_execinstr: u64 = 0x4;
pub const section_flag_merge: u64 = 0x10;
pub const section_flag_strings: u64 = 0x20;
pub const section_flag_info_link: u64 = 0x40;
pub const section_flag_link_order: u64 = 0x80;
pub const section_flag_os_nonconforming: u64 = 0x100;
pub const section_flag_group: u64 = 0x200;
pub const section_flag_tls: u64 = 0x400;

pub const section_index_undefined: u16 = 0;
pub const section_index_abs: u16 = 0xFFF1;
pub const section_index_common: u16 = 0xFFF2;

pub const elf64_header_size: usize = 64;
pub const elf64_program_header_size: usize = 56;
pub const elf64_section_header_size: usize = 64;
