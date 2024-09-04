function file_exists(file)
	local f = io.open(file, "rb")
	if f then f:close() end
	return f ~= nil
end

-- get all lines from a file, returns an empty 
-- list/table if the file does not exist
function read(file)
	if not file_exists(file) then return {} end
	return io.lines(file)
end

function read_directory(dir)
	local pfile = io.popen('dir /b "./'..dir..'/"')
	local result = {}
	for filename in pfile:lines() do
		table.insert(result, filename)
	end
	pfile:close()
	return result
end

function split(str, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	for str in string.gmatch(str, "([^"..sep.."]+)") do
		table.insert(t, str)
	end
	return t
end