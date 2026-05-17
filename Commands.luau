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

    {
        name = {"help", "h", "commands"},
        help = "Reminder about the menu",
        args = "",
        run = function(_)
            notify("Commands", "Type "..PREFIX.."open or press RightAlt.", 4)
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
        name = {"hatrean", "hat", "reanim"},
        help = "FE hat reanimation — re-weld accessories locally",
        args = "",
        run = function(_)
            local c = lp.Character
            if not c then notify("Hat Rean", "No character."); return end
            local hrp = c:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            for _, acc in ipairs(c:GetChildren()) do
                if acc:IsA("Accessory") then
                    local handle = acc:FindFirstChild("Handle")
                    if handle then
                        local clone = handle:Clone()
                        clone.CanCollide = false
                        clone.Massless = true
                        clone.Parent = workspace

                        local weld = Instance.new("Motor6D")
                        weld.Part0 = hrp
                        weld.Part1 = clone
                        weld.C0 = hrp.CFrame:ToObjectSpace(handle.CFrame)
                        weld.Parent = hrp

                        handle.LocalTransparencyModifier = 1
                    end
                end
            end

            notify("Hat Rean", "Done.")
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
        name = {"goto", "tp", "teleport"},
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
        name = {"orbit", "circle", "spin"},
        help = "Orbit player",
        args = "<name>",
        run = function() end,
    },

    {
        name = {"stare", "look", "watch"},
        help = "Look at player",
        args = "<name>",
        run = function() end,
    },

    {
        name = {"spam", "loopchat", "repeat"},
        help = "Spam chat",
        args = "<message>",
        run = function() end,
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

        local row = mkF(scroll, TH.Row, UDim2.new(1,0,0,52), UDim2.new(0,0,0,0), "Row_" .. (type(cmd.name) == "table" and cmd.name[1] or cmd.name), 6, 2)
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
				if type(cmd.name) == "table" then
						for _, alias in ipairs(cmd.name) do
								if alias:lower() == cmdName then
										runCommand(cmd, args)
										return
								end
						end
				else
						if cmd.name:lower() == cmdName then
								runCommand(cmd, args)
								return
						end
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
