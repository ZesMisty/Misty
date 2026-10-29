local src_url = "https://api.luarmor.net/files/v4/loaders/2ba34c68de2188444e8adc5398f89e89.lua"
local stall_s = 45

local tween = game:GetService("TweenService")
local env = getgenv()

local family = "rbxasset://fonts/families/BuilderSans.json"
local white = Color3.fromRGB(235, 241, 247)
local gray = Color3.fromRGB(144, 160, 176)
local accent = Color3.fromRGB(110, 150, 186)
local danger = Color3.fromRGB(255, 96, 96)

local function new(class, props, parent)
    local inst = Instance.new(class)
    if inst:IsA("GuiObject") then
        inst.BorderSizePixel = 0
    end
    for k, v in props do
        inst[k] = v
    end
    inst.Parent = parent
    return inst
end

local function load_logo(mark)
    local path = "Mist/logo.png"
    local function is_png(body)
        return type(body) == "string" and body:sub(1, 4) == "\137PNG"
    end
    if not (isfile(path) and is_png(readfile(path))) then
        local res = (request or http_request)({
            Url = "https://raw.githubusercontent.com/ZesMisty/Misty/main/Mist.png",
            Method = "GET",
        })
        assert(is_png(res.Body), "logo is not a png")
        if not isfolder("Mist") then
            makefolder("Mist")
        end
        writefile(path, res.Body)
    end
    mark.Image = getcustomasset(path)
end

local function make_ui()
    local gui = new("ScreenGui", {
        Name = "\0mist_loading",
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        DisplayOrder = 1000,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    local backdrop = new("TextButton", {
        Text = "",
        AutoButtonColor = false,
        BackgroundColor3 = Color3.fromRGB(5, 7, 10),
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
    }, gui)
    local card = new("CanvasGroup", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 12),
        Size = UDim2.fromOffset(300, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Color3.fromRGB(18, 23, 29),
        GroupTransparency = 1,
    }, gui)
    new("UICorner", { CornerRadius = UDim.new(0, 12) }, card)
    new("UIStroke", { Color = Color3.fromRGB(38, 48, 60) }, card)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 24),
        PaddingBottom = UDim.new(0, 24),
        PaddingLeft = UDim.new(0, 22),
        PaddingRight = UDim.new(0, 22),
    }, card)
    new("UIListLayout", {
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
    }, card)
    local logo = new("ImageLabel", {
        Size = UDim2.fromOffset(56, 56),
        BackgroundTransparency = 1,
        ScaleType = Enum.ScaleType.Fit,
        LayoutOrder = 1,
    }, card)
    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundTransparency = 1,
        FontFace = Font.new(family, Enum.FontWeight.Bold),
        Text = "Mist",
        TextSize = 30,
        TextColor3 = white,
        LayoutOrder = 2,
    }, card)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        LayoutOrder = 3,
    }, card)
    local status = new("TextLabel", {
        Size = UDim2.new(1, -48, 1, 0),
        BackgroundTransparency = 1,
        FontFace = Font.new(family, Enum.FontWeight.Medium),
        Text = "Downloading",
        TextSize = 14,
        TextColor3 = gray,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)
    local pct = new("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0, 44, 1, 0),
        BackgroundTransparency = 1,
        FontFace = Font.new(family, Enum.FontWeight.Medium),
        Text = "0%",
        TextSize = 14,
        TextColor3 = white,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)
    local track = new("Frame", {
        Size = UDim2.new(1, 0, 0, 6),
        BackgroundColor3 = Color3.fromRGB(27, 34, 43),
        LayoutOrder = 4,
    }, card)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
    local fill = new("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = accent,
    }, track)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)

    gui.Parent = gethui and gethui() or game:GetService("CoreGui")
    local fade = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    tween:Create(backdrop, fade, { BackgroundTransparency = 0.35 }):Play()
    tween:Create(card, fade, { GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.5) }):Play()
    return { gui = gui, backdrop = backdrop, card = card, logo = logo, status = status, pct = pct, fill = fill }
end

local function close(ui)
    local fade = TweenInfo.new(0.3)
    tween:Create(ui.backdrop, fade, { BackgroundTransparency = 1 }):Play()
    tween:Create(ui.card, fade, { GroupTransparency = 1 }):Play()
    task.wait(0.35)
    ui.gui:Destroy()
end

env.mist_ready = nil
env.mist_progress = nil

local ui = make_ui()
local failure
local shown, target, moved_at = 0, 0, os.clock()

local function aim(value)
    if value > target then
        target = value
        moved_at = os.clock()
    end
end

task.spawn(function()
    if not pcall(load_logo, ui.logo) then
        ui.logo.Visible = false
    end
end)

task.spawn(function()
    local ok, err = pcall(function()
        local body = game:HttpGet(src_url)
        aim(0.08)
        local chunk = assert(loadstring(body))
        aim(0.12)
        ui.status.Text = "Starting"
        chunk()
    end)
    if not ok then
        failure = tostring(err)
    end
end)

while true do
    local dt = task.wait()
    local prog = env.mist_progress
    if prog then
        aim(0.12 + 0.88 * prog.done / prog.total)
        ui.status.Text = prog.label
    end
    local ready = env.mist_ready
    if ready then
        aim(1)
    end
    shown += (target - shown) * math.min(dt * 6, 1)
    ui.fill.Size = UDim2.fromScale(shown, 1)
    ui.pct.Text = math.floor(shown * 100 + 0.5) .. "%"
    if ready == false or (ready and shown > 0.99) then
        break
    end
    if failure then
        break
    end
    if os.clock() - moved_at > stall_s then
        failure = "timed out waiting for mist"
        break
    end
end

local ready = env.mist_ready
if ready then
    ui.fill.Size = UDim2.fromScale(1, 1)
    ui.pct.Text = "100%"
    ui.status.Text = "Ready"
    task.wait(0.3)
elseif ready == nil then
    warn("mist load failed", failure)
    ui.status.Text = failure:match("[^\n]+") or "load failed"
    ui.status.TextColor3 = danger
    ui.fill.BackgroundColor3 = danger
    task.wait(6)
end
close(ui)
