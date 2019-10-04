const std = @import("std");
const testing = std.testing;
const json = std.json;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
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
    JSONNoEnumForInteger,
    JSONExpectedIntOrEnumName,
    JSONBadEnumName,
    JSONUntaggedUnionNotSupported,
    JSONNoUnionTagName,
    JSONNoUnionValue,
    JSONArrayListError,
    JSONStringHashMapError,
};

fn i64InIntegerRange(comptime int_type: TypeInfo.Int, value: i64) bool {
    const actual_type = @Type(TypeInfo{ .Int = int_type });
    if (value < 0 and !int_type.is_signed) {
        return false;
    }
    if (int_type.bits >= 64) {
        return true;
    }
    if (value <= math.maxInt(actual_type)) {
        return true;
    }
    return false;
}

test "Test i64InIntegerRange" {
    testing.expect(!i64InIntegerRange(TypeInfo.Int{ .is_signed = false, .bits = 64 }, -1));
    testing.expect(i64InIntegerRange(TypeInfo.Int{ .is_signed = false, .bits = 63 }, math.maxInt(u63)));

    testing.expect(i64InIntegerRange(TypeInfo.Int{ .is_signed = true, .bits = 64 }, -1));
    testing.expect(i64InIntegerRange(TypeInfo.Int{ .is_signed = true, .bits = 128 }, -1));
    testing.expect(i64InIntegerRange(TypeInfo.Int{ .is_signed = true, .bits = 16 }, 1 << 15 - 1));
    testing.expect(!i64InIntegerRange(TypeInfo.Int{ .is_signed = true, .bits = 16 }, 1 << 15));
}

fn is_optional(comptime T: type) bool {
    switch (@typeInfo(T)) {
        .Optional => return true,
        else => return false,
    }
}

test "Test is_optional" {
    testing.expect(is_optional(?i32));
    testing.expect(!is_optional(i32));
}

// To find out if something is an ArrayList(S), we can just compare T == ArrayList(S)
// Due to comptime functions beind memoized, this will work.
// However, we need to find the item type. We do this by inspecting the items member of the ArrayList (if it is present) which is a slice of the item type.
// If it's not an ArrayList this will either not be present or not be a slice, so we need some careful programming.
// If ArrayList internals change this function will need updating, but the test will catch that.
fn is_arraylist(comptime T: type) ?type {
    const type_info = @typeInfo(T);
    const TypeInfoTag = @TagType(TypeInfo);
    if (TypeInfoTag(type_info) != TypeInfoTag.Struct) {
        return null;
    }
    comptime var has_items = false;
    comptime var item_type: type = undefined;
    inline for (type_info.Struct.fields) |field| {
        if (std.mem.eql(u8, field.name, "items")) {
            const fti = @typeInfo(field.field_type);
            if (TypeInfoTag(fti) == TypeInfoTag.Pointer and fti.Pointer.size == TypeInfo.Pointer.Size.Slice) {
                has_items = true;
                item_type = fti.Pointer.child;
            }
        }
    }
    if (!has_items) {
        return null;
    }
    if (T == ArrayList(item_type)) {
        return item_type;
    } else {
        return null;
    }
}

// As for ArrayList above, we need to inspect entries.kv.key/value for string/item type
fn is_stringhashmap(comptime T: type) ?type {
    const type_info = @typeInfo(T);
    const TypeInfoTag = @TagType(TypeInfo);
    if (TypeInfoTag(type_info) != TypeInfoTag.Struct) {
        return null;
    }
    comptime var has_entries = false;
    comptime var item_type: type = undefined;
    inline for (type_info.Struct.fields) |field| {
        if (std.mem.eql(u8, field.name, "entries")) {
            const fti = @typeInfo(field.field_type);
            if (TypeInfoTag(fti) == TypeInfoTag.Pointer and fti.Pointer.size == TypeInfo.Pointer.Size.Slice) {
                const entry_type = fti.Pointer.child;
                const eti = @typeInfo(entry_type);
                if (TypeInfoTag(eti) == TypeInfoTag.Struct) {
                    comptime var kv_type: type = undefined;
                    comptime var has_kv = false;
                    inline for (eti.Struct.fields) |efield| {
                        if (std.mem.eql(u8, efield.name, "kv")) {
                            kv_type = efield.field_type;
                            has_kv = true;
                        }
                    }
                    if (!has_kv) {
                        return null;
                    }
                    const kvti = @typeInfo(kv_type);
                    if (TypeInfoTag(kvti) == TypeInfoTag.Struct) {
                        comptime var has_k = false;
                        comptime var has_v = false;
                        comptime var v_type: type = undefined;
                        inline for (kvti.Struct.fields) |kvfield| {
                            if (std.mem.eql(u8, kvfield.name, "key") and kvfield.field_type == []const u8) {
                                has_k = true;
                            }
                            if (std.mem.eql(u8, kvfield.name, "value")) {
                                has_v = true;
                                v_type = kvfield.field_type;
                            }
                        }
                        if (has_k and has_v) {
                            item_type = v_type;
                            has_entries = true;
                        }
                    }
                }
            }
        }
    }
    if (!has_entries) {
        return null;
    }
    if (T == StringHashMap(item_type)) {
        return item_type;
    } else {
        return null;
    }
}

test "Test is_arraylist" {
    testing.expect(is_arraylist(ArrayList(i32)).? == i32);

    testing.expect(is_arraylist(i32) == null);
    testing.expect(is_arraylist([]i32) == null);
    testing.expect(is_arraylist(struct {
        items: []i32,
    }) == null);

    const SomeNamedType = ArrayList(i32);
    testing.expect(is_arraylist(SomeNamedType).? == i32);
    const SomeOtherNamedType = i32;
    testing.expect(is_arraylist(SomeOtherNamedType) == null);
}

test "Test is_stringhashmap" {
    testing.expect(is_stringhashmap(StringHashMap(i32)).? == i32);

    testing.expect(is_stringhashmap(i32) == null);
    testing.expect(is_stringhashmap(ArrayList(i32)) == null);
    testing.expect(is_stringhashmap(struct {
        entries: struct {
            kv: struct {
                key: i32,
                value: i32,
            },
        },
    }) == null);
    testing.expect(is_stringhashmap(struct {
        entries: struct {},
    }) == null);

    const SomeNamedType = StringHashMap(i32);
    testing.expect(is_stringhashmap(SomeNamedType).? == i32);
    const SomeOtherNamedType = i32;
    testing.expect(is_stringhashmap(SomeOtherNamedType) == null);
    const OtherHashMap = std.AutoHashMap(i32, i32);
    testing.expect(is_stringhashmap(OtherHashMap) == null);
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
    if (is_arraylist(T)) |item_type| {
        switch (value) {
            .Array => |a| {
                var ret = ArrayList(item_type).init(std.debug.global_allocator);
                for (a.toSlice()) |array_val| {
                    try ret.append(try tsjson(item_type, array_val)) catch error.JSONArrayListError;
                }
                return ret;
            },
            else => return error.JSONExpectedArray,
        }
    } else if (is_stringhashmap(T)) |item_type| {
        switch (value) {
            .Object => |o| {
                var ret = StringHashMap(item_type).init(std.debug.global_allocator);
                var it = o.iterator();
                while (it.next()) |kv| {
                    _ = try ret.put(kv.key, try tsjson(item_type, kv.value)) catch error.JSONStringHashMapError;
                }
                return ret;
            },
            else => return error.JSONExpectedObject,
        }
    } else {
        // General case struct by field
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
                            @field(ret, field.name) = null;
                        } else {
                            // Ideally we'd just return directly here, but doing so hits a compiler bug.
                            // Returning after the inline for loop instead works though.
                            //return error.JSONMissingObjectField;
                            any_missing = true;
                        }
                    }
                }
                if (any_missing) {
                    return error.JSONMissingObjectField;
                }
                return ret;
            },
            else => return error.JSONExpectedObject,
        }
    }
}

fn tsjson_enum(comptime T: type, comptime enum_type: TypeInfo.Enum, value: json.Value) TSJE!T {
    switch (value) {
        .Integer => |i| {
            var ret: T = undefined;
            var found = false;
            inline for (enum_type.fields) |field| {
                if (field.value == i) {
                    ret = @intToEnum(T, field.value);
                    found = true;
                }
            }
            if (!found) {
                return error.JSONNoEnumForInteger;
            }
            return ret;
        },
        .Float => |f| {
            var ret: T = undefined;
            var found = false;
            inline for (enum_type.fields) |field| {
                if (math.floor(f) == f and field.value == @floatToInt(enum_type.tag_type, f)) {
                    ret = @intToEnum(T, field.value);
                    found = true;
                }
            }
            if (!found) {
                return error.JSONNoEnumForInteger;
            }
            return ret;
        },
        .String => |s| {
            var ret: T = undefined;
            var found = false;
            inline for (enum_type.fields) |field| {
                if (std.mem.eql(u8, field.name, s)) {
                    ret = @intToEnum(T, field.value);
                    found = true;
                }
            }
            if (!found) {
                return error.JSONBadEnumName;
            }
            return ret;
        },
        else => return error.JSONExpectedIntOrEnumName,
    }
}

fn tsjson_union(comptime T: type, comptime union_type: TypeInfo.Union, value: json.Value) TSJE!T {
    if (union_type.tag_type) |tag_type| {
        const JSONTagType = @TagType(json.Value);
        if (JSONTagType(value) != JSONTagType.Object) {
            return error.JSONExpectedObject;
        }
        var tag_name = value.Object.getValue("tag");
        if (tag_name == null) {
            return error.JSONNoUnionTagName;
        }
        var tag = try tsjson_enum(tag_type, @typeInfo(tag_type).Enum, tag_name.?);
        var union_value = value.Object.getValue("value");
        if (union_value == null) {
            return error.JSONNoUnionValue;
        }
        inline for (union_type.fields) |field| {
            if (field.enum_field.?.value == @enumToInt(tag)) {
                var result = try tsjson(field.field_type, union_value.?);
                return @unionInit(T, field.name, result);
            }
        }
        // We found a valid union tag so one of the fields should have matched and returned from the loop.
        unreachable;
    } else {
        return error.JSONUntaggedUnionNotSupported;
    }
}

fn tsjson(comptime T: type, value: json.Value) TSJE!T {
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
        .Enum => |enum_type| tsjson_enum(T, enum_type, value),
        .Union => |union_type| tsjson_union(T, union_type, value),
        else => @compileError("Bad Type"),
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

const TestEnum = enum {
    A = 1,
    B,
    C,
};

const TestStruct = struct {
    foo: bool = false,
    bar: i64 = 0,
    baz: i64 = 12,
    opt: ?i32,
    opt2: ?i32,
    flt: f32,
    iflt: f32,
    arr: [3]f32,
    test_enum: TestEnum,
    nested: Nested,
    array_list: ArrayList(i32),
    string_hash_map: StringHashMap(i32),
};

pub fn main() !void {
    var p = json.Parser.init(std.debug.global_allocator, false);
    defer p.deinit();

    const s = "{\"foo\": true, \"barz\": 1}";

    var tree = try p.parse(s);
    defer tree.deinit();

    //var result = try tsjson(TestStruct, tree);
    var result = try tsjson(TestStruct, tree.root);
    std.debug.warn("\n{}\n", result);
}

test "test all features that work" {
    var p = json.Parser.init(std.debug.global_allocator, false);
    defer p.deinit();

    const s = "{\"string_hash_map\": {\"foo\": 3, \"bar\": 42}, \"array_list\": [1, 2, 3, 4, 5], \"test_enum\": \"C\", \"foo\": true, \"bar\": 1, \"baz\": 2, \"opt\": 3, \"flt\": 2.3, \"iflt\": 1, \"arr\": [1, 2, 3], \"nested\": {\"foo\": true, \"bar\": 1, \"baz\": 2, \"opt\": 3, \"flt\": 2.3, \"iflt\": 1, \"arr\": [1, 2, 3]}}";

    var tree = try p.parse(s);
    defer tree.deinit();

    var result = try tsjson(TestStruct, tree.root);
    std.debug.warn("\n{}\n", result);
}

test "test README example" {
    const ExampleStruct = struct {
        an_int: i32,
        a_float: f32,
        optional: ?i32,
        an_array: [4]i32,
        nested_struct: struct {
            another_int: i32,
        },
    };
    var p = json.Parser.init(std.debug.global_allocator, false);
    defer p.deinit();

    const s =
        \\{
        \\ "an_int": 1,
        \\ "a_float": 3.5,
        \\ 
        \\ "an_array": [1, 2, 3, 4],
        \\ "nested_struct": {"another_int": 6}
        \\}
    ;
    var tree = try p.parse(s);
    defer tree.deinit();

    var result = try tsjson(ExampleStruct, tree.root);
    std.debug.warn("\n{}\n", result);
}

test "Test Union" {
    const ExampleUnion = union(enum) {
        A: i32,
        B: f32,
    };
    var p = json.Parser.init(std.debug.global_allocator, false);
    defer p.deinit();

    const s =
        \\{
        \\ "tag": "A",
        \\ "value": 42
        \\}
    ;
    var tree = try p.parse(s);
    defer tree.deinit();

    var result = try tsjson(ExampleUnion, tree.root);
    std.debug.warn("\n{}\n", result);
}
