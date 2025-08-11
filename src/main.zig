const std = @import("std");

const charset: []const u8 = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#$%^&*()-_=+[]{}<>/\\|?;:,.~";
const frame_ms: usize = 50;
const default_cols: usize = 80;
const default_rows: usize = 24;

const Column = struct {
    head: isize,
    length: usize,
    active: bool,
};

const TermSize = struct {
    cols: usize,
    rows: usize,

    fn init(args: struct {
        cols: usize = default_cols,
        rows: usize = default_rows,
    }) TermSize {
        return TermSize{
            .cols = args.cols,
            .rows = args.rows,
        };
    }
};

fn randChar(random: std.Random) u8 {
    const max_index = charset.len - 1;
    const index = random.intRangeAtMost(usize, 0, max_index);
    return charset[index];
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const stdout = std.io.getStdOut().writer();

    try stdout.writeAll("\x1b[2J\x1b[?251");

    var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const rand = prng.random();

    const size = TermSize.init(.{});

    var cols = try allocator.alloc(Column, size.cols);
    defer allocator.free(cols);

    for (0..size.cols) |i| {
        const head = rand.intRangeAtMost(isize, 0, @intCast(size.rows));
        cols[i] = Column{
            .head = -head,
            .length = rand.intRangeAtMost(usize, 4, 20),
            .active = true,
        };
    }

    var buf = std.ArrayList(u8).init(allocator);

    while (true) {
        buf.items.len = 0;

        try buf.appendSlice("\x1b[H");

        for (0..size.rows) |r| {
            for (0..size.cols) |c| {
                const col = cols[c];
                const R: isize = @intCast(r);
                const rel = R - col.head;
                const l: isize = @intCast(col.length);

                if (col.active and rel <= 0 and rel > -l) {
                    if (rel == 0) {
                        try buf.appendSlice("\x1b[97m");
                        try buf.append(randChar(rand));
                        try buf.appendSlice("\x1b[0m");
                    } else {
                        if (-rel > col.length / 2) {
                            try buf.appendSlice("\x1b[2;32m");
                        } else {
                            try buf.appendSlice("\x1b[32m");
                        }

                        try buf.append(randChar(rand));
                        try buf.appendSlice("\x1b[0m");
                    }
                } else {
                    try buf.appendSlice(" ");
                }
            }
            try buf.appendSlice("\n");
        }

        try stdout.writeAll(buf.items);

        for (0..size.cols) |j| {
            cols[j].head += 1;

            const l: isize = @intCast(cols[j].length);
            const rows: isize = @intCast(size.rows);

            if (cols[j].head - l > rows) {
                cols[j].head = -rand.intRangeAtMost(isize, 0, rows);
                cols[j].length = rand.intRangeAtMost(usize, 4, 20);
                cols[j].active = true;
            }
        }

        std.time.sleep(frame_ms * std.time.ns_per_ms);
    }
}
