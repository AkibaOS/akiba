//! Independent Installed Bundle Shape And Manifest Fixtures

pub const DESCRIPTOR = "bundle version=1 abi=2 type=cli\n";
pub const DRIVER =
    \\bundle version=1 abi=2 type=cli type=driver {
    \\    provides keyboard version=1
    \\    matches "ps2.keyboard"
    \\}
;
pub const GUI = "bundle version=1 abi=2 type=gui\n";
pub const MISSING_TYPE = "bundle version=1 abi=2\n";
pub const UNKNOWN_TYPE = "bundle version=1 abi=2 type=kernel\n";
pub const UNSUPPORTED_VERSION = "bundle version=2 abi=2 type=cli\n";
pub const UNSUPPORTED_ABI = "bundle version=1 abi=3 type=cli\n";
pub const ESCAPE = "bundle version=1 abi=2 type=cli { executable \"../binary\"; }";
pub const DUPLICATE_MATCH = "bundle version=1 abi=2 type=driver { matches \"ps2.keyboard\"; matches \"ps2.keyboard\"; }";
pub const OTHER_ARCH = "not an executable image";

pub const BINARY_MEMBER = "binary";
pub const MANIFEST_MEMBER = "bundle.world";
pub const CHECK_NAME = "schema-check";
pub const CHECK_MANIFEST = "system/binaries/schema-check.akiba/bundle.world";
pub const CHECK_BINARY = "system/binaries/schema-check.akiba/binary";
pub const CHECK_MISSING = "system/binaries/schema-check.akiba/missing";
pub const CHECK_PARENT = "system/binaries/schema-check.akiba";
pub const CHECK_PATH = "source/" ++ CHECK_PARENT;
pub const CHECK_MANIFEST_SOURCE = "source/" ++ CHECK_MANIFEST;
pub const CHECK_BINARY_SOURCE = "source/" ++ CHECK_BINARY;
pub const DRIVER_PATH = "source/system/drivers/alternate.driver";
pub const DRIVER_MANIFEST = DRIVER_PATH ++ "/bundle.world";
pub const DRIVER_BINARY = DRIVER_PATH ++ "/binary";
pub const DRIVER_ROOT_FILE = "source/system/drivers/loose.driver";
pub const WRONG_PATH = "source/system/drivers/wrong.driver";
pub const WRONG_MANIFEST = WRONG_PATH ++ "/bundle.world";
pub const WRONG_BINARY = WRONG_PATH ++ "/binary";
pub const ABSENT_PATH = "source/system/binaries/absent.akiba";
pub const ABSENT_MANIFEST = ABSENT_PATH ++ "/bundle.world";
pub const GUI_PATH = "source/system/binaries/window.akiba";
pub const GUI_MANIFEST = GUI_PATH ++ "/bundle.world";
pub const GUI_BINARY = GUI_PATH ++ "/binary";
pub const CORRUPT_PATH = "source/system/binaries/corrupt.akiba";
pub const CORRUPT_MANIFEST = CORRUPT_PATH ++ "/bundle.world";
pub const CORRUPT_BINARY = CORRUPT_PATH ++ "/binary";
pub const LOOSE_ORDINARY = "source/system/binaries/raw";
pub const WRONG_ID = "wrong";
pub const ALTERNATE_ID = "alternate";
pub const ABSENT_ID = "absent";
pub const GUI_ID = "window";
pub const CORRUPT_ID = "corrupt";
pub const LOOSE_ID = "raw";
pub const LOOSE_DRIVER_ID = "loose";
