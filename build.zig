const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    comptime {
        const current_zig = builtin.zig_version;
        const min_zig = std.SemanticVersion.parse("0.14.0") catch unreachable; // https://ziglang.org/download/0.14.0/release-notes.html
        if (current_zig.order(min_zig) == .lt) {
            @compileError(std.fmt.comptimePrint("Your Zig version v{} does not meet the minimum build requirement of v{}", .{ current_zig, min_zig }));
        }
    }

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Generate C bindings from extism.h using translateC
    const translate_c = b.addTranslateC(.{
        .root_source_file = .{ .cwd_relative = "/usr/local/include/extism.h" },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    // Create a module from the generated bindings
    const extism_c = translate_c.createModule();

    const extism_module = b.addModule("extism", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "extism_c", .module = extism_c },
        },
    });
    extism_module.addIncludePath(.{ .cwd_relative = "/usr/local/include" });
    extism_module.addLibraryPath(.{ .cwd_relative = "/usr/local/lib" });

    var tests = b.addTest(.{
        .name = "Library Tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    tests.root_module.addImport("extism", extism_module);
    tests.root_module.link_libc = true;
    tests.root_module.linkSystemLibrary("extism", .{});
    const tests_run_step = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&tests_run_step.step);

    var example = b.addExecutable(.{
        .name = "Example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/basic.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    example.root_module.addImport("extism", extism_module);
    example.linkLibC();
    example.linkSystemLibrary("extism");
    const example_run_step = b.addRunArtifact(example);

    const example_step = b.step("run_example", "Run the basic example");
    example_step.dependOn(&example_run_step.step);
}

pub fn addLibrary(to: *std.Build.Step.Compile, b: *std.Build) void {
    to.root_module.addImport("extism", b.dependency("extism", .{}).module("extism"));
    to.linkLibC();
    to.linkSystemLibrary("extism");
}
