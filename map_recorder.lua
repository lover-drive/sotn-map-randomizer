dofile('daemon_runner.lua')
dofile('watchers.lua')

print("============================")
print("Initializing map recorder...")
print("============================")
print("Creates save states for randomizer to use.")

function record()
	local room_x = watch(0x973F0, 's32')
	local room_width = watch(0x0730C8, 'u32')
	local velocity = watch(0x0733E2, 's8')
	local map_offset_y = watch(0x0973F5, 's8')
	local last_saved_state = ''
	local room_id = watch(0x073084, 'u32')

	knockback_until = 0
	knockback_velocity = 0

	function get_relative_room_x(x, width)
		x = x or room_x.current_value
		width = width or room_width.current_value
		return x / width - .5
	end

	function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end


	function on_room_change ()
		if not room_id.prev_value then return end
		local edge = get_relative_room_x() < 0 and 'west' or 'east'
		local state_name = 'states/'..room_id.current_value..'_'..map_offset_y.current_value..'_'..edge
		if file_exists(state_name) then
			gui.addmessage(state_name..' already exists')
			knockback_velocity = 0
			knockback_until = 0
			return 
		else
			schedule(
				5,
				function()
					knockback_velocity = get_relative_room_x() < 0 and 1 or -1
					knockback_until = current_frame + 120
					schedule(
						2,
						function()
							save()
							knockback_velocity = get_relative_room_x() < 0 and -2 or 2
						end
					)
					schedule(
						5,
						function()
							knockback_velocity = get_relative_room_x() < 0 and -2 or 2
						end
					)
				end
			)
		end
	end


	function save(state_name)
		local edge = get_relative_room_x() < 0 and 'west' or 'east'
		state_name = state_name or 'states/'..room_id.current_value..'_'..map_offset_y.current_value..'_'..edge

		if state_name == last_saved_state then return end

		savestate.save(state_name)
		last_saved_state = state_name
	end
	
	function tick()
		gui.clearGraphics()
		if math.floor(current_frame / 30) % 2 == 0 then
			gui.drawEllipse(256, 24, 8, 8, nil, 'red')
		end
		gui.drawText(230, 20, 'REC')
		
		if current_frame < knockback_until then
			gui.drawRectangle(0, 0, 512, 512, 'black', 'black')
			gui.drawText(128, 50, knockback_until)
			gui.drawText(128, 50+16, knockback_velocity)
			mainmemory.write_s8(0x072EFC, 1)
			mainmemory.write_s32_le(0x0733E2, knockback_velocity)
		end
		
		local edge_distance = math.min(room_x.current_value, math.abs(room_width.current_value - room_x.current_value))
		if room_id.has_changed and edge_distance <= 32 then
			on_room_change()
		end
	end

	register_late_daemon(tick)
	run_watchers()
	run_daemons()
end

record()