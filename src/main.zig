const std = @import("std");
const testing = std.testing;
const json = std.json;
const ArrayList = std.ArrayList;
const math = std.math;
const TypeInfo = @import("builtin").TypeInfo;

const TSJE = error{
    JSONMissingObjectField,
    JSONExpectedObject,
    JSONExpectedBool,
    JSONIntegerOutOfRange,
    JSONExpectedInt,
    JSONBadType,
    JSONExpectedNumber,
    JSONExpectedNull,
    JSONArrayWrongLength,
    JSONExpectedArray,
};

fn i64InIntegerRange(comptime int_type: TypeInfo.Int, value: i64) bool {
    return true;
}

fn is_optional(comptime T: type) bool {
    switch (@typeInfo(T)) {
        .Optional => return true,
        else => return false,
    }
}

fn tsjson_optional(comptime T: type, value: json.Value) TSJE!?T {
    // Things seem to get confused badly if you mix up TSJE!T and TSJE!?T so we need to be careful here.
    if (tsjson(T, value)) |val| {
        return val;
    } else |err| {
        return err;
    }
}

fn tsjson_array(comptime T: type, comptime array_type: TypeInfo.Array, value: json.Value) TSJE!T {
    switch (value) {
        .Array => |array| {
            if (array.count() == array_type.len) {
                var ret: T = undefined;
                for (array.toSlice()) |val, i| {
                    ret[i] = try tsjson(array_type.child, val);
                }
                return ret;
            } else {
                return error.JSONArrayWrongLength;
            }
        },
        else => return error.JSONExpectedArray,
    }
}

fn tsjson_struct(comptime T: type, comptime struct_type: TypeInfo.Struct, value: json.Value) TSJE!T {
    std.debug.warn("Got here\n");
    switch (value) {
        .Object => |o| {
            // Hopefully this is safe as we either assign to all the fields of ret *or* return an error instead.
            // The "undefined" docs are not 100% clear though so this could be undefined behaviour? We're still using a partially initialised value (but only assigning until all fields are assigned).
            var ret: T = undefined;
            var any_missing = false;
            inline for (struct_type.fields) |field| {
                if (o.getValue(field.name)) |val| {
                    @field(ret, field.name) = try tsjson(field.field_type, val);
                } else {
                    if (comptime is_optional(field.field_type)) {
                        //@field(ret, field.name) = null;
                    } else {
                        // Ideally we'd just return directly here, but doing so hits a compiler bug.
                        // Returning after the inline for loop instead works though.
                        //return error.JSONMissingObjectField;
                        any_missing = true;
                        std.debug.warn("{}", field.name);
                    }
                }
                std.debug.warn("{}\n", o.getValue(field.name));
            }
            if (any_missing) {
                return error.JSONMissingObjectField;
            }
            return ret;
        },
        else => return error.JSONExpectedObject,
    }
}

// There seems to be some bug with returning an error from some switch branches.
// This forces it to be interpreted as an error union not just an error.
fn badType(comptime T: type) TSJE!T {
    return error.JSONBadType;
}

fn tsjson(comptime T: type, value: json.Value) TSJE!T {
    std.debug.warn("Actually running tsjson {}\n", value);
    const type_info = @typeInfo(T);
    return switch (type_info) {
        .Bool => switch (value) {
            .Bool => |b| b,
            else => error.JSONExpectedBool,
        },
        .Int => |int_type| switch (value) {
            .Integer => |i| blk: {
                if (!i64InIntegerRange(int_type, i)) {
                    break :blk error.JSONIntegerOutOfRange;
                } else {
                    break :blk @intCast(T, i);
                }
            },
            .Float => |f| blk: {
                // This is a little questionable but sometimes std.json seems to make ints into floats so this helps.
                if (math.floor(f) == f) {
                    break :blk @floatToInt(T, f);
                } else {
                    break :blk error.JSONExpectedInt;
                }
            },
            else => error.JSONExpectedInt,
        },
        .Float => |float_type| switch (value) {
            .Integer => |i| @intToFloat(T, i),
            // TODO Maybe check floats for precision loss?
            .Float => |f| @floatCast(T, f),
            else => error.JSONExpectedNumber,
        },
        .Array => |array_type| tsjson_array(T, array_type, value),
        .Struct => |struct_type| tsjson_struct(T, struct_type, value),
        .Optional => |optional_type| tsjson_optional(optional_type.child, value),
        else => badType(T),
    };
}

const Nested = struct {
    foo: bool = false,
    bar: i64 = 0,
    baz: i64 = 12,
    opt: ?i32,
    flt: f32,
    iflt: f32,
    arr: [3]i32,
};

const TestStruct = struct {
    foo: bool = false,
    bar: i64 = 0,
    baz: i64 = 12,
    opt: ?i32,
    flt: f32,
    iflt: f32,
    arr: [3]f32,
    nested: Nested,
};

pub fn main() !void {
    std.debug.warn("Actually running test\n");
    var p = json.Parser.init(std.debug.global_allocator, false);
    defer p.deinit();

    const s = "{\"foo\": true, \"barz\": 1}";

    var tree = try p.parse(s);
    defer tree.deinit();

    //var result = try tsjson(TestStruct, tree);
    var result = try tsjson(TestStruct, tree.root);
    std.debug.warn("\n{}\n", result);
}

test "basic add functionality" {
    std.debug.warn("Actually running test\n");
    var p = json.Parser.init(std.debug.global_allocator, false);
    defer p.deinit();

    const s = "{\"foo\": true, \"bar\": 1, \"baz\": 2, \"opt\": 3, \"flt\": 2.3, \"iflt\": 1, \"arr\": [1, 2, 3], \"nested\": {\"foo\": true, \"bar\": 1, \"baz\": 2, \"opt\": 3, \"flt\": 2.3, \"iflt\": 1, \"arr\": [1, 2, 3]}}";

    var tree = try p.parse(s);
    defer tree.deinit();

    var result = try tsjson(TestStruct, tree.root);
    std.debug.warn("\n{}\n", result);
}

const TestStruct2 = struct {
    image: Image,
};

const Image = struct {
    width: i32,
    height: i32,
    title: []const u8,
    thumbnail: Thumbnail,
    animated: bool,
    ids: ArrayList(i32),
    double: f64,
};

const Thumbnail = struct {
    url: []const u8,
    height: i32,
    width: i32,
};
