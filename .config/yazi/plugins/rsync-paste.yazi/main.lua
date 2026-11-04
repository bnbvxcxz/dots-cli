-- rsync-paste.yazi
-- Incremental local copy/paste for Yazi using rsync

local get_context = ya.sync(function()
	local sources = {}

	for _, file in pairs(cx.yanked) do
		sources[#sources + 1] = tostring(file.url)
	end

	return {
		sources = sources,
		destination = tostring(cx.active.current.cwd),
		is_cut = cx.yanked.is_cut,
	}
end)

local function notify(message, level)
	ya.notify({
		title = "Rsync Paste",
		content = message,
		level = level or "info",
		timeout = 5,
	})
end

local function inside(path, parent)
	parent = parent:gsub("/+$", "")
	return path == parent or path:sub(1, #parent + 1) == parent .. "/"
end

-- Convert the byte array returned by Child:read() into text.
local function bytes_to_string(bytes)
	if type(bytes) == "string" then
		return bytes
	end

	if type(bytes) ~= "table" then
		return ""
	end

	local chars = {}

	for i, byte in ipairs(bytes) do
		chars[i] = string.char(byte)
	end

	return table.concat(chars)
end

-- Progress indicator shared with the Yazi header.
local begin_progress = ya.sync(function()
	if Header._rsync_paste_active then
		return false
	end

	Header._rsync_paste_active = true
	Header._rsync_paste_text = " Rsync: starting... "

	if not Header._rsync_paste_registered then
		function Header:rsync_paste()
			return ui.Span(self._rsync_paste_text or ""):style(ui.Style():fg("yellow"))
		end

		Header._rsync_paste_id = Header:children_add("rsync_paste", 1500, Header.RIGHT)

		Header._rsync_paste_registered = true
	end

	ui.render()
	return true
end)

local set_progress = ya.sync(function(_, percentage)
	Header._rsync_paste_text = string.format(" Rsync: %d%% ", percentage)

	ui.render()
end)

local end_progress = ya.sync(function()
	if Header._rsync_paste_id then
		Header:children_remove(Header._rsync_paste_id, Header.RIGHT)
	end

	Header._rsync_paste_id = nil
	Header._rsync_paste_registered = false
	Header._rsync_paste_active = false
	Header._rsync_paste_text = nil

	ui.render()
end)

return {
	entry = function()
		local ctx = get_context()

		if ctx.is_cut then
			return notify("Use y to copy, not x to move.", "warn")
		end

		if #ctx.sources == 0 then
			return notify("No files yanked. Press y first.", "warn")
		end

		for _, source in ipairs(ctx.sources) do
			if inside(ctx.destination, source) then
				return notify("Destination is inside the source. Operation cancelled.", "error")
			end
		end

		if not begin_progress() then
			return notify("An rsync transfer is already running.", "warn")
		end

		local args = {
			"-ah",
			"--info=progress2",
			"--outbuf=L",
			"--",
		}

		for _, source in ipairs(ctx.sources) do
			args[#args + 1] = source
		end

		args[#args + 1] = ctx.destination .. "/"

		local child, err = Command("rsync"):arg(args):stdout(Command.PIPED):spawn()

		if not child then
			end_progress()
			return notify("Failed to start rsync: " .. tostring(err), "error")
		end

		local buffer = ""
		local last_percentage = -1

		local function process_output(data)
			buffer = buffer .. bytes_to_string(data)

			while true do
				local pos = buffer:find("[\r\n]")

				if not pos then
					break
				end

				local line = buffer:sub(1, pos - 1)
				buffer = buffer:sub(pos + 1)

				local percentage = line:match("(%d+)%%")

				if percentage then
					local number = tonumber(percentage)

					if number and number ~= last_percentage then
						last_percentage = number
						set_progress(number)
					end
				end
			end
		end

		while true do
			local data, event = child:read(4096)

			if event == 2 then
				break
			end

			if not data then
				break
			end

			if event == 0 then
				process_output(data)
			end
		end

		-- Process any remaining output.
		process_output("\n")

		local status, wait_err = child:wait()

		end_progress()

		if not status then
			notify("Process error: " .. tostring(wait_err), "error")
		elseif status.success then
			notify("Transfer completed!")
		else
			notify("Rsync failed (exit code " .. tostring(status.code) .. ").", "error")
		end
	end,
}
