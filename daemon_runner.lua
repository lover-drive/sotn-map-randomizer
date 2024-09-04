daemons = {}
daemons_late = {}
scheduled = {}

function register_daemon(daemon)
	table.insert(daemons, daemon)
end

function register_late_daemon(daemon)
	table.insert(daemons_late, daemon)
end

function schedule(time, callback)
	table.insert(scheduled, {
		time = current_frame + time,
		callback = callback
	})
end

function run_daemons ()
	while true do
		for _, daemon in ipairs(daemons) do
			daemon()
		end
		emu.frameadvance()
		for _, daemon in ipairs(daemons_late) do
			daemon()
		end
		for _, s in ipairs(scheduled) do
			if current_frame >= s.time then
				s.callback()
				table.remove(scheduled, _)
			end
		end
	end
end