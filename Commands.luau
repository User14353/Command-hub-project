--[[
╔══════════════════════════════════════════════════════════════════════════════╗
║                    COMMAND MENU  —  Client-Side                              ║
║                                                                              ║
║  Chat prefix  _<command>   to run a command                                  ║
║  _open  /  _close          to show / hide the menu GUI                      ║
║                                                                              ║
║  ── ADDING YOUR OWN COMMANDS ─────────────────────────────────────────────  ║
║                                                                              ║
║  1. Find the COMMANDS table below.                                           ║
║  2. Add a new entry:                                                         ║
║       {                                                                      ║
║           name = "commandname",    -- what you type after _                 ║
║           help = "description",    -- shown in the menu                     ║
║           args = "[optional arg]", -- argument hint (or "" for none)        ║
║           run  = function(args)    -- args = string after command name      ║
║               -- your code here                                             ║
║           end,                                                               ║
║       },                                                                     ║
║  3. Done. No GUI edits needed. It auto-populates.                            ║
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

--[[
    sendChat — works in both modern TextChatService and legacy DefaultChatSystem.
    Tries modern first, falls back automatically.
--]]
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
--  COMMANDS TABLE
-- ════════════════════════════════════════════════════════════════════════════

local COMMANDS = {

    -- ── 1. HELP ───────────────────────────────────────────────────────────────
    {
        name = "help",
        help = "Reminder about the menu",
        args = "",
        run  = function(_)
            notify("Commands", "Type "..PREFIX.."open or press RightAlt.", 4)
        end,
    },

    -- ── 2/3. OPEN / CLOSE (handled by chat listener; listed for the GUI) ──────
    {
        name = "open",
        help = "Open the command menu",
        args = "",
        run  = function(_) end,
    },
    {
        name = "close",
        help = "Close the command menu",
        args = "",
        run  = function(_) end,
    },

    -- ── 4. SERVER HOP ─────────────────────────────────────────────────────────
    {
        name = "serverhop",
        help = "Teleport to a random server",
        args = "",
        run  = function(_)
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

    -- ── 5. LOW PLAYER SERVER ──────────────────────────────────────────────────
    {
        name = "lowserver",
        help = "Join the server with fewest players",
        args = "",
        run  = function(_)
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
                        best = s.id; bestN = s.playing
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

    -- ── 6. REJOIN ─────────────────────────────────────────────────────────────
    {
        name = "rejoin",
        help = "Rejoin the current game",
        args = "",
        run  = function(_)
            notify("Rejoin", "Rejoining…")
            TeleportService:Teleport(game.PlaceId, lp)
        end,
    },

    -- ── 7. HAT REANIMATION ────────────────────────────────────────────────────
    {
        name = "hatrean",
        help = "FE hat reanimation — re-weld accessories locally",
        args = "",
        run  = function(_)
            local c = lp.Character
            if not c then notify("Hat Rean", "No character."); return end
            local hrp = c:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            for _, acc in ipairs(c:GetChildren()) do
                if acc:IsA("Accessory") then
                    local handle = acc:FindFirstChild("Handle")
                    if handle then
                        local clone      = handle:Clone()
                        clone.CanCollide = false
                        clone.Massless   = true
                        clone.Parent     = workspace
                        local weld       = Instance.new("Motor6D")
                        weld.Part0       = hrp
                        weld.Part1       = clone
                        weld.C0          = hrp.CFrame:ToObjectSpace(handle.CFrame)
                        weld.Parent      = hrp
                        handle.LocalTransparencyModifier = 1
                    end
                end
            end
            notify("Hat Rean", "Done.")
        end,
    },

    -- ── 8. WALKSPEED ──────────────────────────────────────────────────────────
    {
        name = "ws",
        help = "Set walk speed",
        args = "<speed>",
        run  = function(args)
            local n = tonumber(args)
            if not n then notify("WalkSpeed", "Usage: "..PREFIX.."ws <number>"); return end
            local h = getHum()
            if h then h.WalkSpeed = n; notify("WalkSpeed", "Set to "..n) end
        end,
    },

    -- ── 9. JUMPPOWER ──────────────────────────────────────────────────────────
    {
        name = "jp",
        help = "Set jump power",
        args = "<power>",
        run  = function(args)
            local n = tonumber(args)
            if not n then notify("JumpPower", "Usage: "..PREFIX.."jp <number>"); return end
            local h = getHum()
            if h then h.JumpPower = n; notify("JumpPower", "Set to "..n) end
        end,
    },

    -- ── 10. NOCLIP ────────────────────────────────────────────────────────────
    {
        name = "noclip",
        help = "Toggle noclip",
        args = "",
        run  = (function()
            local on, conn = false, nil
            return function(_)
                on = not on
                if on then
                    conn = RunService.Stepped:Connect(function()
                        local c = lp.Character
                        if c then
                            for _, p in ipairs(c:GetDescendants()) do
                                if p:IsA("BasePart") then p.CanCollide = false end
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

    -- ── 11. FLY ───────────────────────────────────────────────────────────────
    {
        name = "fly",
        help = "Toggle fly (WASD + Space/LCtrl)",
        args = "",
        run  = (function()
            local on, bv, bg, conn = false, nil, nil, nil
            return function(_)
                on = not on
                local hrp = getHRP()
                if not hrp then return end
                if on then
                    hrp.Velocity = Vector3.zero
                    bv = Instance.new("BodyVelocity")
                    bv.Velocity  = Vector3.zero
                    bv.MaxForce  = Vector3.new(1e5,1e5,1e5)
                    bv.Parent    = hrp
                    bg = Instance.new("BodyGyro")
                    bg.MaxTorque = Vector3.new(1e5,1e5,1e5)
                    bg.D         = 100
                    bg.Parent    = hrp
                    conn = RunService.RenderStepped:Connect(function()
                        local h2 = getHRP(); if not h2 then return end
                        local mv = Vector3.zero
                        if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv = mv + cam.CFrame.LookVector  end
                        if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv = mv - cam.CFrame.LookVector  end
                        if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv = mv - cam.CFrame.RightVector end
                        if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv = mv + cam.CFrame.RightVector end
                        if UserInputService:IsKeyDown(Enum.KeyCode.Space)       then mv = mv + Vector3.new(0,1,0) end
                        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv = mv + Vector3.new(0,1,0) end
                        if bv and bv.Parent then bv.Velocity = mv.Magnitude>0 and mv.Unit*50 or Vector3.zero end
                        if bg and bg.Parent then bg.CFrame = cam.CFrame end
                    end)
                    notify("Fly", "ON")
                else
                    if conn then conn:Disconnect(); conn=nil end
                    if bv   then bv:Destroy();     bv=nil   end
                    if bg   then bg:Destroy();     bg=nil   end
                    notify("Fly", "OFF")
                end
            end
        end)(),
    },

    -- ── 12. INVISIBLE ─────────────────────────────────────────────────────────
    {
        name = "invis",
        help = "Toggle local character invisibility",
        args = "",
        run  = (function()
            local hidden = false
            return function(_)
                hidden = not hidden
                local c = lp.Character; if not c then return end
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then
                        p.LocalTransparencyModifier = hidden and 1 or 0
                    end
                end
                notify("Invisible", hidden and "ON" or "OFF")
            end
        end)(),
    },

    -- ── 13. GOTO ──────────────────────────────────────────────────────────────
    {
        name = "goto",
        help = "Teleport to a player",
        args = "<name>",
        run  = function(args)
            local q = args:match("^%s*(.-)%s*$"):lower()
            local target
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= lp and (p.Name:lower():find(q,1,true) or p.DisplayName:lower():find(q,1,true)) then
                    target = p; break
                end
            end
            if not target then notify("Goto", "Not found: "..q); return end
            local tp  = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            local hrp = getHRP()
            if hrp and tp then
                hrp.CFrame = tp.CFrame + Vector3.new(0,3,0)
                notify("Goto", "Teleported to "..target.Name)
            else
                notify("Goto", target.Name.." has no character.")
            end
        end,
    },

    -- ── 14. BRING ─────────────────────────────────────────────────────────────
    {
        name = "bring",
        help = "Bring a player to you (local)",
        args = "<name>",
        run  = function(args)
            local q = args:match("^%s*(.-)%s*$"):lower()
            local target
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= lp and (p.Name:lower():find(q,1,true) or p.DisplayName:lower():find(q,1,true)) then
                    target = p; break
                end
            end
            if not target then notify("Bring", "Not found: "..q); return end
            local tp  = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            local hrp = getHRP()
            if tp and hrp then
                tp.CFrame = hrp.CFrame + Vector3.new(2,0,2)
                notify("Bring", "Brought "..target.Name)
            else
                notify("Bring", "Could not bring "..target.Name)
            end
        end,
    },

    -- ── 15. HUB ───────────────────────────────────────────────────────────────
    {
        name = "hub",
        help = "Open the script hub",
        args = "",
        run  = function(_)
            local ok, err = pcall(function()
                if readfile then loadstring(readfile("ScriptHub.lua"))()
                else notify("Hub", "Place ScriptHub.lua next to this file.") end
            end)
            if not ok then notify("Hub Error", tostring(err):sub(1,80)) end
        end,
    },

    -- ── 16. RESET ─────────────────────────────────────────────────────────────
    {
        name = "reset",
        help = "Reset your character",
        args = "",
        run  = function(_)
            local h = getHum()
            if h then h.Health = 0 end
        end,
    },

    -- ══════════════════════════════════════════════════════════════════════════
    --  FIXED COMMANDS
    -- ══════════════════════════════════════════════════════════════════════════

    -- ── 17. FOLLOW ────────────────────────────────────────────────────────────
    --[[
        ROOT CAUSE: The original code was  run = (function() active=... return
        function(args) ... end end)()  but active/conn/target were being read
        INSIDE the outer function that ran once at table-build time, so every
        call to run() saw a fresh nil.

        FIX: Declare the persistent state variables in the IIFE scope so they
        survive across calls.  Also read `args` inside the returned function,
        not in the outer shell.
    --]]
    {
        name = "follow",
        help = "Follow a player. Run again to stop.",
        args = "<name>",
        run  = (function()
            -- These three live in the closure and persist across every call
            local active = false
            local conn   = nil
            local target = nil

            return function(args)
                active = not active

                if active then
                    local query = (args or ""):match("^%s*(.-)%s*$"):lower()

                    if query == "" then
                        active = false
                        notify("Follow", "Usage: "..PREFIX.."follow <name>")
                        return
                    end

                    target = nil

                    -- Pass 1: DisplayName
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= lp and p.DisplayName:lower():find(query, 1, true) then
                            target = p; break
                        end
                    end
                    -- Pass 2: Username fallback
                    if not target then
                        for _, p in ipairs(Players:GetPlayers()) do
                            if p ~= lp and p.Name:lower():find(query, 1, true) then
                                target = p; break
                            end
                        end
                    end

                    if not target then
                        active = false
                        notify("Follow", "Player not found: "..query)
                        return
                    end

                    conn = RunService.RenderStepped:Connect(function()
                        local myHRP    = getHRP()
                        local theirHRP = target.Character
                                         and target.Character:FindFirstChild("HumanoidRootPart")
                        if myHRP and theirHRP then
                            myHRP.CFrame = theirHRP.CFrame * CFrame.new(0, 0, 3.5)
                        end
                    end)

                    notify("Follow", "Following "..target.Name.." — run again to stop.")
                else
                    if conn then conn:Disconnect(); conn = nil end
                    target = nil
                    notify("Follow", "OFF")
                end
            end
        end)(),
    },

    -- ── 18. DANCE ─────────────────────────────────────────────────────────────
    --[[
        ROOT CAUSE 1: Instance.new("Animation", parent) — the second argument
        is a deprecated parent shortcut that newer Roblox silently ignores for
        Animation instances specifically, meaning AnimationId never gets set.

        ROOT CAUSE 2: Even if you use Instance.new and set AnimationId right
        after, you must set the property BEFORE calling LoadAnimation, otherwise
        the animator loads an empty animation and produces a "game" error because
        the AnimationId resolves to 0/invalid.

        FIX: Create Animation with no parent arg, set AnimationId, THEN load.
        Also added a stop toggle and 3 dances to cycle through.
    --]]
    {
        name = "dance",
        help = "Toggle a dance emote (cycles through 3)",
        args = "",
        run  = (function()
            local track = nil
            local dances = {
                "rbxassetid://507771019",
                "rbxassetid://507776043",
                "rbxassetid://507777268",
            }
            local idx = 0

            return function(_)
                local hum = getHum()
                if not hum then notify("Dance", "No humanoid."); return end

                -- If already dancing, stop
                if track and track.IsPlaying then
                    track:Stop()
                    track = nil
                    notify("Dance", "Stopped.")
                    return
                end

                -- Advance to next dance
                idx = (idx % #dances) + 1

                -- Create Animation properly — NO parent arg, set id first
                local anim           = Instance.new("Animation")
                anim.AnimationId     = dances[idx]

                local ok, loaded = pcall(function()
                    return hum:LoadAnimation(anim)
                end)

                if not ok or not loaded then
                    notify("Dance", "Load failed: "..tostring(loaded))
                    return
                end

                track = loaded
                track.Priority = Enum.AnimationPriority.Action
                track:Play()
                notify("Dance", "Dancing ("..idx.."/"..#dances..") — run again to stop/switch.")
            end
        end)(),
    },

    -- ── 19. TRIVIA ────────────────────────────────────────────────────────────
    --[[
        ROOT CAUSE 1: Players.PlayerChatted does not exist. You must connect
        to Player.Chatted on each individual player instance.

        ROOT CAUSE 2: The match comparison stripped spaces from the player's
        message (gsub "%s+" → "") but NOT from the stored answer. So a two-word
        answer like "carbon dioxide" was stored as "carbon dioxide" but the
        player message became "carbondioxide", and they never matched.

        FIX: Normalise BOTH sides the same way before comparing — strip spaces
        AND lowercase.

        FIX 3: next question now fires from inside the Chatted callback after a
        correct answer, not in a separate unconnected flow.

        ADDED: 20 extra questions (76 total). Randomised with a recency buffer
        of 10 so the same question can't repeat within 10 questions.
    --]]
    {
        name = "trivia",
        help = "Start/stop trivia game with chat answers",
        args = "",
        run  = (function()
            local active          = false
            local currentAnswer   = nil    -- normalised form
            local chatConns       = {}     -- one RBXScriptConnection per player
            local playerAddedConn = nil

            local ALL_QUESTIONS = {
                -- original set
                {"What planet is known as the Red Planet?",         "mars"},
                {"How many hearts does an octopus have?",           "3"},
                {"What is 5 + 7?",                                  "12"},
                {"What is the capital of Australia?",               "canberra"},
                {"What gas do plants absorb from the air?",         "carbon dioxide"},
                {"What is the largest ocean?",                      "pacific"},
                {"What is H2O commonly known as?",                  "water"},
                {"How many legs does a spider have?",               "8"},
                {"What year did Roblox release?",                   "2006"},
                {"What is the square root of 81?",                  "9"},
                {"What is the fastest land animal?",                "cheetah"},
                {"What is the tallest mountain?",                   "everest"},
                {"What is the currency of Japan?",                  "yen"},
                {"How many continents are there?",                  "7"},
                {"What is the boiling point of water in Celsius?",  "100"},
                {"What planet is closest to the sun?",              "mercury"},
                {"What colour do you get mixing red and blue?",     "purple"},
                {"What is the capital of France?",                  "paris"},
                {"How many days are in a leap year?",               "366"},
                {"What is the hardest natural substance?",          "diamond"},
                {"What is the biggest mammal?",                     "blue whale"},
                {"What language has the most native speakers?",     "mandarin"},
                {"What is 9 x 9?",                                  "81"},
                {"What is the capital of Italy?",                   "rome"},
                {"What organ pumps blood?",                         "heart"},
                {"What is the freezing point of water in Celsius?", "0"},
                {"What planet is famous for its rings?",            "saturn"},
                {"What is the main gas in Earth's atmosphere?",     "nitrogen"},
                {"How many bones does an adult human have?",        "206"},
                {"What is the capital of Germany?",                 "berlin"},
                {"What fruit features in the saying a day keeps the doctor away?", "apple"},
                {"What is 3 squared?",                              "9"},
                {"What is the largest hot desert?",                 "sahara"},
                {"What is the smallest prime number?",              "2"},
                {"What is the capital of Spain?",                   "madrid"},
                {"What is 100 divided by 4?",                       "25"},
                {"What is the official language of Brazil?",        "portuguese"},
                {"What ocean lies between Africa and Australia?",   "indian"},
                {"What is 15 + 15?",                                "30"},
                {"What is the capital of the USA?",                 "washington"},
                {"What animal is known as king of the jungle?",     "lion"},
                {"What is the square root of 144?",                 "12"},
                {"What is the largest continent?",                  "asia"},
                {"What is the capital of China?",                   "beijing"},
                {"What is 7 x 7?",                                  "49"},
                {"What planet appears blue from space?",            "earth"},
                {"What is the smallest country in the world?",      "vatican"},
                {"What is the chemical symbol for gold?",           "au"},
                {"What is 50 + 50?",                                "100"},
                {"What is the capital of Russia?",                  "moscow"},
                {"What is the fastest fish?",                       "sailfish"},
                {"What is 2 + 2 x 2?",                             "6"},
                {"What is the primary source of energy for Earth?", "sun"},
                {"What is the capital of India?",                   "new delhi"},
                {"What is the longest river in the world?",         "nile"},
                {"What is 8 x 8?",                                  "64"},
                -- 20 new questions
                {"What is the capital of Japan?",                   "tokyo"},
                {"What is the capital of Canada?",                  "ottawa"},
                {"How many sides does a hexagon have?",             "6"},
                {"What is the chemical symbol for water?",          "h2o"},
                {"What is the largest planet in the solar system?", "jupiter"},
                {"What is the capital of Brazil?",                  "brasilia"},
                {"How many players are on a standard football team?","11"},
                {"What is the chemical symbol for iron?",           "fe"},
                {"What is the smallest planet in the solar system?","mercury"},
                {"What is the capital of Egypt?",                   "cairo"},
                {"How many strings does a standard guitar have?",   "6"},
                {"What is the powerhouse of the cell?",             "mitochondria"},
                {"What is the capital of South Korea?",             "seoul"},
                {"What is the square root of 256?",                 "16"},
                {"What is 13 x 13?",                                "169"},
                {"What is the capital of Mexico?",                  "mexico city"},
                {"How many hours are in one week?",                 "168"},
                {"What is the chemical symbol for silver?",         "ag"},
                {"What is the largest organ in the human body?",    "skin"},
                {"What is the capital of Argentina?",               "buenos aires"},
            }

            local RECENCY = 10
            local recentIdx = {}    -- ring buffer of recently used indices
            local pool      = {}    -- shuffled remaining indices

            -- Normalise: lowercase + strip all whitespace so "carbon dioxide"
            -- and "carbondioxide" both become "carbondioxide"
            local function norm(s)
                return tostring(s):lower():gsub("%s+", "")
            end

            local function rebuildPool()
                local blocked = {}
                for _, i in ipairs(recentIdx) do blocked[i] = true end
                pool = {}
                for i = 1, #ALL_QUESTIONS do
                    if not blocked[i] then table.insert(pool, i) end
                end
                -- Fisher-Yates shuffle
                for i = #pool, 2, -1 do
                    local j = math.random(1, i)
                    pool[i], pool[j] = pool[j], pool[i]
                end
            end

            local function pickNext()
                if #pool == 0 then rebuildPool() end
                local i = table.remove(pool, 1)
                table.insert(recentIdx, i)
                if #recentIdx > RECENCY then table.remove(recentIdx, 1) end
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
                        table.insert(list, {n = displayName(p), s = s})
                    end
                end
                table.sort(list, function(a,b) return a.s > b.s end)
                local out = "🏆 Scores: "
                for i = 1, math.min(5, #list) do
                    out = out .. i .. ". " .. list[i].n .. "=" .. list[i].s .. "  "
                end
                sendChat(out)
            end

            local function askQuestion()
                if not active then return end
                local q       = pickNext()
                currentAnswer = norm(q[2])
                sendChat("🧠 " .. q[1])
            end

            local function connectPlayer(p)
                -- Connect this player's chat; fires whenever they type anything
                local c = p.Chatted:Connect(function(msg)
                    if not active or not currentAnswer then return end
                    if norm(msg) == currentAnswer then
                        scores[p] = (scores[p] or 0) + 1
                        sendChat("✅ " .. displayName(p)
                                 .. " got it! (answer: " .. currentAnswer
                                 .. ")  total: " .. scores[p])
                        showLeaderboard()
                        task.wait(0.8)
                        askQuestion()
                    end
                end)
                table.insert(chatConns, c)
            end

            local function startTrivia()
                active    = true
                scores    = {}
                recentIdx = {}
                pool      = {}

                for _, p in ipairs(Players:GetPlayers()) do
                    connectPlayer(p)
                end
                playerAddedConn = Players.PlayerAdded:Connect(function(p)
                    if active then connectPlayer(p) end
                end)

                sendChat("🎮 Trivia started! Answer in chat. Type "..PREFIX.."trivia to stop.")
                task.wait(1)
                askQuestion()
            end

            local function stopTrivia()
                active        = false
                currentAnswer = nil

                for _, c in ipairs(chatConns) do pcall(function() c:Disconnect() end) end
                chatConns = {}

                if playerAddedConn then
                    playerAddedConn:Disconnect()
                    playerAddedConn = nil
                end

                showLeaderboard()
                sendChat("🛑 Trivia ended!")
            end

            return function(_)
                if active then stopTrivia() else startTrivia() end
            end
        end)(),
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
        run = (function(args)
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
                    math.random(-200,200),
                    math.random(0,0),
                    math.random(-200,200)
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
    l.Text           = text or ""
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

-- List
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

-- Build rows
local selectedCmd = nil

local function runCommand(cmd, argStr)
    argStr = argStr or ""
    local ok, err = pcall(cmd.run, argStr)
    if not ok then notify("Error: "..cmd.name, tostring(err):sub(1,80), 5) end
end

local function buildList(filter)
    for _, ch in ipairs(scroll:GetChildren()) do
        if ch:IsA("Frame") then ch:Destroy() end
    end
    for i, cmd in ipairs(COMMANDS) do
        if filter and filter ~= "" then
            local f = filter:lower()
            if not cmd.name:lower():find(f,1,true) and
               not cmd.help:lower():find(f,1,true) then continue end
        end

        local row = mkF(scroll, TH.Row, UDim2.new(1,0,0,52), UDim2.new(0,0,0,0), "Row_"..cmd.name, 6, 2)
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
            -- double-click = run
            local now = tick()
            if now - lastClick < 0.35 then runCommand(cmd, argBox.Text) end
            lastClick = now
        end)

        local badge = mkF(row, TH.AccentLo, UDim2.new(0,20,0,20), UDim2.new(0,8,0.5,-10), "Badge", 4, 3)
        mkL(badge, PREFIX, TH.Accent, Enum.Font.Code, 10,
            UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), Enum.TextXAlignment.Center, nil, "PL", 4)

        mkL(row, cmd.name, TH.TextPri, Enum.Font.GothamBold, 13,
            UDim2.new(1,-90,0,22), UDim2.new(0,34,0,4), nil, nil, "Name", 3)
        mkL(row, cmd.help, TH.TextSec, Enum.Font.Gotham, 11,
            UDim2.new(1,-90,0,18), UDim2.new(0,34,0,28), nil, nil, "Help", 3)

        if cmd.args ~= "" then
            mkL(row, cmd.args, TH.TextDis, Enum.Font.Code, 10,
                UDim2.new(0,80,1,0), UDim2.new(1,-84,0,0),
                Enum.TextXAlignment.Right, nil, "Args", 3)
        end

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

searchBox:GetPropertyChangedSignal("Text"):Connect(function() buildList(searchBox.Text) end)
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

    if cmdName == "open"  then openMenu();  return end
    if cmdName == "close" then closeMenu(); return end

    for _, cmd in ipairs(COMMANDS) do
        if cmd.name:lower() == cmdName then
            runCommand(cmd, args)
            return
        end
    end

    notify("Unknown Command", PREFIX .. cmdName)
end

lp.Chatted:Connect(onChat)

-- ════════════════════════════════════════════════════════════════════════════
--  KEYBIND  —  RightAlt toggles menu
-- ════════════════════════════════════════════════════════════════════════════

UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.RightAlt then
        win.Visible = not win.Visible
    end
end)

notify("Command Menu", "Loaded! Type "..PREFIX.."open or press RightAlt", 4)
