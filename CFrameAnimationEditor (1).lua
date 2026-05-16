--[[
	╔══════════════════════════════════════════════════════════════════════╗
	║        CFrame Lerp Animation Editor  •  Executor Edition  v3.0      ║
	║  Direct Motor6D.C0 lerping  •  NO AnimationTracks / KeyframeSeq     ║
	╚══════════════════════════════════════════════════════════════════════╝

	v3.0 CHANGES
	  - Per-axis sine:  X, Y, Z each have their own Amp / Speed / Offset / Reverse
	  - Per-axis spin:  X, Y, Z each have their own Speed / Reverse / Enable
	    Uses math.cos(sine * speed) so it oscillates smoothly and is lerp-safe
	  - Accessories detected as direct Accessory children of the character,
	    reading the Handle's Weld/Motor6D for the C0 offset
	  - Typed values still bypass slider limits
	  - Spin no longer resets / glitches
--]]

-- ═══════════════════════════════════════════════════════════════════════
--  SERVICES
-- ═══════════════════════════════════════════════════════════════════════
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local CoreGui          = game:GetService("CoreGui")
local Camera           = workspace.CurrentCamera

local player = Players.LocalPlayer

-- ═══════════════════════════════════════════════════════════════════════
--  WAIT FOR CHARACTER
-- ═══════════════════════════════════════════════════════════════════════
local char = player.Character or player.CharacterAdded:Wait()

local function waitForRig(c)
	local t0 = tick()
	while not (c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso"))
		and tick()-t0 < 5 do task.wait(0.05) end
	task.wait(0.2)
end
waitForRig(char)

-- ═══════════════════════════════════════════════════════════════════════
--  DISABLE ROBLOX DEFAULT ANIMATE SCRIPT
-- ═══════════════════════════════════════════════════════════════════════
local function disableAnimate(c)
	local anim = c:FindFirstChild("Animate")
	if anim and anim:IsA("LocalScript") then anim.Disabled = true end
	local hum = c:FindFirstChildOfClass("Humanoid")
	if hum then
		local animator = hum:FindFirstChildOfClass("Animator")
		if animator then
			for _, t in ipairs(animator:GetPlayingAnimationTracks()) do t:Stop(0) end
		end
	end
end
disableAnimate(char)

-- ═══════════════════════════════════════════════════════════════════════
--  SCREEN SCALING
-- ═══════════════════════════════════════════════════════════════════════
local BASE_W, BASE_H = 1920, 1080
local function calcScale()
	local vp = Camera.ViewportSize
	return math.min(vp.X/BASE_W, vp.Y/BASE_H)
end
local S = calcScale()
local function px(n)   return math.max(1, math.round(n*S)) end
local function ud(s,o) return UDim.new(s, px(o)) end
local FS = { tiny=math.max(8,px(10)), sm=math.max(9,px(11)), md=math.max(10,px(13)) }
Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function() S=calcScale() end)

-- ═══════════════════════════════════════════════════════════════════════
--  MATH
-- ═══════════════════════════════════════════════════════════════════════
local cf     = CFrame.new
local angles = CFrame.Angles
local function cfMul(a,b) return a*b end
local function Lerp(a,b,t) return a:Lerp(b,t) end
local pi     = math.pi
local sin    = math.sin
local cos    = math.cos
local fmt    = string.format
local TWO_PI = pi*2

-- ═══════════════════════════════════════════════════════════════════════
--  R6 DEFAULTS
-- ═══════════════════════════════════════════════════════════════════════
local R6_DEF = {
	RootJoint     = { pos=cf(0,0,0),     rot=angles(-pi/2,0,pi)  },
	Neck          = { pos=cf(0,1,0),     rot=angles(-pi/2,0,pi)  },
	RightShoulder = { pos=cf(1,0.5,0),   rot=angles(0,pi/2,0)    },
	LeftShoulder  = { pos=cf(-1,0.5,0),  rot=angles(0,-pi/2,0)   },
	RightHip      = { pos=cf(0.5,-1,0),  rot=angles(0,pi/2,0)    },
	LeftHip       = { pos=cf(-0.5,-1,0), rot=angles(0,-pi/2,0)   },
}
local DISPLAY_NAMES = {
	RootJoint="Torso (RootJoint)", Neck="Head (Neck)",
	RightShoulder="R Arm (RightShoulder)", LeftShoulder="L Arm (LeftShoulder)",
	RightHip="R Leg (RightHip)", LeftHip="L Leg (LeftHip)",
}
local MIRROR_MAP = {
	RightShoulder="LeftShoulder", LeftShoulder="RightShoulder",
	RightHip="LeftHip",          LeftHip="RightHip",
}
local R6_ORDER = {"RootJoint","Neck","RightShoulder","LeftShoulder","RightHip","LeftHip"}

-- ═══════════════════════════════════════════════════════════════════════
--  JOINT DATA  (per-axis sine + per-axis cos spin)
-- ═══════════════════════════════════════════════════════════════════════
--[[
	Sine per axis:
	  sineX = { amp, speed, offset, reverse }   → added to rotX
	  sineY = { ... }                            → added to rotY
	  sineZ = { ... }                            → added to rotZ
	  sinePosX/Y/Z same idea for position

	Spin per axis (cos-based, lerp-safe):
	  spinX = { enabled, speed, reverse }
	  spinY = { ... }
	  spinZ = { ... }
	  Each produces:  cos(sine * speed) * π   added to that rotation axis
	  This oscillates between -π and +π, never overflows, lerp handles it fine.
]]

local function makeSineAxis()
	return { amp=0, speed=1, offset=0, reverse=false }
end
local function makeSpinAxis()
	return { enabled=false, speed=1, reverse=false }
end

local function makeJointData(motor)
	local name = motor.Name
	local def  = R6_DEF[name]
	local bpx,bpy,bpz, brx,bry,brz

	if def then
		bpx,bpy,bpz = def.pos.X, def.pos.Y, def.pos.Z
		brx,bry,brz = def.rot:ToEulerAnglesXYZ()
	else
		local c0 = motor.C0
		bpx,bpy,bpz = c0.X, c0.Y, c0.Z
		brx,bry,brz = c0:ToEulerAnglesXYZ()
	end

	return {
		name=name, motor=motor, enabled=true,
		-- base transform
		posX=bpx, posY=bpy, posZ=bpz,
		rotX=brx, rotY=bry, rotZ=brz,
		-- per-axis rotation sine
		sineX=makeSineAxis(), sineY=makeSineAxis(), sineZ=makeSineAxis(),
		-- per-axis position sine
		sinePosX=makeSineAxis(), sinePosY=makeSineAxis(), sinePosZ=makeSineAxis(),
		-- per-axis cos spin
		spinX=makeSpinAxis(), spinY=makeSpinAxis(), spinZ=makeSpinAxis(),
		-- axis lock
		lockX=false, lockY=false, lockZ=false,
	}
end

-- ═══════════════════════════════════════════════════════════════════════
--  DETECT ALL MOTORS + ACCESSORIES
--
--  Body joints:   Motor6D descendants anywhere in character
--  Accessories:   Direct Accessory children of character
--                 → their Handle part → Weld / Motor6D on Handle
-- ═══════════════════════════════════════════════════════════════════════
local allJointData = {}
local jointOrder   = {}

local function getHandleWeld(accessory)
	local handle = accessory:FindFirstChild("Handle")
	if not handle then return nil end
	-- Look for Motor6D or Weld on the Handle
	for _, v in ipairs(handle:GetChildren()) do
		if v:IsA("Motor6D") or v:IsA("Weld") then
			return v
		end
	end
	-- Also check for WeldConstraint (some accessories use this)
	for _, v in ipairs(handle:GetChildren()) do
		if v:IsA("WeldConstraint") then return v end
	end
	return nil
end

local function detectAllMotors(c)
	allJointData = {}
	jointOrder   = {}
	local seen = {}   -- prevent duplicate keys

	-- Collect body Motor6Ds
	local bodyMotors = {}
	for _, v in ipairs(c:GetDescendants()) do
		if v:IsA("Motor6D") then
			local key = v.Name
			if not bodyMotors[key] then bodyMotors[key] = v end
		end
	end

	-- Insert R6 body joints first in order
	for _, name in ipairs(R6_ORDER) do
		if bodyMotors[name] and not seen[name] then
			allJointData[name] = makeJointData(bodyMotors[name])
			table.insert(jointOrder, name)
			seen[name] = true
			bodyMotors[name] = nil
		end
	end

	-- Insert any remaining body motors (non-standard body welds)
	local extras = {}
	for k in pairs(bodyMotors) do table.insert(extras,k) end
	table.sort(extras)
	for _, key in ipairs(extras) do
		if not seen[key] then
			allJointData[key] = makeJointData(bodyMotors[key])
			table.insert(jointOrder, key)
			seen[key] = true
		end
	end

	-- Now scan direct Accessory children of character
	for _, child in ipairs(c:GetChildren()) do
		if child:IsA("Accessory") then
			local weld = getHandleWeld(child)
			if weld then
				-- Key by accessory name so it's human-readable in GUI
				local key = child.Name
				-- If duplicate name, suffix with _2 etc
				local baseKey = key
				local n = 2
				while seen[key] do key = baseKey.."_"..n; n=n+1 end

				-- Build a fake "motor" proxy table since WeldConstraint
				-- doesn't have C0; we'll wrap it
				local fakeMotor
				if weld:IsA("Motor6D") or weld:IsA("Weld") then
					fakeMotor = weld
				else
					-- WeldConstraint — no C0, treat as identity
					fakeMotor = { Name=key, C0=CFrame.new() }
					-- We'll store the WeldConstraint separately for later
				end

				-- For Weld/Motor6D, C0 is the offset
				local data = makeJointData(fakeMotor)
				data.name = key
				data.accessoryName = child.Name
				data.weld = weld   -- keep direct reference
				data.isAccessory = true

				allJointData[key] = data
				table.insert(jointOrder, key)
				seen[key] = true
			end
		end
	end
end

detectAllMotors(char)

-- ═══════════════════════════════════════════════════════════════════════
--  UNDO / REDO
-- ═══════════════════════════════════════════════════════════════════════
local undoStack, redoStack = {}, {}

local function deepCopy(t)
	if type(t)~="table" then return t end
	local c={}
	for k,v in pairs(t) do
		if k~="motor" and k~="weld" then c[k]=deepCopy(v)
		else c[k]=v end
	end
	return c
end
local function snapshotAll()
	local s={}; for n,d in pairs(allJointData) do s[n]=deepCopy(d) end; return s
end
local function pushUndo()
	table.insert(undoStack,snapshotAll())
	if #undoStack>50 then table.remove(undoStack,1) end
	redoStack={}
end
local function restoreSnapshot(snap)
	for name,saved in pairs(snap) do
		if allJointData[name] then
			saved.motor=allJointData[name].motor
			saved.weld =allJointData[name].weld
			allJointData[name]=saved
		end
	end
end
local function doUndo()
	if #undoStack==0 then return end
	table.insert(redoStack,snapshotAll()); restoreSnapshot(table.remove(undoStack))
end
local function doRedo()
	if #redoStack==0 then return end
	table.insert(undoStack,snapshotAll()); restoreSnapshot(table.remove(redoStack))
end
local clipboard=nil

-- ═══════════════════════════════════════════════════════════════════════
--  CODE EXPORT
-- ═══════════════════════════════════════════════════════════════════════
local function fmtN(n) return fmt("%.16g",n) end

local function sineAxisExpr(base, sa)
	-- Returns base +/- amp*sin(sine*speed+offset)
	if sa.amp==0 then return fmtN(base) end
	local realAmp = sa.reverse and -sa.amp or sa.amp
	local sign    = realAmp>=0 and "+" or "-"
	local offStr  = sa.offset~=0 and fmt("+%s",fmtN(sa.offset)) or ""
	return fmt("%s%s%s*sin(sine*%s%s)",
		fmtN(base), sign, fmtN(math.abs(realAmp)), fmtN(sa.speed), offStr)
end

local function spinAxisExpr(spinA)
	-- cos(sine*speed)*π  oscillates ±π, lerp-safe
	if not spinA.enabled then return nil end
	local dir = spinA.reverse and "-" or "+"
	return fmt("%s3.141592653589793*cos(sine*%s)", dir, fmtN(spinA.speed))
end

local function buildCf(d)
	local function axExpr(base, sa)
		if sa.amp==0 then return fmtN(base) end
		local r=sa.reverse and -sa.amp or sa.amp
		local sign=r>=0 and "+" or "-"
		local off=sa.offset~=0 and fmt("+%s",fmtN(sa.offset)) or ""
		return fmt("%s%s%s*sin(sine*%s%s)",fmtN(base),sign,fmtN(math.abs(r)),fmtN(sa.speed),off)
	end
	return fmt("cf(%s,%s,%s)",axExpr(d.posX,d.sinePosX),axExpr(d.posY,d.sinePosY),axExpr(d.posZ,d.sinePosZ))
end

local function buildAngles(d)
	local function rotExpr(base, sa, spA)
		local s = sineAxisExpr(base, sa)
		local sp = spinAxisExpr(spA)
		if sp then
			return "("..s..sp..")"
		end
		return s
	end
	return fmt("angles(%s,%s,%s)",
		rotExpr(d.rotX,d.sineX,d.spinX),
		rotExpr(d.rotY,d.sineY,d.spinY),
		rotExpr(d.rotZ,d.sineZ,d.spinZ))
end

local function exportLine(varName,d)
	return fmt("%s.C0=Lerp(%s.C0,cfMul(%s,%s),deltaTime)",varName,varName,buildCf(d),buildAngles(d))
end

local function generateCode()
	local lines={}
	for _,name in ipairs(jointOrder) do
		local d=allJointData[name]
		if d and d.enabled then table.insert(lines,exportLine(name,d)) end
	end
	return table.concat(lines,"\n")
end

-- ═══════════════════════════════════════════════════════════════════════
--  RUNTIME ANIMATION
-- ═══════════════════════════════════════════════════════════════════════
local sine  = 0
local ALPHA = 0.2

local function evalSineAxis(base, sa)
	if sa.amp==0 then return base end
	local dir = sa.reverse and -1 or 1
	return base + sin(sine*sa.speed + sa.offset) * sa.amp * dir
end

local function evalSpinAxis(spA)
	-- cos oscillates between -1 and +1, multiply by π to get full rotation range
	-- This is lerp-safe because the output is always bounded ±π
	if not spA.enabled then return 0 end
	local dir = spA.reverse and -1 or 1
	return cos(sine * spA.speed) * pi * dir
end

local function applyJoint(d)
	-- Get the actual weld/motor to write to
	local motor = d.isAccessory and d.weld or d.motor
	if not motor or not motor.Parent or not d.enabled then return end
	-- WeldConstraint doesn't have C0
	if motor:IsA("WeldConstraint") then return end

	local px_ = evalSineAxis(d.posX, d.sinePosX)
	local py_ = evalSineAxis(d.posY, d.sinePosY)
	local pz_ = evalSineAxis(d.posZ, d.sinePosZ)

	local rx = evalSineAxis(d.rotX, d.sineX) + evalSpinAxis(d.spinX)
	local ry = evalSineAxis(d.rotY, d.sineY) + evalSpinAxis(d.spinY)
	local rz = evalSineAxis(d.rotZ, d.sineZ) + evalSpinAxis(d.spinZ)

	motor.C0 = Lerp(motor.C0, cfMul(cf(px_,py_,pz_), angles(rx,ry,rz)), ALPHA)
end

local rtConn
local function startRuntime()
	if rtConn then rtConn:Disconnect() end
	rtConn = RunService.RenderStepped:Connect(function(dt)
		sine = sine + dt * 60 * 0.016
		for _, name in ipairs(jointOrder) do
			local d = allJointData[name]
			if d then applyJoint(d) end
		end
	end)
end
startRuntime()

-- ═══════════════════════════════════════════════════════════════════════
--  GUI
-- ═══════════════════════════════════════════════════════════════════════
local old = CoreGui:FindFirstChild("CFrameAnimEditor")
if old then old:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name="CFrameAnimEditor" ScreenGui.ResetOnSpawn=false
ScreenGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset=true ScreenGui.DisplayOrder=999
if not pcall(function() ScreenGui.Parent=CoreGui end) then
	ScreenGui.Parent=player.PlayerGui
end

local C={
	bg=Color3.fromRGB(10,10,14),       panel=Color3.fromRGB(18,18,25),
	elevated=Color3.fromRGB(26,26,36), border=Color3.fromRGB(40,40,56),
	accent=Color3.fromRGB(78,228,196), accent2=Color3.fromRGB(158,128,255),
	warn=Color3.fromRGB(251,191,36),   red=Color3.fromRGB(248,96,96),
	green=Color3.fromRGB(68,220,118),  text=Color3.fromRGB(212,212,228),
	muted=Color3.fromRGB(105,105,135), white=Color3.fromRGB(255,255,255),
	code=Color3.fromRGB(120,255,190),  revOn=Color3.fromRGB(248,150,60),
	axisX=Color3.fromRGB(255,90,90),   axisY=Color3.fromRGB(90,220,90),
	axisZ=Color3.fromRGB(90,150,255),
	subpanel=Color3.fromRGB(22,22,32),
}

-- Instance helpers
local function make(cls,props,parent)
	local i=Instance.new(cls); for k,v in pairs(props) do i[k]=v end
	if parent then i.Parent=parent end; return i
end
local function frm(props,parent)
	props.BackgroundColor3=props.BackgroundColor3 or C.panel
	props.BorderSizePixel=props.BorderSizePixel or 0
	return make("Frame",props,parent)
end
local function lbl(props,parent)
	props.BackgroundTransparency=props.BackgroundTransparency or 1
	props.TextColor3=props.TextColor3 or C.text
	props.Font=props.Font or Enum.Font.Gotham
	props.TextSize=props.TextSize or FS.sm
	return make("TextLabel",props,parent)
end
local function btn(props,parent)
	props.BackgroundColor3=props.BackgroundColor3 or C.elevated
	props.BorderSizePixel=0
	props.Font=props.Font or Enum.Font.GothamBold
	props.TextSize=props.TextSize or FS.tiny
	props.TextColor3=props.TextColor3 or C.text
	props.AutoButtonColor=false
	local b=make("TextButton",props,parent)
	local orig=props.BackgroundColor3
	b.MouseEnter:Connect(function()
		TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=Color3.new(
			math.min(1,orig.R+0.08),math.min(1,orig.G+0.08),math.min(1,orig.B+0.08))}):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=orig}):Play()
	end)
	return b
end
local function crn(r,parent) return make("UICorner",{CornerRadius=ud(0,r)},parent) end
local function pad(t,b,l,r,parent)
	return make("UIPadding",{PaddingTop=ud(0,t),PaddingBottom=ud(0,b),
		PaddingLeft=ud(0,l),PaddingRight=ud(0,r)},parent)
end
local function strk(col,th,parent) return make("UIStroke",{Color=col,Thickness=th},parent) end
local function listL(dir,gap,va,parent)
	return make("UIListLayout",{FillDirection=dir or Enum.FillDirection.Vertical,
		Padding=ud(0,gap or 3),VerticalAlignment=va or Enum.VerticalAlignment.Top,
		SortOrder=Enum.SortOrder.LayoutOrder},parent)
end

-- Dimensions
local WIN_W=px(560); local WIN_H=px(660)
local TITLE_H=px(34); local TOOL_H=px(32)
local SEARCH_H=px(30); local PRESET_H=px(30)
local CODE_H=px(100)
local SCROLL_H=WIN_H-TITLE_H-TOOL_H-SEARCH_H-PRESET_H-px(4)-CODE_H
local vp=Camera.ViewportSize
local WX=math.round(vp.X*0.03); local WY=math.round(vp.Y*0.03)

-- Main window
local Main=frm({Name="Main",Size=UDim2.fromOffset(WIN_W,WIN_H),
	Position=UDim2.fromOffset(WX,WY),BackgroundColor3=C.bg,ClipsDescendants=true},ScreenGui)
crn(9,Main); strk(C.border,1.5,Main)

-- Title bar
local TitleBar=frm({Size=UDim2.new(1,0,0,TITLE_H),BackgroundColor3=C.panel},Main)
crn(9,TitleBar)
frm({Size=UDim2.new(1,0,0,px(9)),Position=UDim2.new(0,0,1,-px(9)),BackgroundColor3=C.panel},TitleBar)
frm({Size=UDim2.new(0,px(3),1,0),BackgroundColor3=C.accent},TitleBar)
lbl({Size=UDim2.new(1,-px(116),1,0),Position=UDim2.new(0,px(10),0,0),
	Text="Lerp Animator",TextColor3=C.white,
	Font=Enum.Font.GothamBold,TextSize=FS.md,TextXAlignment=Enum.TextXAlignment.Left},TitleBar)
local vb=frm({Size=UDim2.fromOffset(px(36),px(15)),
	Position=UDim2.new(1,-px(90),0.5,-px(7)),BackgroundColor3=C.accent2},TitleBar)
crn(3,vb)
lbl({Size=UDim2.new(1,0,1,0),Text="v3.0",Font=Enum.Font.GothamBold,
	TextSize=FS.tiny,TextColor3=C.white,BackgroundTransparency=0},vb)

local CloseBtn=btn({Size=UDim2.fromOffset(px(20),px(20)),
	Position=UDim2.new(1,-px(24),0.5,-px(10)),
	BackgroundColor3=C.red,Text="X",TextSize=FS.tiny,TextColor3=C.white},TitleBar)
crn(4,CloseBtn); CloseBtn.MouseButton1Click:Connect(function() Main.Visible=false end)

local MinBtn=btn({Size=UDim2.fromOffset(px(20),px(20)),
	Position=UDim2.new(1,-px(48),0.5,-px(10)),
	BackgroundColor3=C.elevated,Text="-",TextSize=FS.tiny,TextColor3=C.muted},TitleBar)
crn(4,MinBtn)
local minimised=false
MinBtn.MouseButton1Click:Connect(function()
	minimised=not minimised
	TweenService:Create(Main,TweenInfo.new(0.18,Enum.EasingStyle.Quint),{
		Size=minimised and UDim2.fromOffset(WIN_W,TITLE_H) or UDim2.fromOffset(WIN_W,WIN_H)}):Play()
end)

-- Drag
do
	local dragging,ds,sp_
	TitleBar.InputBegan:Connect(function(inp)
		if inp.UserInputType==Enum.UserInputType.MouseButton1 then
			dragging=true ds=inp.Position sp_=Main.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(inp)
		if dragging and inp.UserInputType==Enum.UserInputType.MouseMovement then
			local d=inp.Position-ds
			Main.Position=UDim2.fromOffset(sp_.X.Offset+d.X,sp_.Y.Offset+d.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(inp)
		if inp.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
	end)
end

-- Toolbar
local Toolbar=frm({Size=UDim2.new(1,0,0,TOOL_H),
	Position=UDim2.new(0,0,0,TITLE_H),BackgroundColor3=C.panel},Main)
pad(px(4),px(4),px(6),px(6),Toolbar)
listL(Enum.FillDirection.Horizontal,px(3),Enum.VerticalAlignment.Center,Toolbar)
local function tbBtn(txt,bgCol,txCol)
	local b=btn({Size=UDim2.new(0,0,0,px(22)),AutomaticSize=Enum.AutomaticSize.X,
		BackgroundColor3=bgCol or C.elevated,Text=" "..txt.." ",
		TextSize=FS.tiny,Font=Enum.Font.GothamBold,TextColor3=txCol or C.text},Toolbar)
	pad(0,0,px(5),px(5),b); crn(4,b); return b
end
local UndoBtn     = tbBtn("< Undo")
local RedoBtn     = tbBtn("> Redo")
local ResetAllBtn = tbBtn("<> Reset All")
local ExportBtn   = tbBtn(">> Export",Color3.fromRGB(14,48,40),C.accent)
local JsonExpBtn  = tbBtn("v JSON")
local JsonImpBtn  = tbBtn("^ JSON")

UndoBtn.MouseButton1Click:Connect(doUndo)
RedoBtn.MouseButton1Click:Connect(doRedo)
ResetAllBtn.MouseButton1Click:Connect(function()
	pushUndo()
	for _,name in ipairs(jointOrder) do
		local d=allJointData[name]; if d then allJointData[name]=makeJointData(d.motor or d.weld) end
	end
end)

-- Search
local SearchY=TITLE_H+TOOL_H+px(2)
local SearchRow=frm({Size=UDim2.new(1,-px(12),0,px(26)),
	Position=UDim2.new(0,px(6),0,SearchY),BackgroundColor3=C.elevated},Main)
crn(6,SearchRow); strk(C.border,1,SearchRow)
lbl({Size=UDim2.new(0,px(18),1,0),Position=UDim2.new(0,px(6),0,0),
	Text="🔍",TextColor3=C.muted,TextSize=FS.sm},SearchRow)
local SearchInput=make("TextBox",{Size=UDim2.new(1,-px(26),1,0),
	Position=UDim2.new(0,px(22),0,0),BackgroundTransparency=1,
	Text="",PlaceholderText="Search joint / accessory…",
	Font=Enum.Font.Gotham,TextSize=FS.sm,TextColor3=C.text,
	PlaceholderColor3=C.muted,ClearTextOnFocus=false},SearchRow)

-- Presets
local PresetY=SearchY+SEARCH_H
local PresetRow=frm({Size=UDim2.new(1,0,0,PRESET_H),
	Position=UDim2.new(0,0,0,PresetY),BackgroundColor3=C.panel},Main)
pad(px(3),px(3),px(6),px(6),PresetRow)
listL(Enum.FillDirection.Horizontal,px(3),Enum.VerticalAlignment.Center,PresetRow)
lbl({Size=UDim2.new(0,px(50),1,0),Text="Presets:",
	TextColor3=C.muted,TextSize=FS.tiny,Font=Enum.Font.GothamBold},PresetRow)

-- Scroll
local ScrollY=PresetY+PRESET_H+px(2)
local ScrollFrame=make("ScrollingFrame",{
	Size=UDim2.new(1,-px(6),0,SCROLL_H),Position=UDim2.new(0,px(3),0,ScrollY),
	BackgroundColor3=C.bg,BorderSizePixel=0,
	ScrollBarThickness=px(4),ScrollBarImageColor3=C.accent,
	CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,
	ClipsDescendants=true},Main)
listL(Enum.FillDirection.Vertical,px(3),Enum.VerticalAlignment.Top,ScrollFrame)
pad(px(3),px(3),px(3),px(3),ScrollFrame)

-- Code panel
local CodeY=WIN_H-CODE_H
local CodePanel=frm({Size=UDim2.new(1,0,0,CODE_H),
	Position=UDim2.new(0,0,0,CodeY),BackgroundColor3=C.panel},Main)
strk(C.border,1,CodePanel)
local codeHdr=frm({Size=UDim2.new(1,0,0,px(18)),BackgroundColor3=C.elevated},CodePanel)
lbl({Size=UDim2.new(1,-px(30),1,0),Position=UDim2.new(0,px(6),0,0),
	Text="LIVE EXPORT  ·  ⬡ freezes  ·  ⎘ copies",
	TextColor3=C.muted,TextSize=FS.tiny,Font=Enum.Font.GothamBold,
	TextXAlignment=Enum.TextXAlignment.Left},codeHdr)
local CopyBtn=btn({Size=UDim2.fromOffset(px(24),px(14)),
	Position=UDim2.new(1,-px(26),0.5,-px(7)),
	BackgroundColor3=C.accent,Text="⎘",TextSize=FS.tiny,TextColor3=C.bg},codeHdr)
crn(3,CopyBtn)
local CodeLabel=lbl({Size=UDim2.new(1,-px(8),1,-px(22)),
	Position=UDim2.new(0,px(4),0,px(20)),
	Text="-- initialising…",TextColor3=C.code,Font=Enum.Font.Code,TextSize=FS.tiny,
	TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
	TextWrapped=true},CodePanel)

CopyBtn.MouseButton1Click:Connect(function()
	local code=generateCode()
	if setclipboard then pcall(setclipboard,code)
	elseif syn and syn.clipboard then pcall(syn.clipboard.set,code)
	elseif writeclipboard then pcall(writeclipboard,code)
	else
		local tb=Instance.new("TextBox")
		tb.Parent=ScreenGui tb.Size=UDim2.fromOffset(1,1)
		tb.Position=UDim2.new(2,0,2,0) tb.Text=code
		tb:CaptureFocus(); task.delay(0.05,function() tb:ReleaseFocus() tb:Destroy() end)
	end
	CopyBtn.Text="✓"; task.delay(1.5,function() CopyBtn.Text="⎘" end)
end)

-- ═══════════════════════════════════════════════════════════════════════
--  REUSABLE WIDGETS
-- ═══════════════════════════════════════════════════════════════════════

-- Slider — typed input bypasses slider range (no clamping)
local function makeSliderRow(parent,labelTxt,sMin,sMax,initV,onChange,lo)
	local row=frm({Size=UDim2.new(1,-px(6),0,px(22)),
		BackgroundTransparency=1,LayoutOrder=lo},parent)
	lbl({Size=UDim2.new(0,px(68),1,0),Text=labelTxt,
		TextColor3=C.muted,TextSize=FS.tiny,Font=Enum.Font.Gotham,
		TextXAlignment=Enum.TextXAlignment.Left},row)
	local range=math.max(sMax-sMin,1e-6)
	local track=frm({Size=UDim2.new(1,-px(122),0,px(4)),
		Position=UDim2.new(0,px(70),0.5,-px(2)),BackgroundColor3=C.border},row)
	crn(px(2),track)
	local initT=math.clamp((initV-sMin)/range,0,1)
	local fill=frm({Size=UDim2.new(initT,0,1,0),BackgroundColor3=C.accent},track)
	crn(px(2),fill)
	local thumb=frm({Size=UDim2.fromOffset(px(10),px(10)),
		Position=UDim2.new(initT,-px(5),0.5,-px(5)),BackgroundColor3=C.white},track)
	crn(px(5),thumb)
	local numBox=make("TextBox",{Size=UDim2.fromOffset(px(46),px(18)),
		Position=UDim2.new(1,-px(48),0.5,-px(9)),
		BackgroundColor3=C.elevated,BorderSizePixel=0,
		Text=fmt("%.3f",initV),Font=Enum.Font.Code,
		TextSize=FS.tiny,TextColor3=C.accent,ClearTextOnFocus=true},row)
	crn(px(3),numBox)

	local function setVal(v, clampSlider)
		local dv=clampSlider and math.clamp(v,sMin,sMax) or v
		local t=math.clamp((dv-sMin)/range,0,1)
		fill.Size=UDim2.new(t,0,1,0)
		thumb.Position=UDim2.new(t,-px(5),0.5,-px(5))
		numBox.Text=fmt("%.3f",v)
		onChange(v)
	end

	local drag=false
	track.InputBegan:Connect(function(inp)
		if inp.UserInputType==Enum.UserInputType.MouseButton1 then
			drag=true
			local ap=track.AbsolutePosition; local as=track.AbsoluteSize
			setVal(sMin+math.clamp((inp.Position.X-ap.X)/as.X,0,1)*range,true)
		end
	end)
	UserInputService.InputChanged:Connect(function(inp)
		if drag and inp.UserInputType==Enum.UserInputType.MouseMovement then
			local ap=track.AbsolutePosition; local as=track.AbsoluteSize
			setVal(sMin+math.clamp((inp.Position.X-ap.X)/as.X,0,1)*range,true)
		end
	end)
	UserInputService.InputEnded:Connect(function(inp)
		if inp.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
	end)
	numBox.FocusLost:Connect(function()
		local v=tonumber(numBox.Text); if v then pushUndo(); setVal(v,false) end
	end)
	return row,setVal
end

-- Toggle
local function makeToggle(parent,labelTxt,initState,onChange,lo)
	local row=frm({Size=UDim2.new(1,-px(6),0,px(20)),BackgroundTransparency=1,LayoutOrder=lo},parent)
	lbl({Size=UDim2.new(1,-px(50),1,0),Text=labelTxt,
		TextColor3=C.muted,TextSize=FS.tiny,Font=Enum.Font.Gotham,
		TextXAlignment=Enum.TextXAlignment.Left},row)
	local trk=frm({Size=UDim2.fromOffset(px(32),px(16)),
		Position=UDim2.new(1,-px(36),0.5,-px(8)),
		BackgroundColor3=initState and C.accent or C.border},row)
	crn(px(8),trk)
	local knob=frm({Size=UDim2.fromOffset(px(12),px(12)),
		Position=initState and UDim2.new(1,-px(14),0.5,-px(6)) or UDim2.new(0,px(2),0.5,-px(6)),
		BackgroundColor3=C.white},trk)
	crn(px(6),knob)
	local state=initState
	local function setState(v)
		state=v
		TweenService:Create(trk,TweenInfo.new(0.12),{BackgroundColor3=v and C.accent or C.border}):Play()
		TweenService:Create(knob,TweenInfo.new(0.12),{
			Position=v and UDim2.new(1,-px(14),0.5,-px(6)) or UDim2.new(0,px(2),0.5,-px(6))}):Play()
	end
	trk.InputBegan:Connect(function(inp)
		if inp.UserInputType==Enum.UserInputType.MouseButton1 then
			state=not state; setState(state); onChange(state)
		end
	end)
	return row,setState
end

-- Small pill toggle button (for Reverse)
local function makePill(parent,txt,initState,activeCol,onChange,lo)
	local row=frm({Size=UDim2.new(1,-px(6),0,px(20)),BackgroundTransparency=1,LayoutOrder=lo},parent)
	lbl({Size=UDim2.new(0,px(68),1,0),Text=txt,
		TextColor3=C.muted,TextSize=FS.tiny,Font=Enum.Font.Gotham,
		TextXAlignment=Enum.TextXAlignment.Left},row)
	local b=btn({Size=UDim2.fromOffset(px(52),px(16)),
		Position=UDim2.new(0,px(70),0.5,-px(8)),
		BackgroundColor3=initState and activeCol or C.elevated,
		Text=initState and "ON" or "OFF",
		TextSize=FS.tiny,Font=Enum.Font.GothamBold,
		TextColor3=initState and C.bg or C.muted},row)
	crn(px(4),b)
	local state=initState
	local function setState(v)
		state=v
		b.BackgroundColor3=v and activeCol or C.elevated
		b.Text=v and "ON" or "OFF"
		b.TextColor3=v and C.bg or C.muted
	end
	b.MouseButton1Click:Connect(function() state=not state; setState(state); onChange(state) end)
	return row,setState
end

-- Section separator
local function makeSep(parent,txt,lo)
	local s=frm({Size=UDim2.new(1,-px(6),0,px(12)),BackgroundTransparency=1,LayoutOrder=lo},parent)
	lbl({Size=UDim2.new(1,0,1,0),Text=txt,TextColor3=Color3.fromRGB(55,55,78),
		TextSize=math.max(7,FS.tiny-1),Font=Enum.Font.GothamBold,
		TextXAlignment=Enum.TextXAlignment.Left},s)
end

-- ═══════════════════════════════════════════════════════════════════════
--  PER-AXIS SINE BLOCK
--  Builds a collapsible sub-panel for one axis's sine settings.
--  axisColor: tint colour for the axis label
--  Returns setters table { amp, speed, offset }
-- ═══════════════════════════════════════════════════════════════════════
local function makeAxisSineBlock(parent, axisLabel, axisColor, sineTable, lo)
	local collapsed = true  -- start collapsed to save space

	local header = frm({Size=UDim2.new(1,-px(6),0,px(18)),
		BackgroundColor3=C.subpanel,LayoutOrder=lo},parent)
	crn(px(4),header)

	local arrowL = lbl({Size=UDim2.fromOffset(px(12),px(18)),Position=UDim2.new(0,px(3),0,0),
		Text="▶",TextColor3=axisColor,TextSize=FS.tiny,Font=Enum.Font.GothamBold},header)
	lbl({Size=UDim2.new(1,-px(20),1,0),Position=UDim2.new(0,px(14),0,0),
		Text="Axis "..axisLabel,TextColor3=axisColor,TextSize=FS.tiny,Font=Enum.Font.GothamBold,
		TextXAlignment=Enum.TextXAlignment.Left},header)

	local body = frm({Size=UDim2.new(1,-px(6),0,0),AutomaticSize=Enum.AutomaticSize.Y,
		BackgroundColor3=C.subpanel,LayoutOrder=lo+0.5,Visible=false},parent)
	crn(px(4),body)
	listL(Enum.FillDirection.Vertical,px(2),Enum.VerticalAlignment.Top,body)
	pad(px(4),px(4),px(6),px(4),body)

	header.InputBegan:Connect(function(inp)
		if inp.UserInputType==Enum.UserInputType.MouseButton1 then
			collapsed=not collapsed
			body.Visible=not collapsed
			arrowL.Text=collapsed and "▶" or "▼"
		end
	end)

	local lo2=1
	local function nlo2() lo2=lo2+1; return lo2 end

	local _,setAmp    = makeSliderRow(body,"Amp",   -TWO_PI,TWO_PI, sineTable.amp,    function(v) sineTable.amp=v    end,nlo2())
	local _,setSpeed  = makeSliderRow(body,"Speed",  0.1,    20,     sineTable.speed,  function(v) sineTable.speed=v  end,nlo2())
	local _,setOffset = makeSliderRow(body,"Offset", -TWO_PI,TWO_PI, sineTable.offset, function(v) sineTable.offset=v end,nlo2())
	makePill(body,"Reverse",sineTable.reverse,C.revOn,function(v) sineTable.reverse=v end,nlo2())

	return { setAmp=setAmp, setSpeed=setSpeed, setOffset=setOffset }
end

-- ═══════════════════════════════════════════════════════════════════════
--  PER-AXIS SPIN BLOCK  (cos-based)
-- ═══════════════════════════════════════════════════════════════════════
local function makeAxisSpinBlock(parent, axisLabel, axisColor, spinTable, lo)
	local collapsed = true

	local header = frm({Size=UDim2.new(1,-px(6),0,px(18)),
		BackgroundColor3=C.subpanel,LayoutOrder=lo},parent)
	crn(px(4),header)

	local arrowL = lbl({Size=UDim2.fromOffset(px(12),px(18)),Position=UDim2.new(0,px(3),0,0),
		Text="▶",TextColor3=axisColor,TextSize=FS.tiny,Font=Enum.Font.GothamBold},header)
	lbl({Size=UDim2.new(1,-px(20),1,0),Position=UDim2.new(0,px(14),0,0),
		Text="Axis "..axisLabel.."  (cos)",TextColor3=axisColor,TextSize=FS.tiny,Font=Enum.Font.GothamBold,
		TextXAlignment=Enum.TextXAlignment.Left},header)

	local body = frm({Size=UDim2.new(1,-px(6),0,0),AutomaticSize=Enum.AutomaticSize.Y,
		BackgroundColor3=C.subpanel,LayoutOrder=lo+0.5,Visible=false},parent)
	crn(px(4),body)
	listL(Enum.FillDirection.Vertical,px(2),Enum.VerticalAlignment.Top,body)
	pad(px(4),px(4),px(6),px(4),body)

	header.InputBegan:Connect(function(inp)
		if inp.UserInputType==Enum.UserInputType.MouseButton1 then
			collapsed=not collapsed
			body.Visible=not collapsed
			arrowL.Text=collapsed and "▶" or "▼"
		end
	end)

	local lo2=1
	local function nlo2() lo2=lo2+1; return lo2 end

	makeToggle(body,"Enabled",spinTable.enabled,function(v) spinTable.enabled=v end,nlo2())
	local _,setSpeed = makeSliderRow(body,"Speed",0.1,20,spinTable.speed,function(v) spinTable.speed=v end,nlo2())
	makePill(body,"Reverse",spinTable.reverse,C.revOn,function(v) spinTable.reverse=v end,nlo2())

	return { setSpeed=setSpeed }
end

-- ═══════════════════════════════════════════════════════════════════════
--  MAIN JOINT SECTION BUILDER
-- ═══════════════════════════════════════════════════════════════════════
local jointSections={}
local loCount=0
local function nlo() loCount=loCount+1; return loCount end

local AXIS_COLORS = { X=C.axisX, Y=C.axisY, Z=C.axisZ }

local function buildJointSection(name,d,parentFrame)
	local dispName
	if d.isAccessory then
		dispName = "🎩 "..name
	else
		dispName = DISPLAY_NAMES[name] or ("✦ "..name)
	end

	local sectionCollapsed=false

	local header=frm({Size=UDim2.new(1,-px(6),0,px(28)),
		BackgroundColor3=C.elevated,LayoutOrder=nlo()},parentFrame)
	crn(px(5),header); strk(C.border,1,header)

	local arrowL=lbl({Size=UDim2.fromOffset(px(16),px(28)),Position=UDim2.new(0,px(5),0,0),
		Text="▼",TextColor3=C.accent,TextSize=FS.tiny,Font=Enum.Font.GothamBold},header)
	lbl({Size=UDim2.new(1,-px(60),1,0),Position=UDim2.new(0,px(22),0,0),
		Text=dispName,TextColor3=C.text,TextSize=FS.sm,Font=Enum.Font.GothamBold,
		TextXAlignment=Enum.TextXAlignment.Left},header)

	local enBtn=btn({Size=UDim2.fromOffset(px(38),px(15)),
		Position=UDim2.new(1,-px(42),0.5,-px(7)),
		BackgroundColor3=d.enabled and Color3.fromRGB(16,50,38) or C.elevated,
		Text=d.enabled and "ON" or "OFF",TextSize=FS.tiny,Font=Enum.Font.GothamBold,
		TextColor3=d.enabled and C.green or C.muted},header)
	crn(px(3),enBtn)
	enBtn.MouseButton1Click:Connect(function()
		d.enabled=not d.enabled
		enBtn.BackgroundColor3=d.enabled and Color3.fromRGB(16,50,38) or C.elevated
		enBtn.Text=d.enabled and "ON" or "OFF"
		enBtn.TextColor3=d.enabled and C.green or C.muted
	end)

	local body=frm({Size=UDim2.new(1,-px(6),0,0),AutomaticSize=Enum.AutomaticSize.Y,
		BackgroundColor3=C.panel,LayoutOrder=nlo()},parentFrame)
	crn(px(5),body)
	listL(Enum.FillDirection.Vertical,px(2),Enum.VerticalAlignment.Top,body)
	pad(px(5),px(6),px(5),px(5),body)

	header.InputBegan:Connect(function(inp)
		if inp.UserInputType==Enum.UserInputType.MouseButton1 then
			sectionCollapsed=not sectionCollapsed
			body.Visible=not sectionCollapsed
			arrowL.Text=sectionCollapsed and "▶" or "▼"
		end
	end)

	-- ── BASE POSITION ─────────────────────────────────────────────
	makeSep(body,"──  BASE POSITION",nlo())
	local _,setPX=makeSliderRow(body,"Pos X",-5,5,d.posX,function(v) d.posX=v end,nlo())
	local _,setPY=makeSliderRow(body,"Pos Y",-5,5,d.posY,function(v) d.posY=v end,nlo())
	local _,setPZ=makeSliderRow(body,"Pos Z",-5,5,d.posZ,function(v) d.posZ=v end,nlo())

	-- ── BASE ROTATION ─────────────────────────────────────────────
	makeSep(body,"──  BASE ROTATION  (radians)",nlo())
	local _,setRX=makeSliderRow(body,"Rot X",-TWO_PI,TWO_PI,d.rotX,function(v) d.rotX=v end,nlo())
	local _,setRY=makeSliderRow(body,"Rot Y",-TWO_PI,TWO_PI,d.rotY,function(v) d.rotY=v end,nlo())
	local _,setRZ=makeSliderRow(body,"Rot Z",-TWO_PI,TWO_PI,d.rotZ,function(v) d.rotZ=v end,nlo())

	-- ── SINE ROTATION per axis ────────────────────────────────────
	makeSep(body,"──  SINE ROTATION  (per axis, click to expand)",nlo())
	makeAxisSineBlock(body,"X",C.axisX,d.sineX,nlo())
	makeAxisSineBlock(body,"Y",C.axisY,d.sineY,nlo())
	makeAxisSineBlock(body,"Z",C.axisZ,d.sineZ,nlo())

	-- ── SINE POSITION per axis ────────────────────────────────────
	makeSep(body,"──  SINE POSITION  (per axis, click to expand)",nlo())
	makeAxisSineBlock(body,"X",C.axisX,d.sinePosX,nlo())
	makeAxisSineBlock(body,"Y",C.axisY,d.sinePosY,nlo())
	makeAxisSineBlock(body,"Z",C.axisZ,d.sinePosZ,nlo())

	-- ── COS SPIN per axis ─────────────────────────────────────────
	makeSep(body,"──  COS SPIN  (per axis, click to expand)",nlo())
	makeAxisSpinBlock(body,"X",C.axisX,d.spinX,nlo())
	makeAxisSpinBlock(body,"Y",C.axisY,d.spinY,nlo())
	makeAxisSpinBlock(body,"Z",C.axisZ,d.spinZ,nlo())

	-- ── AXIS LOCK ─────────────────────────────────────────────────
	makeSep(body,"──  AXIS LOCK",nlo())
	local lockRow=frm({Size=UDim2.new(1,-px(6),0,px(22)),
		BackgroundTransparency=1,LayoutOrder=nlo()},body)
	lbl({Size=UDim2.new(0,px(68),1,0),Text="Lock Axis",
		TextColor3=C.muted,TextSize=FS.tiny,Font=Enum.Font.Gotham,
		TextXAlignment=Enum.TextXAlignment.Left},lockRow)
	for i,ax in ipairs({"X","Y","Z"}) do
		local axCol=AXIS_COLORS[ax]
		local b=btn({Size=UDim2.fromOffset(px(34),px(18)),
			Position=UDim2.new(0,px(70)+(i-1)*px(38),0.5,-px(9)),
			BackgroundColor3=d["lock"..ax] and C.warn or C.elevated,
			Text=ax.." 🔒",TextSize=FS.tiny,TextColor3=axCol},lockRow)
		crn(px(3),b)
		b.MouseButton1Click:Connect(function()
			d["lock"..ax]=not d["lock"..ax]
			b.BackgroundColor3=d["lock"..ax] and C.warn or C.elevated
		end)
	end

	-- ── ACTIONS ───────────────────────────────────────────────────
	makeSep(body,"──  ACTIONS",nlo())
	local actRow=frm({Size=UDim2.new(1,-px(6),0,px(24)),
		BackgroundTransparency=1,LayoutOrder=nlo()},body)
	listL(Enum.FillDirection.Horizontal,px(4),Enum.VerticalAlignment.Center,actRow)
	local function aBtn(txt,bgCol,txCol)
		local b=btn({Size=UDim2.new(0,0,0,px(20)),AutomaticSize=Enum.AutomaticSize.X,
			BackgroundColor3=bgCol or C.elevated,Text=" "..txt.." ",
			TextSize=FS.tiny,TextColor3=txCol or C.text},actRow)
		pad(0,0,px(5),px(5),b); crn(px(3),b); return b
	end

	local resetBtn=aBtn("⟳ Reset")
	local copyBtn =aBtn("⎘ Copy")
	local pasteBtn=aBtn("⎗ Paste")

	if MIRROR_MAP[name] then
		local mBtn=aBtn("↔ Mirror",Color3.fromRGB(20,24,52),C.accent2)
		mBtn.MouseButton1Click:Connect(function()
			pushUndo()
			local o=allJointData[MIRROR_MAP[name]]
			if o then
				o.posX=-d.posX; o.posY=d.posY; o.posZ=d.posZ
				o.rotX=d.rotX;  o.rotY=-d.rotY; o.rotZ=-d.rotZ
				-- Mirror sine amps on X axis (flip sign)
				for _,ax in ipairs({"X","Y","Z"}) do
					o["sine"..ax].amp=d["sine"..ax].amp
					o["sine"..ax].speed=d["sine"..ax].speed
					o["sine"..ax].offset=d["sine"..ax].offset
					o["sine"..ax].reverse= ax=="X" and not d["sine"..ax].reverse or d["sine"..ax].reverse
				end
			end
		end)
	end

	local function doReset()
		pushUndo()
		local motor=d.motor or d.weld
		local fresh=makeJointData(motor)
		for k,v in pairs(fresh) do if k~="motor" and k~="weld" and k~="name" then d[k]=v end end
		setPX(d.posX,false); setPY(d.posY,false); setPZ(d.posZ,false)
		setRX(d.rotX,false); setRY(d.rotY,false); setRZ(d.rotZ,false)
	end
	resetBtn.MouseButton1Click:Connect(doReset)
	copyBtn.MouseButton1Click:Connect(function() clipboard=deepCopy(d) end)
	pasteBtn.MouseButton1Click:Connect(function()
		if not clipboard then return end
		pushUndo()
		for k,v in pairs(clipboard) do
			if k~="motor" and k~="weld" and k~="name" then d[k]=deepCopy(v) end
		end
		setPX(d.posX,false); setPY(d.posY,false); setPZ(d.posZ,false)
		setRX(d.rotX,false); setRY(d.rotY,false); setRZ(d.rotZ,false)
	end)

	jointSections[name]={header=header,body=body}
end

for _,name in ipairs(jointOrder) do
	local d=allJointData[name]; if d then buildJointSection(name,d,ScrollFrame) end
end

-- ═══════════════════════════════════════════════════════════════════════
--  PRESETS
-- ═══════════════════════════════════════════════════════════════════════
local PRESETS={
	{name="Idle",apply=function()
		pushUndo()
		local rj=allJointData.RootJoint; local ne=allJointData.Neck
		local rs=allJointData.RightShoulder; local ls=allJointData.LeftShoulder
		if rj then rj.sinePosY.amp=0.06; rj.sinePosY.speed=2 end
		if ne then ne.rotX=ne.rotX-0.1 end
		if rs then rs.sineX.amp=0.06; rs.sineX.speed=2 end
		if ls then ls.sineX.amp=0.06; ls.sineX.speed=2 end
	end},
	{name="Walk",apply=function()
		pushUndo()
		local rh=allJointData.RightHip; local lh=allJointData.LeftHip
		local rs=allJointData.RightShoulder; local ls=allJointData.LeftShoulder
		local rj=allJointData.RootJoint; local ne=allJointData.Neck
		if rh then rh.sineX.amp=0.45; rh.sineX.speed=1 end
		if lh then lh.sineX.amp=0.45; lh.sineX.speed=1; lh.sineX.reverse=true end
		if rs then rs.sineX.amp=0.35; rs.sineX.speed=1; rs.sineX.reverse=true end
		if ls then ls.sineX.amp=0.35; ls.sineX.speed=1 end
		if rj then rj.sinePosY.amp=0.08; rj.sinePosY.speed=2 end
		if ne then ne.sineY.amp=0.04; ne.sineY.speed=2 end
	end},
	{name="Crazy",apply=function()
		pushUndo()
		for _,name in ipairs(jointOrder) do
			local d=allJointData[name]; if not d then continue end
			for _,ax in ipairs({"X","Y","Z"}) do
				d["sine"..ax].amp=math.random()*TWO_PI*0.5
				d["sine"..ax].speed=math.random()*4+0.5
				d["sine"..ax].reverse=math.random()>0.5
				d["spin"..ax].enabled=math.random()>0.5
				d["spin"..ax].speed=math.random()*3+0.5
				d["spin"..ax].reverse=math.random()>0.5
			end
		end
	end},
	{name="Reset All",apply=function()
		pushUndo()
		for _,name in ipairs(jointOrder) do
			local d=allJointData[name]
			if d then
				local motor=d.motor or d.weld
				local fresh=makeJointData(motor)
				for k,v in pairs(fresh) do
					if k~="motor" and k~="weld" and k~="name" then d[k]=deepCopy(v) end
				end
			end
		end
	end},
}
for _,p in ipairs(PRESETS) do
	local b=btn({Size=UDim2.new(0,0,0,px(22)),AutomaticSize=Enum.AutomaticSize.X,
		BackgroundColor3=C.elevated,Text=" "..p.name.." ",
		TextSize=FS.tiny,Font=Enum.Font.GothamBold},PresetRow)
	pad(0,0,px(5),px(5),b); crn(px(4),b)
	b.MouseButton1Click:Connect(p.apply)
end

-- ═══════════════════════════════════════════════════════════════════════
--  SEARCH
-- ═══════════════════════════════════════════════════════════════════════
SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
	local q=SearchInput.Text:lower()
	for name,sec in pairs(jointSections) do
		local vis=q==""
			or name:lower():find(q,1,true)~=nil
			or (DISPLAY_NAMES[name] or ""):lower():find(q,1,true)~=nil
		sec.header.Visible=vis
		if not vis then sec.body.Visible=false end
	end
end)

-- ═══════════════════════════════════════════════════════════════════════
--  EXPORT / JSON
-- ═══════════════════════════════════════════════════════════════════════
local previewFrozen=false
ExportBtn.MouseButton1Click:Connect(function()
	previewFrozen=not previewFrozen
	ExportBtn.TextColor3=previewFrozen and C.warn or C.accent
	ExportBtn.Text=previewFrozen and " ⬡ Frozen " or " ⬡ Export "
	if previewFrozen then CodeLabel.Text=generateCode() end
end)

local function serializeData()
	local t={}
	for _,name in ipairs(jointOrder) do
		local d=allJointData[name]; if not d then continue end
		local function copySine(s) return {amp=s.amp,speed=s.speed,offset=s.offset,reverse=s.reverse} end
		local function copySpin(s) return {enabled=s.enabled,speed=s.speed,reverse=s.reverse} end
		t[name]={
			posX=d.posX,posY=d.posY,posZ=d.posZ,
			rotX=d.rotX,rotY=d.rotY,rotZ=d.rotZ,
			sineX=copySine(d.sineX),sineY=copySine(d.sineY),sineZ=copySine(d.sineZ),
			sinePosX=copySine(d.sinePosX),sinePosY=copySine(d.sinePosY),sinePosZ=copySine(d.sinePosZ),
			spinX=copySpin(d.spinX),spinY=copySpin(d.spinY),spinZ=copySpin(d.spinZ),
			enabled=d.enabled,
		}
	end
	return t
end

JsonExpBtn.MouseButton1Click:Connect(function()
	local ok,json=pcall(function() return HttpService:JSONEncode(serializeData()) end)
	CodeLabel.Text=ok and json or "-- JSON encode failed"
end)

JsonImpBtn.MouseButton1Click:Connect(function()
	CodeLabel.Text="-- Paste JSON here then click ↑ JSON again"
	local conn; conn=JsonImpBtn.MouseButton1Click:Connect(function()
		conn:Disconnect()
		local ok,t=pcall(function() return HttpService:JSONDecode(CodeLabel.Text) end)
		if ok and type(t)=="table" then
			pushUndo()
			for name,vals in pairs(t) do
				local d=allJointData[name]; if not d then continue end
				for k,v in pairs(vals) do
					if k~="motor" and k~="weld" and k~="name" then d[k]=deepCopy(v) end
				end
			end
			CodeLabel.Text="-- ✓ JSON imported"
		else CodeLabel.Text="-- ✗ Invalid JSON" end
	end)
end)

-- ═══════════════════════════════════════════════════════════════════════
--  LIVE PREVIEW
-- ═══════════════════════════════════════════════════════════════════════
local previewTimer=0
RunService.RenderStepped:Connect(function(dt)
	previewTimer=previewTimer+dt
	if previewTimer>=0.5 and not previewFrozen then
		previewTimer=0
		local lines,i={},0
		for line in generateCode():gmatch("[^\n]+") do
			i=i+1; lines[i]=line; if i>=4 then break end
		end
		if i>0 then CodeLabel.Text=table.concat(lines,"\n") end
	end
end)

-- ═══════════════════════════════════════════════════════════════════════
--  CHARACTER RESPAWN
-- ═══════════════════════════════════════════════════════════════════════
player.CharacterAdded:Connect(function(newChar)
	char=newChar
	waitForRig(newChar)
	disableAnimate(newChar)
	detectAllMotors(newChar)
	startRuntime()
end)

-- ═══════════════════════════════════════════════════════════════════════
--  INIT
-- ═══════════════════════════════════════════════════════════════════════
task.delay(0.25,function() CodeLabel.Text=generateCode() end)
local n=0; for _ in pairs(allJointData) do n=n+1 end
print(fmt("[CFrameAnimEditor v3.0]  scale=%.2fx  %dx%d  joints=%d",S,WIN_W,WIN_H,n))