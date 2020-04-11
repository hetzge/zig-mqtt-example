const std = @import("std");

const First = packed struct {
    value: i32,
};

const Second = packed struct {
    value: i32,
};

const Data = packed union {
    first: First,
    second: Second,
};

const Message = packed struct {
    id: i32,
    data: Data,
};

const c = @cImport({
    @cInclude("mqtt.h");
    @cInclude("posix_sockets.h");
});

pub fn main() anyerror!void {
    const sockfd = c.open_nb_socket("test.mosquitto.org", "1883");
    if (sockfd == -1) {
        @panic("Error creating socket");
    }

    var send_buffer: [10000]u8 = undefined;
    var receive_buffer: [10000]u8 = undefined;
    var client: c.mqtt_client = undefined;

    // mqtt_init_reconnect()
    try_mqtt(c.mqtt_init(&client, sockfd, send_buffer[0..], send_buffer.len, receive_buffer[0..], receive_buffer.len, @ptrCast(Callback, publish_callback)));
    try_mqtt(c.mqtt_connect(&client, "213435346745745754", null, null, 0, null, null, c.MQTT_CONNECT_CLEAN_SESSION, 400));

    try_mqtt(c.mqtt_sync(&client));
    try_mqtt(c.mqtt_subscribe(&client, "topic/test", 0));

    while (true) {
        try_mqtt(c.mqtt_sync(&client));

        var message = Message{
            .id = 1,
            .data = Data{
                .first = First{
                    .value = 4343,
                },
            },
        };
        try_mqtt(c.mqtt_publish(&client, "topic/test", &message, @sizeOf(Message), c.MQTT_PUBLISH_QOS_1));

        std.time.sleep(1000000000);
        std.debug.warn(".....\n", .{});
    }
}

const Callback = fn ([*c]?*c_void, [*c]c.mqtt_response_publish) callconv(.C) void;
fn publish_callback(unused: *c_void, published: *c.mqtt_response_publish) void {
    const message = @ptrCast([*c]const Message, published.application_message)[0..published.application_message_size][0];

    if (message.id == 1) {
        std.debug.warn("callback {}\n", .{message.data.first});
    } else {
        std.debug.warn("callback {}\n", .{message.data.second});
    }
}

fn try_mqtt(mqtt_error: c.enum_MQTTErrors) void {
    if (mqtt_error != @intToEnum(c.enum_MQTTErrors, c.MQTT_OK)) {
        @panic("Mqtt failed");
    }
}
