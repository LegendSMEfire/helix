nut.command = nut.command or {}
nut.command.list = nut.command.list or {}

local COMMAND_PREFIX = "/"

-- Adds a new command to the list of commands.
function nut.command.add(command, data)
	-- For showing users the arguments of the command.
	data.syntax = data.syntax or "[none]"

	-- Why bother adding a command if it doesn't do anything.
	if (!data.onRun) then
		return ErrorNoHalt("Command '"..command.."' does not have a callback, not adding!\n")
	end

	-- Store the old onRun because we're able to change it.
	local onRun = data.onRun

	-- Check if the command is for basic admins only.
	if (data.adminOnly) then
		data.onRun = function(client, arguments)
			if (client:IsAdmin()) then
				return onRun(client, arguments)
			end
		end
	-- Or if it is only for super administrators.
	elseif (data.superAdminOnly) then
		data.onRun = function(client, arguments)
			if (client:IsSuperAdmin()) then
				return onRun(client, arguments)
			end
		end
	-- Or if we specify a usergroup allowed to use this.
	elseif (data.group) then
		-- The group property can be a table of usergroups.
		if (type(data.group) == "table") then
			data.onRun = function(client, arguments)
				-- Check if the client's group is allowed.
				for k, v in ipairs(data.group) do
					if (client:IsUserGroup(v)) then
						return onRun(client, arguments)
					end
				end
			end
		-- Otherwise it is most likely a string.
		else
			data.onRun = function(client, arguments)
				if (client:IsUserGroup(data.group)) then
					return onRun(client, arguments)
				end
			end		
		end
	end

	-- Add the command to the list of commands.
	nut.command.list[command] = data
end

-- Gets a table of arguments from a string.
function nut.command.extractArgs(text)
	local skip = 0
	local arguments = {}
	local curString = ""

	for i = 1, #text do
		if (i <= skip) then continue end

		local c = text:sub(i, i)

		if (c == "\"" or c == "'") then
			local match = text:sub(i):match("%b"..c..c)

			if (match) then
				curString = ""
				skip = i + #match
				arguments[#arguments + 1] = match:sub(2, -2)
			else
				curString = curString..c
			end
		elseif (c == " " and curString != "") then
			arguments[#arguments + 1] = curString
			curString = ""
		else
			if (c == " " and curString == "") then
				continue
			end

			curString = curString..c
		end
	end

	if (curString != "") then
		arguments[#arguments + 1] = curString
	end

	return arguments
end

if (SERVER) then
	-- Add a function to parse a regular chat string.
	function nut.command.parse(client, text, realCommand, arguments)
		-- See if the string contains a command.
		local match = realCommand or text:match(COMMAND_PREFIX.."([_%w]+)")
		local command = nut.command.list[match]

		-- We have a valid, registered command.
		if (command) then
			-- Get the arguments like a console command.
			if (!arguments) then
				arguments = nut.command.extractArgs(text:sub(#command + 2))
			end

			-- Run the command's callback and get the return.
			local result = command.onRun(client, arguments)

			-- If a string is returned, it is a notification.
			if (type(result) == "string") then
				-- Normal player here.
				if (IsValid(client)) then
					client:notify(result)
				-- They are running from RCON.
				else
					-- to-do: add logging capability.
					print(result)
				end
			end
		else
			if (IsValid(client)) then
				client:Notify(L("cmdNoExist", client))
			else
				print("Sorry, that command does not exist.")
			end
		end
	end

	concommand.Add("nut", function(client, _, arguments)
		local command = arguments[1]
		table.remove(arguments, 1)

		nut.command.parse(client, nil, command, arguments)
	end)
end