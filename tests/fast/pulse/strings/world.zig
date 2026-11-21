//! World Parser And Dependency Fixtures

pub const VALID =
    \\// System services
    \\(system)service "provider" binary="old" binary = #"serviceprobe"# restart=1 enabled=true required=false control=true {
    \\    parameters (text)"provider";
    \\}
    \\service "consumer" binary="serviceprobe" { after "provider"; parameters "consumer"; }
;
pub const POSITION = "service binary=\"probe\" \"late\"\n";
pub const DUPLICATE = "service \"same\" binary=\"a\"\nservice \"same\" binary=\"b\"\n";
pub const CYCLE = "service \"a\" binary=\"x\" { after \"b\"; }\nservice \"b\" binary=\"x\" { after \"a\"; }\n";
pub const MISSING = "service \"a\" binary=\"x\" { after \"absent\"; }\n";
pub const KEYWORD = "service \"a\" binary=\"x\" enabled=#true\n";
pub const UNFINISHED = "service \"a\" binary=\"x\" { after \"b\"";
pub const MULTILINE =
    \\/* outer /* nested */ comment */
    \\/- service "unused" binary="ignored";
    \\service "provider" \
    \\  binary="serviceprobe" restart=0x1 enabled=false enabled=true {
    \\  parameters #"""
    \\    alpha
    \\    beta
    \\    """#;
    \\}
;
pub const UNICODE_SPACE = "\u{feff}service\u{a0}\"provider\" binary=\"serviceprobe\"\u{2028}";
pub const MULTILINE_VALUE = "alpha\nbeta";
pub const ADJACENT = "service\"provider\" binary=\"serviceprobe\"\n";
pub const PROVIDER = "provider";
pub const CONSUMER = "consumer";
pub const BINARY = "serviceprobe";
