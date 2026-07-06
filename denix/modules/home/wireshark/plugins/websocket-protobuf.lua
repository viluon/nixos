local protobuf_dissector = Dissector.get("protobuf")

local ws_protobuf_proto = Proto("ws_protobuf", "WebSocket Protobuf")

local ws_payload_field = Field.new("websocket.payload")
local ws_opcode_field = Field.new("websocket.opcode")
local tcp_srcport_field = Field.new("tcp.srcport")
local tcp_dstport_field = Field.new("tcp.dstport")

function ws_protobuf_proto.dissector(tvb, pinfo, tree)
	local ws_payload = ws_payload_field()
	local ws_opcode = ws_opcode_field()
	local tcp_srcport = tcp_srcport_field()
	local tcp_dstport = tcp_dstport_field()

	if not ws_payload or not ws_opcode or ws_opcode.value ~= 2 then
		return
	end

	if not tcp_srcport or not tcp_dstport then
		return
	end

	local server_port = 8443
	local message_type

	if tcp_dstport.value == server_port then
		message_type = "dbag.energy.m7g.v1.OutboundEventsRequest"
	elseif tcp_srcport.value == server_port then
		message_type = "dbag.energy.m7g.v1.OutboundEventsResponse"
	else
		return
	end

	pinfo.private["pb_msg_type"] = "message," .. message_type
	protobuf_dissector:call(ws_payload.range:tvb(), pinfo, tree)
end

register_postdissector(ws_protobuf_proto)
