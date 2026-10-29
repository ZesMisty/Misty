local src_url = "https://api.luarmor.net/files/v4/loaders/2ba34c68de2188444e8adc5398f89e89.lua"
local slow_s = 12
local long_s = 60
local panel_h = 234

local tween_svc = game:GetService("TweenService")
local lighting = game:GetService("Lighting")
local env = getgenv()

local family = "rbxasset://fonts/families/Inter.json"
local white = Color3.new(1, 1, 1)
local ink = Color3.fromRGB(245, 248, 252)
local dim = Color3.fromRGB(166, 178, 192)
local faint = Color3.fromRGB(116, 128, 142)
local accent = Color3.fromRGB(132, 172, 208)
local amber = Color3.fromRGB(240, 192, 108)
local red = Color3.fromRGB(255, 108, 100)

local faq = {
    { "Slow or unstable internet", "Mist is a large script and has to come through Luarmor. On a weak connection, or behind a VPN or proxy, that can take a minute or more." },
    { "Luarmor is slow or down", "The servers at api.luarmor.net and cdn.luarmor.net can be busy or briefly unavailable. Wait a little, then run the script again." },
    { "Something is blocking the connection", "A firewall, antivirus or DNS filter can block those hosts. Try another network, or allow Roblox through." },
    { "The key is not accepted", "Check that script_key is set to your own key before the loader runs. A wrong or expired key stops Mist from loading." },
    { "Still stuck?", "Hide this window and run the script again. If it keeps happening, send the stage and time shown below to support." },
}

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

local function play(inst, props, seconds, style)
    local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    tween_svc:Create(inst, info, props):Play()
end

local function text(parent, props)
    props.FontFace = Font.new(family, props.weight or Enum.FontWeight.Regular)
    props.weight = nil
    props.BackgroundTransparency = 1
    props.TextColor3 = props.TextColor3 or ink
    return new("TextLabel", props, parent)
end

local function gap(parent, px, order)
    return new("Frame", { Size = UDim2.new(1, 0, 0, px), BackgroundTransparency = 1, LayoutOrder = order }, parent)
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

local function add_faq(list)
    for i, item in ipairs(faq) do
        local row = new("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = i * 2,
        }, list)
        new("UIPadding", { PaddingTop = UDim.new(0, 11), PaddingBottom = UDim.new(0, 11) }, row)
        new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, row)
        text(row, {
            Text = item[1],
            TextSize = 13,
            weight = Enum.FontWeight.Medium,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, 0, 0, 16),
            LayoutOrder = 1,
        })
        text(row, {
            Text = item[2],
            TextSize = 12,
            TextColor3 = dim,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 2,
        })
        if i < #faq then
            new("Frame", {
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = white,
                BackgroundTransparency = 0.92,
                LayoutOrder = i * 2 + 1,
            }, list)
        end
    end
end

local function make_panel(parent)
    local frame = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        LayoutOrder = 10,
    }, parent)
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, frame)
    gap(frame, 18, 1)
    local head = new("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = 2 }, frame)
    local dot = new("Frame", {
        Size = UDim2.fromOffset(7, 7),
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        BackgroundColor3 = amber,
    }, head)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
    local title = text(head, {
        Text = "Taking longer than usual",
        TextSize = 13,
        weight = Enum.FontWeight.SemiBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(15, 0),
        Size = UDim2.new(1, -15, 1, 0),
    })
    gap(frame, 8, 3)
    local list = new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 168),
        BackgroundColor3 = white,
        BackgroundTransparency = 0.94,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = white,
        ScrollBarImageTransparency = 0.6,
        LayoutOrder = 4,
    }, frame)
    new("UICorner", { CornerRadius = UDim.new(0, 14) }, list)
    new("UIStroke", { Color = white, Transparency = 0.92 }, list)
    new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, list)
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, list)
    add_faq(list)
    gap(frame, 8, 5)
    local stage = text(frame, {
        Text = "",
        TextSize = 11,
        TextColor3 = faint,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 14),
        LayoutOrder = 6,
    })
    return { frame = frame, title = title, dot = dot, stage = stage }
end

local function make_ui()
    local view = workspace.CurrentCamera.ViewportSize
    local base = math.clamp(math.min(view.Y / 900, view.X / 440, view.Y / 560), 0.6, 1.4)
    local gui = new("ScreenGui", {
        Name = "\0mist_loading",
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        DisplayOrder = 1000,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    local blur = new("BlurEffect", { Name = "\0blur_loading", Size = 0 }, lighting)
    local backdrop = new("TextButton", {
        Text = "",
        AutoButtonColor = false,
        BackgroundColor3 = Color3.fromRGB(4, 6, 9),
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
    }, gui)
    local card = new("CanvasGroup", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 16),
        Size = UDim2.fromOffset(400, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        GroupTransparency = 1,
    }, gui)
    local scale = new("UIScale", { Scale = base * 0.95 }, card)

    local glass = new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(24, 30, 38),
        BackgroundTransparency = 0.2,
    }, card)
    new("UICorner", { CornerRadius = UDim.new(0, 26) }, glass)
    new("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 0.14),
        }),
    }, glass)
    local rim = new("UIStroke", { Color = white, Thickness = 1 }, glass)
    new("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.5),
            NumberSequenceKeypoint.new(0.4, 0.85),
            NumberSequenceKeypoint.new(1, 0.93),
        }),
    }, rim)

    local body = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, card)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 30),
        PaddingBottom = UDim.new(0, 18),
        PaddingLeft = UDim.new(0, 32),
        PaddingRight = UDim.new(0, 32),
    }, body)
    new("UIListLayout", {
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, body)

    local logo = new("ImageLabel", {
        Size = UDim2.fromOffset(60, 60),
        BackgroundTransparency = 1,
        ScaleType = Enum.ScaleType.Fit,
        LayoutOrder = 1,
    }, body)
    gap(body, 10, 2)
    text(body, {
        Text = "Mist",
        TextSize = 28,
        weight = Enum.FontWeight.SemiBold,
        Size = UDim2.new(1, 0, 0, 34),
        LayoutOrder = 3,
    })
    gap(body, 2, 4)
    local status = text(body, {
        Text = "Contacting Luarmor",
        TextSize = 14,
        TextColor3 = dim,
        TextWrapped = true,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 5,
    })
    gap(body, 20, 6)

    local track = new("Frame", {
        Size = UDim2.new(1, 0, 0, 4),
        BackgroundColor3 = white,
        BackgroundTransparency = 0.86,
        LayoutOrder = 7,
    }, body)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
    local fill = new("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = accent,
        ClipsDescendants = true,
    }, track)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
    local sheen = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = white }, fill)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, sheen)
    local sweep = new("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0.55),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Offset = Vector2.new(-1, 0),
    }, sheen)
    local loop = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1)
    tween_svc:Create(sweep, loop, { Offset = Vector2.new(1, 0) }):Play()
    gap(body, 10, 8)

    local meta = new("Frame", { Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, LayoutOrder = 9 }, body)
    local clock = text(meta, {
        Text = "0:00",
        TextSize = 12,
        TextColor3 = faint,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.fromScale(0.5, 1),
    })
    local pct = text(meta, {
        Text = "0%",
        TextSize = 12,
        TextColor3 = dim,
        TextXAlignment = Enum.TextXAlignment.Right,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.fromScale(0.5, 1),
    })

    local panel = make_panel(body)
    gap(body, 10, 11)
    local foot = new("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = 12 }, body)
    local button = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.fromScale(1, 0.5),
        Size = UDim2.fromOffset(0, 26),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = white,
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        FontFace = Font.new(family, Enum.FontWeight.Medium),
        Text = "Hide",
        TextSize = 13,
        TextColor3 = accent,
    }, foot)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, button)
    new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, button)
    button.MouseEnter:Connect(function()
        play(button, { BackgroundTransparency = 0.9 }, 0.15)
    end)
    button.MouseLeave:Connect(function()
        play(button, { BackgroundTransparency = 1 }, 0.15)
    end)

    gui.Parent = gethui and gethui() or game:GetService("CoreGui")
    play(backdrop, { BackgroundTransparency = 0.45 }, 0.4)
    play(blur, { Size = 18 }, 0.5)
    play(card, { GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.5) }, 0.55)
    play(scale, { Scale = base }, 0.55)
    return {
        gui = gui,
        blur = blur,
        backdrop = backdrop,
        card = card,
        scale = scale,
        base = base,
        logo = logo,
        status = status,
        fill = fill,
        clock = clock,
        pct = pct,
        panel = panel,
        button = button,
    }
end

local function open_panel(ui, title, color)
    ui.panel.title.Text = title
    ui.panel.dot.BackgroundColor3 = color
    play(ui.panel.frame, { Size = UDim2.new(1, 0, 0, panel_h) }, 0.55)
end

local function close(ui)
    play(ui.backdrop, { BackgroundTransparency = 1 }, 0.3)
    play(ui.blur, { Size = 0 }, 0.3)
    play(ui.card, { GroupTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, 10) }, 0.3)
    play(ui.scale, { Scale = ui.base * 0.97 }, 0.3)
    task.wait(0.35)
    ui.blur:Destroy()
    ui.gui:Destroy()
end

env.mist_ready = nil
env.mist_progress = nil

local ui = make_ui()
local t0 = os.clock()
local shown, target, moved_at = 0, 0, t0
local stage = "Contacting Luarmor"
local script_at, failure, dismissed, opened, failed

ui.button.Activated:Connect(function()
    dismissed = true
end)

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
        stage = "Waiting for Luarmor"
        chunk()
    end)
    if not ok then
        failure = tostring(err)
    end
end)

local function wait_loop()
    local last_sec = -1
    while not dismissed do
        local dt = task.wait()
        local now = os.clock()
        local prog = env.mist_progress
        if prog then
            script_at = script_at or now
            aim(0.12 + 0.88 * prog.done / prog.total)
            stage = prog.label
        end
        local ready = env.mist_ready
        if ready then
            aim(1)
        end
        if ready == false then
            return
        end

        if not failed then
            shown += (target - shown) * math.min(dt * 6, 1)
            ui.fill.Size = UDim2.fromScale(shown, 1)
            ui.pct.Text = math.floor(shown * 100 + 0.5) .. "%"
            if ui.status.Text ~= stage then
                ui.status.Text = stage
            end
        end

        local sec = math.floor(now - t0)
        if sec ~= last_sec then
            last_sec = sec
            local clock = string.format("%d:%02d", math.floor(sec / 60), sec % 60)
            ui.clock.Text = clock
            ui.panel.stage.Text = "Stage: " .. stage .. " \u{00B7} " .. clock
        end

        if ready and shown > 0.99 then
            ui.fill.Size = UDim2.fromScale(1, 1)
            ui.pct.Text = "100%"
            ui.status.Text = "Ready"
            print(string.format("mist ready %.1fs (luarmor %.1fs)", now - t0, (script_at or now) - t0))
            task.wait(0.4)
            return
        end

        if failure and not ready and not failed then
            failed = true
            warn("mist load failed", failure)
            ui.status.Text = (failure:match("[^\n]+") or "Load failed"):sub(1, 140)
            ui.status.TextColor3 = red
            ui.fill.BackgroundColor3 = red
            ui.button.Text = "Close"
            opened = true
            open_panel(ui, "Couldn't load Mist", red)
        elseif not opened and now - moved_at > slow_s then
            opened = true
            open_panel(ui, "Taking longer than usual", amber)
        elseif opened and not failed and now - moved_at > long_s then
            ui.panel.title.Text = "Still waiting for Mist"
        end
    end
end

local ok, err = pcall(wait_loop)
close(ui)
if not ok then
    error(err, 0)
end
