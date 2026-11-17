//! Fixture Entry And Exit Instructions

pub const ENTRY = ".extern akiba_fixture_main\ncallq akiba_fixture_main\nud2";
pub const ENTRY_SECTION = ".text.fixture.entry";
pub const EXIT = "int $0x80\nud2";
