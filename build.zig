const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    //const lib = b.addStaticLibrary("typesafejson", "src/main.zig");
    //lib.setBuildMode(mode);
    //lib.install();

    var tjp_tests = b.addTest("src/tjp.zig");
    var unmarshal_tests = b.addTest("src/unmarshal.zig");
    tjp_tests.setBuildMode(mode);
    unmarshal_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&tjp_tests.step);
    test_step.dependOn(&unmarshal_tests.step);
}
