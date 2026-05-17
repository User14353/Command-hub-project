--[[
╔══════════════════════════════════════════════════════════════════════════════╗
║                    COMMAND MENU  —  Client-Side                              ║
║                                                                              ║
║  Chat prefix  _<command>  or any alias to run a command                      ║
║  _open / _close           to show / hide the menu                            ║
║                                                                              ║
║  ── ADDING YOUR OWN COMMANDS ──────────────────────────────────────────────  ║
║                                                                              ║
║  {                                                                           ║
║      name = "cmd",              -- string, OR a table of aliases:            ║
║      name = {"cmd","c","alias"},-- first entry is the display name           ║
║      help = "description",                                                   ║
║      args = "<arg>",            -- hint shown in GUI  ("" for none)          ║
║      run  = function(args) end, -- args = everything typed after the cmd     ║
║  },                                                                          ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
--]]

-- ════════════════════════════════════════════════════════════════════════════
--  CONFIGURATION
-- ════════════════════════════════════════════════════════════════════════════

local PREFIX = "_"

-- ════════════════════════════════════════════════════════════════════════════
--  SERVICES
-- ════════════════════════════════════════════════════════════════════════════

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local TeleportService  = game:GetService("TeleportService")
local StarterGui       = game:GetService("StarterGui")
local HttpService      = game:GetService("HttpService")
local TextChatService  = game:GetService("TextChatService")

local lp   = Players.LocalPlayer
local pgui = lp:WaitForChild("PlayerGui")
local cam  = workspace.CurrentCamera

-- ════════════════════════════════════════════════════════════════════════════
--  SHARED HELPERS
-- ════════════════════════════════════════════════════════════════════════════

local function notify(title, body, dur)
    StarterGui:SetCore("SendNotification", {
        Title    = title,
        Text     = body,
        Duration = dur or 3,
    })
end

local function sendChat(msg)
    pcall(function()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local ch = TextChatService:FindFirstChild("TextChannels")
            local rb = ch and ch:FindFirstChild("RBXGeneral")
            if rb then rb:SendAsync(msg); return end
        end
        game:GetService("ReplicatedStorage")
            .DefaultChatSystemChatEvents
            .SayMessageRequest:FireServer(msg, "All")
    end)
end

local function getHRP()
    local c = lp.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHum()
    local c = lp.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- ════════════════════════════════════════════════════════════════════════════
--  NAME HELPERS
--  cmd.name can be a string OR a table of aliases.
--  These two functions make everything else not have to care which it is.
-- ════════════════════════════════════════════════════════════════════════════

-- Returns the primary display name (always a string)
local function primaryName(cmd)
    if type(cmd.name) == "table" then
        return cmd.name[1] or "?"
    end
    return tostring(cmd.name)
end

-- Returns true if `text` matches any alias (case-insensitive)
local function nameMatches(cmd, text)
    local t = text:lower()
    if type(cmd.name) == "table" then
        for _, alias in ipairs(cmd.name) do
            if tostring(alias):lower() == t then return true end
        end
        return false
    end
    return tostring(cmd.name):lower() == t
end

-- Returns true if `text` is contained in any alias or the help string
local function nameContains(cmd, text)
    local t = text:lower()
    if cmd.help:lower():find(t, 1, true) then return true end
    if type(cmd.name) == "table" then
        for _, alias in ipairs(cmd.name) do
            if tostring(alias):lower():find(t, 1, true) then return true end
        end
        return false
    end
    return tostring(cmd.name):lower():find(t, 1, true) ~= nil
end

-- ════════════════════════════════════════════════════════════════════════════
--  COMMANDS TABLE
-- ════════════════════════════════════════════════════════════════════════════

local COMMANDS = {

    {
        name = {"help", "h", "commands"},
        help = "Reminder about the menu",
        args = "",
        run = function(_)
            notify("Commands", "Type "..PREFIX.."open or press Home on your Keypad.", 4)
        end,
    },

    {
        name = {"open", "o", "menu"},
        help = "Open the command menu",
        args = "",
        run = function(_) end,
    },
    {
        name = {"close", "c", "hide"},
        help = "Close the command menu",
        args = "",
        run = function(_) end,
    },

    {
        name = {"serverhop", "sh", "hop"},
        help = "Teleport to a random server",
        args = "",
        run = function(_)
            notify("Server Hop", "Finding a server…")
            local pid = game.PlaceId
            local ok, res = pcall(function()
                return HttpService:JSONDecode(game:HttpGet(
                    ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100")
                    :format(pid)))
            end)

            if ok and res and res.data and #res.data > 0 then
                local pool = {}
                for _, s in ipairs(res.data) do
                    if s.id ~= game.JobId and s.playing < s.maxPlayers then
                        table.insert(pool, s.id)
                    end
                end
                if #pool > 0 then
                    TeleportService:TeleportToPlaceInstance(pid, pool[math.random(1,#pool)], lp)
                else
                    notify("Server Hop", "No other servers found.")
                end
            else
                TeleportService:Teleport(pid, lp)
            end
        end,
    },

    {
        name = {"lowserver", "ls", "low"},
        help = "Join the server with fewest players",
        args = "",
        run = function(_)
            notify("Low Server", "Searching…")
            local pid = game.PlaceId
            local ok, res = pcall(function()
                return HttpService:JSONDecode(game:HttpGet(
                    ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100")
                    :format(pid)))
            end)

            if ok and res and res.data and #res.data > 0 then
                local best, bestN = nil, math.huge
                for _, s in ipairs(res.data) do
                    if s.id ~= game.JobId and s.playing < bestN then
                        best = s.id
                        bestN = s.playing
                    end
                end

                if best then
                    notify("Low Server", ("Joining: %d players"):format(bestN))
                    TeleportService:TeleportToPlaceInstance(pid, best, lp)
                else
                    notify("Low Server", "No other servers found.")
                end
            else
                notify("Low Server", "Could not fetch server list.")
            end
        end,
    },

    {
        name = {"rejoin", "rj", "re"},
        help = "Rejoin the current game",
        args = "",
        run = function(_)
            notify("Rejoin", "Rejoining…")
            TeleportService:Teleport(game.PlaceId, lp)
        end,
    },

    {
        name = {"ws", "speed", "walkspeed"},
        help = "Set walk speed",
        args = "<speed>",
        run = function(args)
            local n = tonumber(args)
            if not n then notify("WalkSpeed", "Usage: "..PREFIX.."ws <number>"); return end
            local h = getHum()
            if h then h.WalkSpeed = n; notify("WalkSpeed", "Set to "..n) end
        end,
    },

    {
        name = {"jp", "jump", "jumppower"},
        help = "Set jump power",
        args = "<power>",
        run = function(args)
            local n = tonumber(args)
            if not n then notify("JumpPower", "Usage: "..PREFIX.."jp <number>"); return end
            local h = getHum()
            if h then h.JumpPower = n; notify("JumpPower", "Set to "..n) end
        end,
    },

    {
        name = {"noclip", "nc", "clip"},
        help = "Toggle noclip",
        args = "",
        run = (function()
            local on, conn = false, nil
            return function(_)
                on = not on
                if on then
                    conn = RunService.Stepped:Connect(function()
                        local c = lp.Character
                        if c then
                            for _, p in ipairs(c:GetDescendants()) do
                                if p:IsA("BasePart") then
                                    p.CanCollide = false
                                end
                            end
                        end
                    end)
                    notify("Noclip", "ON")
                else
                    if conn then conn:Disconnect(); conn = nil end
                    notify("Noclip", "OFF")
                end
            end
        end)(),
    },

    {
        name = {"fly", "f", "flight"},
        help = "Toggle fly (WASD + Space/LCtrl)",
        args = "",
        run = (function()
            local on, bv, bg, conn = false, nil, nil, nil
            return function(_)
                on = not on
                local hrp = getHRP()
                if not hrp then return end

                if on then
                    hrp.Velocity = Vector3.zero

                    bv = Instance.new("BodyVelocity")
                    bv.MaxForce = Vector3.new(1e5,1e5,1e5)
                    bv.Parent = hrp

                    bg = Instance.new("BodyGyro")
                    bg.MaxTorque = Vector3.new(1e5,1e5,1e5)
                    bg.D = 100
                    bg.Parent = hrp

                    conn = RunService.RenderStepped:Connect(function()
                        local mv = Vector3.zero
                        if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv = mv + cam.CFrame.LookVector end
                        if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv = mv - cam.CFrame.LookVector end
                        if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv = mv - cam.CFrame.RightVector end
                        if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv = mv + cam.CFrame.RightVector end

                        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv = mv + Vector3.new(0,1,0) end
                        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv = mv - Vector3.new(0,1,0) end

                        bv.Velocity = mv.Magnitude > 0 and mv.Unit * 50 or Vector3.zero
                        bg.CFrame = cam.CFrame
                    end)

                    notify("Fly", "ON")
                else
                    if conn then conn:Disconnect(); conn = nil end
                    if bv then bv:Destroy(); bv = nil end
                    if bg then bg:Destroy(); bg = nil end
                    notify("Fly", "OFF")
                end
            end
        end)(),
    },

    {
        name = {"invis", "ghost", "hide"},
        help = "Toggle local character invisibility",
        args = "",
        run = (function()
            local hidden = false
            return function(_)
                hidden = not hidden
                local c = lp.Character
                if not c then return end

                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then
                        p.LocalTransparencyModifier = hidden and 1 or 0
                    end
                end

                notify("Invisible", hidden and "ON" or "OFF")
            end
        end)(),
    },

    {
        name = {"goto", "tp", "to"},
        help = "Teleport to a player",
        args = "<name>",
        run = function(args)
            local q = args:match("^%s*(.-)%s*$"):lower()
            local target

            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= lp and (p.Name:lower():find(q,1,true) or p.DisplayName:lower():find(q,1,true)) then
                    target = p
                    break
                end
            end

            if not target then notify("Goto", "Not found: "..q); return end

            local hrp = getHRP()
            local tp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")

            if hrp and tp then
                hrp.CFrame = tp.CFrame + Vector3.new(0,3,0)
                notify("Goto", "Teleported to "..target.Name)
            end
        end,
    },

    {
        name = {"bring", "summon", "pull"},
        help = "Bring a player to you",
        args = "<name>",
        run = function(args)
            local q = args:match("^%s*(.-)%s*$"):lower()
            local target

            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= lp and (p.Name:lower():find(q,1,true) or p.DisplayName:lower():find(q,1,true)) then
                    target = p
                    break
                end
            end

            if not target then notify("Bring", "Not found: "..q); return end

            local hrp = getHRP()
            local tp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")

            if hrp and tp then
                tp.CFrame = hrp.CFrame + Vector3.new(2,0,2)
                notify("Bring", "Brought "..target.Name)
            end
        end,
    },

    {
        name = {"hub", "script", "loader"},
        help = "Open script hub",
        args = "",
        run = function(_)
            pcall(function()
                if readfile then
                    loadstring(game:HttpGet("https://raw.githubusercontent.com/User14353/Command-hub-project/refs/heads/main/Script%20hub.luau"))()
                end
            end)
        end,
    },

    {
        name = {"animator", "anim", "cframe"},
        help = "Open animator",
        args = "",
        run = function(_)
            pcall(function()
                if readfile then
                    loadstring(game:HttpGet("https://raw.githubusercontent.com/User14353/Animator/refs/heads/main/Animator%20Final"))()
                end
            end)
        end,
    },

    {
        name = {"reset", "rs", "respawn"},
        help = "Reset character",
        args = "",
        run = function(_)
            local h = getHum()
            if h then h.Health = 0 end
        end,
    },

    {
        name = {"follow", "track", "f"},
        help = "Follow a player",
        args = "<name>",
        run = (function()
            local active = false
            local conn = nil
            local target = nil

            return function(args)
                active = not active

                if active then
                    local query = (args or ""):lower()

                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= lp and (p.DisplayName:lower():find(query,1,true) or p.Name:lower():find(query,1,true)) then
                            target = p
                            break
                        end
                    end

                    if not target then return end

                    conn = RunService.RenderStepped:Connect(function()
                        local hrp = getHRP()
                        local thrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")

                        if hrp and thrp then
                            hrp.CFrame = thrp.CFrame * CFrame.new(0,0,3.5)
                        end
                    end)
                else
                    if conn then conn:Disconnect() end
                    conn = nil
                    target = nil
                end
            end
        end)(),
    },
		{ 
			name = "dance", 
			help = "Toggle a dance emote (cycles through 3)", 
			args = "", 
			run = (function() 
				local track = nil 
				local dances = { "rbxassetid://507771019", "rbxassetid://507776043", "rbxassetid://507777268", } 
				local idx = 0 return function(_) local hum = getHum() if not hum then notify("Dance", "No humanoid."); 
					return end 
				if track and track.IsPlaying then 
					track:Stop() track = nil notify("Dance", "Stopped.") 
					return end 
				idx = (idx % #dances) + 1 
				
				local anim = Instance.new("Animation") 
				anim.AnimationId = dances[idx] 
				local ok, 
				loaded = pcall(function() 
					return hum:LoadAnimation(anim) end) 
					if not ok or not loaded then 
						notify("Dance", "Load failed: "..tostring(loaded)) 
						return end 
					track = loaded 
					track.Priority = Enum.AnimationPriority.Action 
					track:Play() 
					notify("Dance", "Dancing ("..idx.."/"..#dances..") — run again to stop/switch.") 
				end 
			end)(), 
		},

		{
			name = "trivia",
			help = "Start/stop trivia game with chat answers",
			args = "",
			run = (function()
					local active = false
					local currentAnswer = nil -- normalised form
					local chatConns = {} -- one RBXScriptConnection per player
					local playerAddedConn = nil

					local ALL_QUESTIONS = {
							{"What planet is known as the Red Planet?", "mars"},
							{"How many hearts does an octopus have?", "3"},
							{"What is 5 + 7?", "12"},
							{"What is the capital of Australia?", "canberra"},
							{"What gas do plants absorb from the air?", "carbon dioxide"},
							{"What is the largest ocean?", "pacific"},
							{"What is H2O commonly known as?", "water"},
							{"How many legs does a spider have?", "8"},
							{"What year did Roblox release?", "2006"},
							{"What is the square root of 81?", "9"},
							{"What is the fastest land animal?", "cheetah"},
							{"What is the tallest mountain?", "everest"},
							{"What is the currency of Japan?", "yen"},
							{"How many continents are there?", "7"},
							{"What is the boiling point of water in Celsius?", "100"},
							{"What planet is closest to the sun?", "mercury"},
							{"What colour do you get mixing red and blue?", "purple"},
							{"What is the capital of France?", "paris"},
							{"How many days are in a leap year?", "366"},
							{"What is the hardest natural substance?", "diamond"},
							{"What is the biggest mammal?", "blue whale"},
							{"What language has the most native speakers?", "mandarin"},
							{"What is 9 x 9?", "81"},
							{"What is the capital of Italy?", "rome"},
							{"What organ pumps blood?", "heart"},
							{"What is the freezing point of water in Celsius?", "0"},
							{"What planet is famous for its rings?", "saturn"},
							{"What is the main gas in Earth's atmosphere?", "nitrogen"},
							{"How many bones does an adult human have?", "206"},
							{"What is the capital of Germany?", "berlin"},
							{"What fruit features in the saying a day keeps the doctor away?", "apple"},
							{"What is 3 squared?", "9"},
							{"What is the largest hot desert?", "sahara"},
							{"What is the smallest prime number?", "2"},
							{"What is the capital of Spain?", "madrid"},
							{"What is 100 divided by 4?", "25"},
							{"What is the official language of Brazil?", "portuguese"},
							{"What ocean lies between Africa and Australia?", "indian"},
							{"What is 15 + 15?", "30"},
							{"What is the capital of the USA?", "washington"},
							{"What animal is known as king of the jungle?", "lion"},
							{"What is the square root of 144?", "12"},
							{"What is the largest continent?", "asia"},
							{"What is the capital of China?", "beijing"},
							{"What is 7 x 7?", "49"},
							{"What planet appears blue from space?", "earth"},
							{"What is the smallest country in the world?", "vatican"},
							{"What is the chemical symbol for gold?", "au"},
							{"What is 50 + 50?", "100"},
							{"What is the capital of Russia?", "moscow"},
							{"What is the fastest fish?", "sailfish"},
							{"What is 2 + 2 x 2?", "6"},
							{"What is the primary source of energy for Earth?", "sun"},
							{"What is the capital of India?", "new delhi"},
							{"What is the longest river in the world?", "nile"},
							{"What is 8 x 8?", "64"},

							-- 20 new questions
							{"What is the capital of Japan?", "tokyo"},
							{"What is the capital of Canada?", "ottawa"},
							{"How many sides does a hexagon have?", "6"},
							{"What is the chemical symbol for water?", "h2o"},
							{"What is the largest planet in the solar system?", "jupiter"},
							{"What is the capital of Brazil?", "brasilia"},
							{"How many players are on a standard football team?", "11"},
							{"What is the chemical symbol for iron?", "fe"},
							{"What is the smallest planet in the solar system?", "mercury"},
							{"What is the capital of Egypt?", "cairo"},
							{"How many strings does a standard guitar have?", "6"},
							{"What is the powerhouse of the cell?", "mitochondria"},
							{"What is the capital of South Korea?", "seoul"},
							{"What is the square root of 256?", "16"},
							{"What is 13 x 13?", "169"},
							{"What is the capital of Mexico?", "mexico city"},
							{"How many hours are in one week?", "168"},
							{"What is the chemical symbol for silver?", "ag"},
							{"What is the largest organ in the human body?", "skin"},
							{"What is the capital of Argentina?", "buenos aires"},
					}

					local RECENCY = 10
					local recentIdx = {}
					local pool = {}

					local function norm(s)
							return tostring(s):lower():gsub("%s+", "")
					end

					local function rebuildPool()
							local blocked = {}

							for _, i in ipairs(recentIdx) do
									blocked[i] = true
							end

							pool = {}

							for i = 1, #ALL_QUESTIONS do
									if not blocked[i] then
											table.insert(pool, i)
									end
							end

							-- Fisher-Yates shuffle
							for i = #pool, 2, -1 do
									local j = math.random(1, i)
									pool[i], pool[j] = pool[j], pool[i]
							end
					end

					local function pickNext()
							if #pool == 0 then
									rebuildPool()
							end

							local i = table.remove(pool, 1)
							table.insert(recentIdx, i)

							if #recentIdx > RECENCY then
									table.remove(recentIdx, 1)
							end

							return ALL_QUESTIONS[i]
					end

					local scores = {}

					local function displayName(p)
							return p and (p.DisplayName ~= "" and p.DisplayName or p.Name) or "?"
					end

					local function showLeaderboard()
							local list = {}

							for p, s in pairs(scores) do
									if p and p.Parent then
											table.insert(list, { n = displayName(p), s = s })
									end
							end

							table.sort(list, function(a, b)
									return a.s > b.s
							end)

							local out = "🏆 Scores: "

							for i = 1, math.min(5, #list) do
									out = out .. i .. ". " .. list[i].n .. "=" .. list[i].s .. " "
							end

							sendChat(out)
					end

					local function askQuestion()
							if not active then return end

							local q = pickNext()
							currentAnswer = norm(q[2])

							sendChat("🧠 " .. q[1])
					end

					local function connectPlayer(p)
							local c = p.Chatted:Connect(function(msg)
									if not active or not currentAnswer then return end

									if norm(msg) == currentAnswer then
											scores[p] = (scores[p] or 0) + 1
											sendChat("✅ " .. displayName(p) ..
													" got it! (answer: " .. currentAnswer .. ") total: " .. scores[p])

											showLeaderboard()
											task.wait(0.8)
											askQuestion()
									end
							end)

							table.insert(chatConns, c)
					end

					local function startTrivia()
							active = true
							scores = {}
							recentIdx = {}
							pool = {}

							for _, p in ipairs(Players:GetPlayers()) do
									connectPlayer(p)
							end

							playerAddedConn = Players.PlayerAdded:Connect(function(p)
									if active then
											connectPlayer(p)
									end
							end)

							sendChat("🎮 Trivia started! Answer in chat. Type "..PREFIX.."trivia to stop.")
							task.wait(1)
							askQuestion()
					end

					local function stopTrivia()
							active = false
							currentAnswer = nil

							for _, c in ipairs(chatConns) do
									pcall(function()
											c:Disconnect()
									end)
							end

							chatConns = {}

							if playerAddedConn then
									playerAddedConn:Disconnect()
									playerAddedConn = nil
							end

							showLeaderboard()
							sendChat("🛑 Trivia ended!")
					end

					return function(_)
							if active then
									stopTrivia()
							else
									startTrivia()
							end
					end
			end)(),
		},

    {
        name = {"orbit", "circle", "spin"},
        help = "Orbit player",
        args = "<name>",
				run = (function()
						local active = false
						local conn = nil
						local target = nil
						local angle = 0

						return function(args)
								active = not active

								if active then
										local name = (args or ""):match("^%s*(.-)%s*$")
										local query = name:lower()

										target = nil

										-- pass 1: DisplayName
										for _, p in ipairs(Players:GetPlayers()) do
												if p.DisplayName:lower():find(query, 1, true) then
														target = p
														break
												end
										end

										-- pass 2: Username fallback
										if not target then
												for _, p in ipairs(Players:GetPlayers()) do
														if p.Name:lower():find(query, 1, true) then
																target = p
																break
														end
												end
										end

										if not target then
												active = false
												notify("Orbit", "Player not found.")
												return
										end

										conn = RunService.RenderStepped:Connect(function(dt)
												local hrp = getHRP()
												local thrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")

												if hrp and thrp then
														angle = angle + dt * 2

														local offset = Vector3.new(
																math.cos(angle) * 6,
																2,
																math.sin(angle) * 6
														)

														hrp.CFrame = CFrame.new(thrp.Position + offset, thrp.Position)
												end
										end)

										notify("Orbit", "ON")

								else
										if conn then
												conn:Disconnect()
												conn = nil
										end

										target = nil
										angle = 0
										notify("Orbit", "OFF")
								end
						end
				end)(),
		},

    {
        name = {"stare", "look", "watch"},
        help = "Look at player",
        args = "<name>",
				run = (function()
						local active = false
						local conn = nil
						local target = nil

						return function(args)
								active = not active

								if active then
										local name = (args or ""):match("^%s*(.-)%s*$")
										local query = name:lower()

										target = nil

										-- pass 1: DisplayName
										for _, p in ipairs(Players:GetPlayers()) do
												if p.DisplayName:lower():find(query, 1, true) then
														target = p
														break
												end
										end

										-- pass 2: Username fallback
										if not target then
												for _, p in ipairs(Players:GetPlayers()) do
														if p.Name:lower():find(query, 1, true) then
																target = p
																break
														end
												end
										end

										if not target then
												active = false
												notify("Stare", "Player not found.")
												return
										end

										conn = RunService.RenderStepped:Connect(function()
												local hrp = getHRP()
												local thrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")

												if hrp and thrp then
														hrp.CFrame = CFrame.new(hrp.Position, thrp.Position)
												end
										end)

										notify("Stare", "ON")

								else
										if conn then
												conn:Disconnect()
												conn = nil
										end

										target = nil
										notify("Stare", "OFF")
								end
						end
				end)(),
		},

    {
        name = {"jumpspin", "jspin", "spinjump"},
        help = "Spin jump",
        args = "",
        run = function(_)
            local hrp = getHRP()
            local hum = getHum()

            if hrp and hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
                for i = 1, 50 do
                    hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(40), 0)
                    task.wait()
                end
            end
        end,
    },

    {
        name = {"fling", "yeet", "spinfast"},
        help = "Spin fast",
        args = "",
        run = (function()
            local on = false
            local conn

            return function()
                on = not on

                local hrp = getHRP()
                if not hrp then return end

                if on then
                    conn = RunService.RenderStepped:Connect(function()
                        hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(150), 0)
                    end)
                else
                    if conn then conn:Disconnect() end
                end
            end
        end)(),
    },

		{
			name = {"ToolKill", "TK", "Remove"},
			help = "Kill other players",
			args = "<name>",
			run = function(args)
					local q = args:match("^%s*(.-)%s*$"):lower()
					local target

					for _, p in ipairs(Players:GetPlayers()) do
							if p ~= lp and (p.Name:lower():find(q,1,true) or p.DisplayName:lower():find(q,1,true)) then
									target = p
									break
							end
					end

					if not target then notify("Goto", "Not found: "..q); return end

					local hrp = getHRP()
					local tp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")

					if hrp and tp then
							hrp.CFrame = tp.CFrame + Vector3.new(0,0,0)
							notify("Goto", "Teleported to "..target.Name)
					end
					function GetPlr(name)
							local plrs = game.Players
							local lp = plrs.LocalPlayer

							if not name or name == "" then return end

							name = name:lower():gsub("([%.%+%-%*%?%[%]%^%$%(%)%%])", "%%%1")

							for _, a in plrs:GetPlayers() do
									if a ~= lp then
											local char = a.Character
											if char then
													local hrp = char:FindFirstChild("HumanoidRootPart")
													local hum = char:FindFirstChild("Humanoid")
													if hrp and hum and hum.Health > 1 then
															local n = a.Name:lower()
															local d = a.DisplayName:lower()
															if n:find("^" .. name) or d:find("^" .. name) then
																	return a
															end
													end
											end
									end
							end
					end

					function FlingUser(name)
							if not name or name == "" then return end

							local target = GetPlr(name)
							if not target then return end -- IMPORTANT FIX

							local plrs = game.Players

							local targetchar = target.Character
							if not targetchar then return end

							local targethead = targetchar:WaitForChild("HumanoidRootPart")

							local lp = plrs.LocalPlayer
							local char = lp.Character
							if not char then return end

							local hrp = char:FindFirstChild("HumanoidRootPart")
							if not hrp then return end

							local backpack = lp.Backpack

							local random = math.random
							local v3 = Vector3.new

							char.Archivable = true

							local Clone = char:Clone()
							task.wait(0.1)

							lp.Character = Clone
							lp.Character = char

							hrp.AssemblyLinearVelocity = v3(0,0,0)

							local oldHum = char:FindFirstChildOfClass("Humanoid")
							if oldHum then oldHum:Destroy() end

							task.wait(0.1)

							local Humanoid = Instance.new("Humanoid")
							Humanoid.Parent = char

							task.wait(0.2)

							local Tool =
									char:FindFirstChildOfClass("Tool")
									or backpack:FindFirstChildOfClass("Tool")

							if not Tool then return end

							local Arm

							if char:FindFirstChild("Right Arm") then
									Arm = char["Right Arm"].CFrame * CFrame.new(0, -1, 0)
							else
									Arm = char["RightHand"].CFrame * CFrame.new(0, -1, 0)
							end

							Tool.Grip = Arm:ToObjectSpace(targethead.CFrame):Inverse()
							Tool.Parent = char

							repeat
									task.wait()
							until not Tool or Tool.Parent == workspace or Tool.Parent == targetchar

							Tool.Grip = Arm:ToObjectSpace(CFrame.new(0, 1e8, 0)):Inverse()

							hrp.CFrame = hrp.CFrame * CFrame.new(random(-100,100),0,random(-100,100))

							task.wait(0.01)

							lp.Character = nil
							Humanoid.Health = 0
					end

					-- ✅ USE COMMAND ARGUMENT
					FlingUser(args)

			end
		},

    {
        name = {"randomtp", "rtp", "randtp"},
        help = "Random teleport",
        args = "",
        run = function(_)
            local hrp = getHRP()
            if hrp then
                hrp.CFrame = hrp.CFrame + Vector3.new(math.random(-200,200),0,math.random(-200,200))
            end
        end,
    },
		{
			name = {"AutoRadiusKill", "ARK", "SelfDefence"},
			help = "Teleports to players in radius, executes code, and returns home",
			args = "<radius>",
			run = function(args)
					-- Parse radius from arguments, default to 20 studs if blank
					local radius = tonumber(args:match("^%s*(.-)%s*$")) or 20
					
					-- Toggle logic: Running the command again turns it off
					if _G.AutoRadiusLoop then
							_G.AutoRadiusLoop = false
							notify("AutoRadius", "Disabled")
							return
					else
							_G.AutoRadiusLoop = true
							notify("AutoRadius", "Enabled with radius: " .. radius)
					end

					-- Teleport and Cycle Function
					local function ActionCycle(targetPlayer)
							local lp = game.Players.LocalPlayer
							local char = lp.Character
							if not char then return end

							local hrp = char:FindFirstChild("HumanoidRootPart")
							local hum = char:FindFirstChildOfClass("Humanoid")
							if not hrp or not hum then return end

							local targetChar = targetPlayer.Character
							if not targetChar then return end
							local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
							if not targetHrp then return end

							-- 1. SAVE YOUR ORIGINAL POSITION
							local originalCFrame = hrp.CFrame

							-- 2. TELEPORT TO THE TARGET
							hrp.CFrame = targetHrp.CFrame
							task.wait(0.05) -- Tiny delay to ensure physics syncs up

							function GetPlr(name)
									local plrs = game.Players
									local lp = plrs.LocalPlayer

									if not name or name == "" then return end

									name = name:lower():gsub("([%.%+%-%*%?%[%]%^%$%(%)%%])", "%%%1")

									for _, a in plrs:GetPlayers() do
											if a ~= lp then
													local char = a.Character
													if char then
															local hrp = char:FindFirstChild("HumanoidRootPart")
															local hum = char:FindFirstChild("Humanoid")
															if hrp and hum and hum.Health > 1 then
																	local n = a.Name:lower()
																	local d = a.DisplayName:lower()
																	if n:find("^" .. name) or d:find("^" .. name) then
																			return a
																	end
															end
													end
											end
									end
							end

							function FlingUser(name)
									if not name or name == "" then return end

									local target = GetPlr(name)
									if not target then return end -- IMPORTANT FIX

									local plrs = game.Players

									local targetchar = target.Character
									if not targetchar then return end

									local targethead = targetchar:WaitForChild("HumanoidRootPart")

									local lp = plrs.LocalPlayer
									local char = lp.Character
									if not char then return end

									local hrp = char:FindFirstChild("HumanoidRootPart")
									if not hrp then return end

									local backpack = lp.Backpack

									local random = math.random
									local v3 = Vector3.new

									char.Archivable = true

									local Clone = char:Clone()
									task.wait(0.1)

									lp.Character = Clone
									lp.Character = char

									hrp.AssemblyLinearVelocity = v3(0,0,0)

									local oldHum = char:FindFirstChildOfClass("Humanoid")
									if oldHum then oldHum:Destroy() end

									task.wait(0.1)

									local Humanoid = Instance.new("Humanoid")
									Humanoid.Parent = char

									task.wait(0.2)

									local Tool =
											char:FindFirstChildOfClass("Tool")
											or backpack:FindFirstChildOfClass("Tool")

									if not Tool then return end

									local Arm

									if char:FindFirstChild("Right Arm") then
											Arm = char["Right Arm"].CFrame * CFrame.new(0, -1, 0)
									else
											Arm = char["RightHand"].CFrame * CFrame.new(0, -1, 0)
									end

									Tool.Grip = Arm:ToObjectSpace(targethead.CFrame):Inverse()
									Tool.Parent = char

									repeat
											task.wait()
									until not Tool or Tool.Parent == workspace or Tool.Parent == targetchar

									Tool.Grip = Arm:ToObjectSpace(CFrame.new(0, 1e8, 0)):Inverse()

									hrp.CFrame = hrp.CFrame * CFrame.new(random(-100,100),0,random(-100,100))

									task.wait(0.01)

									lp.Character = nil
									Humanoid.Health = 0
							end

							-- ✅ USE COMMAND ARGUMENT
							FlingUser(args)

							task.wait(0.05) -- Give your kill code a brief moment to impact the target

							-- 3. FAST LOCAL RESPAWN
							lp.Character = nil
							hum.Health = 0
							
							-- 4. WAIT FOR RESPAWN AND TELEPORT BACK HOME
							local newChar = lp.CharacterAdded:Wait()
							local newHrp = newChar:WaitForChild("HumanoidRootPart", 5)
							
							if newHrp and originalCFrame then
									task.wait(0.05) -- Brief delay so the engine registers the new character position
									newHrp.CFrame = originalCFrame
									notify("AutoRadius", "Returned back to original position")
							end
					end

					-- Active Automation Loop
					task.spawn(function()
							while _G.AutoRadiusLoop do
									task.wait(0.3) -- Scanning speed (adjust higher if you experience lag)
									local lp = game.Players.LocalPlayer
									local char = lp.Character
									local hrp = char and char:FindFirstChild("HumanoidRootPart")
									local hum = char and char:FindFirstChildOfClass("Humanoid")

									-- Only search for targets if you are currently alive and ready
									if hrp and hum and hum.Health > 0 then
											for _, player in ipairs(game.Players:GetPlayers()) do
													if player ~= lp and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
															local tHrp = player.Character.HumanoidRootPart
															local tHum = player.Character:FindFirstChildOfClass("Humanoid")
															
															if tHum and tHum.Health > 0 then
																	-- Check distance between you and the enemy player
																	local distance = (hrp.Position - tHrp.Position).Magnitude
																	if distance <= radius then
																			ActionCycle(player)
																			break -- Pauses scanning loop to finish the teleport/respawn cycle cleanly
																	end
															end
													end
											end
									end
							end
					end)
			end
		},


}   -- ← end of COMMANDS table

-- ════════════════════════════════════════════════════════════════════════════
--  GUI THEME
-- ════════════════════════════════════════════════════════════════════════════

local TH = {
    BG       = Color3.fromHex("#0e0e13"),
    Panel    = Color3.fromHex("#16161f"),
    Row      = Color3.fromHex("#1c1c28"),
    RowHover = Color3.fromHex("#232334"),
    Accent   = Color3.fromHex("#7c6dfa"),
    AccentLo = Color3.fromHex("#3d3675"),
    Border   = Color3.fromHex("#2a2a3d"),
    TextPri  = Color3.fromHex("#e8e8f0"),
    TextSec  = Color3.fromHex("#7070a0"),
    TextDis  = Color3.fromHex("#3a3a55"),
    Green    = Color3.fromHex("#4ade80"),
    Red      = Color3.fromHex("#f87171"),
}

-- ════════════════════════════════════════════════════════════════════════════
--  GUI HELPERS
-- ════════════════════════════════════════════════════════════════════════════

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = p
end

local function stroke(p, col, thick)
    local s = Instance.new("UIStroke")
    s.Color     = col   or TH.Border
    s.Thickness = thick or 1
    s.Parent    = p
end

local function mkF(parent, col, sz, pos, name, r, zi)
    local f = Instance.new("Frame")
    f.BackgroundColor3 = col  or TH.Panel
    f.BorderSizePixel  = 0
    f.Size             = sz   or UDim2.new(1,0,1,0)
    f.Position         = pos  or UDim2.new(0,0,0,0)
    f.Name             = name or "F"
    f.ZIndex           = zi   or 1
    if r then corner(f, r) end
    f.Parent = parent
    return f
end

local function mkL(parent, text, col, font, tsz, sz, pos, xa, ya, name, zi, wrap)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text           = tostring(text or "")
    l.TextColor3     = col  or TH.TextPri
    l.Font           = font or Enum.Font.GothamMedium
    l.TextSize       = tsz  or 13
    l.Size           = sz   or UDim2.new(1,0,1,0)
    l.Position       = pos  or UDim2.new(0,0,0,0)
    l.TextXAlignment = xa   or Enum.TextXAlignment.Left
    l.TextYAlignment = ya   or Enum.TextYAlignment.Center
    l.Name           = name or "L"
    l.ZIndex         = zi   or 1
    l.TextWrapped    = wrap or false
    l.Parent         = parent
    return l
end

local function mkB(parent, text, col, tcol, font, tsz, sz, pos, name, r, zi)
    local b = Instance.new("TextButton")
    b.BackgroundColor3 = col  or TH.AccentLo
    b.BorderSizePixel  = 0
    b.Text             = text or ""
    b.TextColor3       = tcol or TH.TextPri
    b.Font             = font or Enum.Font.GothamBold
    b.TextSize         = tsz  or 13
    b.Size             = sz   or UDim2.new(0,100,0,32)
    b.Position         = pos  or UDim2.new(0,0,0,0)
    b.AutoButtonColor  = false
    b.Name             = name or "B"
    b.ZIndex           = zi   or 1
    if r then corner(b, r) end
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = TH.Accent}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = col or TH.AccentLo}):Play()
    end)
    b.Parent = parent
    return b
end

local function mkInput(parent, ph, sz, pos, name, r, zi)
    local x = Instance.new("TextBox")
    x.BackgroundColor3  = TH.Row
    x.BorderSizePixel   = 0
    x.PlaceholderText   = ph or ""
    x.PlaceholderColor3 = TH.TextDis
    x.Text              = ""
    x.TextColor3        = TH.TextPri
    x.Font              = Enum.Font.Code
    x.TextSize          = 13
    x.Size              = sz  or UDim2.new(1,0,0,30)
    x.Position          = pos or UDim2.new(0,0,0,0)
    x.ClearTextOnFocus  = false
    x.Name              = name or "Input"
    x.ZIndex            = zi  or 1
    x.TextXAlignment    = Enum.TextXAlignment.Left
    if r then corner(x, r) end
    stroke(x, TH.Border, 1)
    x.Parent = parent
    return x
end

local function makeDraggable(frame, handle)
    local drag, sp, sf = false
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag=true; sp=i.Position; sf=frame.Position
        end
    end)
    handle.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag=false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - sp
            frame.Position = UDim2.new(sf.X.Scale, sf.X.Offset+d.X,
                                       sf.Y.Scale, sf.Y.Offset+d.Y)
        end
    end)
end

-- ════════════════════════════════════════════════════════════════════════════
--  BUILD GUI
-- ════════════════════════════════════════════════════════════════════════════

local oldGui = pgui:FindFirstChild("CmdMenu")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name           = "CmdMenu"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = pgui

local vp     = cam.ViewportSize
local winW   = math.clamp(math.floor(vp.X * 0.26), 320, 500)
local winH   = math.clamp(math.floor(vp.Y * 0.72), 420, 650)
local startX = math.floor(vp.X * 0.5 - winW * 0.5)
local startY = math.floor(vp.Y * 0.5 - winH * 0.5)

local win = mkF(gui, TH.BG,
                UDim2.new(0,winW,0,winH),
                UDim2.new(0,startX,0,startY),
                "Window", 10, 2)
stroke(win, TH.Border, 1)

cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    local v2 = cam.ViewportSize
    win.Size = UDim2.new(0,
        math.clamp(math.floor(v2.X*0.26),320,500), 0,
        math.clamp(math.floor(v2.Y*0.72),420,650))
end)

-- Header
local HDR_H = 44
local hdr   = mkF(win, TH.Panel, UDim2.new(1,0,0,HDR_H), UDim2.new(0,0,0,0), "Hdr", 10, 3)
mkF(hdr, TH.Panel, UDim2.new(1,0,0,10), UDim2.new(0,0,1,-10), "HdrFix", 0, 3)
mkF(hdr, TH.Accent, UDim2.new(0,3,0,24), UDim2.new(0,12,0,10), "Stripe", 2, 4)
mkL(hdr, "  Command Menu", TH.TextPri, Enum.Font.GothamBold, 15,
    UDim2.new(1,-100,1,0), UDim2.new(0,14,0,0), nil, nil, "Title", 4)
mkL(hdr, PREFIX.."<cmd>", TH.TextSec, Enum.Font.Code, 11,
    UDim2.new(0,90,1,0), UDim2.new(1,-180,0,0),
    Enum.TextXAlignment.Right, nil, "Hint", 4)

local closeBtn = mkB(hdr, "✕", Color3.fromHex("#2a1520"), TH.Red,
                     Enum.Font.GothamBold, 13,
                     UDim2.new(0,28,0,28), UDim2.new(1,-36,0,8), "Close", 5, 5)
makeDraggable(win, hdr)

-- Search
local SEARCH_Y  = HDR_H + 10
local searchBox = mkInput(win, "  search commands…",
                          UDim2.new(1,-16,0,30), UDim2.new(0,8,0,SEARCH_Y), "Search", 6, 3)

-- Scrolling list
local LIST_Y = SEARCH_Y + 40
local scroll = Instance.new("ScrollingFrame")
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel        = 0
scroll.ScrollBarThickness     = 3
scroll.ScrollBarImageColor3   = TH.AccentLo
scroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
scroll.CanvasSize             = UDim2.new(0,0,0,0)
scroll.Size                   = UDim2.new(1,-16, 1, -(LIST_Y+54))
scroll.Position               = UDim2.new(0,8, 0, LIST_Y)
scroll.ZIndex                 = 2
scroll.Parent                 = win

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding   = UDim.new(0,4)
listLayout.Parent    = scroll

-- Arg bar
local argBox = mkInput(win, "  args (if needed)…",
                       UDim2.new(1,-120,0,30), UDim2.new(0,8,1,-52), "ArgBox", 6, 3)
local runBtn = mkB(win, "Run ▶", TH.Accent, Color3.new(1,1,1),
                   Enum.Font.GothamBold, 13,
                   UDim2.new(0,100,0,30), UDim2.new(1,-108,1,-52), "RunBtn", 6, 3)

-- ── Row builder ───────────────────────────────────────────────────────────────

local selectedCmd = nil

--[[
    runCommand — wraps cmd.run in a pcall.
    Uses primaryName() for the error title so it always gets a string,
    even when cmd.name is a table.
--]]
local function runCommand(cmd, argStr)
    argStr = argStr or ""
    local ok, err = pcall(cmd.run, argStr)
    if not ok then
        notify("Error: "..primaryName(cmd), tostring(err):sub(1,80), 5)
    end
end

--[[
    buildList — rebuilds the scrolling command list.
    Filter checks primaryName AND all aliases AND help text,
    so typing any alias into the search box finds the command.
--]]
local function buildList(filter)
    for _, ch in ipairs(scroll:GetChildren()) do
        if ch:IsA("Frame") then ch:Destroy() end
    end

    for i, cmd in ipairs(COMMANDS) do
        -- Filter: skip if filter is set and nothing matches
        if filter and filter ~= "" then
            if not nameContains(cmd, filter) then continue end
        end

        local pname = primaryName(cmd)

        -- Row frame — uses primaryName so the Instance name is always valid
        local row = mkF(scroll, TH.Row,
                        UDim2.new(1,0,0,52), UDim2.new(0,0,0,0),
                        "Row_"..pname, 6, 2)
        row.LayoutOrder = i

        row.MouseEnter:Connect(function()
            TweenService:Create(row,TweenInfo.new(0.1),{BackgroundColor3=TH.RowHover}):Play()
        end)
        row.MouseLeave:Connect(function()
            if selectedCmd ~= cmd then
                TweenService:Create(row,TweenInfo.new(0.1),{BackgroundColor3=TH.Row}):Play()
            end
        end)

        local lastClick = 0
        row.InputBegan:Connect(function(inp)
            if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            selectedCmd = cmd
            argBox.PlaceholderText = cmd.args ~= "" and ("  "..cmd.args) or "  no arguments"
            argBox.Text = ""
            for _, r in ipairs(scroll:GetChildren()) do
                if r:IsA("Frame") then r.BackgroundColor3 = TH.Row end
            end
            row.BackgroundColor3 = TH.RowHover
            local now = tick()
            if now - lastClick < 0.35 then runCommand(cmd, argBox.Text) end
            lastClick = now
        end)

        -- Prefix badge
        local badge = mkF(row, TH.AccentLo,
                          UDim2.new(0,20,0,20), UDim2.new(0,8,0.5,-10), "Badge", 4, 3)
        mkL(badge, PREFIX, TH.Accent, Enum.Font.Code, 10,
            UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
            Enum.TextXAlignment.Center, nil, "PL", 4)

        -- Primary name label
        mkL(row, pname, TH.TextPri, Enum.Font.GothamBold, 13,
            UDim2.new(1,-90,0,22), UDim2.new(0,34,0,4), nil, nil, "Name", 3)

        -- Help text
        mkL(row, cmd.help, TH.TextSec, Enum.Font.Gotham, 11,
            UDim2.new(1,-90,0,18), UDim2.new(0,34,0,28), nil, nil, "Help", 3)

        -- Args hint
        if cmd.args ~= "" then
            mkL(row, cmd.args, TH.TextDis, Enum.Font.Code, 10,
                UDim2.new(0,80,1,0), UDim2.new(1,-84,0,0),
                Enum.TextXAlignment.Right, nil, "Args", 3)
        end

        -- Per-row run button
        local rowRun = mkB(row, "▶", TH.AccentLo, TH.Accent,
                           Enum.Font.GothamBold, 11,
                           UDim2.new(0,24,0,24), UDim2.new(1,-30,0.5,-12), "RowRun", 5, 3)
        rowRun.MouseButton1Click:Connect(function()
            selectedCmd = cmd
            runCommand(cmd, argBox.Text)
        end)
    end
end

buildList()

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    buildList(searchBox.Text)
end)

runBtn.MouseButton1Click:Connect(function()
    if selectedCmd then runCommand(selectedCmd, argBox.Text)
    else notify("Command Menu", "Select a command first.") end
end)

closeBtn.MouseButton1Click:Connect(function() win.Visible = false end)

-- ════════════════════════════════════════════════════════════════════════════
--  OPEN / CLOSE
-- ════════════════════════════════════════════════════════════════════════════

local function openMenu()
    win.Visible = true
    TweenService:Create(win, TweenInfo.new(0.18, Enum.EasingStyle.Quad),
        {Position = UDim2.new(0,startX,0,startY)}):Play()
end

local function closeMenu()
    win.Visible = false
end

win.Visible = false

-- ════════════════════════════════════════════════════════════════════════════
--  CHAT LISTENER
-- ════════════════════════════════════════════════════════════════════════════

local function onChat(msg)
    if msg:sub(1, #PREFIX) ~= PREFIX then return end
    local body    = msg:sub(#PREFIX + 1)
    local matched = body:match("^(%S+)")
    if not matched then return end
    local cmdName = matched:lower()
    local args    = body:sub(#matched + 1):match("^%s*(.-)%s*$") or ""

    -- Open/close handled before table lookup
    if cmdName == "open"  then openMenu();  return end
    if cmdName == "close" then closeMenu(); return end

    -- nameMatches() handles both string and table cmd.name correctly
    for _, cmd in ipairs(COMMANDS) do
        if nameMatches(cmd, cmdName) then
            runCommand(cmd, args)
            return
        end
    end

    notify("Unknown Command", PREFIX..cmdName)
end

lp.Chatted:Connect(onChat)

-- ════════════════════════════════════════════════════════════════════════════
--  KEYBIND  —  Home Key toggles menu
-- ════════════════════════════════════════════════════════════════════════════

UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.Home then
        win.Visible = not win.Visible
    end
end)

notify("Command Menu", "Loaded! Type "..PREFIX.."open or press RightAlt", 4)
