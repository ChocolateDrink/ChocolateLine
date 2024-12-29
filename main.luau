local choco = {}
local ui = {}
local cmds = {}

if getgenv().choco then
	getgenv().choco.unload()
end

local startLoad = tick()
local scriptVer = 1

local cloneref = cloneref or function(i) return i end
local httpService = cloneref(game:GetService('HttpService'))
local players = cloneref(game:GetService('Players'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local runService = cloneref(game:GetService('RunService'))

do -- core funcs
	choco.objects = {}
	choco.connections = {}

	function choco.make(name, props)
		if not name then return end
		props = typeof(props) == 'table' and props or {}

		local draw = table.find({'Square', 'Line', 'Text', 'Quad', 'Circle', 'Triangle'}, name)
		local obj = draw and Drawing or Instance

		local inst = obj.new(name)
		for prop, val in next, props do
			inst[prop] = val
		end

		table.insert(choco.objects, inst)
		return inst
	end

	function choco.connect(signal, func)
		local listener = signal:Connect(func)
		table.insert(choco.connections, listener)

		return listener
	end

	function choco.unload()
		for _, v in next, choco.connections do
			if not v then continue end
			pcall(v.Disconnect, v)
		end

		for _, v in next, choco.objects do
			if not v then continue end
			pcall(v.Destroy, v)
		end

		choco, ui, cmds = nil, nil, nil
		getgenv().choco = nil
	end
end

do -- core util funcs
	choco.coreUtils = {}

	function choco.coreUtils.decode(data)
		if not data then return end

		local suc, res = pcall(httpService.JSONDecode, httpService, data)
		if not suc then
			local tries = 0
			repeat
				suc, res = pcall(httpService.JSONDecode, httpService, data)
				tries += 1
				task.wait()
			until suc or tries > 10
			if not suc then res = nil end
		end

		return res
	end

	function choco.coreUtils.encode(data)
		if not data then return end

		local suc, res = pcall(httpService.JSONEncode, httpService, data)
		if not suc then
			local tries = 0
			repeat
				suc, res = pcall(httpService.JSONEncode, httpService, data)
				tries += 1
				task.wait()
			until suc or tries > 10
			if not suc then res = nil end
		end

		return res
	end

	function choco.coreUtils.getFunc(func)
		if not func then return false end

		if not getgenv()[func] or type(getgenv()[func]) ~= 'function' then
			ui.log(string.format('missing function "%s"', func), 1, choco.constants.colors.yellow)
			return false
		end

		return true
	end

	function choco.coreUtils.execRaw(url, json)
		if not url then return end

		local suc, res = pcall(game.HttpGet, game, url)
		if not suc or res:sub(1, 1) == '4' or res:sub(1, 1) == '5' then
			return '4/5 error', res
		end

		if json then return res end

		local func, err = loadstring(res)
		if not func then
			return 'syntax error', err
		end

		func()

		return 'ok'
	end

	function choco.coreUtils.print(data, options)
		if not data then return end

		options = typeof(options) == 'table' and options or {}

		if typeof(data) == 'table' then
			options.indent = typeof(options.indent) == 'number' and options.indent or 0

			local indent = string.rep('    ', options.indent)

			for k, v in next, data do
				local key = tostring(k)
				if type(k) == 'string' then
					key = string.format('[%q]', k)
				elseif type(k) == 'number' then
					key = string.format('[%d]', k)
				end

				if type(v) == 'table' then
					print(string.format('%s%s = {', indent, key))
					choco.coreUtils.print(v, {indent = options.indent + 1})
					print(string.format('%s},', indent))
				else
					local val = tostring(v)
					if type(v) == 'string' then
						val = string.format('%q', v)
					elseif type(v) == 'number' then
						val = string.format('%g', v)
					end

					print(string.format('%s%s = %s,', indent, key, val))
				end
			end
		elseif typeof(data) == 'string' then
			print(data)
		end
	end
end

do -- core store
	choco.constants = {}
	choco.constants.colors = {}

	choco.game = {}
	choco.temp = {}

	choco.saves = {}
	choco.scriptsaves = {}
	choco.globalsaves = {}

	local rng = Random.new(tick() / math.cos(21 * (math.sqrt(2)) + 3))
	choco.constants.rng = rng
	choco.constants.randomnumber = rng:NextInteger(7, 10e5)

	choco.game.me = players.LocalPlayer
	choco.game.mouse = players.LocalPlayer:GetMouse()
	choco.game.cam = workspace.CurrentCamera

	choco.game.id = game.PlaceId
	choco.game.job = game.JobId

	choco.constants.colors.black = Color3.new(0, 0, 0)
	choco.constants.colors.white = Color3.new(1, 1, 1)
	choco.constants.colors.red = Color3.new(1, 0, 0)
	choco.constants.colors.orange = Color3.new(1, 0.6, 0)
	choco.constants.colors.yellow = Color3.new(0.9, 1, 0.2)
	choco.constants.colors.green = Color3.new(0, 1, 0)

	choco.temp.flyspeed = 50
	choco.temp.tpwalkspeed = 1.5

	choco.temp.esphealth = true
	choco.temp.espdistance = true
	choco.temp.espteam = true
end

do -- file sys
	if not isfolder('chocolateline') then makefolder('chocolateline') end

	if not isfolder('chocolateline/chatlogs') then makefolder('chocolateline/chatlogs') end
	if not isfolder('chocolateline/saves') then makefolder('chocolateline/saves') end

	if not isfile('chocolateline/saves/_script.json') then writefile('chocolateline/saves/_script.json', '[]') end
	if not isfile('chocolateline/saves/_global.json') then writefile('chocolateline/saves/_global.json', '[]') end

	local file = string.format('chocolateline/saves/%s.json', choco.game.id)

	if not isfile(file) then
		writefile(file, '[]')
	end

	function choco.updateSaves(where)
		if where == 'script' then
			writefile('chocolateline/saves/_script.json', choco.coreUtils.encode(choco.scriptsaves))
		elseif where == 'global' then
			writefile('chocolateline/saves/_global.json', choco.coreUtils.encode(choco.globalsaves))
		else
			writefile(file, choco.coreUtils.encode(choco.saves))
		end
	end

	task.spawn(function()
		local jsonData = readfile(file)
		if not jsonData then return end

		local luaData = choco.coreUtils.decode(jsonData)

		choco.saves.waypoints = luaData.waypoints or {}
		choco.saves.configs = luaData.configs or {}
		choco.saves.keybinds = luaData.keybinds or {}
	end)

	task.spawn(function()
		local jsonData = readfile('chocolateline/saves/_script.json')
		if not jsonData then return end

		local luaData = choco.coreUtils.decode(jsonData)

		choco.scriptsaves.uikeybind = luaData.uikeybind or 'insert'
	end)

	task.spawn(function()
		local jsonData = readfile('chocolateline/saves/_global.json')
		if not jsonData then return end

		local luaData = choco.coreUtils.decode(jsonData)

		choco.globalsaves.waypoints = luaData.waypoints or {}
	end)
end

do -- ui funcs
	function ui.dragify(gui)
		local doing, dInput, mPos, fPos = false, false, false, false
		local tInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

		choco.connect(gui.InputBegan, function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			doing, mPos, fPos = true, input.Position, gui.Position

			input.Changed:Connect(function()
				if input.UserInputState ~= Enum.UserInputState.End then return end
				doing = false
			end)
		end)

		choco.connect(gui.InputChanged, function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			dInput = input
		end)

		choco.connect(inputService.InputChanged, function(input)
			if input ~= dInput or not doing then return end
			local delta = input.Position - mPos

			tweenService:Create(gui, tInfo, {
				Position = UDim2.new(fPos.X.Scale, fPos.X.Offset + delta.X, fPos.Y.Scale, fPos.Y.Offset + delta.Y)
			}):Play()
		end)
	end

	function ui.log(text, err, color)
		for i = 9, 2, -1 do
			ui['output' .. i].Text = ui['output' .. (i - 1)].Text
			ui['output' .. i].TextColor3 = ui['output' .. (i - 1)].TextColor3
		end

		local prefix = '[*]'
		if err == 0 then
			prefix = '[*]'
		elseif err == 1 then
			prefix = '[-]'
		elseif err == 2 then
			prefix = '[!]'
		end

		ui.output1.Text = string.format('%s %s', prefix, text)
		ui.output1.TextColor3 = color or choco.constants.colors.white
	end
end

do -- ui
	local coreUi = cloneref(game:GetService('CoreGui'))

	local colors = choco.constants.colors
	local accent = Color3.new(0.1, 0.1, 0.1)

	ui.baseUi = choco.make('ScreenGui', {
		DisplayOrder = 999,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		OnTopOfCoreBlur = true
	})

	ui.holder = choco.make('Frame', {
		Active = false,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 945, 0, 50),
		Size = UDim2.new(0, 525, 0, 277),
		Visible = false,
		ZIndex = 999,
		Parent = ui.baseUi
	})

	ui.outputHolder = choco.make('Frame', {
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Position = UDim2.new(0, -8, 0, 19),
		Size = UDim2.new(0, 525, 0, 253),
		Style = Enum.FrameStyle.RobloxRound,
		Visible = false,
		Parent = ui.holder
	})

	for i = 1, 9, 1 do
		ui['output' .. i] = choco.make('TextLabel', {
			BackgroundTransparency = 1,
			Position = UDim2.new(0.01, 0, 0.849240005 - (i - 1) * 0.106719374, 0),
			Size = UDim2.new(0, 500, 0, 27),
			Font = Enum.Font.Code,
			Text = '',
			TextColor3 = colors.white,
			TextSize = 16,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = ui.outputHolder
		})
	end

	ui.entry = choco.make('Frame', {
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Position = UDim2.new(-0.0152380951, 0, 0.965582669, 0),
		Size = UDim2.new(0, 525, 0, 38),
		Parent = ui.holder
	})

	ui.entryLabel = choco.make('TextLabel', {
		BackgroundTransparency = 1,
		Position = UDim2.new(-0.0152380941, 0, 0, 0),
		Size = UDim2.new(0, 137, 0, 36),
		Font = Enum.Font.Code,
		Text = 'enter command >',
		TextColor3 = Color3.new(1, 0.3, 0),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = ui.entry
	})

	ui.commandSuggestion = choco.make('TextLabel', {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0.274285644, 0, 0, 0),
		Size = UDim2.new(0, 341, 0, 35),
		Font = Enum.Font.Code,
		Text = '',
		TextColor3 = Color3.new(0.4, 0.4, 0.4),
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = ui.entry
	})

	ui.commandLine = choco.make('TextBox', {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Position = UDim2.new(-0, 0, 0, 0),
		Size = UDim2.new(0, 341, 0, 35),
		Font = Enum.Font.Code,
		PlaceholderColor3 = colors.white,
		PlaceholderText = '...',
		Text = '',
		TextColor3 = colors.white,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = ui.commandSuggestion
	})

	do -- cmds ui
		ui.cmdsHolder = choco.make('Frame', {
			Active = false,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 862, 0, 481),
			Size = UDim2.new(0, 430, 0, 277),
			Visible = false,
			ZIndex = 999,
			Parent = ui.baseUi
		})

		ui.cmdsContentHolder = choco.make('ScrollingFrame', {
			BackgroundColor3 = colors.black,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Position = UDim2.new(0, -8, 0, 19),
			Size = UDim2.new(0, 455, 0, 253),
			Visible = false,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			ScrollBarImageColor3 = Color3.new(0.3, 0.3, 0.3),
			ScrollBarThickness = 4,
			Parent = ui.cmdsHolder
		})

		ui.cmdsLayout = choco.make('UIListLayout', {
			Padding = UDim.new(0, -5),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = ui.cmdsContentHolder
		})

		ui.cmdsDescriptionHolder = choco.make('Frame', {
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			Position = UDim2.new(-0.0152380951, -1, 0.965582669, 0),
			Size = UDim2.new(0, 454, 0, 38),
			Parent = ui.cmdsHolder
		})

		ui.cmdsDescription = choco.make('TextLabel', {
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 445, 0, 36),
			Font = Enum.Font.Code,
			Text = '',
			TextColor3 = colors.white,
			TextSize = 16,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = ui.cmdsDescriptionHolder
		})

		choco.make('UIPadding', {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			Parent = ui.cmdsDescription
		})
	end

	do -- waypoints ui
		ui.waypointsHolder = choco.make('Frame', {
			Active = false,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 862, 0, 481),
			Size = UDim2.new(0, 430, 0, 277),
			Visible = false,
			ZIndex = 999,
			Parent = ui.baseUi
		})

		ui.waypointsContentHolder = choco.make('ScrollingFrame', {
			BackgroundColor3 = colors.black,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Position = UDim2.new(0, -8, 0, 19),
			Size = UDim2.new(0, 455, 0, 253),
			Visible = false,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			ScrollBarImageColor3 = Color3.new(0.3, 0.3, 0.3),
			ScrollBarThickness = 4,
			Parent = ui.waypointsHolder
		})

		ui.waypointsLayout = choco.make('UIListLayout', {
			Padding = UDim.new(0, 5),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = ui.waypointsContentHolder
		})

		choco.connect(ui.waypointsLayout:GetPropertyChangedSignal('AbsoluteContentSize'), function()
			local contentSize = ui.waypointsLayout.AbsoluteContentSize.Y
			local size = ui.waypointsContentHolder.AbsoluteSize.Y
			ui.waypointsContentHolder.CanvasSize = UDim2.new(0, 0, 0, contentSize)

			ui.waypointsContentHolder.ScrollBarThickness = contentSize > size and 4 or 0
		end)
	end

	do -- keybinds ui
		ui.keybindsHolder = choco.make('Frame', {
			Active = false,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 46, 0, 400),
			Size = UDim2.new(0, 300, 0, 277),
			Visible = false,
			ZIndex = 999,
			Parent = ui.baseUi
		})

		ui.keybindsContentHolder = choco.make('ScrollingFrame', {
			BackgroundColor3 = colors.black,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Position = UDim2.new(0, -8, 0, 19),
			Size = UDim2.new(0, 300, 0, 253),
			Visible = false,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			ScrollBarImageColor3 = Color3.new(0.3, 0.3, 0.3),
			ScrollBarThickness = 4,
			Parent = ui.keybindsHolder
		})

		ui.keybindsLayout = choco.make('UIListLayout', {
			Padding = UDim.new(0, -3),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = ui.keybindsContentHolder
		})
	end

	ui.dragify(ui.holder)
	ui.dragify(ui.keybindsHolder)
	ui.dragify(ui.cmdsHolder)
	ui.dragify(ui.waypointsHolder)

	ui.baseUi.Parent = gethui and gethui() or coreUi
	ui.holder.Visible = true
	ui.outputHolder.Visible = true

	function ui.doThing(action)
		if action == 'setcore' then
			ui.baseUi.Parent = coreUi
		elseif action == 'sethidden' then
			ui.baseUi.Parent = gethui and gethui() or coreUi
		else
			return ui.baseUi.Parent
		end
	end
end

do -- connections
	local lastClickedEnter = 0

	local inputs = {
		semicolon = function()
			ui.commandLine:CaptureFocus()
			runService.RenderStepped:Wait()

			ui.commandLine.Text = ''
		end,
		tab = function()
			if not ui.commandLine:IsFocused() then return end
			if ui.commandSuggestion.Text == '' then return end

			local suggestion = ui.commandSuggestion.Text
			runService.RenderStepped:Wait()

			ui.commandLine.Text = suggestion .. ' '
			ui.commandLine.CursorPosition = #ui.commandLine.Text + 1
		end,
		['return'] = function()
			lastClickedEnter = tick()
		end
	}

	choco.connect(inputService.InputBegan, function(input)
		local code = input.KeyCode.Name:lower()

		if code == choco.scriptsaves.uikeybind then
			ui.holder.Visible = not ui.holder.Visible
			ui.outputHolder.Visible = not ui.outputHolder.Visible

			if ui.cmdsHolder.Visible or ui.cmdsContentHolder.Visible then
				ui.cmdsHolder.Visible = false
				ui.cmdsContentHolder.Visible = false
			end

			if ui.keybindsHolder.Visible or ui.keybindsContentHolder.Visible then
				ui.keybindsHolder.Visible = false
				ui.keybindsContentHolder.Visible = false
			end
		end

		if inputs[code] then
			inputs[code]()
		end

		if inputService:GetFocusedTextBox() then return end
		for i, v in next, choco.saves.keybinds do
			if v ~= code:upper() or v == 'UNKNOWN' then continue end
			cmds.exec(i)
		end
	end)

	choco.connect(ui.commandLine.FocusLost, function()
		runService.RenderStepped:Wait()
		if tick() - lastClickedEnter > 1 then return end

		local args = ui.commandLine.Text:split(' ')
		if args[1]:len() < 1 then return end

		local command = args[1]
		table.remove(args, 1)

		ui.commandLine.Text = ''
		ui.commandSuggestion.Text = ''

		cmds.exec(command, unpack(args))
	end)

	choco.connect(ui.commandLine:GetPropertyChangedSignal('Text'), function()
		local input = ui.commandLine.Text:lower()
		if input:len() < 1 then
			ui.commandLine.Text = ''
			ui.commandSuggestion.Text = ''
			return
		end

		local sorted = {}
		for i, v in next, cmds.all do
			table.insert(sorted, { name = i, aliases = v.aliases })
		end
		table.sort(sorted, function(a, b)
			return #a.name < #b.name
		end)

		for _, v in next, sorted do
			if v.name:sub(1, #input) == input then
				ui.commandSuggestion.Text = v.name
				return
			end

			for _, v2 in next, v.aliases do
				if v2:sub(1, #input) == input then
					ui.commandSuggestion.Text = v.name
					return
				end
			end
		end

		ui.commandSuggestion.Text = ''
	end)
end

do -- cmd base
	cmds.all = {}

	function cmds.find(cmd)
		if cmds.all[cmd] then
			return cmds.all[cmd]
		end

		for _, v in next, cmds.all do
			if table.find(v.aliases, cmd) then
				return v
			end
		end

		return nil
	end

	function cmds.exec(cmd, ...)
		cmd = cmd:gsub('^%s+', ''):gsub('%s+$', '')
		cmd = cmd:gsub('%s+', ' ')

		local found = cmds.find(cmd)
		if not found then return end

		local suc, res = pcall(found.func, ...)
		if suc then return end

		local err = res:match(':%d+: .+') or '???'
		if choco.debugging then warn(res) end

		ui.log(string.format('execution error in command "%s":', cmd), 2, choco.constants.colors.red)
		ui.log(err, 2, choco.constants.colors.red)
	end

	function cmds.add(name, func, aliases)
		if not name or not func then return end
		if typeof(aliases) ~= 'table' then aliases = { aliases } end

		cmds.all[name:lower()] = { aliases = aliases, func = func }
	end
end

do -- cmd list
	cmds.list = {}

	cmds.list['eject'] = 'unloads the script'
	cmds.list['debug'] = 'enabled debug mode'
	cmds.list['undebug / nodebug'] = 'disables debug mode'
	cmds.list['test'] = 'test command'
	cmds.list['rebindui [key]'] = 'rebinds the ui toggle key to [key]'
	cmds.list['commands / cmds'] = 'shows a list of commands and what they do'
	cmds.list['keybinds / binds'] = 'lets you bind certain modules to a key'
	cmds.list['rejoin / rj'] = 'rejoins the game'
	cmds.list['autorejoin / autorj'] = 'automatically rejoins the game when you get kicked'
	cmds.list['unautorejoin / unautorj / noautorejoin / noautorj'] = 'disables autorejoin'
	cmds.list['waypoints'] = 'shows all the saved waypoints'
	cmds.list['setwaypoint / addwaypoint / swp [name]'] = 'sets a waypoint with the name [name]'
	cmds.list['esp'] = 'lets you see people through walls'
	cmds.list['unesp / noesp'] = 'disables esp'
	cmds.list['esptogglehealth'] = 'toggles if esp should display the persons health'
	cmds.list['esptoggledistance'] = 'toggles if esp should display the persons distance to your camera'
	cmds.list['fly [speed?]'] = 'lets you fly'
	cmds.list['flyspeed [speed]'] = 'sets the fly speed to [speed]'
	cmds.list['flyvelo / flyvelocity / velofly / velocityfly [speed?]'] = 'manipulates your velocity to let you fly'
	cmds.list['vehiclefly / vfly [speed?]'] = 'lets you fly when sitting in a vehicle'
	cmds.list['directionalfly / dirfly [speed?]'] = 'flys in the direction of your camera (inserts a body mover)'
	cmds.list['directionalcframefly / dircffly [speed?]'] = 'flys in the direction of your camera by setting your cframe'
	cmds.list['unfly / nofly'] = 'disables fly'
	cmds.list['togglefly'] = 'toggles fly (for keybinds)'
	cmds.list['toggleflyvelo'] = 'toggles velocity fly (for keybinds)'
	cmds.list['togglevfly'] = 'toggles vehicle fly (for keybinds)'
	cmds.list['toggledirfly'] = 'toggles directional fly (for keybinds)'
	cmds.list['toggledircframefly'] = 'toggles cframe directional fly (for keybinds)'
end

do -- script utils
	choco.utils = {}

	local me = choco.game.me
	local cam = choco.game.cam

	local function countTable(tab)
		local count = 0
		for _ in next, tab do count += 1 end

		return count
	end

	function choco.utils.getString(str)
		if not str then return end
		if str:gsub('%s', '') == '' then return end

		return str
	end

	function choco.utils.getNumber(num)
		return tonumber(num)
	end

	function choco.utils.getTable(tab, blank)
		if countTable(tab) == 0 then return end
		if not blank and tab[1] == '' then return end

		return tab
	end

	function choco.utils.getRoot()
		local root = me.Character and me.Character:FindFirstChild('HumanoidRootPart')
		return root
	end

	function choco.utils.getHum()
		local hum = me.Character and me.Character:FindFirstChildOfClass('Humanoid')
		return hum
	end

	function choco.utils.getBoth()
		return choco.utils.getRoot(), choco.utils.getHum()
	end

	function choco.utils.behindWall(player, part)
		return cam:GetPartsObscuringTarget({part.CFrame.Position}, player.Character:GetDescendants()) > 0
	end

	function choco.utils.isTeam(player)
		local myTeam, thierTeam = me.Team, player.Team

		if not myTeam or not thierTeam then
			return
		end

		return myTeam == thierTeam
	end

	function choco.utils.getClosestToMouse(fov, part, walls, team)
		local player, distance = nil, fov

		for _, v in next, players:GetPlayers() do
			if v == me then continue end

			local char = v.Character
			if not char then continue end

			local hum = v:FindFirstChildOfClass('Humanoid')
			if not hum or hum.Health <= 0 then continue end

			local target = char:FindFirstChild(part or 'HumanoidRootPart')
			if not target then continue end

			if walls and choco.utils.behindWall(v, target) then continue end
			if team and choco.utils.isTeam(v) then continue end

			local vector, inVp = cam:WorldToViewportPoint(target.CFrame.Position)
			local magnitude = (inputService:GetMouseLocation() - Vector2.new(vector.X, vector.Y)).Magnitude

			if magnitude <= distance and inVp then
				distance = magnitude
				player = v
			end
		end

		return player
	end

	function choco.utils.getClosestToChar(range, part, walls, team)
		local player, distance = nil, range

		local root = me.Character and me.Character.PrimaryPart
		if not root then return end

		for _, v in next, players:GetPlayers() do
			if v == me then continue end

			local char = v.Character
			if not char then continue end

			local hum = v:FindFirstChildOfClass('Humanoid')
			if not hum or hum.Health <= 0 then continue end

			local target = char:FindFirstChild(part or 'HumanoidRootPart')
			if not target then continue end

			if walls and choco.utils.behindWall(v, target) then continue end
			if team and choco.utils.isTeam(v) then continue end

			local magnitude = (root.CFrame.Position - target.CFrame.Position).Magnitude
			if magnitude <= distance then
				distance = magnitude
				player = v
			end
		end

		return player
	end

	function choco.utils.getPlayer(name)
		name = choco.utils.getString(name)
		if not name then return end

		if name == 'me' then
			return me
		elseif name == 'random' then
			return players:GetPlayers()[choco.constants.rng:NextInteger(2, #players:GetPlayers())]
		elseif name == 'all' then
			local returns = {}

			for _, v in next, players:GetPlayers() do
				if v == me or table.find(returns, v) then continue end
				table.insert(returns, v)
			end

			return returns
		elseif name == 'close' or name == 'closest' or name == 'near' or name == 'nearest' then
			return choco.utils.getClosestToChar(math.huge)
		elseif name == 'mouse' or name == 'cursor' then
			return choco.utils.getClosestToMouse(math.huge)
		elseif name:sub(1, 1) == '@' then
			return players:FindFirstChild(name:sub(2))
		elseif name:sub(1, 1) == '#' then
			return players:GetPlayers()[choco.utils.getNumber(name:sub(2))]
		else
			for _, v in next, players:GetPlayers() do
				if not v.Name:lower():find(name:lower()) and not v.DisplayName:lower():find(name:lower()) then continue end
				return v
			end
		end
	end
end

do -- script funcs
	choco.funcs = {}

	local me = choco.game.me
	local cam = choco.game.cam

	local actionService = cloneref(game:GetService('ContextActionService'))

	function choco.funcs.showCmdsUi()
		if ui.cmdsCached then return end

		local numCmds, sorted = 1, {}

		for i in next, cmds.list do
			table.insert(sorted, i)
		end
		table.sort(sorted)

		for _, v in next, sorted do
			local label = choco.make('TextLabel', {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -10, 0, 27),
				Font = Enum.Font.Code,
				Text = string.format('%s) %s', numCmds, v),
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = ui.cmdsContentHolder
			})

			choco.make('UIPadding', {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
				Parent = label
			})

			choco.connect(label.MouseEnter, function()
				ui.cmdsDescription.Text = cmds.list[v]
			end)

			choco.connect(label.MouseLeave, function()
				if ui.cmdsDescription.Text ~= cmds.list[v] then return end
				ui.cmdsDescription.Text = ''
			end)

			numCmds += 1
		end

		local contentSize = ui.cmdsLayout.AbsoluteContentSize
		ui.cmdsContentHolder.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y)

		ui.cmdsCached = true
	end

	do -- waypoints
		local buttonColor = Color3.new(0.2, 0.2, 0.2)
		local white = choco.constants.colors.white

		function choco.funcs.addWaypoint(name, cframe, save)
			name = typeof(name) == 'table' and table.concat(name, ' ') or name

			local label = choco.make('TextLabel', {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -10, 0, 27),
				Font = Enum.Font.Code,
				Text = name,
				TextColor3 = white,
				TextSize = 16,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = ui.waypointsContentHolder
			})

			choco.make('UIPadding', {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
				Parent = label
			})

			local deleteWaypoint = choco.make('TextButton', {
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = buttonColor,
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.new(0.145, 0, 0.75, 0),
				Font = Enum.Font.Code,
				Text = 'delete',
				TextColor3 = white,
				TextSize = 16,
				Parent = label
			})

			local toWaypoint = choco.make('TextButton', {
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = buttonColor,
				Position = UDim2.new(1, -70, 0.5, 0),
				Size = UDim2.new(0.18, 0, 0.65, 0),
				Font = Enum.Font.Code,
				Text = 'teleport',
				TextColor3 = white,
				TextSize = 16,
				Parent = label
			})

			choco.connect(deleteWaypoint.MouseButton1Click, function()
				label:Destroy()
				choco.saves.waypoints[name] = nil
				choco.updateSaves()
			end)

			choco.connect(toWaypoint.MouseButton1Click, function()
				local root = choco.utils.getRoot()
				if not root then return end

				local components = choco.saves.waypoints[name]
				root.CFrame = CFrame.new(components[1], components[2], components[3])
			end)

			if save then
				local root = choco.utils.getRoot()
				if not root then return end

				local components = cframe or {root.CFrame:GetComponents()}
				choco.saves.waypoints[name] = {components[1], components[2], components[3]}
				choco.updateSaves()
			end
		end

		function choco.funcs.toggleWaypointUi()
			ui.waypointsHolder.Visible = not ui.waypointsHolder.Visible
			ui.waypointsContentHolder.Visible = not ui.waypointsContentHolder.Visible
		end

		for i, v in next, choco.saves.waypoints do
			choco.funcs.addWaypoint(i, v, false)
		end
	end

	do -- esp
		local esp = {}

		local function convertVector(x, y, z)
			return cam.CFrame:VectorToWorldSpace(Vector3.new(x, y, z))
		end

		do
			esp.__index = esp

			function esp.new(player)
				local self = setmetatable({}, esp)

				self._player = player
				self._playerName = player.Name

				self._visible = false

				self._label = choco.make('Text', {
					Visible = false,
					Center = true,
					Outline = true,
					Text = '',
					Font = Drawing.Fonts.Plex,
					Size = 20,
					Color = choco.constants.colors.white
				})

				self._box = choco.make('Quad', {
					Visible = false,
					Thickness = 1,
					Filled = false,
					Color = choco.constants.colors.white
				})

				return self
			end

			function esp:Hide()
				if not self._visible then return end
				self._visible = false

				self._label.Visible = false
				self._box.Visible = false
			end

			function esp:Destroy()
				self._label:Destroy()
				self._label = nil

				self._box:Destroy()
				self._box = nil
			end

			function esp:Update()
				local char = self._player.Character
				if not char then return self:Hide() end

				local isTeam = choco.utils.isTeam(self._player)
				if isTeam and not choco.temp.espteam then return self:Hide() end

				local root = char:FindFirstChild('HumanoidRootPart')
				local hum = char:FindFirstChildOfClass('Humanoid')
				if not root or not hum then return self:Hide() end

				local rootPos = root.CFrame.Position

				local pos, visible = cam:WorldToViewportPoint(rootPos + convertVector(0, 3.25, 0))

				self._visible = visible

				local boxTopRight = cam:WorldToViewportPoint(rootPos + convertVector(2.5, 3, 0))
				local boxBottomLeft = cam:worldToViewportPoint(rootPos + convertVector(-2.5, -4.5, 0))

				local topRightX, topRightY = boxTopRight.X, boxTopRight.Y
				local bottomLeftX, bottomLeftY = boxBottomLeft.X, boxBottomLeft.Y

				self._label.Visible = visible
				self._box.Visible = visible

				self._label.Position = Vector2.new(pos.X, pos.Y - self._label.TextBounds.Y)

				local hpText = choco.temp.esphealth and (' | ' .. math.round(hum.Health)) or ''
				local magText = choco.temp.espdistance and (' | ' .. math.round((rootPos - cam.CFrame.Position).Magnitude)) or ''
				self._label.Text = self._playerName .. hpText .. magText
				self._label.Color = self._player.TeamColor.Color

				self._box.PointA = Vector2.new(topRightX, topRightY)
				self._box.PointB = Vector2.new(bottomLeftX, topRightY)
				self._box.PointC = Vector2.new(bottomLeftX, bottomLeftY)
				self._box.PointD = Vector2.new(topRightX, bottomLeftY)
				self._box.Color = self._player.TeamColor.Color
			end
		end

		local playerList = {}

		local function onPlayerAdded(player)
			if player == me then return end

			local espPlayer = esp.new(player)
			table.insert(playerList, espPlayer)
		end

		local function onPlayerRemoving(player)
			if player == me then return end

			if table.find(playerList, player) then
				playerList[player]:Destroy()
			end
		end

		choco.connect(players.PlayerAdded, onPlayerAdded)
		choco.connect(players.PlayerRemoving, onPlayerRemoving)

		for _, v in next, players:GetPlayers() do
			task.spawn(onPlayerAdded, v)
		end

		local espUpdated = 0

		function choco.funcs.startESP()
			choco.funcs.stopESP()

			choco.temp.esploop = choco.connect(runService.RenderStepped, function()
				if tick() - espUpdated < 0.01 then return end
				espUpdated = tick()

				for _, v in next, playerList do
					v:Update()
				end
			end)
		end

		function choco.funcs.stopESP()
			if choco.temp.esploop then
				choco.temp.esploop:Disconnect()
				choco.temp.esploop = nil
			end

			for _, v in next, playerList do
				v:Hide()
			end
		end
	end

	do -- fly
		local function getMovePart()
			local root, hum = choco.utils.getBoth()
			if not root or not hum then return end

			local seat = hum.SeatPart
			if not seat or not seat:IsA('VehicleSeat') then return root end

			return seat.Parent and seat.Parent.PrimaryPart or root
		end

		function choco.funcs.disableFly()
			actionService:UnbindAction('vflyup')
			actionService:UnbindAction('vflydown')

			if choco.temp.flyvelo then
				choco.temp.flyvelo:Disconnect()
				choco.temp.flyvelo = nil
			end

			if choco.temp.vflydied then
				choco.temp.vflydied:Disconnect()
				choco.temp.vflydied = nil
			end

			if choco.temp.fly then
				choco.temp.fly:Disconnect()
				choco.temp.fly = nil
			end

			if choco.temp.flydtc then
				choco.temp.flydtc:Disconnect()
				choco.temp.flydtc = nil
			end

			if choco.temp.dtcflyinputbegan then
				choco.temp.dtcflyinputbegan:Disconnect()
				choco.temp.dtcflyinputbegan = nil
			end

			if choco.temp.flymover then
				choco.temp.flymover:Destroy()
				choco.temp.flymover = nil
			end

			if choco.temp.dirflyinputbegan then
				choco.temp.dirflyinputbegan:Disconnect()
				choco.temp.dirflyinputbegan = nil
			end

			if choco.temp.flydir then
				choco.temp.flydir:Disconnect()
				choco.temp.flydir = nil
			end
		end

		function choco.funcs.startFlyVelocity(vfly)
			choco.funcs.disableFly()

			local verticle = 0

			if vfly then
				actionService:BindAction('vflyup', function(_, state)
					if state == Enum.UserInputState.Begin then
						verticle = 1
					elseif state == Enum.UserInputState.End then
						verticle = 0
					end
				end, false, Enum.KeyCode.Space)

				actionService:BindAction('vflydown', function(_, state)
					if state == Enum.UserInputState.Begin then
						verticle = -1
					elseif state == Enum.UserInputState.End then
						verticle = 0
					end
				end, false, Enum.KeyCode.LeftControl)
			end

			choco.temp.flyvelo = choco.connect(runService.Heartbeat, function()
				local root, hum = choco.utils.getBoth()
				if not root or not hum then return end

				if inputService:IsKeyDown(Enum.KeyCode.Space) and not inputService:GetFocusedTextBox() then
					verticle = 1
				elseif inputService:IsKeyDown(Enum.KeyCode.LeftControl) and not inputService:GetFocusedTextBox() then
					verticle = -1
				else
					verticle = 0
				end

				local moveDir = hum.MoveDirection

				if vfly then
					getMovePart().AssemblyLinearVelocity = Vector3.new(moveDir.X, verticle, moveDir.Z) * choco.temp.flyspeed + Vector3.new(0, 2.25, 0)

					choco.temp.vflydied = choco.temp.vflydied or choco.connect(hum.Died, function()
						cmds.exec('unfly')
						choco.temp.vflydied:Disconnect()
						choco.temp.vflydied = nil
					end)
				else
					root.AssemblyLinearVelocity = Vector3.new(moveDir.X, verticle, moveDir.Z) * choco.temp.flyspeed + Vector3.new(0, 2.25, 0)
				end
			end)
		end

		function choco.funcs.startFlyCFrame()
			choco.funcs.disableFly()

			local verticle = 0

			choco.temp.fly = choco.connect(runService.Heartbeat, function(dt)
				local root, hum = choco.utils.getBoth()
				if not root or not hum then return end

				if inputService:IsKeyDown(Enum.KeyCode.Space) and not inputService:GetFocusedTextBox() then
					verticle = 1
				elseif inputService:IsKeyDown(Enum.KeyCode.LeftControl) and not inputService:GetFocusedTextBox() then
					verticle = -1
				else
					verticle = 0
				end

				local moveDir = hum.MoveDirection
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero

				verticle = (verticle * choco.temp.flyspeed * dt) + ((tick() % 0.4) / 0.5) * 0.1
				root.CFrame += moveDir * choco.temp.flyspeed * dt
				root.CFrame += Vector3.new(0, verticle, 0)
			end)
		end

		function choco.funcs.startDetectedFly()
			choco.funcs.disableFly()

			local w, a, s, d, v = 0, 0, 0, 0, 0
			choco.temp.dtcflyinputbegan = choco.connect(inputService.InputBegan, function(input)
				if inputService:GetFocusedTextBox() then return end

				if input.KeyCode == Enum.KeyCode.W then
					w = -1
				elseif input.KeyCode == Enum.KeyCode.S then
					s = 1
				elseif input.KeyCode == Enum.KeyCode.A then
					a = -1
				elseif input.KeyCode == Enum.KeyCode.D then
					d = 1
				elseif input.KeyCode == Enum.KeyCode.LeftControl then
					v = -1
				elseif input.KeyCode == Enum.KeyCode.Space then
					v = 1
				end
			end)

			choco.temp.dtcflyinputended = choco.connect(inputService.InputEnded, function(input)
				if inputService:GetFocusedTextBox() then return end

				if input.KeyCode == Enum.KeyCode.W then
					w = 0
				elseif input.KeyCode == Enum.KeyCode.S then
					s = 0
				elseif input.KeyCode == Enum.KeyCode.A then
					a = 0
				elseif input.KeyCode == Enum.KeyCode.D then
					d = 0
				elseif input.KeyCode == Enum.KeyCode.LeftControl then
					v = 0
				elseif input.KeyCode == Enum.KeyCode.Space then
					v = 0
				end
			end)

			choco.temp.flymover = cloneref(choco.make('BodyVelocity'))
			choco.temp.flymover.MaxForce = Vector3.one * math.huge

			choco.temp.flydtc = choco.connect(runService.Heartbeat, function()
				local root = choco.utils.getRoot()
				if not root or not cam then return end

				choco.temp.flymover.Parent = root
				choco.temp.flymover.Velocity = cam.CFrame:VectorToWorldSpace(Vector3.new(a + d, v, w + s) * choco.temp.flyspeed)
			end)
		end

		function choco.funcs.startDirectionalFly()
			choco.funcs.disableFly()

			local w, a, s, d, v = 0, 0, 0, 0, 0
			choco.temp.dirflyinputbegan = choco.connect(inputService.InputBegan, function(input)
				if inputService:GetFocusedTextBox() then return end

				if input.KeyCode == Enum.KeyCode.W then
					w = -1
				elseif input.KeyCode == Enum.KeyCode.S then
					s = 1
				elseif input.KeyCode == Enum.KeyCode.A then
					a = -1
				elseif input.KeyCode == Enum.KeyCode.D then
					d = 1
				elseif input.KeyCode == Enum.KeyCode.LeftControl then
					v = -1
				elseif input.KeyCode == Enum.KeyCode.Space then
					v = 1
				end
			end)

			choco.temp.dirflyinputended = choco.connect(inputService.InputEnded, function(input)
				if inputService:GetFocusedTextBox() then return end

				if input.KeyCode == Enum.KeyCode.W then
					w = 0
				elseif input.KeyCode == Enum.KeyCode.S then
					s = 0
				elseif input.KeyCode == Enum.KeyCode.A then
					a = 0
				elseif input.KeyCode == Enum.KeyCode.D then
					d = 0
				elseif input.KeyCode == Enum.KeyCode.LeftControl then
					v = 0
				elseif input.KeyCode == Enum.KeyCode.Space then
					v = 0
				end
			end)

			choco.temp.flydir = choco.connect(runService.Heartbeat, function(dt)
				local root = choco.utils.getRoot()
				if not root or not cam then return end

				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero

				root.CFrame += cam.CFrame:VectorToWorldSpace(Vector3.new(a + d, v, w + s) * choco.temp.flyspeed * dt)
			end)
		end
	end
end

do -- script
	local lplr = choco.game.me
	local cam = choco.game.cam

	local funcs = choco.funcs
	local utils = choco.utils
	local temp = choco.temp

	local tpService = cloneref(game:GetService('TeleportService'))
	local networkClient = cloneref(game:GetService('NetworkClient'))
	local ppService = cloneref(game:GetService('ProximityPromptService'))

	cmds.add('eject', choco.unload)

	cmds.add('debug', function()
		choco.debugging = true
		ui.log('debugging enabled')
	end)

	cmds.add('undebug', function()
		choco.debugging = false
		ui.log('debugging disabled')
	end, 'nodebug')

	cmds.add('test', function()
		local rng = choco.constants.rng
		ui.log('this is a test!', 0, Color3.fromRGB(rng:NextInteger(0, 255), rng:NextInteger(0, 255), rng:NextInteger(0, 255)))
	end)

	cmds.add('rebindui', function(key)
		local allowedKey = false
		for _, v in next, Enum.KeyCode:GetEnumItems() do
			if v.Name:lower() ~= key:lower() then continue end

			allowedKey = true
			break
		end

		if not allowedKey then
			ui.log(string.format('invalid key "%s"', key), 1, choco.constants.colors.orange)
			return
		end

		choco.scriptsaves.uikeybind = key
		choco.updateSaves('script')
		ui.log(string.format('ui keybind set to "%s"', key:upper()), 0)
	end)

	cmds.add('commands', function()
		ui.cmdsHolder.Visible = not ui.cmdsHolder.Visible
		ui.cmdsContentHolder.Visible = not ui.cmdsContentHolder.Visible

		funcs.showCmdsUi()
	end, 'cmds')

	cmds.add('keybinds', function()
		ui.keybindsHolder.Visible = not ui.keybindsHolder.Visible
		ui.keybindsContentHolder.Visible = not ui.keybindsContentHolder.Visible
	end, 'binds')

	cmds.add('rejoin', function()
		ui.log('rejoining...')

		if #players:GetPlayers() <= 1 then
			tpService:Teleport(choco.game.id, lplr)
			return
		end

		tpService:TeleportToPlaceInstance(choco.game.id, choco.game.job, lplr)
	end, 'rj')

	cmds.add('autorejoin', function()
		if not networkClient:FindFirstChild('ClientReplicator') then
			cmds.exec('rejoin')
		end

		cmds.exec('unautorejoin')

		temp.autorj = choco.connect(networkClient.ChildRemoved, function(inst)
			if not inst:IsA('ClientReplicator') then return end
			cmds.exec('rejoin')
		end)
	end, 'autorj')

	cmds.add('unautorejoin', function()
		if temp.autorj then
			temp.autorj:Disconnect()
			temp.autorj = nil
		end
	end, { 'unautorj', 'noautorejoin', 'noautorj' })

	cmds.add('waypoints', funcs.toggleWaypointUi)

	cmds.add('setwaypoint', function(...)
		local name = {...}
		if not utils.getTable(name) then return end

		funcs.addWaypoint(name, nil, true)
	end, { 'addwaypoint', 'swp' })

	cmds.add('esp', funcs.startESP)

	cmds.add('unesp', funcs.stopESP, 'noesp')

	cmds.add('esptogglehealth', function()
		choco.temp.esphealth = not choco.temp.esphealth
	end)

	cmds.add('esptoggledistance', function()
		choco.temp.espdistance = not choco.temp.espdistance
	end)

	cmds.add('esptoggleteam', function()
		choco.temp.espteam = not choco.temp.espteam
	end)

	cmds.add('fly', function(speed)
		speed = utils.getNumber(speed)
		if speed then temp.flyspeed = speed end

		funcs.startFlyCFrame()
	end)

	cmds.add('flyspeed', function(speed)
		temp.flyspeed = utils.getNumber(speed) or 50
	end)

	cmds.add('flyvelo', function(speed)
		speed = utils.getNumber(speed)
		if speed then temp.flyspeed = speed end

		funcs.startFlyVelocity()
	end, { 'flyvelocity', 'velofly', 'velocityfly' })

	cmds.add('vehiclefly', function(speed)
		speed = utils.getNumber(speed)
		if speed then temp.flyspeed = speed end

		funcs.startFlyVelocity(true)
	end, 'vfly')

	cmds.add('directionalfly', function(speed)
		speed = utils.getNumber(speed)
		if speed then temp.flyspeed = speed end

		choco.funcs.startDetectedFly()
	end, 'dirfly')

	cmds.add('directionalcframefly', function(speed)
		speed = utils.getNumber(speed)
		if speed then temp.flyspeed = speed end

		choco.funcs.startDirectionalFly()
	end, 'dircffly')

	cmds.add('unfly', choco.funcs.disableFly, 'nofly')

	cmds.add('togglefly', function()
		if temp.fly then
			cmds.exec('unfly')
		else
			cmds.exec('fly')
		end
	end)

	cmds.add('toggleflyvelo', function()
		if temp.flyvelo then
			cmds.exec('unfly')
		else
			cmds.exec('flyvelo')
		end
	end)

	cmds.add('togglevfly', function()
		if temp.vflydied then
			cmds.exec('unfly')
		else
			cmds.exec('vehiclefly')
		end
	end)

	cmds.add('toggledirfly', function()
		if temp.flydtc then
			cmds.exec('unfly')
		else
			cmds.exec('directionalfly')
		end
	end)

	cmds.add('toggledircframefly', function()
		if temp.flydir then
			cmds.exec('unfly')
		else
			cmds.exec('directionalcframefly')
		end
	end)

	cmds.add('teleportwalk', function(speed)
		cmds.exec('unteleportwalk')

		speed = utils.getNumber(speed)
		if speed then temp.tpwalkspeed = speed end

		temp.tpwalk = choco.connect(runService.Heartbeat, function(dt)
			local root, hum = utils.getBoth()
			if not root or not hum then return end

			local dir = hum.MoveDirection
			if dir.Magnitude <= 0 then return end

			lplr.Character:TranslateBy(dir * temp.tpwalkspeed * dt * 10)
		end)
	end, { 'tpwalk' })

	cmds.add('unteleportwalk', function()
		if temp.tpwalk then
			temp.tpwalk:Disconnect()
			temp.tpwalk = nil
		end
	end, { 'untpwalk' })

	cmds.add('teleportwalkspeed', function(speed)
		temp.tpwalkspeed = utils.getNumber(speed) or 1.5
	end, 'tpwalkspeed')

	cmds.add('toggletpwalk', function()
		if temp.tpwalk then
			cmds.exec('unteleportwalk')
		else
			cmds.exec('teleportwalk')
		end
	end)

	cmds.add('teleportto', function(player)
		player = utils.getPlayer(player)
		if not player then return end

		local otherRoot = player.Character and player.Character.PrimaryPart
		local localRoot = utils.getRoot()
		if not localRoot or not otherRoot then return end

		localRoot.CFrame = otherRoot.CFrame
	end, { 'goto', 'to' })

	cmds.add('safeteleportto', function(player)
		player = utils.getPlayer(player)
		if not player then return end

		local otherRoot = player.Character and player.Character.PrimaryPart
		local localRoot = utils.getRoot()
		if not localRoot or not otherRoot then return end

		local allowed = false
		task.delay(1.2, function() allowed = true end)

		task.spawn(function()
			while not allowed do
				lplr:RequestStreamAroundAsync(otherRoot.CFrame.Position, 1)
				localRoot.AssemblyLinearVelocity = Vector3.zero
				localRoot.AssemblyAngularVelocity = Vector3.zero
				task.wait()
			end
		end)

		task.delay(0.3, function()
			localRoot.CFrame = otherRoot.CFrame
		end)
	end, { 'safegoto', 'safeto' })

	cmds.add('inviscam', function()
		lplr.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
	end, { 'noclipcam', 'nccam' })

	cmds.add('uninviscam', function()
		lplr.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
	end, { 'unnoclipcam' })

	cmds.add('maxzoom', function(distance)
		if not distance then
			if temp.maxzoom then
				lplr.CameraMaxZoomDistance = temp.maxzoom
			end

			return
		end

		temp.maxzoom = lplr.CameraMaxZoomDistance
		lplr.CameraMaxZoomDistance = tonumber(distance) or temp.maxzoom
	end)

	cmds.add('minzoom', function(distance)
		if not distance then
			if temp.minzoom then
				lplr.CameraMinZoomDistance = temp.maxzoom
			end

			return
		end

		temp.minzoom = lplr.CameraMaxZoomDistance
		lplr.CameraMinZoomDistance = tonumber(distance) or temp.minzoom
	end)

	cmds.add('instantproximityprompts', function()
		if not choco.coreUtils.getFunc('fireproximityprompt') then return end

		temp.instapp = choco.connect(ppService.PromptButtonHoldBegan, function(prompt)
			fireproximityprompt(prompt)
		end)
	end, { 'instantpp', 'instapp' })

	cmds.add('uninstantproximityprompts', function()
		if temp.instapp then
			temp.instapp:Disconnect()
			temp.instapp = nil
		end
	end, { 'uninstantpp', 'uninstapp' })
end

do -- keybinds
	local keybindWorthy = {}
	local doing
	local savedBinds = {}

	for i in next, cmds.all do
		if i:sub(1, 6) ~= 'toggle' then continue end
		table.insert(keybindWorthy, i)
	end

	local function onClicked(bind)
		if doing and doing ~= bind then
			doing.Text = savedBinds[doing] or 'UNKNOWN'
		end

		doing = bind

		if choco.temp.selectingbind then
			choco.temp.selectingbind:Disconnect()
			choco.temp.selectingbind = nil
		end

		bind.Text = 'PRESS A KEY'

		choco.temp.selectingbind = choco.connect(inputService.InputBegan, function(input)
			local keyName = input.KeyCode.Name:upper()

			choco.saves.keybinds['toggle' .. bind.Parent.Text] = keyName
			choco.updateSaves()

			bind.Text = keyName
			savedBinds[bind] = keyName

			doing = nil

			if choco.temp.selectingbind then
				choco.temp.selectingbind:Disconnect()
				choco.temp.selectingbind = nil
			end
		end)
	end

	for _, v in next, keybindWorthy do
		local label = choco.make('TextLabel', {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -10, 0, 27),
			Font = Enum.Font.Code,
			Text = string.sub(v, 7),
			TextColor3 = choco.constants.colors.white,
			TextSize = 16,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = ui.keybindsContentHolder
		})

		choco.make('UIPadding', {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			Parent = label
		})

		local keybind = choco.make('TextButton', {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = Color3.new(0.2, 0.2, 0.2),
			Position = UDim2.new(1, 10, 0.5, 0),
			Size = UDim2.new(0.145, 90, 0.75, 0),
			Font = Enum.Font.Code,
			Text = choco.saves.keybinds[v] or 'UNKNOWN',
			TextColor3 = choco.constants.colors.white,
			TextSize = 16,
			Parent = label
		})

		choco.connect(keybind.MouseButton1Click, function()
			onClicked(keybind)
		end)
	end
end

do -- end
	ui.log(string.format('loaded in %.02f seconds!', tick() - startLoad), 0, choco.constants.colors.green)
	ui.log(string.format('click %s to toggle the ui', choco.scriptsaves.uikeybind), 0)

	choco.ui, choco.cmds = ui, cmds
	getgenv().choco = choco

	task.spawn(function()
		local url = 'https://raw.githubusercontent.com/ChocolateDrink/chocolateLine/refs/heads/main/version.json'
		local res, err = choco.coreUtils.execRaw(url, true)
		if err or not res then return end

		res = choco.coreUtils.decode(res)
		if not res then return end

		if res.ver == scriptVer then return end
		if res.critical == scriptVer then
			choco.unload()
			hookmetamethod(game, '__index', function() end)

			if messagebox then
				messagebox('you are using a outdated version of the script that contains a critial error', 'chocolate line', 0)
			else
				choco.game.me:Kick('[chocolate line]: you are using a outdated version of the script that contains a critial error')
			end

			while true do end
			game:Shutdown()
		else
			ui.log('you are using a outdated version of the script', 2, choco.constants.colors.orange)
			ui.log(string.format('your version: %s, expected version: %s', scriptVer, res.ver), 2, choco.constants.colors.orange)
		end
	end)
end