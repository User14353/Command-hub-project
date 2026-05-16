--[[
╔══════════════════════════════════════════════════════════════════════════════╗
║                    COMMAND MENU  —  Client-Side                              ║
║                                                                              ║
║  Chat prefix  _<command>   to run a command                                  ║
║  _open  /  _close          to show / hide the menu GUI                       ║
║                                                                              ║
║  ── ADDING YOUR OWN COMMANDS ─────────────────────────────────────────────   ║
║                                                                              ║
║  1. Find the COMMANDS table below.                                           ║
║  2. Add a new entry:                                                         ║
║       {                                                                      ║
║           name    = "commandname",   -- what you type after _                ║
║           help    = "description",   -- shown in the menu                    ║
║           args    = "[optional arg]", -- argument hint (or "" for none)      ║
║           run     = function(args)   -- args = string after command name     ║
║               -- your code here                                              ║
║           end,                                                               ║
║       },                                                                     ║
║  3. Done. No GUI edits needed. It auto-populates.                            ║
╚══════════════════════════════════════════════════════════════════════════════╝
--]]

-- ════════════════════════════════════════════════════════════════════════════
--  CONFIGURATION
-- ════════════════════════════════════════════════════════════════════════════

local PREFIX = "_"   -- change this if you want a different prefix

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

local lp      = Players.LocalPlayer
local pgui    = lp:WaitForChild("PlayerGui")
local char    = lp.Character or lp.CharacterAdded:Wait()
local cam     = workspace.CurrentCamera

-- ════════════════════════════════════════════════════════════════════════════
--  UTILITY HELPERS
-- ════════════════════════════════════════════════════════════════════════════

local function notify(title, body, dur)
    dur = dur or 3
    StarterGui:SetCore("SendNotification", {
        Title    = title,
        Text     = body,
        Duration = dur,
    })
end

local function chat(msg)
    -- sends a chat message through the LocalPlayer
    -- works in most executor environments
    local success = pcall(function()
        game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
            :FindFirstChild("SayMessageRequest"):FireServer(msg, "All")
    end)
    if not success then
        -- fallback: use the chat bar
        local vc = lp:FindFirstChild("PlayerScripts") and
                   lp.PlayerScripts:FindFirstChild("ChatScript")
        pcall(function()
            game.ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest
                :FireServer(msg, "All")
        end)
    end
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
--  ██████╗ ██████╗ ███╗   ███╗███╗   ███╗ █████╗ ███╗   ██╗██████╗ ███████╗
--  ██╔════╝██╔═══██╗████╗ ████║████╗ ████║██╔══██╗████╗  ██║██╔══██╗██╔════╝
--  ██║     ██║   ██║██╔████╔██║██╔████╔██║███████║██╔██╗ ██║██║  ██║███████╗
--  ██║     ██║   ██║██║╚██╔╝██║██║╚██╔╝██║██╔══██║██║╚██╗██║██║  ██║╚════██║
--  ╚██████╗╚██████╔╝██║ ╚═╝ ██║██║ ╚═╝ ██║██║  ██║██║ ╚████║██████╔╝███████║
--   ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝ ╚══════╝
-- ════════════════════════════════════════════════════════════════════════════
--
--  Each entry:  { name, help, args, run(args) }
--  name  = what the user types after the prefix   (_name)
--  help  = one-line description shown in the GUI
--  args  = hint string for arguments              ("" = no args)
--  run   = function(args:string) called on execution
--
-- ════════════════════════════════════════════════════════════════════════════

local COMMANDS = {

    -- ── 1. HELP ───────────────────────────────────────────────────────────────
    {
        name = "help",
        help = "Show all commands in chat",
        args = "",
        run  = function(_args)
            notify("Commands", "Check the menu GUI or type "..PREFIX.."open", 4)
        end,
    },

    -- ── 2. OPEN / CLOSE (also handled by the chat watcher separately) ─────────
    {
        name = "open",
        help = "Open the command menu",
        args = "",
        run  = function(_args)
            -- handled in the chat watcher — listed here just so it shows in help
        end,
    },

    {
        name = "close",
        help = "Close the command menu",
        args = "",
        run  = function(_args)
            -- handled in the chat watcher
        end,
    },

    -- ── 3. SERVER HOP ─────────────────────────────────────────────────────────
    {
        name = "serverhop",
        help = "Teleport to a random server of the same game",
        args = "",
        run  = function(_args)
            notify("Server Hop", "Finding a new server…")
            local placeId = game.PlaceId
            local ok, result = pcall(function()
                return HttpService:JSONDecode(
                    game:HttpGet(("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(placeId))
                )
            end)
            if ok and result and result.data and #result.data > 0 then
                -- pick a random server that isn't the current one
                local servers = {}
                for _, s in ipairs(result.data) do
                    if s.id ~= game.JobId and s.playing < s.maxPlayers then
                        table.insert(servers, s.id)
                    end
                end
                if #servers > 0 then
                    local pick = servers[math.random(1, #servers)]
                    TeleportService:TeleportToPlaceInstance(placeId, pick, lp)
                else
                    notify("Server Hop", "No other servers found.")
                end
            else
                -- fallback: rejoin
                TeleportService:Teleport(placeId, lp)
            end
        end,
    },

    -- ── 4. LOW-PLAYER SERVER ──────────────────────────────────────────────────
    {
        name = "lowserver",
        help = "Jump to the server with the fewest players",
        args = "",
        run  = function(_args)
            notify("Low Server", "Finding quietest server…")
            local placeId = game.PlaceId
            local ok, result = pcall(function()
                return HttpService:JSONDecode(
                    game:HttpGet(("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(placeId))
                )
            end)
            if ok and result and result.data and #result.data > 0 then
                local best, bestCount = nil, math.huge
                for _, s in ipairs(result.data) do
                    if s.id ~= game.JobId and s.playing < bestCount then
                        best = s.id; bestCount = s.playing
                    end
                end
                if best then
                    notify("Low Server", ("Joining server with %d players"):format(bestCount))
                    TeleportService:TeleportToPlaceInstance(placeId, best, lp)
                else
                    notify("Low Server", "No other servers found.")
                end
            else
                notify("Low Server", "Could not fetch servers.")
            end
        end,
    },

    -- ── 5. REJOIN ─────────────────────────────────────────────────────────────
    {
        name = "rejoin",
        help = "Rejoin the current game",
        args = "",
        run  = function(_args)
            notify("Rejoin", "Rejoining…")
            TeleportService:Teleport(game.PlaceId, lp)
        end,
    },

    -- ── 6. HAT REANIMATION (FE) ───────────────────────────────────────────────
    --  Detaches all accessories from the character and re-parents them to
    --  workspace, then rewelds them with a Motor6D so they animate freely.
    --  100% client-side visual; won't replicate beyond normal FE limits.
    {
        name = "hatrean",
        help = "FE hat reanimation — detach + reanimate accessories",
        args = "",
        run  = function(_args)
            char = lp.Character
            if not char then notify("Hat Rean", "No character found."); return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            for _, acc in ipairs(char:GetChildren()) do
                if acc:IsA("Accessory") then
                    local handle = acc:FindFirstChild("Handle")
                    if handle then
                        -- Clone handle into workspace for FE reanimate
                        local clone = handle:Clone()
                        clone.CanCollide = false
                        clone.Massless   = true
                        clone.Parent     = workspace

                        local weld       = Instance.new("Motor6D")
                        weld.Part0       = hrp
                        weld.Part1       = clone
                        weld.C0          = hrp.CFrame:ToObjectSpace(handle.CFrame)
                        weld.Parent      = hrp

                        -- Hide original
                        handle.LocalTransparencyModifier = 1
                    end
                end
            end
            notify("Hat Rean", "Accessories reanimated on fake rig.")
        end,
    },

    -- ── 7. WALKSPEED ──────────────────────────────────────────────────────────
    {
        name = "ws",
        help = "Set walkspeed",
        args = "<speed>",
        run  = function(args)
            local speed = tonumber(args)
            if not speed then notify("WalkSpeed", "Usage: "..PREFIX.."ws <number>"); return end
            local hum = getHum()
            if hum then hum.WalkSpeed = speed; notify("WalkSpeed", "Set to "..speed) end
        end,
    },

    -- ── 8. JUMPPOWER ──────────────────────────────────────────────────────────
    {
        name = "jp",
        help = "Set jump power",
        args = "<power>",
        run  = function(args)
            local power = tonumber(args)
            if not power then notify("JumpPower", "Usage: "..PREFIX.."jp <number>"); return end
            local hum = getHum()
            if hum then
                hum.JumpPower = power
                notify("JumpPower", "Set to "..power)
            end
        end,
    },

    -- ── 9. NOCLIP ─────────────────────────────────────────────────────────────
    {
        name = "noclip",
        help = "Toggle noclip (walk through walls)",
        args = "",
        run  = (function()
            local active = false
            local conn   = nil
            return function(_args)
                active = not active
                if active then
                    conn = RunService.Stepped:Connect(function()
                        local c = lp.Character
                        if c then
                            for _, part in ipairs(c:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    part.CanCollide = false
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

    -- ── 10. FLY ──────────────────────────────────────────────────────────────
    {
        name = "fly",
        help = "Toggle fly mode",
        args = "",
        run  = (function()
            local flying  = false
            local bv, bg  = nil, nil
            local conn    = nil

            return function(_args)
                flying = not flying
                local hrp = getHRP()
                if not hrp then return end

                if flying then
                    -- remove gravity, add BodyVelocity + BodyGyro
                    hrp.Velocity = Vector3.zero
                    bv = Instance.new("BodyVelocity")
                    bv.Velocity    = Vector3.zero
                    bv.MaxForce    = Vector3.new(1e5,1e5,1e5)
                    bv.Parent      = hrp

                    bg = Instance.new("BodyGyro")
                    bg.MaxTorque   = Vector3.new(1e5,1e5,1e5)
                    bg.D           = 100
                    bg.Parent      = hrp

                    conn = RunService.RenderStepped:Connect(function()
                        local hrp2 = getHRP(); if not hrp2 then return end
                        local spd  = 50
                        local move = Vector3.zero
                        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                            move = move + cam.CFrame.LookVector
                        end
                        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                            move = move - cam.CFrame.LookVector
                        end
                        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                            move = move - cam.CFrame.RightVector
                        end
                        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                            move = move + cam.CFrame.RightVector
                        end
                        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                            move = move + Vector3.new(0,1,0)
                        end
                        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                            move = move - Vector3.new(0,1,0)
                        end
                        if bv and bv.Parent then
                            bv.Velocity = move.Magnitude > 0
                                          and move.Unit * spd
                                          or  Vector3.zero
                        end
                        if bg and bg.Parent then
                            bg.CFrame = cam.CFrame
                        end
                    end)
                    notify("Fly", "ON  (WASD + Space/Ctrl)")
                else
                    if conn  then conn:Disconnect();  conn  = nil end
                    if bv    then bv:Destroy();       bv    = nil end
                    if bg    then bg:Destroy();       bg    = nil end
                    notify("Fly", "OFF")
                end
            end
        end)(),
    },

    -- ── 11. INVISIBLE (local transparency) ───────────────────────────────────
    {
        name = "invis",
        help = "Toggle local character invisibility",
        args = "",
        run  = (function()
            local hidden = false
            return function(_args)
                hidden = not hidden
                local c = lp.Character; if not c then return end
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then
                        p.LocalTransparencyModifier = hidden and 1 or 0
                    end
                end
                notify("Invisible", hidden and "ON (local only)" or "OFF")
            end
        end)(),
    },

    -- ── 12. GOTO PLAYER ──────────────────────────────────────────────────────
    {
        name = "goto",
        help = "Teleport to a player by name",
        args = "<name>",
        run  = function(args)
						local name = args:match("^%s*(.-)%s*$")
						local query = name:lower()

						local target = nil

						-- pass 1: DisplayName match first
						for _, p in ipairs(Players:GetPlayers()) do
								if p.DisplayName:lower():find(query, 1, true) then
										target = p
										break
								end
						end

						-- pass 2: fallback to Username
						if not target then
								for _, p in ipairs(Players:GetPlayers()) do
										if p.Name:lower():find(query, 1, true) then
												target = p
												break
										end
								end
						end
            if not target then notify("Goto", "Player not found: "..name); return end
            local tc = target.Character
            local tp = tc and tc:FindFirstChild("HumanoidRootPart")
            local hrp = getHRP()
            if hrp and tp then
                hrp.CFrame = tp.CFrame + Vector3.new(0,3,0)
                notify("Goto", "Teleported to "..target.Name)
            else
                notify("Goto", target.Name.." has no character.")
            end
        end,
    },

    -- ── 13. BRING PLAYER ─────────────────────────────────────────────────────
    {
        name = "bring",
        help = "Bring a player to you (local only)",
        args = "<name>",
        run  = function(args)
						local name = args:match("^%s*(.-)%s*$")
						local query = name:lower()

						local target = nil

						-- pass 1: DisplayName match first
						for _, p in ipairs(Players:GetPlayers()) do
								if p.DisplayName:lower():find(query, 1, true) then
										target = p
										break
								end
						end

						-- pass 2: fallback to Username
						if not target then
								for _, p in ipairs(Players:GetPlayers()) do
										if p.Name:lower():find(query, 1, true) then
												target = p
												break
										end
								end
						end
            if not target then notify("Bring", "Player not found: "..name); return end
            local tc  = target.Character
            local tp  = tc and tc:FindFirstChild("HumanoidRootPart")
            local hrp = getHRP()
            if tp and hrp then
                tp.CFrame = hrp.CFrame + Vector3.new(2, 0, 2)
                notify("Bring", "Brought "..target.Name.." to you (local)")
            else
                notify("Bring", "Could not bring "..target.Name)
            end
        end,
    },

    -- ── 14. OPEN SCRIPT HUB ──────────────────────────────────────────────────
    {
        name = "hub",
        help = "Open the script hub",
        args = "",
        run  = function(_args)
            -- Loads ScriptHub.lua from the same folder.
            -- In an executor you'd use: loadstring(readfile("ScriptHub.lua"))()
            -- or if you have it as a URL:
            -- loadstring(game:HttpGet("YOUR_URL_HERE"))()
            --
            -- For local file loading (most executors):
            local ok, err = pcall(function()
                if readfile then
                    loadstring(readfile("ScriptHub.lua"))()
                else
                    notify("Hub", "Place ScriptHub.lua next to this file and use readfile.")
                end
            end)
            if not ok then
                notify("Hub Error", tostring(err):sub(1,60))
            end
        end,
    },

    -- ── 15. RESET CHARACTER ───────────────────────────────────────────────────
    {
        name = "reset",
        help = "Reset your character",
        args = "",
        run  = function(_args)
            local hum = getHum()
            if hum then hum.Health = 0 end
        end,
    },
    {
        name = "follow",
        help = "Automatically follow a player",
        args = "<name>",
        run = (function(args)
						active = not active

						if active then
								local name = args:match("^%s*(.-)%s*$")
								local query = name:lower()

								target = nil

								-- pass 1: DisplayName only
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
										notify("Follow", "Player not found.")
										return
								end

								conn = RunService.RenderStepped:Connect(function()
										local hrp = getHRP()
										local thrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")

										if hrp and thrp then
												hrp.CFrame = thrp.CFrame * CFrame.new(0,0,3)
										end
								end)

								notify("Follow", "ON")

						else
								if conn then
										conn:Disconnect()
										conn = nil
								end

								target = nil
								notify("Follow", "OFF")
						end
				end)(),
    },

    -- ── TRIVIA GAME ─────────────────────────────────────────────────────────────
    {
        name = "trivia",
        help = "Start/stop trivia game with chat answers + leaderboard",
        args = "",
        run = (function()
    
            local active = false
            local currentAnswer = nil
            local questionIndex = 0
            local chatConn = nil
    
            local scores = {}
    
            local questions = {
                {"What planet is known as the Red Planet?", "mars"},
                {"How many hearts does an octopus have?", "3"},
                {"What is 5 + 7?", "12"},
                {"What is the capital of Australia?", "canberra"},
                {"What gas do plants breathe in?", "carbon dioxide"},
                {"What is the largest ocean?", "pacific"},
                {"What is H2O commonly known as?", "water"},
                {"How many legs does a spider have?", "8"},
                {"What year did Roblox release?", "2006"},
                {"What is the square root of 81?", "9"},
                {"What is the fastest land animal?", "cheetah"},
                {"What is the tallest mountain?", "everest"},
                {"What is the currency of Japan?", "yen"},
                {"How many continents are there?", "7"},
                {"What is the boiling point of water (C)?", "100"},
                {"What planet is closest to the sun?", "mercury"},
                {"What color do you get mixing red and blue?", "purple"},
                {"What is the capital of France?", "paris"},
                {"How many days in a leap year?", "366"},
                {"What is the hardest natural substance?", "diamond"},
                {"What is the biggest mammal?", "blue whale"},
                {"What language has the most native speakers?", "mandarin"},
                {"What is 9 x 9?", "81"},
                {"What is the capital of Italy?", "rome"},
                {"What organ pumps blood?", "heart"},
                {"What is the freezing point of water?", "0"},
                {"What planet has rings?", "saturn"},
                {"What is the main gas in air?", "nitrogen"},
                {"How many bones in adult body?", "206"},
                {"What is the speed of light?", "299792458"},
                {"What is the capital of Germany?", "berlin"},
                {"What fruit keeps the doctor away (saying)?", "apple"},
                {"What is 3 squared?", "9"},
                {"What is the largest desert?", "sahara"},
                {"What is the smallest prime number?", "2"},
                {"What is the capital of Spain?", "madrid"},
                {"What is 100 divided by 4?", "25"},
                {"What is the main language in Brazil?", "portuguese"},
                {"What is the ocean between Africa and Australia?", "indian"},
                {"What is 15 + 15?", "30"},
                {"What is the capital of USA?", "washington"},
                {"What animal is known as king of jungle?", "lion"},
                {"What is the square root of 144?", "12"},
                {"What is the largest continent?", "asia"},
                {"What is the capital of China?", "beijing"},
                {"What is 7 x 7?", "49"},
                {"What planet is blue?", "earth"},
                {"What is the smallest country?", "vatican"},
                {"What is the chemical symbol for gold?", "au"},
                {"What is 50 + 50?", "100"},
                {"What is the capital of Russia?", "moscow"},
                {"What is the fastest water animal?", "sailfish"},
                {"What is 2 + 2 x 2?", "6"},
                {"What is the main source of Earth’s energy?", "sun"},
                {"What is the capital of India?", "new delhi"},
                {"What is the longest river?", "nile"},
            }
    
            -- 🔥 display name helper
            local function getName(plr)
                return plr.DisplayName or plr.Name
            end
    
            -- 🔥 modern chat sender (fixes your error)
            local function say(msg)
                local TextChatService = game:GetService("TextChatService")
    
                if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
                    local channel = TextChatService:FindFirstChild("TextChannels")
                    if channel and channel:FindFirstChild("RBXGeneral") then
                        channel.RBXGeneral:SendAsync(msg)
                    end
                else
                    local ev = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
                    if ev then
                        ev.SayMessageRequest:FireServer(msg, "All")
                    end
                end
            end
    
            local function nextQuestion()
                if not active then return end
    
                questionIndex = questionIndex + 1
                if questionIndex > #questions then
                    questionIndex = 1
                end
    
                local q = questions[questionIndex]
                currentAnswer = q[2]
    
                say("🧠 Trivia: "..q[1])
            end
    
            local function leaderboard()
                local list = {}
    
                for plr, score in pairs(scores) do
                    table.insert(list, {
                        name = getName(plr),
                        score = score
                    })
                end
    
                table.sort(list, function(a,b)
                    return a.score > b.score
                end)
    
                local msg = "🏆 Trivia Leaderboard:\n"
    
                for i = 1, math.min(5, #list) do
                    msg = msg .. i .. ". " .. list[i].name .. " - " .. list[i].score .. "\n"
                end
    
                say(msg)
            end
    
            local function start()
                active = true
                scores = {}
                questionIndex = 0
    
                say("🎮 Trivia Started!")
    
                chatConn = game:GetService("Players").PlayerChatted:Connect(function(plr, msg)
                    if not active then return end
    
                    msg = msg:lower():gsub("%s+", "")
    
                    if currentAnswer and msg == currentAnswer then
                        scores[plr] = (scores[plr] or 0) + 1
    
                        say("✅ "..getName(plr).." got it right! ("..currentAnswer..")")
    
                        leaderboard()
                        nextQuestion()
                    end
                end)
    
                nextQuestion()
            end
    
            local function stop()
                active = false
    
                if chatConn then
                    chatConn:Disconnect()
                    chatConn = nil
                end
    
                leaderboard()
                say("🛑 Trivia Ended!")
            end
    
            return function()
                if active then
                    stop()
                else
                    start()
                end
            end
    
        end)(),
    },

    -- ── DANCE ─────────────────────────────────────────────────────────────────
    {
        name = "dance",
        help = "Play a random Roblox dance emote",
        args = "",
        run  = function(_args)
            local hum = getHum()

            if hum then
                hum:LoadAnimation(Instance.new("Animation", hum){
                    AnimationId = "rbxassetid://507771019"
                }):Play()

                notify("Dance", "Started dancing.")
            end
        end,
    },

    -- ── ORBIT ─────────────────────────────────────────────────────────────────
		{
				name = "orbit",
				help = "Orbit around a player",
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
    -- ── STARE ─────────────────────────────────────────────────────────────────
		{
				name = "stare",
				help = "Continuously look at a player",
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

    -- ── SPAM ──────────────────────────────────────────────────────────────────
    {
        name = "spam",
        help = "Spam a message into chat",
        args = "<message>",
        run = (function()
            local active = false
    
            return function(args)
                active = not active
    
                if active then
                    local msg = tostring(args)
    
                    if msg == "" then
                        active = false
                        notify("Spam", "Invalid message")
                        return
                    end
    
                    task.spawn(function()
                        while active do
                            game:GetService("ReplicatedStorage")
                                .DefaultChatSystemChatEvents
                                .SayMessageRequest:FireServer(msg, "All")
    
                            task.wait(2)
                        end
                    end)
    
                    notify("Spam", "ON")
                else
                    notify("Spam", "OFF")
                end
            end
        end)(),
    },

    -- ── JUMPSPIN ──────────────────────────────────────────────────────────────
    {
        name = "jumpspin",
        help = "Spin rapidly while jumping",
        args = "",
        run  = function(_args)
            local hrp = getHRP()
            local hum = getHum()

            if hrp and hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)

                for i = 1, 50 do
                    hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(40), 0)
                    task.wait()
                end

                notify("JumpSpin", "Completed spin jump.")
            end
        end,
    },

    -- ── FLING ─────────────────────────────────────────────────────────────────
    {
        name = "fling",
        help = "Spin extremely fast",
        args = "",
        run = (function()
            local active = false
            local conn = nil
    
            return function()
                active = not active
    
                local hrp = getHRP()
                if not hrp then return end
    
                if active then
                    conn = RunService.RenderStepped:Connect(function()
                        hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(150), 0)
                    end)
    
                    notify("Fling", "ON")
                else
                    if conn then conn:Disconnect(); conn = nil end
                    notify("Fling", "OFF")
                end
            end
        end)(),
    },

    -- ── RANDOMTP ──────────────────────────────────────────────────────────────
    {
        name = "randomtp",
        help = "Teleport to a random spot nearby",
        args = "",
        run  = function(_args)
            local hrp = getHRP()

            if hrp then
                local offset = Vector3.new(
                    math.random(-100,100),
                    math.random(10,40),
                    math.random(-100,100)
                )

                hrp.CFrame = hrp.CFrame + offset

                notify("RandomTP", "Teleported randomly.")
            end
        end,
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
    Yellow   = Color3.fromHex("#facc15"),
}

-- ════════════════════════════════════════════════════════════════════════════
--  GUI BUILDER HELPERS
-- ════════════════════════════════════════════════════════════════════════════

local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = parent
end

local function stroke(parent, col, thick)
    local s = Instance.new("UIStroke")
    s.Color     = col or TH.Border
    s.Thickness = thick or 1
    s.Parent    = parent
end

local function mkF(parent, col, size, pos, name, r, zi)
    local f = Instance.new("Frame")
    f.BackgroundColor3 = col or TH.Panel
    f.BorderSizePixel  = 0
    f.Size             = size  or UDim2.new(1,0,1,0)
    f.Position         = pos   or UDim2.new(0,0,0,0)
    f.Name             = name  or "F"
    f.ZIndex           = zi    or 1
    if r then corner(f, r) end
    f.Parent = parent
    return f
end

local function mkL(parent, text, col, font, tsz, size, pos, xa, ya, name, zi, wrap)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text               = text  or ""
    l.TextColor3         = col   or TH.TextPri
    l.Font               = font  or Enum.Font.GothamMedium
    l.TextSize           = tsz   or 13
    l.Size               = size  or UDim2.new(1,0,1,0)
    l.Position           = pos   or UDim2.new(0,0,0,0)
    l.TextXAlignment     = xa    or Enum.TextXAlignment.Left
    l.TextYAlignment     = ya    or Enum.TextYAlignment.Center
    l.Name               = name  or "L"
    l.ZIndex             = zi    or 1
    l.TextWrapped        = wrap  or false
    l.Parent = parent
    return l
end

local function mkB(parent, text, col, tcol, font, tsz, size, pos, name, r, zi)
    local b = Instance.new("TextButton")
    b.BackgroundColor3  = col   or TH.AccentLo
    b.BorderSizePixel   = 0
    b.Text              = text  or ""
    b.TextColor3        = tcol  or TH.TextPri
    b.Font              = font  or Enum.Font.GothamBold
    b.TextSize          = tsz   or 13
    b.Size              = size  or UDim2.new(0,100,0,32)
    b.Position          = pos   or UDim2.new(0,0,0,0)
    b.AutoButtonColor   = false
    b.Name              = name  or "B"
    b.ZIndex            = zi    or 1
    if r then corner(b, r) end
    -- hover effect
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = TH.Accent}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = col or TH.AccentLo}):Play()
    end)
    b.Parent = parent
    return b
end

local function mkInput(parent, ph, size, pos, name, r, zi)
    local x = Instance.new("TextBox")
    x.BackgroundColor3  = TH.Row
    x.BorderSizePixel   = 0
    x.PlaceholderText   = ph   or ""
    x.PlaceholderColor3 = TH.TextDis
    x.Text              = ""
    x.TextColor3        = TH.TextPri
    x.Font              = Enum.Font.Code
    x.TextSize          = 13
    x.Size              = size or UDim2.new(1,0,0,30)
    x.Position          = pos  or UDim2.new(0,0,0,0)
    x.ClearTextOnFocus  = false
    x.Name              = name or "Input"
    x.ZIndex            = zi   or 1
    x.TextXAlignment    = Enum.TextXAlignment.Left
    if r then corner(x, r) end
    stroke(x, TH.Border, 1)
    x.Parent = parent
    return x
end

-- Draggable
local function makeDraggable(frame, handle)
    local drag, sp, sf = false
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true; sp = i.Position; sf = frame.Position
        end
    end)
    handle.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
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

-- Remove old instance if re-running
local oldGui = pgui:FindFirstChild("CmdMenu")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name           = "CmdMenu"
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = pgui

-- ── Responsive sizing ─────────────────────────────────────────────────────────
-- Width  = 26% of screen, clamped 320–500
-- Height = 72% of screen, clamped 420–650

local vp       = cam.ViewportSize
local winW     = math.clamp(math.floor(vp.X * 0.26), 320, 500)
local winH     = math.clamp(math.floor(vp.Y * 0.72), 420, 650)
local startX   = math.floor(vp.X * 0.5 - winW * 0.5)
local startY   = math.floor(vp.Y * 0.5 - winH * 0.5)

local win = mkF(gui, TH.BG,
                UDim2.new(0,winW,0,winH),
                UDim2.new(0,startX,0,startY),
                "Window", 10, 2)
stroke(win, TH.Border, 1)

-- Update size on viewport change
cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    local vp2 = cam.ViewportSize
    local w   = math.clamp(math.floor(vp2.X * 0.26), 320, 500)
    local h   = math.clamp(math.floor(vp2.Y * 0.72), 420, 650)
    win.Size  = UDim2.new(0, w, 0, h)
end)

-- ── Title bar ─────────────────────────────────────────────────────────────────
local HDR_H = 44
local hdr = mkF(win, TH.Panel,
                UDim2.new(1,0,0,HDR_H), UDim2.new(0,0,0,0),
                "Hdr", 10, 3)
-- Fix bottom radius bleed
mkF(hdr, TH.Panel, UDim2.new(1,0,0,10), UDim2.new(0,0,1,-10), "HdrFix", 0, 3)

-- Accent left stripe
local stripe = mkF(hdr, TH.Accent,
                   UDim2.new(0,3,0,24), UDim2.new(0,12,0,10),
                   "Stripe", 2, 4)

mkL(hdr, "  Command Menu", TH.TextPri, Enum.Font.GothamBold, 15,
    UDim2.new(1,-100,1,0), UDim2.new(0,14,0,0), nil, nil, "Title", 4)

mkL(hdr, PREFIX.."<cmd>", TH.TextSec, Enum.Font.Code, 11,
    UDim2.new(0,90,1,0), UDim2.new(1,-180,0,0), Enum.TextXAlignment.Right, nil, "PfxHint", 4)

-- Close button
local closeBtn = mkB(hdr, "✕", Color3.fromHex("#2a1520"), TH.Red,
                     Enum.Font.GothamBold, 13,
                     UDim2.new(0,28,0,28), UDim2.new(1,-36,0,8),
                     "Close", 5, 5)

makeDraggable(win, hdr)

-- ── Search bar ────────────────────────────────────────────────────────────────
local SEARCH_Y = HDR_H + 10
local searchBox = mkInput(win, "  search commands…",
                          UDim2.new(1,-16,0,30), UDim2.new(0,8,0,SEARCH_Y),
                          "Search", 6, 3)

-- ── Command list ──────────────────────────────────────────────────────────────
local LIST_Y    = SEARCH_Y + 40
local LIST_PADH = HDR_H + 10 + 30 + 10 -- header + search + gap

local scroll = Instance.new("ScrollingFrame")
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel        = 0
scroll.ScrollBarThickness     = 3
scroll.ScrollBarImageColor3   = TH.AccentLo
scroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
scroll.CanvasSize             = UDim2.new(0,0,0,0)
scroll.Size                   = UDim2.new(1,-16, 1, -(LIST_Y + 54))
scroll.Position               = UDim2.new(0,8, 0, LIST_Y)
scroll.ZIndex                 = 2
scroll.Parent                 = win

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding   = UDim.new(0,4)
listLayout.Parent    = scroll

-- ── Run arg bar ───────────────────────────────────────────────────────────────
local ARG_Y = -52 -- bottom of window
local argBox = mkInput(win, "  args (if needed)…",
                       UDim2.new(1,-120,0,30), UDim2.new(0,8,1,ARG_Y),
                       "ArgBox", 6, 3)
local runBtn = mkB(win, "Run ▶", TH.Accent, Color3.new(1,1,1),
                   Enum.Font.GothamBold, 13,
                   UDim2.new(0,100,0,30), UDim2.new(1,-108,1,ARG_Y),
                   "RunBtn", 6, 3)

-- ── Populate command rows ─────────────────────────────────────────────────────

local selectedCmd = nil  -- the currently selected COMMANDS entry

local function runCommand(cmd, argStr)
    argStr = argStr or ""
    local ok, err = pcall(cmd.run, argStr)
    if not ok then
        notify("Error: "..cmd.name, tostring(err):sub(1,80), 5)
    end
end

local function buildList(filter)
    -- clear existing rows
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    for i, cmd in ipairs(COMMANDS) do
        if filter and filter ~= "" then
            local f = filter:lower()
            if not cmd.name:lower():find(f,1,true) and
               not cmd.help:lower():find(f,1,true) then
                continue
            end
        end

        local ROW_H = 52
        local row = mkF(scroll, TH.Row,
                        UDim2.new(1,0,0,ROW_H), UDim2.new(0,0,0,0),
                        "Row_"..cmd.name, 6, 2)
        row.LayoutOrder = i

        -- Hover
        row.MouseEnter:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.1), {BackgroundColor3=TH.RowHover}):Play()
        end)
        row.MouseLeave:Connect(function()
            if selectedCmd ~= cmd then
                TweenService:Create(row, TweenInfo.new(0.1), {BackgroundColor3=TH.Row}):Play()
            end
        end)

        -- Select on click
        row.InputBegan:Connect(function(inp)
            if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            selectedCmd = cmd
            argBox.PlaceholderText = cmd.args ~= "" and ("  "..cmd.args) or "  no arguments"
            argBox.Text = ""
            -- highlight
            for _, r in ipairs(scroll:GetChildren()) do
                if r:IsA("Frame") then
                    r.BackgroundColor3 = TH.Row
                end
            end
            row.BackgroundColor3 = TH.RowHover
        end)

        -- Double-click to run immediately
        local lastClick = 0
        row.InputBegan:Connect(function(inp)
            if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            local now = tick()
            if now - lastClick < 0.35 then
                runCommand(cmd, argBox.Text)
            end
            lastClick = now
        end)

        -- Left: command name + prefix badge
        local badge = mkF(row, TH.AccentLo,
                          UDim2.new(0,20,0,20), UDim2.new(0,8,0.5,-10),
                          "Badge", 4, 3)
        mkL(badge, PREFIX, TH.Accent, Enum.Font.Code, 10,
            UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
            Enum.TextXAlignment.Center, nil, "PL", 4)

        mkL(row, cmd.name, TH.TextPri, Enum.Font.GothamBold, 13,
            UDim2.new(1,-90,0,22), UDim2.new(0,34,0,4),
            nil, nil, "Name", 3)

        mkL(row, cmd.help, TH.TextSec, Enum.Font.Gotham, 11,
            UDim2.new(1,-90,0,18), UDim2.new(0,34,0,28),
            nil, nil, "Help", 3, false)

        -- Right: args hint
        if cmd.args ~= "" then
            mkL(row, cmd.args, TH.TextDis, Enum.Font.Code, 10,
                UDim2.new(0,80,1,0), UDim2.new(1,-84,0,0),
                Enum.TextXAlignment.Right, nil, "Args", 3)
        end

        -- Run button on right
        local rowRun = mkB(row, "▶", TH.AccentLo, TH.Accent,
                           Enum.Font.GothamBold, 11,
                           UDim2.new(0,24,0,24), UDim2.new(1,-30,0.5,-12),
                           "RowRun", 5, 3)
        rowRun.MouseButton1Click:Connect(function()
            selectedCmd = cmd
            runCommand(cmd, argBox.Text)
        end)
    end
end

buildList()

-- Search filter
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    buildList(searchBox.Text)
end)

-- Run button
runBtn.MouseButton1Click:Connect(function()
    if selectedCmd then
        runCommand(selectedCmd, argBox.Text)
    else
        notify("Command Menu", "Select a command first.")
    end
end)

-- Close button
closeBtn.MouseButton1Click:Connect(function()
    win.Visible = false
end)

-- ── Open / close toggle ───────────────────────────────────────────────────────

local function openMenu()
    win.Visible = true
    TweenService:Create(win, TweenInfo.new(0.18, Enum.EasingStyle.Quad),
        {Position = UDim2.new(0,startX,0,startY)}):Play()
end

local function closeMenu()
    win.Visible = false
end

-- Default: start hidden
win.Visible = false

-- ════════════════════════════════════════════════════════════════════════════
--  CHAT LISTENER
-- ════════════════════════════════════════════════════════════════════════════

local function onChat(msg)
    if not msg:sub(1,#PREFIX) == PREFIX then return end
    if msg:sub(1,#PREFIX) ~= PREFIX then return end

    local body    = msg:sub(#PREFIX+1)               -- strip prefix
    local cmdName = body:match("^(%S+)"):lower()      -- first word
    local args    = body:sub(#cmdName+1):match("^%s*(.-)%s*$") or ""

    -- Special: open / close
    if cmdName == "open"  then openMenu();  return end
    if cmdName == "close" then closeMenu(); return end

    -- Find command
    for _, cmd in ipairs(COMMANDS) do
        if cmd.name:lower() == cmdName then
            runCommand(cmd, args)
            return
        end
    end

    notify("Unknown Command", PREFIX..cmdName)
end

-- Hook into the chat output (works in most games)
lp.Chatted:Connect(onChat)

-- ════════════════════════════════════════════════════════════════════════════
--  KEYBIND:  RightAlt  toggles menu
-- ════════════════════════════════════════════════════════════════════════════

UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.RightAlt then
        win.Visible = not win.Visible
    end
end)

notify("Command Menu", "Loaded!  Type "..PREFIX.."open or press RightAlt", 4)
