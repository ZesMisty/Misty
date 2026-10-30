--s
local src_url = "https://api.luarmor.net/files/v4/loaders/2ba34c68de2188444e8adc5398f89e89.lua"
local slow_s = 12
local long_s = 60
local card_w = 340
local card_h = 128
local panel_y = 120
local panel_h = 150
local open_h = panel_y + panel_h + 16
local pad = 18

local tween_svc = game:GetService("TweenService")
local lighting = game:GetService("Lighting")
local http_svc = game:GetService("HttpService")
local env = getgenv()

local family = "rbxasset://fonts/families/Roboto.json"
local white = Color3.new(1, 1, 1)
local accent = Color3.fromRGB(132, 172, 208)
local deep = Color3.fromRGB(84, 112, 168)
local tint = Color3.fromRGB(20, 24, 31)
local amber = Color3.fromRGB(255, 207, 90)
local red = Color3.fromRGB(255, 96, 88)
local soft = 0.35
local mute = 0.6

local tones = {
    pending = Color3.fromRGB(150, 158, 170),
    ok = Color3.fromRGB(72, 208, 120),
    warn = amber,
    bad = red,
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
    props.TextColor3 = props.TextColor3 or white
    return new("TextLabel", props, parent)
end

local function gap(parent, px, order)
    return new("Frame", { Size = UDim2.new(1, 0, 0, px), BackgroundTransparency = 1, LayoutOrder = order }, parent)
end

local function rim(inst, lit)
    local line = new("UIStroke", {
        Color = white,
        Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, inst)
    new("UIGradient", {
        Rotation = 60,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, lit),
            NumberSequenceKeypoint.new(0.35, 0.9),
            NumberSequenceKeypoint.new(0.7, 0.94),
            NumberSequenceKeypoint.new(1, lit + (1 - lit) * 0.45),
        }),
    }, line)
end

local function glow(parent, color, x, y, px)
    local spot = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(x, y),
        Size = UDim2.fromOffset(px, px),
        BackgroundTransparency = 1,
    }, parent)
    for i = 0, 13 do
        local r = 1 - (i / 14) ^ 0.6
        local ring = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(r, r),
            BackgroundColor3 = color,
            BackgroundTransparency = 0.978,
        }, spot)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
    end
end

local function make_shadow(parent)
    local group = new("CanvasGroup", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 14),
        Size = UDim2.new(1, 100, 1, 100),
        BackgroundTransparency = 1,
        GroupTransparency = 1,
        ZIndex = 1,
    }, parent)
    for i = 0, 8 do
        local layer = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, -92 + i * 10, 1, -92 + i * 10),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.982,
        }, group)
        new("UICorner", { CornerRadius = UDim.new(0, 24 + i * 5) }, layer)
    end
    return group
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

local function read_json(res)
    local ok, data = pcall(http_svc.JSONDecode, http_svc, res.Body)
    if ok and type(data) == "table" then
        return data
    end
end

local function read_luarmor(res)
    local data = read_json(res)
    if not data then
        return "warn", "unreadable reply", true
    end
    if not data.active then
        return "bad", tostring(data.message or "offline")
    end
    if data.warning then
        return "warn", tostring(data.warning_message or "warning")
    end
    return "ok", "online"
end

local function read_reach(res, ms)
    local code = res.StatusCode
    if code == 403 or code == 429 then
        return "warn", "blocked, HTTP " .. code
    end
    if code >= 500 then
        return "bad", "server error, HTTP " .. code
    end
    return "ok", "reachable, " .. ms .. " ms"
end

local function read_cloudflare(res)
    local data = read_json(res)
    if not (data and data.incidents) then
        return "warn", "unreadable reply", true
    end
    local live = data.incidents[1]
    if not live then
        return "ok", "no active incident"
    end
    local severe = live.impact == "major" or live.impact == "critical"
    return severe and "bad" or "warn", tostring(live.name)
end

local checks = {
    { "Luarmor", "https://luarmor.net/status/", read_luarmor },
    { "Luarmor API", "https://api.luarmor.net/", read_reach },
    { "Luarmor CDN", "https://cdn.luarmor.net/", read_reach },
    { "Cloudflare", "https://www.cloudflarestatus.com/api/v2/summary.json", read_cloudflare },
}

local function make_panel(parent)
    local frame = new("Frame", {
        Position = UDim2.fromOffset(pad, panel_y),
        Size = UDim2.new(1, -pad * 2, 0, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
    }, parent)
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, frame)
    local head = new("Frame", { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, LayoutOrder = 1 }, frame)
    local dot = new("Frame", {
        Size = UDim2.fromOffset(7, 7),
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        BackgroundColor3 = amber,
    }, head)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
    local title = text(head, {
        Text = "Taking a while",
        TextSize = 12,
        weight = Enum.FontWeight.Medium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(15, 0),
        Size = UDim2.new(1, -15, 1, 0),
    })
    gap(frame, 6, 2)
    local rows = {}
    for i, check in ipairs(checks) do
        local row = new("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = i + 2 }, frame)
        local light = new("Frame", {
            Size = UDim2.fromOffset(6, 6),
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.fromScale(0, 0.5),
            BackgroundColor3 = tones.pending,
        }, row)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, light)
        text(row, {
            Text = check[1],
            TextSize = 12,
            weight = Enum.FontWeight.Medium,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(14, 0),
            Size = UDim2.new(0, 112, 1, 0),
        })
        local value = text(row, {
            Text = "",
            TextSize = 12,
            TextTransparency = soft,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(126, 0),
            Size = UDim2.new(1, -126, 1, 0),
        })
        rows[i] = { light = light, value = value }
    end
    gap(frame, 8, 8)
    local note = text(frame, {
        Text = "",
        TextSize = 12,
        TextTransparency = soft,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Size = UDim2.new(1, 0, 0, 32),
        LayoutOrder = 9,
    })
    return { frame = frame, title = title, dot = dot, rows = rows, note = note }
end

local function make_button(parent)
    local button = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -pad, 0, 88),
        Size = UDim2.fromOffset(0, 24),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = white,
        BackgroundTransparency = 0.9,
        AutoButtonColor = false,
        FontFace = Font.new(family, Enum.FontWeight.Medium),
        Text = "Hide",
        TextSize = 12,
        TextColor3 = white,
    }, parent)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, button)
    new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, button)
    rim(button, 0.6)
    local press = new("UIScale", {}, button)
    button.MouseEnter:Connect(function()
        play(button, { BackgroundTransparency = 0.82 }, 0.15)
    end)
    button.MouseLeave:Connect(function()
        play(button, { BackgroundTransparency = 0.9 }, 0.15)
        play(press, { Scale = 1 }, 0.15)
    end)
    button.MouseButton1Down:Connect(function()
        play(press, { Scale = 0.95 }, 0.1)
    end)
    button.MouseButton1Up:Connect(function()
        play(press, { Scale = 1 }, 0.2, Enum.EasingStyle.Back)
    end)
    return button
end

local function make_ui()
    local view = workspace.CurrentCamera.ViewportSize
    local base = math.clamp(math.min(view.Y / 560, view.X / 380), 0.6, 1)
    local top_y = -math.floor(card_h * base / 2)
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
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
    }, gui)
    local root = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0.5, top_y + 14),
        Size = UDim2.fromOffset(card_w, card_h),
        BackgroundTransparency = 1,
    }, gui)
    local scale = new("UIScale", { Scale = base * 0.95 }, root)
    local shadow = make_shadow(root)
    local card = new("CanvasGroup", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        GroupTransparency = 1,
        ZIndex = 2,
    }, root)
    new("UICorner", { CornerRadius = UDim.new(0, 24) }, card)

    local glass = new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = tint,
        BackgroundTransparency = 0.36,
    }, card)
    new("UICorner", { CornerRadius = UDim.new(0, 24) }, glass)
    glow(glass, accent, 0.12, 0.1, 260)
    glow(glass, deep, 1, 1, 220)
    local sheen = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = white }, glass)
    new("UICorner", { CornerRadius = UDim.new(0, 24) }, sheen)
    new("UIGradient", {
        Rotation = 20,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.9),
            NumberSequenceKeypoint.new(0.5, 1),
            NumberSequenceKeypoint.new(1, 0.96),
        }),
    }, sheen)
    rim(glass, 0.3)

    local logo = new("ImageLabel", {
        Position = UDim2.fromOffset(pad, pad),
        Size = UDim2.fromOffset(44, 44),
        BackgroundTransparency = 1,
        ScaleType = Enum.ScaleType.Fit,
    }, card)
    text(card, {
        Text = "Mist",
        TextSize = 16,
        weight = Enum.FontWeight.Medium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(74, pad),
        Size = UDim2.new(1, -74 - 70, 0, 22),
    })
    local pct = text(card, {
        Text = "0%",
        TextSize = 13,
        weight = Enum.FontWeight.Medium,
        TextTransparency = soft,
        TextXAlignment = Enum.TextXAlignment.Right,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -pad, 0, pad),
        Size = UDim2.fromOffset(56, 22),
    })
    local status = text(card, {
        Text = "Contacting Luarmor",
        TextSize = 13,
        TextTransparency = soft,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(74, pad + 22),
        Size = UDim2.new(1, -74 - pad, 0, 20),
    })

    local track = new("Frame", {
        Position = UDim2.fromOffset(pad, 76),
        Size = UDim2.new(1, -pad * 2, 0, 4),
        BackgroundColor3 = white,
        BackgroundTransparency = 0.82,
    }, card)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
    local fill = new("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = white,
    }, track)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)

    local clock = text(card, {
        Text = "0:00",
        TextSize = 12,
        TextTransparency = mute,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(pad, 88),
        Size = UDim2.new(0.5, -pad, 0, 24),
    })
    local panel = make_panel(card)
    local button = make_button(card)

    gui.Parent = gethui and gethui() or game:GetService("CoreGui")
    play(backdrop, { BackgroundTransparency = 0.55 }, 0.45)
    play(blur, { Size = 22 }, 0.6)
    play(card, { GroupTransparency = 0 }, 0.5)
    play(shadow, { GroupTransparency = 0 }, 0.8)
    play(root, { Position = UDim2.new(0.5, 0, 0.5, top_y) }, 0.65)
    play(scale, { Scale = base }, 0.65, Enum.EasingStyle.Back)
    return {
        gui = gui,
        blur = blur,
        backdrop = backdrop,
        root = root,
        card = card,
        shadow = shadow,
        scale = scale,
        base = base,
        top_y = top_y,
        logo = logo,
        status = status,
        fill = fill,
        clock = clock,
        pct = pct,
        panel = panel,
        button = button,
    }
end

local checking = false

local function show(row, state, msg)
    row.light.BackgroundColor3 = tones[state]
    row.value.Text = msg
end

local function diagnose(r, failed)
    local svc, api, cdn, cf = r[1], r[2], r[3], r[4]
    if svc.lost and api.lost and cdn.lost and cf.lost then
        return "No reply from any server. Check your internet connection."
    end
    if not svc.lost and svc.state == "bad" then
        return "Luarmor reports it is offline. Wait, then run it again."
    end
    if not svc.lost and svc.state == "warn" then
        return "Luarmor has posted a warning, shown above."
    end
    if not cf.lost and cf.state ~= "ok" then
        return "Cloudflare has an active incident, which can affect Luarmor. Wait, then run it again."
    end
    if api.lost or cdn.lost then
        return "Your network can't reach Luarmor. Try another network, or turn off any VPN or firewall."
    end
    if api.state ~= "ok" or cdn.state ~= "ok" then
        return "Luarmor is refusing this connection. Try another network or turn off your VPN."
    end
    if failed then
        return "Luarmor and Cloudflare look fine, so the error above is the cause. Run the script again."
    end
    return "Luarmor and Cloudflare look fine. Mist is large, so it can still take a minute."
end

local function run_checks(panel)
    if checking then
        return
    end
    checking = true
    panel.note.Text = "Checking connection"
    local results, left = {}, #checks
    local function finish(i, state, msg, lost)
        if results[i] then
            return
        end
        results[i] = { state = state, lost = lost }
        show(panel.rows[i], state, msg)
        left -= 1
        if left == 0 then
            panel.note.Text = diagnose(results, panel.failed)
            checking = false
        end
    end
    for i, check in ipairs(checks) do
        show(panel.rows[i], "pending", "checking")
        task.delay(10, finish, i, "bad", "no response", true)
        task.spawn(function()
            local t = os.clock()
            local ok, res = pcall(request or http_request, { Url = check[2], Method = "GET" })
            if not ok or type(res) ~= "table" or not res.StatusCode then
                return finish(i, "bad", "no response", true)
            end
            local state, msg, lost = check[3](res, math.floor((os.clock() - t) * 1000))
            finish(i, state, msg, lost)
        end)
    end
end

local function open_panel(ui, title, color)
    ui.panel.title.Text = title
    ui.panel.dot.BackgroundColor3 = color
    run_checks(ui.panel)
    play(ui.panel.frame, { Size = UDim2.new(1, -pad * 2, 0, panel_h) }, 0.55)
    play(ui.root, { Size = UDim2.fromOffset(card_w, open_h) }, 0.55)
end

local function close(ui)
    play(ui.backdrop, { BackgroundTransparency = 1 }, 0.3)
    play(ui.blur, { Size = 0 }, 0.3)
    play(ui.card, { GroupTransparency = 1 }, 0.3)
    play(ui.shadow, { GroupTransparency = 1 }, 0.3)
    play(ui.root, { Position = UDim2.new(0.5, 0, 0.5, ui.top_y + 8) }, 0.3)
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
            ui.status.TextTransparency = 0
            ui.fill.BackgroundColor3 = red
            ui.button.Text = "Close"
            opened = true
            ui.panel.failed = true
            open_panel(ui, "Couldn't load", red)
        elseif not opened and now - moved_at > slow_s then
            opened = true
            open_panel(ui, "Taking a while", amber)
        elseif opened and not failed and now - moved_at > long_s then
            ui.panel.title.Text = "Still waiting"
        end
    end
end

local ok, err = pcall(wait_loop)
close(ui)
if not ok then
    error(err, 0)
end
