//! sysinfo - System information display

const colors = @import("colors");
const datetime = @import("datetime");
const format = @import("format");
const io = @import("io");
const os = @import("os");
const params = @import("params");
const sys = @import("sys");

const LOGO = [_][]const u8{
    "+---------------+",
    "|   A K I B A   |",
    "+---------------+",
};

const LOGO_WIDTH = 17;
const GAP = 4;

var version_buf: [64]u8 = undefined;
var cpu_buf: [64]u8 = undefined;

export fn main(pc: u32, pv: [*]const [*:0]const u8) u8 {
    _ = pc;
    _ = pv;

    display();
    return 0;
}

fn display() void {
    // Collect all info first
    const cpu_str = os.cpuinfo(&cpu_buf) orelse "Unknown";

    var mem_str_buf: [32]u8 = undefined;
    var mem_str: []const u8 = "Unknown";
    if (os.meminfo()) |mem| {
        mem_str = formatMemory(mem.used, mem.total, &mem_str_buf);
    }

    var disk_str_buf: [32]u8 = undefined;
    var disk_str: []const u8 = "Unknown";
    if (os.diskinfo()) |disk| {
        disk_str = formatMemory(disk.used, disk.total, &disk_str_buf);
    }

    var kernel_str_buf: [64]u8 = undefined;
    const version = readVersion();
    const kernel_str = concat(&kernel_str_buf, "Mirai ", version);

    var uptime_str_buf: [32]u8 = undefined;
    var uptime_str: []const u8 = "Unknown";
    if (os.uptime()) |secs| {
        uptime_str = datetime.formatDuration(secs, &uptime_str_buf);
    }

    var bin_entries: [64]io.StackEntry = undefined;
    const bin_count = io.viewstack("/binaries", &bin_entries) catch 0;
    var bin_count_buf: [16]u8 = undefined;
    const bin_count_str = format.intToStr(bin_count, &bin_count_buf);

    var lib_entries: [64]io.StackEntry = undefined;
    const lib_count = io.viewstack("/system/libraries", &lib_entries) catch 0;
    var lib_count_buf: [16]u8 = undefined;
    const lib_count_str = format.intToStr(lib_count, &lib_count_buf);

    var time_str_buf: [32]u8 = undefined;
    var time_str: []const u8 = "Unknown";
    if (datetime.now()) |timestamp| {
        time_str = datetime.formatDate(timestamp, &time_str_buf);
    }

    // Line 0: logo + Hardware header
    printLogo(0);
    printGap();
    format.colorln("------- Hardware --------", colors.cyan);

    // Line 1: logo + Device
    printLogo(1);
    printGap();
    printField("Device", "x86_64 QEMU");

    // Line 2: logo + CPU
    printLogo(2);
    printGap();
    printField("CPU", cpu_str);

    // Line 3: RAM
    printLogoSpace();
    printGap();
    printField("RAM", mem_str);

    // Line 4: Disk
    printLogoSpace();
    printGap();
    printField("Disk", disk_str);

    // Line 5: empty
    format.print("\n");

    // Line 6: System header
    printLogoSpace();
    printGap();
    format.colorln("------- System ----------", colors.cyan);

    // Line 7: OS
    printLogoSpace();
    printGap();
    printField("OS", "Akiba");

    // Line 8: Kernel
    printLogoSpace();
    printGap();
    printField("Kernel", kernel_str);

    // Line 9: Terminal
    printLogoSpace();
    printGap();
    printField("Terminal", "Akiba Terminal");

    // Line 10: Uptime
    printLogoSpace();
    printGap();
    printField("Uptime", uptime_str);

    // Line 11: empty
    format.print("\n");

    // Line 12: Environment header
    printLogoSpace();
    printGap();
    format.colorln("------- Environment -----", colors.cyan);

    // Line 13: Shell
    printLogoSpace();
    printGap();
    printField("Shell", "Ash");

    // Line 14: Binaries
    printLogoSpace();
    printGap();
    printField("Binaries", bin_count_str);

    // Line 15: Libraries
    printLogoSpace();
    printGap();
    printField("Libraries", lib_count_str);

    // Line 16: empty
    format.print("\n");

    // Line 17: Time header
    printLogoSpace();
    printGap();
    format.colorln("------- Time ------------", colors.cyan);

    // Line 18: Current
    printLogoSpace();
    printGap();
    printField("Current", time_str);
}

fn printLogo(line: usize) void {
    if (line < LOGO.len) {
        format.color(LOGO[line], colors.yellow);
    } else {
        printLogoSpace();
    }
}

fn printLogoSpace() void {
    var i: usize = 0;
    while (i < LOGO_WIDTH) : (i += 1) {
        format.print(" ");
    }
}

fn printGap() void {
    var i: usize = 0;
    while (i < GAP) : (i += 1) {
        format.print(" ");
    }
}

fn printField(label: []const u8, value: []const u8) void {
    format.color(label, colors.green);

    var padding: usize = if (label.len < 12) 12 - label.len else 1;
    while (padding > 0) : (padding -= 1) {
        format.print(" ");
    }

    format.println(value);
}

fn readVersion() []const u8 {
    const fd = io.attach("/system/akiba/mirai.version", io.VIEW_ONLY) catch {
        return "Unknown";
    };

    const len = io.view(fd, &version_buf) catch {
        io.seal(fd);
        return "Unknown";
    };

    io.seal(fd);

    var end = len;
    while (end > 0 and (version_buf[end - 1] == '\n' or version_buf[end - 1] == '\r')) {
        end -= 1;
    }

    if (end == 0) return "Unknown";
    return version_buf[0..end];
}

fn formatMemory(used: u64, total: u64, buf: []u8) []const u8 {
    var pos: usize = 0;

    var used_buf: [16]u8 = undefined;
    const used_str = format.formatBytes(used, &used_buf);
    for (used_str) |c| {
        if (pos >= buf.len) break;
        buf[pos] = c;
        pos += 1;
    }

    const sep = " / ";
    for (sep) |c| {
        if (pos >= buf.len) break;
        buf[pos] = c;
        pos += 1;
    }

    var total_buf: [16]u8 = undefined;
    const total_str = format.formatBytes(total, &total_buf);
    for (total_str) |c| {
        if (pos >= buf.len) break;
        buf[pos] = c;
        pos += 1;
    }

    return buf[0..pos];
}

fn concat(buf: []u8, a: []const u8, b: []const u8) []const u8 {
    var pos: usize = 0;

    for (a) |c| {
        if (pos >= buf.len) break;
        buf[pos] = c;
        pos += 1;
    }

    for (b) |c| {
        if (pos >= buf.len) break;
        buf[pos] = c;
        pos += 1;
    }

    return buf[0..pos];
}
