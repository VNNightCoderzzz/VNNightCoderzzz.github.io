local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

if PlayerGui:FindFirstChild("SonicExecutorGui") then
    PlayerGui:FindFirstChild("SonicExecutorGui"):Destroy()
end
if PlayerGui:FindFirstChild("SonicToggleGui") then
    PlayerGui:FindFirstChild("SonicToggleGui"):Destroy()
end

local BG_COLOR = Color3.fromRGB(28, 28, 36)
local BG_T     = 0.15  

local BORDER   = Color3.fromRGB(155, 150, 175)

local C = {
    ACCENT   = Color3.fromRGB(140, 135, 190),
    TEXT     = Color3.fromRGB(225, 222, 235),
    TEXT_DIM = Color3.fromRGB(125, 120, 148),
    SCROLL   = Color3.fromRGB(115, 110, 142),
    LINE_NUM = Color3.fromRGB(118, 112, 145),
    WHITE    = Color3.fromRGB(255, 255, 255),
    TAB_ACT  = Color3.fromRGB(72, 70, 95),
    SEL_COL  = Color3.fromRGB(30, 80, 180),
    SYN_KW   = Color3.fromRGB(200, 150, 255),
    SYN_STR  = Color3.fromRGB(235, 170, 110),
    SYN_NUM  = Color3.fromRGB(150, 225, 155),
    SYN_CMT  = Color3.fromRGB(105, 168, 95),
    SYN_FN   = Color3.fromRGB(235, 228, 148),
    SYN_PROP = Color3.fromRGB(140, 215, 255),
    SEARCH_BG = Color3.fromRGB(50, 50, 62),
    SEARCH_HL = Color3.fromRGB(255, 200, 80),

    SEARCH_MATCH_BG = Color3.fromRGB(255, 220, 100), 

}

local WIN_W    = 680
local WIN_H    = 480
local WIN_SIZE = UDim2.new(0, WIN_W, 0, WIN_H)
local WIN_POS  = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
local SAVE_KEY = "SonicExecutor_TabData"
local HEADER_H = 36
local TABBAR_H = 30
local BOTTOM_H = 48
local GUTTER_W = 36
local LINE_H   = 13
local LINE_YOFF= 1
local HSCROLL_H = 8

local MAX_HIGHLIGHT_LEN = 8000
local HIGHLIGHT_DEBOUNCE = 0.05
local lastHighlightTime = 0
local pendingHighlight = false

local SNIPPETS = {
    func      = "function name()\n\t\nend",
    fori      = "for i = 1, 10 do\n\t\nend",
    forpairs  = "for k, v in pairs(t) do\n\t\nend",
    foripairs = "for i, v in ipairs(t) do\n\t\nend",
    ifs       = "if condition then\n\t\nend",
    whil      = "while condition do\n\t\nend",
    rep       = "repeat\n\t\nuntil condition",
    pcal      = "local ok, err = pcall(function()\n\t\nend)",
    tsk       = "task.spawn(function()\n\t\nend)",
}

local AC_LIST = {
    "game","workspace","script","print","warn","error","pcall","xpcall",
    "require","loadstring","task","coroutine","math","string","table","os",
    "Instance.new","Instance.fromExisting",
    "game:GetService","Players.LocalPlayer","Players:GetPlayers",
    "Vector3.new","Vector2.new","CFrame.new","UDim2.new","UDim.new",
    "Color3.new","Color3.fromRGB","BrickColor.new","TweenInfo.new",
    "RunService","UserInputService","TweenService","HttpService",
    "tostring","tonumber","type","pairs","ipairs","next","select","unpack",
    "rawget","rawset","setmetatable","getmetatable","typeof",
    "game.Players.LocalPlayer","game.ReplicatedStorage","game.Workspace",
    "wait","task.wait","task.delay","task.spawn","task.defer",
    "FireServer","InvokeServer","FireClient","InvokeClient",
    "humanoid","HumanoidRootPart",
}

local AUTOPAIRS = {["("]=")", ["["]="]", ["{"]="}",  ['"']='"', ["'"]=  "'"}

local KEYWORDS = {
    "and","break","do","else","elseif","end","false","for","function",
    "if","in","local","nil","not","or","repeat","return","then","true",
    "until","while","continue",
}
local BUILTINS = {
    "print","warn","error","pairs","ipairs","next","select","type","typeof",
    "tostring","tonumber","pcall","xpcall","require","loadstring","rawget",
    "rawset","setmetatable","getmetatable","unpack","assert","wait","spawn",
    "delay","game","workspace","script","task","math","string","table","os",
    "coroutine","Instance","Vector3","Vector2","CFrame","UDim2","UDim",
    "Color3","BrickColor","TweenInfo","Enum","RunService","UserInputService",
    "TweenService","Players","Humanoid",
}

local STRING_FUNCS = {
    "find","match","gmatch","gsub","sub","upper","lower","len","byte","char",
    "rep","reverse","format","split","pack","unpack","packsize",
}

local KW_SET, BI_SET, SF_SET = {}, {}, {}
for _, k in ipairs(KEYWORDS) do KW_SET[k] = true end
for _, b in ipairs(BUILTINS) do BI_SET[b] = true end
for _, s in ipairs(STRING_FUNCS) do SF_SET[s] = true end

local tabs      = {}
local tabFrames = {}
local tabCount  = 0
local activeTab = nil

local searchVisible = false
local searchMatches = {}
local currentMatchIndex = 0
local currentSearchQuery = "" 

local function corner(obj, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = r or UDim.new(0, 6)
    c.Parent = obj
end

local function stroke(obj, col, thick, t)
    local s = Instance.new("UIStroke")
    s.Color = col or BORDER
    s.Thickness = thick or 0.8
    s.Transparency = t or 0.5
    s.Parent = obj
end

local function ghost(size, pos, zi, parent)
    local f = Instance.new("Frame")
    f.Size = size
    f.Position = pos or UDim2.new(0,0,0,0)
    f.BackgroundTransparency = 1
    f.BorderSizePixel = 0
    f.ZIndex = zi or 2
    f.Parent = parent
    return f
end

local function hover(btn, nC, hC, nT, hT)
    nT = nT or btn.BackgroundTransparency
    hT = hT or nT
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3=hC, BackgroundTransparency=hT}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3=nC, BackgroundTransparency=nT}):Play()
    end)
end

local function saveData()
    local enc = {}
    for i, t in ipairs(tabs) do enc[i] = {name=t.name, content=t.content} end
    local p = HttpService:JSONEncode({tabs=enc, active=activeTab})
    if writefile then pcall(writefile, SAVE_KEY..".json", p)
    elseif savestring then pcall(savestring, SAVE_KEY, p) end
end

local function loadData()
    if isfile and isfile(SAVE_KEY..".json") then
        local raw = readfile(SAVE_KEY..".json")
        if raw then
            local ok, d = pcall(HttpService.JSONDecode, HttpService, raw)
            if ok and d and d.tabs then return d.tabs, d.active or 1 end
        end
    end
    return nil, nil
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SonicExecutorGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999999
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = PlayerGui

local NotifContainer = Instance.new("Frame")
NotifContainer.Size = UDim2.new(0,260,1,-24)
NotifContainer.Position = UDim2.new(1,-16,1,-8)
NotifContainer.AnchorPoint = Vector2.new(1,1)
NotifContainer.BackgroundTransparency = 1
NotifContainer.BorderSizePixel = 0
NotifContainer.ZIndex = 50
NotifContainer.Parent = ScreenGui

local NotifList = Instance.new("UIListLayout")
NotifList.FillDirection = Enum.FillDirection.Vertical
NotifList.SortOrder = Enum.SortOrder.LayoutOrder
NotifList.VerticalAlignment = Enum.VerticalAlignment.Bottom
NotifList.Padding = UDim.new(0,6)
NotifList.Parent = NotifContainer

local notifSeq = 0
local function showToast(msg)
    notifSeq += 1
    local toast = Instance.new("TextLabel")
    toast.Size = UDim2.new(1,0,0,34)
    toast.BackgroundColor3 = BG_COLOR
    toast.BackgroundTransparency = 0.25
    toast.TextColor3 = C.TEXT
    toast.Font = Enum.Font.Gotham
    toast.TextSize = 12
    toast.TextWrapped = true
    toast.TextXAlignment = Enum.TextXAlignment.Left
    toast.TextYAlignment = Enum.TextYAlignment.Center
    toast.Text = "  "..msg
    toast.LayoutOrder = notifSeq
    toast.ZIndex = 51
    toast.Parent = NotifContainer
    corner(toast, UDim.new(0,6))
    stroke(toast, BORDER, 0.7, 0.35)

    toast.BackgroundTransparency = 1
    toast.TextTransparency = 1
    TweenService:Create(toast, TweenInfo.new(0.18), {
        BackgroundTransparency = 0.25,
        TextTransparency = 0
    }):Play()

    task.delay(5, function()
        if toast.Parent then
            TweenService:Create(toast, TweenInfo.new(0.18), {
                BackgroundTransparency = 1,
                TextTransparency = 1
            }):Play()
            task.delay(0.2, function()
                if toast then toast:Destroy() end
            end)
        end
    end)
end

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0,0,0,0)
MainFrame.Position = UDim2.new(0.5,0,0.5,0)
MainFrame.BackgroundColor3 = BG_COLOR
MainFrame.BackgroundTransparency = BG_T
MainFrame.ClipsDescendants = true
MainFrame.Visible = false
MainFrame.ZIndex = 1
MainFrame.Parent = ScreenGui
corner(MainFrame, UDim.new(0,9))
stroke(MainFrame, BORDER, 0.8, 0.48)

local Header = ghost(UDim2.new(1,0,0,HEADER_H), UDim2.new(0,0,0,0), 5, MainFrame)
Header.ClipsDescendants = false

local HLine = Instance.new("Frame")
HLine.Size = UDim2.new(1,0,0,1)
HLine.Position = UDim2.new(0,0,1,-1)
HLine.BackgroundColor3 = BORDER
HLine.BackgroundTransparency = 0.55
HLine.BorderSizePixel = 0
HLine.ZIndex = 6
HLine.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0,300,1,0)
Title.Position = UDim2.new(0,12,0,0)
Title.BackgroundTransparency = 1
Title.Text = ""
Title.TextColor3 = C.TEXT
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 6
Title.Parent = Header

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0,22,0,HEADER_H)
MinBtn.Position = UDim2.new(1,-30,0,0)
MinBtn.BackgroundTransparency = 1
MinBtn.Text = "-"
MinBtn.TextColor3 = C.TEXT_DIM
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 18
MinBtn.ZIndex = 7
MinBtn.Parent = Header
MinBtn.MouseEnter:Connect(function()
    TweenService:Create(MinBtn, TweenInfo.new(0.1), {TextColor3=C.WHITE}):Play()
end)
MinBtn.MouseLeave:Connect(function()
    TweenService:Create(MinBtn, TweenInfo.new(0.1), {TextColor3=C.TEXT_DIM}):Play()
end)

local EC_H = WIN_H - HEADER_H - BOTTOM_H
local EditorContainer = ghost(UDim2.new(1,0,0,EC_H), UDim2.new(0,0,0,HEADER_H), 2, MainFrame)

local TabBar = ghost(UDim2.new(1,0,0,TABBAR_H), UDim2.new(0,0,0,0), 5, EditorContainer)
TabBar.ClipsDescendants = true

local TBLine = Instance.new("Frame")
TBLine.Size = UDim2.new(1,0,0,1)
TBLine.Position = UDim2.new(0,0,1,-1)
TBLine.BackgroundColor3 = BORDER
TBLine.BackgroundTransparency = 0.55
TBLine.BorderSizePixel = 0
TBLine.ZIndex = 6
TBLine.Parent = TabBar

local TabScroll = Instance.new("ScrollingFrame")
TabScroll.Size = UDim2.new(1,-34,1,0)
TabScroll.Position = UDim2.new(0,2,0,0)
TabScroll.BackgroundTransparency = 1
TabScroll.ScrollBarThickness = 2
TabScroll.ScrollBarImageColor3 = C.SCROLL
TabScroll.ScrollingDirection = Enum.ScrollingDirection.X
TabScroll.VerticalScrollBarInset = Enum.ScrollBarInset.Always
TabScroll.CanvasSize = UDim2.new(0,0,1,0)
TabScroll.ZIndex = 6
TabScroll.Parent = TabBar

local TabList = Instance.new("UIListLayout")
TabList.FillDirection = Enum.FillDirection.Horizontal
TabList.SortOrder = Enum.SortOrder.LayoutOrder
TabList.Padding = UDim.new(0,0)
TabList.VerticalAlignment = Enum.VerticalAlignment.Bottom
TabList.Parent = TabScroll
TabList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    TabScroll.CanvasSize = UDim2.new(0, TabList.AbsoluteContentSize.X+4, 1, 0)
end)

local AddTabBtn = Instance.new("TextButton")
AddTabBtn.Size = UDim2.new(0,26,0,24)
AddTabBtn.Position = UDim2.new(1,-30,0.5,-12)
AddTabBtn.BackgroundColor3 = BG_COLOR
AddTabBtn.BackgroundTransparency = 0.5
AddTabBtn.Text = "+"
AddTabBtn.TextColor3 = C.TEXT_DIM
AddTabBtn.Font = Enum.Font.GothamBold
AddTabBtn.TextSize = 15
AddTabBtn.ZIndex = 7
AddTabBtn.Parent = TabBar
corner(AddTabBtn, UDim.new(0,5))
hover(AddTabBtn, BG_COLOR, Color3.fromRGB(60,58,80), 0.5, 0.18)

local EO_H = EC_H - TABBAR_H - HSCROLL_H
local EditorOuter = ghost(UDim2.new(1,0,0,EO_H), UDim2.new(0,0,0,TABBAR_H), 2, EditorContainer)
EditorOuter.ClipsDescendants = true

local GutterFrame = ghost(UDim2.new(0,GUTTER_W,1,0), UDim2.new(0,0,0,0), 3, EditorOuter)

local GutterBorder = Instance.new("Frame")
GutterBorder.Size = UDim2.new(0,1,1,0)
GutterBorder.Position = UDim2.new(1,0,0,0)
GutterBorder.BackgroundColor3 = BORDER
GutterBorder.BackgroundTransparency = 0.6
GutterBorder.BorderSizePixel = 0
GutterBorder.ZIndex = 4
GutterBorder.Parent = GutterFrame

local LineNumScroll = Instance.new("ScrollingFrame")
LineNumScroll.Size = UDim2.new(1,0,1,0)
LineNumScroll.BackgroundTransparency = 1
LineNumScroll.ScrollBarThickness = 0
LineNumScroll.ScrollingDirection = Enum.ScrollingDirection.Y
LineNumScroll.CanvasSize = UDim2.new(1,0,0,0)
LineNumScroll.ScrollingEnabled = false
LineNumScroll.ZIndex = 4
LineNumScroll.Parent = GutterFrame

local SyntaxScroll = Instance.new("ScrollingFrame")
SyntaxScroll.Size = UDim2.new(1,-(GUTTER_W+1),1,0)
SyntaxScroll.Position = UDim2.new(0,GUTTER_W+1,0,0)
SyntaxScroll.BackgroundTransparency = 1
SyntaxScroll.ScrollBarThickness = 0
SyntaxScroll.ScrollingEnabled = false
SyntaxScroll.CanvasSize = UDim2.new(0,2000,0,0)
SyntaxScroll.ZIndex = 3
SyntaxScroll.Parent = EditorOuter

local SyntaxLabel = Instance.new("TextLabel")
SyntaxLabel.Size = UDim2.new(0,2000,1,0)
SyntaxLabel.Position = UDim2.new(0,6,0,LINE_YOFF)
SyntaxLabel.BackgroundTransparency = 1
SyntaxLabel.Text = ""
SyntaxLabel.RichText = true
SyntaxLabel.TextWrapped = false
SyntaxLabel.Font = Enum.Font.Code
SyntaxLabel.TextSize = 14
SyntaxLabel.TextColor3 = C.TEXT
SyntaxLabel.TextXAlignment = Enum.TextXAlignment.Left
SyntaxLabel.TextYAlignment = Enum.TextYAlignment.Top
SyntaxLabel.ZIndex = 3
SyntaxLabel.Parent = SyntaxScroll

local EditorScroll = Instance.new("ScrollingFrame")
EditorScroll.Size = UDim2.new(1,-(GUTTER_W+1),1,0)
EditorScroll.Position = UDim2.new(0,GUTTER_W+1,0,0)
EditorScroll.BackgroundTransparency = 1
EditorScroll.ScrollBarThickness = 5
EditorScroll.ScrollBarImageColor3 = C.SCROLL
EditorScroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
EditorScroll.ScrollingDirection = Enum.ScrollingDirection.Y
EditorScroll.CanvasSize = UDim2.new(0,0,0,0)
EditorScroll.ZIndex = 4
EditorScroll.Parent = EditorOuter

local HScrollBar = Instance.new("ScrollingFrame")
HScrollBar.Size = UDim2.new(1,-(GUTTER_W+1),0,HSCROLL_H)
HScrollBar.Position = UDim2.new(0,GUTTER_W+1,0,TABBAR_H+EO_H)
HScrollBar.BackgroundTransparency = 1
HScrollBar.ScrollBarThickness = HSCROLL_H
HScrollBar.ScrollBarImageColor3 = C.SCROLL
HScrollBar.ScrollingDirection = Enum.ScrollingDirection.X
HScrollBar.VerticalScrollBarInset = Enum.ScrollBarInset.Always
HScrollBar.CanvasSize = UDim2.new(0,2000,1,0)
HScrollBar.ZIndex = 5
HScrollBar.Parent = EditorContainer

local CodeBox = Instance.new("TextBox")
CodeBox.Size = UDim2.new(0,2000,1,0)
CodeBox.Position = UDim2.new(0,6,0,LINE_YOFF)
CodeBox.BackgroundTransparency = 1
CodeBox.Text = ""
CodeBox.PlaceholderText = "Skibid Vietnam Executor"
CodeBox.PlaceholderColor3 = C.TEXT_DIM
CodeBox.TextColor3 = C.TEXT
CodeBox.TextTransparency = 0.65 
CodeBox.Font = Enum.Font.Code
CodeBox.TextSize = 14
CodeBox.TextWrapped = false
CodeBox.MultiLine = true
CodeBox.TextXAlignment = Enum.TextXAlignment.Left
CodeBox.TextYAlignment = Enum.TextYAlignment.Top
CodeBox.ClearTextOnFocus = false
CodeBox.ZIndex = 5
CodeBox.Parent = EditorScroll
pcall(function() CodeBox.SelectionColor3 = C.SEARCH_MATCH_BG end)

HScrollBar:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
    local x = HScrollBar.CanvasPosition.X
    EditorScroll.CanvasPosition = Vector2.new(x, EditorScroll.CanvasPosition.Y)
    SyntaxScroll.CanvasPosition = Vector2.new(x, SyntaxScroll.CanvasPosition.Y)
end)

EditorScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
    LineNumScroll.CanvasPosition = Vector2.new(0, EditorScroll.CanvasPosition.Y)
    SyntaxScroll.CanvasPosition = Vector2.new(HScrollBar.CanvasPosition.X, EditorScroll.CanvasPosition.Y)
end)

local SearchBar = Instance.new("Frame")
SearchBar.Name = "SearchBar"
SearchBar.Size = UDim2.new(0, 280, 0, 32)
SearchBar.Position = UDim2.new(1, -290, 0, 4)
SearchBar.BackgroundColor3 = C.SEARCH_BG
SearchBar.BackgroundTransparency = 0.1
SearchBar.Visible = false
SearchBar.ZIndex = 25
SearchBar.Parent = EditorOuter
corner(SearchBar, UDim.new(0, 6))
stroke(SearchBar, BORDER, 0.8, 0.4)

local SearchInput = Instance.new("TextBox")
SearchInput.Size = UDim2.new(0, 140, 0, 24)
SearchInput.Position = UDim2.new(0, 6, 0.5, -12)
SearchInput.BackgroundColor3 = BG_COLOR
SearchInput.BackgroundTransparency = 0.3
SearchInput.Text = ""
SearchInput.PlaceholderText = "Find..."
SearchInput.PlaceholderColor3 = C.TEXT_DIM
SearchInput.TextColor3 = C.TEXT
SearchInput.Font = Enum.Font.Code
SearchInput.TextSize = 12
SearchInput.ClearTextOnFocus = false
SearchInput.ZIndex = 26
SearchInput.Parent = SearchBar
corner(SearchInput, UDim.new(0, 4))

local SearchCount = Instance.new("TextLabel")
SearchCount.Size = UDim2.new(0, 45, 0, 24)
SearchCount.Position = UDim2.new(0, 150, 0.5, -12)
SearchCount.BackgroundTransparency = 1
SearchCount.Text = "0/0"
SearchCount.TextColor3 = C.TEXT_DIM
SearchCount.Font = Enum.Font.Code
SearchCount.TextSize = 11
SearchCount.ZIndex = 26
SearchCount.Parent = SearchBar

local SearchPrev = Instance.new("TextButton")
SearchPrev.Size = UDim2.new(0, 22, 0, 22)
SearchPrev.Position = UDim2.new(0, 198, 0.5, -11)
SearchPrev.BackgroundColor3 = BG_COLOR
SearchPrev.BackgroundTransparency = 0.5
SearchPrev.Text = "<"
SearchPrev.TextColor3 = C.TEXT
SearchPrev.Font = Enum.Font.GothamBold
SearchPrev.TextSize = 12
SearchPrev.ZIndex = 26
SearchPrev.Parent = SearchBar
corner(SearchPrev, UDim.new(0, 4))
hover(SearchPrev, BG_COLOR, Color3.fromRGB(70, 68, 95), 0.5, 0.2)

local SearchNext = Instance.new("TextButton")
SearchNext.Size = UDim2.new(0, 22, 0, 22)
SearchNext.Position = UDim2.new(0, 222, 0.5, -11)
SearchNext.BackgroundColor3 = BG_COLOR
SearchNext.BackgroundTransparency = 0.5
SearchNext.Text = ">"
SearchNext.TextColor3 = C.TEXT
SearchNext.Font = Enum.Font.GothamBold
SearchNext.TextSize = 12
SearchNext.ZIndex = 26
SearchNext.Parent = SearchBar
corner(SearchNext, UDim.new(0, 4))
hover(SearchNext, BG_COLOR, Color3.fromRGB(70, 68, 95), 0.5, 0.2)

local SearchClose = Instance.new("TextButton")
SearchClose.Size = UDim2.new(0, 22, 0, 22)
SearchClose.Position = UDim2.new(0, 250, 0.5, -11)
SearchClose.BackgroundTransparency = 1
SearchClose.Text = "×"
SearchClose.TextColor3 = C.TEXT_DIM
SearchClose.Font = Enum.Font.GothamBold
SearchClose.TextSize = 16
SearchClose.ZIndex = 26
SearchClose.Parent = SearchBar
SearchClose.MouseEnter:Connect(function()
    TweenService:Create(SearchClose, TweenInfo.new(0.1), {TextColor3 = C.WHITE}):Play()
end)
SearchClose.MouseLeave:Connect(function()
    TweenService:Create(SearchClose, TweenInfo.new(0.1), {TextColor3 = C.TEXT_DIM}):Play()
end)

local ACFrame = Instance.new("Frame")
ACFrame.Name = "ACPopup"
ACFrame.Size = UDim2.new(0,220,0,0)
ACFrame.BackgroundColor3 = BG_COLOR
ACFrame.BackgroundTransparency = 0.22
ACFrame.Visible = false
ACFrame.ZIndex = 20
ACFrame.Parent = EditorOuter
corner(ACFrame, UDim.new(0,5))
stroke(ACFrame, BORDER, 0.8, 0.35)

local ACListLayout = Instance.new("UIListLayout")
ACListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ACListLayout.Parent = ACFrame

local acItems    = {}
local acSelected = 1
local acVisible  = false
local acCurrent  = {}

local function hideAC()
    ACFrame.Visible = false
    acVisible = false
    acCurrent = {}
    for _, f in ipairs(acItems) do f:Destroy() end
    acItems = {}
end

local function showAC(items, posY)
    hideAC()
    if #items == 0 then return end
    acCurrent = items
    acSelected = 1
    local itemH = 22
    ACFrame.Size = UDim2.new(0,220,0, math.min(#items,6)*itemH)
    ACFrame.Position = UDim2.new(0, GUTTER_W+8, 0, posY)
    for i, word in ipairs(items) do
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1,0,0,itemH)
        row.BackgroundColor3 = i==1 and C.ACCENT or BG_COLOR
        row.BackgroundTransparency = i==1 and 0.3 or 0.7
        row.Text = "  "..word
        row.TextColor3 = C.TEXT
        row.Font = Enum.Font.Code
        row.TextSize = 13
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.LayoutOrder = i
        row.ZIndex = 21
        row.Parent = ACFrame
        table.insert(acItems, row)
        local cap = i
        row.MouseButton1Click:Connect(function()
            local src = CodeBox.Text
            local cur = CodeBox.CursorPosition
            local existing = src:sub(1,cur-1):match("[%a_%.][%a%d_%.]*$") or ""
            local before = src:sub(1,cur-1-#existing)
            local after  = src:sub(cur)
            CodeBox.Text = before..acCurrent[cap]..after
            CodeBox.CursorPosition = #before+#acCurrent[cap]+1
            hideAC()
        end)
    end
    ACFrame.Visible = true
    acVisible = true
end

local function updateACHighlight()
    for i, row in ipairs(acItems) do
        row.BackgroundColor3 = i==acSelected and C.ACCENT or BG_COLOR
        row.BackgroundTransparency = i==acSelected and 0.3 or 0.7
    end
end

local function c2hex(c3)
    return string.format("#%02X%02X%02X",
        math.clamp(math.floor(c3.R*255),0,255),
        math.clamp(math.floor(c3.G*255),0,255),
        math.clamp(math.floor(c3.B*255),0,255))
end

local function esc(s)
    return (s:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"))
end

local function wrap(text, col)
    if text == "" then return "" end
    return string.format('<font color="%s">%s</font>', c2hex(col), esc(text))
end

local function highlightSearchMatches(text, query, currentColorHex)
    if query == "" or #query == 0 then return esc(text) end
    local colorHex = currentColorHex or c2hex(C.TEXT)

    local result = {}
    local queryLower = query:lower()
    local textLower = text:lower()
    local lastEnd = 1
    local startPos = 1

    while true do
        local s, e = textLower:find(queryLower, startPos, true)
        if not s then break end

        if s > lastEnd then
            table.insert(result, esc(text:sub(lastEnd, s - 1)))
        end

        local matchText = text:sub(s, e)
        table.insert(result, string.format('<font color="%s"><b>%s</b></font>', c2hex(C.SEARCH_HL), esc(matchText)))

        startPos = e + 1
        lastEnd = e + 1
    end

    if lastEnd <= #text then
        table.insert(result, esc(text:sub(lastEnd)))
    end

    return table.concat(result)
end

local lastContext = "" 

local function highlight(src)

    local truncated = false
    if #src > MAX_HIGHLIGHT_LEN then
        truncated = true
        src = src:sub(1, MAX_HIGHLIGHT_LEN)
    end

    local out = {}
    local i = 1
    local n = #src

    while i <= n do
        local ch = src:sub(i,i)

        if src:sub(i,i+1) == "--" then
            if src:sub(i,i+3) == "--[[" then
                local e = src:find("]]",i+4,true)
                local seg = e and src:sub(i,e+1) or src:sub(i)
                table.insert(out, wrap(seg, C.SYN_CMT))
                i = e and e+2 or n+1
            else
                local nl = src:find("\n",i,true)
                local seg = nl and src:sub(i,nl-1) or src:sub(i)
                table.insert(out, wrap(seg, C.SYN_CMT))
                i = nl and nl or n+1
            end

        elseif src:sub(i,i+1) == "[[" then
            local e = src:find("]]",i+2,true)
            local seg = e and src:sub(i,e+1) or src:sub(i)
            table.insert(out, wrap(seg, C.SYN_STR))
            i = e and e+2 or n+1

        elseif ch == '"' or ch == "'" then
            local q = ch
            local j = i+1
            while j <= n do
                local c2 = src:sub(j,j)
                if c2=="\\" then j=j+2
                elseif c2==q then j=j+1; break
                elseif c2=="\n" then break
                else j=j+1 end
            end
            table.insert(out, wrap(src:sub(i,j-1), C.SYN_STR))
            i = j

        elseif ch:match("%d") then
            local seg
            if src:sub(i,i+1):lower() == "0x" then
                local _, e2 = src:find("^0[xX][%da-fA-F]+", i)
                seg = e2 and src:sub(i,e2) or ch
                i = e2 and e2+1 or i+1
            else
                local _, e2 = src:find("^%d+%.?%d*[eE]?[+-]?%d*", i)
                seg = e2 and src:sub(i,e2) or ch
                i = e2 and e2+1 or i+1
            end
            table.insert(out, wrap(seg, C.SYN_NUM))

        elseif ch:match("[%a_]") then
            local _, e2 = src:find("^[%a%d_]+", i)
            local word = e2 and src:sub(i,e2) or ch
            local nextI = e2 and e2+1 or i+1

            local prevContext = src:sub(math.max(1,i-7), i-1)
            local isStringFunc = prevContext:match("string%.$") and SF_SET[word]

            if KW_SET[word] then
                table.insert(out, wrap(word, C.SYN_KW))
            elseif isStringFunc then
                table.insert(out, wrap(word, C.SYN_STR)) 

            elseif BI_SET[word] then
                table.insert(out, wrap(word, C.SYN_FN))
            else
                local after = src:sub(nextI, nextI)
                if after == "(" then
                    table.insert(out, wrap(word, C.SYN_FN))
                else
                    table.insert(out, wrap(word, C.TEXT))
                end
            end
            i = nextI

        elseif ch=="." and src:sub(i+1,i+1):match("[%a_]") then
            local _, e2 = src:find("^%.[%a%d_]+", i)
            local seg = e2 and src:sub(i,e2) or ch
            table.insert(out, wrap(seg, C.SYN_PROP))
            i = e2 and e2+1 or i+1

        elseif ch=="\n" then
            table.insert(out, "\n")
            i = i+1

        else
            table.insert(out, esc(ch))
            i = i+1
        end
    end

    if truncated then
        table.insert(out, wrap("\n... (truncated for performance)", C.TEXT_DIM))
    end

    local highlighted = table.concat(out)

    if currentSearchQuery ~= "" and searchVisible then
        highlighted = highlightSearchMatchesInRichText(highlighted, currentSearchQuery)
    end

    return highlighted
end

local function highlightSearchMatchesInRichText(richText, query)
    if query == "" then return richText end

    local lines = {}
    for line in richText:gmatch("[^\n]*\n?") do
        if line ~= "" then
            table.insert(lines, line)
        end
    end

    local resultLines = {}
    for _, line in ipairs(lines) do

        local currentColorHex = c2hex(C.TEXT)
        local reconstructed = ""
    local pattern = '(<[^>]+>)([^<]*)'
    local pos = 1

    while pos <= #line do
        local tagStart, tagEnd, tagContent, textContent = line:find(pattern, pos)
        if not tagStart then
                local remaining = line:sub(pos)
                if remaining ~= "" then
                    reconstructed ..= highlightSearchMatches(remaining, query, currentColorHex)
                end
                break
            end

            if tagStart > pos then
                local between = line:sub(pos, tagStart - 1)
                if between ~= "" then
                    reconstructed ..= highlightSearchMatches(between, query, currentColorHex)
                end
            end

            local colorHex = tagContent:match('color=\"(#[%x%l%u]+)\"')
            if colorHex then
                currentColorHex = colorHex
            end

            reconstructed ..= tagContent
            if textContent and textContent ~= "" then
                reconstructed ..= highlightSearchMatches(textContent, query, currentColorHex)
            end

            pos = tagEnd + 1
        end

        table.insert(resultLines, reconstructed)
    end

    return table.concat(resultLines)
end

local lineNumCache = {}
local lastLineCount = 0
local lineLabels = {}
local highlightedLine = nil

local function updateLineNumbers(lineCount)
    local lines = math.max(1, lineCount)

    if lines == lastLineCount then return end
    lastLineCount = lines

    for _, child in ipairs(LineNumScroll:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    lineLabels = {}

    for ln = 1, lines do
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,-4,0,LINE_H)
        lbl.Position = UDim2.new(0,0,0,(ln-1)*LINE_H+LINE_YOFF)
        lbl.BackgroundTransparency = 1
        lbl.Text = tostring(ln)
        lbl.TextColor3 = C.LINE_NUM
        lbl.Font = Enum.Font.Code
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Right
        lbl.ZIndex = 5
        lbl.Parent = LineNumScroll
        lineLabels[ln] = lbl
    end
    if highlightedLine then
        setLineHighlight(highlightedLine)
    end
end

local function setLineHighlight(lineNum)
    highlightedLine = lineNum
    for ln, lbl in pairs(lineLabels) do
        if ln == lineNum then
            lbl.BackgroundTransparency = 0.1
            lbl.BackgroundColor3 = C.SEARCH_MATCH_BG
            lbl.TextColor3 = C.WHITE
        else
            lbl.BackgroundTransparency = 1
            lbl.BackgroundColor3 = Color3.new(0,0,0)
            lbl.TextColor3 = C.LINE_NUM
        end
    end
end

local function updateCanvasSize()
    local src = CodeBox.Text
    local lineCount = select(2, src:gsub("\n", "\n")) + 1
    local h = math.max(lineCount * LINE_H + 10, EditorScroll.AbsoluteSize.Y)
    local w = math.max(CodeBox.TextBounds.X+60, 2000)

    EditorScroll.CanvasSize = UDim2.new(0,w,0,h)
    CodeBox.Size = UDim2.new(0,w-6,0,h)
    SyntaxScroll.CanvasSize = UDim2.new(0,w,0,h)
    SyntaxLabel.Size = UDim2.new(0,w-6,0,h)
    HScrollBar.CanvasSize = UDim2.new(0,w,1,0)
    LineNumScroll.CanvasSize = UDim2.new(1,0,0,lineCount*LINE_H + LINE_YOFF*2 + 4)

    updateLineNumbers(lineCount)
end

local function updateHighlightDebounced()
    local now = tick()
    if now - lastHighlightTime < HIGHLIGHT_DEBOUNCE then
        if not pendingHighlight then
            pendingHighlight = true
            task.delay(HIGHLIGHT_DEBOUNCE, function()
                pendingHighlight = false
                lastHighlightTime = tick()
                local src = CodeBox.Text
                local ok, rich = pcall(highlight, src)
                SyntaxLabel.Text = ok and rich or esc(src)
            end)
        end
        return
    end

    lastHighlightTime = now
    local src = CodeBox.Text
    local ok, rich = pcall(highlight, src)
    SyntaxLabel.Text = ok and rich or esc(src)
end

local function updateCanvas()
    updateCanvasSize()
    updateHighlightDebounced()
end

local function findAllMatches(text, query)
    local matches = {}
    if query == "" then return matches end

    local queryLower = query:lower()
    local textLower = text:lower()
    local start = 1

    while true do
        local s, e = textLower:find(queryLower, start, true)
        if not s then break end
        table.insert(matches, {start = s, finish = e})
        start = e + 1
    end

    return matches
end

local function updateSearchUI()
    if #searchMatches == 0 then
        SearchCount.Text = "0/0"
        SearchCount.TextColor3 = C.TEXT_DIM
    else
        SearchCount.Text = currentMatchIndex .. "/" .. #searchMatches
        SearchCount.TextColor3 = C.TEXT
    end
end

local function goToMatch(index, andFocusCode)
    if #searchMatches == 0 then return end

    currentMatchIndex = index
    if currentMatchIndex < 1 then currentMatchIndex = #searchMatches end
    if currentMatchIndex > #searchMatches then currentMatchIndex = 1 end

    local match = searchMatches[currentMatchIndex]

    local src = CodeBox.Text
    local beforeMatch = src:sub(1, match.start - 1)
    local lineNum = select(2, beforeMatch:gsub("\n", "\n")) + 1
    local scrollY = math.max(0, (lineNum - 1) * LINE_H)
    EditorScroll.CanvasPosition = Vector2.new(EditorScroll.CanvasPosition.X, scrollY)

    setLineHighlight(lineNum)
    showToast(("Found text at line %d"):format(lineNum))

    if andFocusCode then
        CodeBox.CursorPosition = match.finish + 1
        CodeBox:CaptureFocus()
    end

    updateSearchUI()
end

local function performSearch()
    local query = SearchInput.Text
    currentSearchQuery = query  

    searchMatches = findAllMatches(CodeBox.Text, query)

    if #searchMatches > 0 then
        currentMatchIndex = 1
        setLineHighlight(nil)
    else
        currentMatchIndex = 0
        setLineHighlight(nil)
    end

    updateSearchUI()

    updateHighlightDebounced()
end

local function showSearch()
    searchVisible = true
    SearchBar.Visible = true
    SearchInput:CaptureFocus()
    performSearch()
end

local function hideSearch()
    searchVisible = false
    SearchBar.Visible = false
    searchMatches = {}
    currentMatchIndex = 0
    currentSearchQuery = ""  
    setLineHighlight(nil)

    updateSearchUI()

    updateHighlightDebounced()
end

SearchInput:GetPropertyChangedSignal("Text"):Connect(performSearch)

SearchNext.MouseButton1Click:Connect(function()
    goToMatch(currentMatchIndex + 1, true)
end)

SearchPrev.MouseButton1Click:Connect(function()
    goToMatch(currentMatchIndex - 1, true)
end)

SearchClose.MouseButton1Click:Connect(hideSearch)

local BottomBar = ghost(UDim2.new(1,0,0,BOTTOM_H), UDim2.new(0,0,1,-BOTTOM_H), 3, MainFrame)

local BBLine = Instance.new("Frame")
BBLine.Size = UDim2.new(1,0,0,1)
BBLine.BackgroundColor3 = BORDER
BBLine.BackgroundTransparency = 0.55
BBLine.BorderSizePixel = 0
BBLine.ZIndex = 4
BBLine.Parent = BottomBar

local function makeBtn(text, xOff, fromLeft)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0,96,0,28)
    btn.Position = fromLeft
        and UDim2.new(0,xOff,0.5,-14)
        or  UDim2.new(1,xOff,0.5,-14)
    btn.BackgroundColor3 = BG_COLOR
    btn.BackgroundTransparency = 0.44
    btn.Text = text
    btn.TextColor3 = C.TEXT
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.ZIndex = 4
    btn.Parent = BottomBar
    corner(btn, UDim.new(0,5))
    stroke(btn, BORDER, 0.7, 0.48)
    hover(btn, BG_COLOR, Color3.fromRGB(62,60,82), 0.44, 0.12)
    return btn
end

local ExecBtn  = makeBtn("Execute", 10,   true)
local ClearBtn = makeBtn("Clear",   -106, false)

local function setActiveTab(index)
    if not tabs[index] then return end
    if activeTab and tabs[activeTab] then tabs[activeTab].content = CodeBox.Text end
    activeTab = index

    local content = tabs[index].content or ""
    CodeBox.Text = content

    lastLineCount = 0

    task.defer(function()
        updateCanvas()
        if searchVisible then performSearch() end
        setLineHighlight(nil)
    end)

    for i, f in pairs(tabFrames) do
        local act = (i==activeTab)
        f.BackgroundColor3 = act and C.TAB_ACT or BG_COLOR
        f.BackgroundTransparency = act and 0.22 or 0.55
        local ind = f:FindFirstChild("Ind")
        if ind then ind.Visible = act end
    end
end

local function removeTab(tabFrame)
    local idx
    for i, f in pairs(tabFrames) do if f==tabFrame then idx=i break end end
    if not idx then return end
    if #tabs<=1 then
        tabs[1].content=""
        CodeBox.Text=""
        updateCanvas(); saveData(); return
    end
    tabFrames[idx]:Destroy()
    table.remove(tabFrames, idx)
    table.remove(tabs, idx)
    for i, f in pairs(tabFrames) do f.LayoutOrder=i end
    activeTab=nil
    setActiveTab(math.min(idx,#tabs))
    saveData()
end

local function addTab(name, content)
    tabCount=tabCount+1
    local tName = name or ("Tab "..tabCount)
    table.insert(tabs, {name=tName, content=content or ""})
    local idx = #tabs

    local TF = Instance.new("Frame")
    TF.Size = UDim2.new(0,112,1,-2)
    TF.BackgroundColor3 = BG_COLOR
    TF.BackgroundTransparency = 0.55
    TF.LayoutOrder = idx
    TF.ZIndex = 7
    TF.Parent = TabScroll
    corner(TF, UDim.new(0,5))

    local Ind = Instance.new("Frame")
    Ind.Name = "Ind"
    Ind.Size = UDim2.new(1,-16,0,2)
    Ind.Position = UDim2.new(0,8,1,-2)
    Ind.BackgroundColor3 = C.ACCENT
    Ind.BorderSizePixel = 0
    Ind.Visible = false
    Ind.ZIndex = 8
    Ind.Parent = TF
    corner(Ind, UDim.new(0,1))

    local TLabel = Instance.new("TextButton")
    TLabel.Size = UDim2.new(1,-20,1,0)
    TLabel.Position = UDim2.new(0,8,0,0)
    TLabel.BackgroundTransparency = 1
    TLabel.Text = tName
    TLabel.TextColor3 = C.TEXT
    TLabel.Font = Enum.Font.Gotham
    TLabel.TextSize = 12
    TLabel.TextXAlignment = Enum.TextXAlignment.Left
    TLabel.TextTruncate = Enum.TextTruncate.AtEnd
    TLabel.ZIndex = 8
    TLabel.Parent = TF

    local RBtn = Instance.new("TextButton")
    RBtn.Size = UDim2.new(0,14,0,14)
    RBtn.Position = UDim2.new(1,-17,0.5,-7)
    RBtn.BackgroundTransparency = 1
    RBtn.Text = "x"
    RBtn.TextColor3 = C.TEXT_DIM
    RBtn.Font = Enum.Font.Gotham
    RBtn.TextSize = 11
    RBtn.ZIndex = 9
    RBtn.Parent = TF
    RBtn.MouseEnter:Connect(function()
        TweenService:Create(RBtn,TweenInfo.new(0.1),{TextColor3=C.WHITE}):Play()
    end)
    RBtn.MouseLeave:Connect(function()
        TweenService:Create(RBtn,TweenInfo.new(0.1),{TextColor3=C.TEXT_DIM}):Play()
    end)

    table.insert(tabFrames, TF)
    TLabel.MouseButton1Click:Connect(function()
        for i, f in pairs(tabFrames) do
            if f == TF then setActiveTab(i); break end
        end
    end)
    RBtn.MouseButton1Click:Connect(function() removeTab(TF) end)
    setActiveTab(idx)
    saveData()
end

local lastText   = ""
local ignoreNext = false

local function getWordBefore(text, cur)
    return text:sub(1,cur-1):match("[%a_%.][%a%d_%.]*$") or ""
end

local function applyCompletion(word)
    local src = CodeBox.Text
    local cur = CodeBox.CursorPosition
    local existing = getWordBefore(src, cur)
    local before = src:sub(1, cur-1-#existing)
    local after  = src:sub(cur)
    ignoreNext = true
    CodeBox.Text = before..word..after
    CodeBox.CursorPosition = #before+#word+1
    hideAC()
    lastText = CodeBox.Text
    if activeTab and tabs[activeTab] then tabs[activeTab].content=CodeBox.Text end
    updateCanvas(); saveData()
end

CodeBox:GetPropertyChangedSignal("Text"):Connect(function()
    if ignoreNext then
        ignoreNext = false
        lastText = CodeBox.Text
        return
    end

    local src = CodeBox.Text
    local cur = CodeBox.CursorPosition

    if acVisible and #acCurrent > 0 and #src >= #lastText and cur > 1 then
        local typed = src:sub(cur - 1, cur - 1)

        if typed == " " or typed == "\t" or typed == "\n" then
            local beforeTyped = src:sub(1, cur - 2)
            local word = beforeTyped:match("[%a_%.][%a%d_%.]*$") or ""

            if word ~= "" then
                local replacement = acCurrent[acSelected]
                local head = beforeTyped:sub(1, #beforeTyped - #word)
                local tail = src:sub(cur)

                ignoreNext = true
                CodeBox.Text = head .. replacement .. tail
                CodeBox.CursorPosition = #head + #replacement + 1
                hideAC()

                lastText = CodeBox.Text
                if activeTab and tabs[activeTab] then
                    tabs[activeTab].content = CodeBox.Text
                end
                updateCanvas()
                saveData()
                return
            end
        end
    end

    if #src > #lastText and cur > 1 then
        local newChar = src:sub(cur-1,cur-1)

        if newChar==" " and not acVisible then
            local wordEnd = cur-2
            local word = src:sub(1,wordEnd):match("[%a_]+$")
            if word and SNIPPETS[word] then
                local before    = src:sub(1, wordEnd-#word)
                local after     = src:sub(cur)
                local expansion = SNIPPETS[word]
                ignoreNext = true
                CodeBox.Text = before..expansion..after
                CodeBox.CursorPosition = #before+#expansion+1
                lastText = CodeBox.Text
                if activeTab and tabs[activeTab] then tabs[activeTab].content=CodeBox.Text end
                updateCanvas(); saveData(); return
            end
        end

        if AUTOPAIRS[newChar] then
            local closing  = AUTOPAIRS[newChar]
            local nextChar = src:sub(cur,cur)
            if nextChar~=closing then
                ignoreNext = true
                CodeBox.Text = src:sub(1,cur-1)..closing..src:sub(cur)
                CodeBox.CursorPosition = cur
                lastText = CodeBox.Text
                if activeTab and tabs[activeTab] then tabs[activeTab].content=CodeBox.Text end
                updateCanvas(); saveData(); return
            end
        end
    end

    if cur > 0 then
        local word = getWordBefore(src, cur)
        if #word >= 2 then
            local matches = {}
            local wordLower = word:lower()
            for _, cand in ipairs(AC_LIST) do
                if cand:lower():sub(1,#word) == wordLower then
                    table.insert(matches, cand)
                    if #matches >= 8 then break end
                end
            end
            if #matches > 0 then
                local lineNum = select(2, src:sub(1,cur):gsub("\n","\n"))
                showAC(matches, lineNum*LINE_H+LINE_H+2)
            else 
                hideAC() 
            end
        else 
            hideAC() 
        end
    end

    lastText = src
    if activeTab and tabs[activeTab] then tabs[activeTab].content=src end
    updateCanvas(); saveData()
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

    local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or 
                 UserInputService:IsKeyDown(Enum.KeyCode.RightControl)

    if ctrl and input.KeyCode == Enum.KeyCode.F then
        if searchVisible then
            hideSearch()
        else
            showSearch()
        end
        return
    end

    if searchVisible then
        if input.KeyCode == Enum.KeyCode.Escape then
            hideSearch()
            CodeBox:CaptureFocus()
            return
        elseif input.KeyCode == Enum.KeyCode.Return and SearchInput:IsFocused() then
            goToMatch(currentMatchIndex + 1, true)
            return
        end
    end

    if CodeBox:IsFocused() and acVisible and #acCurrent > 0 then
        local k = input.KeyCode

        if k == Enum.KeyCode.Up then
            acSelected = math.max(1, acSelected - 1)
            updateACHighlight()
            return
        elseif k == Enum.KeyCode.Down then
            acSelected = math.min(#acCurrent, acSelected + 1)
            updateACHighlight()
            return
        elseif k == Enum.KeyCode.Escape then
            hideAC()
            return
        end
    end

    if CodeBox:IsFocused() and input.KeyCode == Enum.KeyCode.Escape then
        hideAC()
    end
end)

ExecBtn.MouseButton1Click:Connect(function()
    if activeTab and tabs[activeTab] and CodeBox.Text~="" then
        local ok, err = pcall(function()
            if loadstring then
                local fn, ce = loadstring(CodeBox.Text)
                if fn then fn() else error("[SonicExecutor] "..tostring(ce)) end
            end
        end)
        if not ok then error("[SonicExecutor] "..tostring(err)) end
    end
end)

ClearBtn.MouseButton1Click:Connect(function()
    CodeBox.Text=""; lastText=""
    if activeTab and tabs[activeTab] then tabs[activeTab].content="" end
    lastLineCount = 0
    updateCanvas(); saveData()
end)

AddTabBtn.MouseButton1Click:Connect(function() addTab() end)

local lastWindowPosition = WIN_POS
local dragging, dragStart, startPos = false, nil, nil

local function resolveCurrentPosition()
    if dragging and dragStart and startPos then
        local mousePos = UserInputService:GetMouseLocation()
        local delta = mousePos - Vector2.new(dragStart.X, dragStart.Y)
        return UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
    return MainFrame.Position
end

local function getCenterCollapse(pos)
    return UDim2.new(
        pos.X.Scale, pos.X.Offset + WIN_W/2,
        pos.Y.Scale, pos.Y.Offset + WIN_H/2
    )
end

local function hideWindow()
    local resolved = resolveCurrentPosition()
    lastWindowPosition = resolved
    dragging = false

    local t = TweenService:Create(MainFrame, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size = UDim2.new(0,0,0,0),
        Position = getCenterCollapse(lastWindowPosition),
    })
    t:Play()
    t.Completed:Connect(function()
        MainFrame.Visible = false
    end)
end

local function typeTitle(text, speed)
    Title.Text=""
    for i=1,#text do
        Title.Text=text:sub(1,i)
        task.wait(speed or 0.04)
    end
end

local function showWindow()
    MainFrame.Size = UDim2.new(0,0,0,0)
    MainFrame.Position = getCenterCollapse(lastWindowPosition)
    MainFrame.Visible = true

    local t = TweenService:Create(MainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = WIN_SIZE,
        Position = lastWindowPosition,
    })
    t:Play()
    t.Completed:Connect(function()
        task.spawn(typeTitle, "Sonic Executor - External", 0.04)
    end)
end

MinBtn.MouseButton1Click:Connect(hideWindow)

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)

Header.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if dragging then
            lastWindowPosition = resolveCurrentPosition()
        end
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        local newPos = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
        MainFrame.Position = newPos
        lastWindowPosition = newPos
    end
end)

local ToggleGui = Instance.new("ScreenGui")
ToggleGui.Name = "SonicToggleGui"
ToggleGui.ResetOnSpawn = false
ToggleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ToggleGui.DisplayOrder = 999999
ToggleGui.IgnoreGuiInset = true
ToggleGui.Parent = PlayerGui

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0,44,0,44)
ToggleBtn.Position = UDim2.new(0,20,0.5,-22)
ToggleBtn.BackgroundColor3 = BG_COLOR
ToggleBtn.BackgroundTransparency = 0.44
ToggleBtn.Text = "Q"
ToggleBtn.TextColor3 = C.TEXT
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 19
ToggleBtn.ZIndex = 10
ToggleBtn.Parent = ToggleGui
corner(ToggleBtn, UDim.new(0,10))
stroke(ToggleBtn, BORDER, 0.8, 0.45)
hover(ToggleBtn, BG_COLOR, Color3.fromRGB(62,60,82), 0.44, 0.12)

local togDrag, togDS, togSP, togMoved = false, nil, nil, false
ToggleBtn.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        togDrag=true; togMoved=false; togDS=input.Position; togSP=ToggleBtn.Position
    end
end)
ToggleBtn.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        togDrag=false
        if not togMoved then
            if MainFrame.Visible then hideWindow() else showWindow() end
        end
        togMoved=false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if togDrag and input.UserInputType==Enum.UserInputType.MouseMovement then
        local d=input.Position-togDS
        if math.abs(d.X)>4 or math.abs(d.Y)>4 then togMoved=true end
        ToggleBtn.Position=UDim2.new(togSP.X.Scale,togSP.X.Offset+d.X,togSP.Y.Scale,togSP.Y.Offset+d.Y)
    end
end)

local savedTabs, savedActive = loadData()
if savedTabs and #savedTabs>0 then
    tabCount=0
    for _, t in ipairs(savedTabs) do addTab(t.name, t.content) end
    if savedActive and tabs[savedActive] then setActiveTab(savedActive) end
else
    addTab("Tab 1", "")
end

showWindow()
