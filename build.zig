const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const zstbi = b.addModule("root", .{
        .root_source_file = b.path("src/zstbi.zig"),
    });

    zstbi.addIncludePath(b.path("libs/stbi"));

    if (target.result.os.tag == .emscripten) {
        // Zig 0.17 no longer exposes the --sysroot flag to build.zig, so the
        // emscripten sysroot is taken from the EMSCRIPTEN_SYSROOT env var.
        if (b.graph.environ_map.get("EMSCRIPTEN_SYSROOT")) |sysroot| {
            const include_path = std.fs.path.join(b.allocator, &.{ sysroot, "include" }) catch @panic("OOM");
            zstbi.addIncludePath(.{ .cwd_relative = include_path });
        }
    }
    if (optimize == .debug) {
        // TODO: Workaround for Zig bug.
        zstbi.addCSourceFile(.{
            .file = b.path("src/zstbi.c"),
            .flags = &.{
                "-std=c99",
                "-fno-sanitize=undefined",
                "-g",
                "-O0",
            },
        });
    } else {
        zstbi.addCSourceFile(.{
            .file = b.path("src/zstbi.c"),
            .flags = &.{
                "-std=c99",
                "-fno-sanitize=undefined",
            },
        });
    }
    zstbi.link_libc = true;

    const test_step = b.step("test", "Run zstbi tests");

    const tests = b.addTest(.{
        .name = "zstbi-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zstbi.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    tests.root_module.addImport("zstbi", zstbi);
    b.installArtifact(tests);

    test_step.dependOn(&b.addRunArtifact(tests).step);
}
