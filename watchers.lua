watchers = {}

current_frame = 0

function watch(address, value_type, callback)
	callback = callback or function() end
	if not watchers[address] then
		watchers[address] = { prev_value = 0, current_value = -123124, callbacks = {}, type = value_type, has_changed = false }
	end
	
	table.insert(watchers[address].callbacks, callback)

	return watchers[address]
end

function run_watchers()
	local frames = watch(0x097C3C, 'u8')

	function count_frames ()
		local current = frames.current_value
		local prev = frames.prev_value
		if not current or not prev then return end
		if prev > current then prev = prev - 60 end
		current_frame = current_frame + math.abs(current - prev)
	end
	
	function update_watchers()
		for address, watcher in pairs(watchers) do
			local current_value = 0
			if watcher.type == 'u32' then
				current_value = mainmemory.read_u32_le(address)
			elseif watcher.type == 's32' then
				current_value = mainmemory.read_s32_le(address)
			elseif watcher.type == 'u8' then
				current_value = mainmemory.read_u8(address)
			elseif watcher.type == 's8' then
				current_value = mainmemory.read_s8(address)
			end
			if watcher.current_value ~= current_value then
				watcher.prev_value = watcher.current_value
				watcher.current_value = current_value
				watcher.has_changed = true
			else
				watcher.has_changed = false
			end
		end
	end

	function check_watchers()
		for address, watcher in pairs(watchers) do
			if watcher.has_changed then
				for _, callback in ipairs(watcher.callbacks) do
					callback(watcher.prev_value, watcher.current_value)
				end
			end
		end
	end

	event.onloadstate(function () frames.prev_value = nil; end)
	register_daemon(update_watchers)
	register_daemon(count_frames)
	register_late_daemon(check_watchers)
end