const akiba = @import("akiba");

export fn _start() noreturn {
    akiba.io.println("Hello from Echo!") catch {};
    akiba.kata.exit(0);
}
