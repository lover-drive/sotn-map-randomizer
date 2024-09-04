dofile('daemon_runner.lua')
dofile('watchers.lua')
dofile('file_utils.lua')

print("===============================")
print("Initializing map randomizer...")
print("===============================")
print("Teleports Alucard to a random room on every transition.")
print("Press R to reroll next room. Press V to set it to vanilla.")
print(" ")

function map_randomizer ()
	local room_id = watch(0x073084, 'u32')
	local room_x = watch(0x973F0, 's32')
	local room_width = watch(0x0730C8, 'u32')
	local map_offset_y = watch(0x0973F5, 's8')
	local status = watch(0x03C734, 's8')

	local edge = nil
	local opposite_edge = nil
	local prev_state = nil
	local next_state = nil
	local current_state = nil
	local paused_until = 120

	local saved_data = {}
	local persistent_addresses = {}

	local states = {
		east = {},
		west = {}
	}
	local connections = {}
	local forbidden_rooms = {'2149186616', '2149193460'}

	local function get_relative_room_x(x, width)
		x = x or room_x.current_value
		width = width or room_width.current_value
		return x / width - .5
	end

	function save_data()
		for i, address in ipairs(persistent_addresses) do
			saved_data[address] = mainmemory.read_u32_le(address)
		end
	end

	function restore_data()
		for i, address in ipairs(persistent_addresses) do
			mainmemory.write_u32_le(address, saved_data[address])
		end
	end

	local function teleport(state)
		save_data()
		savestate.load(state, true)
		restore_data()
		emu.frameadvance()
		restore_data()
	end

	local function on_room_changed()
		if next_state ~= 'VANILLA' then
			teleport('states/'..next_state)
		else
			connections[room_id.current_value..'_'..map_offset_y.current_value..'_'..edge] = 'VANILLA'
		end
	end

	local function update_next_state()
		next_state = connections[current_state]

		if not next_state then
			if #states[edge] > 0 then
				local index = math.random(#states[opposite_edge])
				next_state = states[opposite_edge][index]
				print(next_state)

				connections[current_state] = next_state
				connections[next_state] = current_state
				table.remove(states[opposite_edge], index)
			end
		end
	end
	
	local function tick()
		if status.current_value ~= 2 then return end
		if not room_id.prev_value then return end
		mainmemory.write_u8(0x13B668, 0)
		-- mute music to prevent jarring transitions

		edge = get_relative_room_x() < 0 and 'west' or 'east'
		opposite_edge = edge == 'west' and 'east' or 'west'
		
		if room_id.has_changed then
			if current_frame > paused_until then
				paused_until = current_frame + 5
			end
			if math.abs(get_relative_room_x()) > .495 then
				on_room_changed()
			end
		else
			if current_frame > paused_until then
				current_state = room_id.current_value..'_'..map_offset_y.current_value..'_'..edge
				update_next_state()
			end
		end
	end
	
	local function draw_gui()
		if status.current_value ~= 2 then return end
		gui.clearGraphics()
		gui.text(32, 32, 'Map randomizer v0.1 by Alice Loverdrive')
		gui.text(32, 48, '[V] set transition to vanilla')
		gui.text(32, 64, '[R] reroll next transition')
		gui.text(32, 128, mainmemory.read_s32_le(0x03C9A0))
		gui.text(32, 128+16, mainmemory.read_s32_le(0x03C734))
		gui.text(32, 128+32, mainmemory.read_s32_le(0x03C9A8))
	end

	local function process_input()
		if status.current_value ~= 2 then return end
		local pressed = input.get()
		if pressed.V and next_state ~= 'VANILLA' then
			connections[next_state] = nil
			connections[current_state] = 'VANILLA'
			table.insert(states[edge], next_state)
			gui.addmessage('Setting next room to vanilla...')
		end

		if pressed.R then
			connections[next_state] = nil
			connections[current_state] = nil
		end
	end

	for i, filename in ipairs(read_directory('states')) do
		if string.find(filename, "east") then
			table.insert(states.east, filename)
		elseif string.find(filename, "west") then 
			table.insert(states.west, filename)
		end
	end

	for line in read('addresses/alucard.wch') do
		local separated = split(line, '%s')
		local address = separated[1]
		if address ~= '0' and address then
			table.insert(persistent_addresses, tonumber('0x'..address))
		end
	end

	print(persistent_addresses)
	
	register_late_daemon(tick)
	register_late_daemon(draw_gui)
	register_late_daemon(process_input)
	run_watchers()
	run_daemons()
end

map_randomizer()