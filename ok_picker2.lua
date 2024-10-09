dofile("./ok_color.lua")

local tau <const> = 6.2831853071796
local oneTau <const> = 0.1591549430919

local defaults <const> = {
    -- TODO: Account for screen scale?
    wCanvas = 180,
    hCanvasCircle = 180,
    hCanvasAxis = 16,
    hCanvasAlpha = 16,

    circleReticleSize = 8,
    circleReticleStroke = 2,
    swatchSize = 17,
    textDisplayLimit = 50,
    radiansOffset = math.rad(30),

    useBack = false,
    useSat = false,
    satAxis = 1.0,
    lightAxis = 0.5,

    foreKey = "&FORE",
    backKey = "&BACK",
    canvasKey = "C&ANVAS",
    closeKey = "&X",
}

local active <const> = {
    radiansOffset = defaults.radiansOffset,

    wCanvasCircle = defaults.wCanvas,
    hCanvasCircle = defaults.hCanvasCircle,
    triggerCircleRepaint = true,
    byteStrCircle = "",

    wCanvasAxis = defaults.wCanvas,
    hCanvasAxis = defaults.hCanvasAxis,
    triggerAxisRepaint = true,
    byteStrAxis = "",

    wCanvasAlpha = defaults.wCanvas,
    hCanvasAlpha = defaults.hCanvasAlpha,
    triggerAlphaRepaint = true,
    byteStrAlpha = "",

    useBack = defaults.useBack,
    useSat = defaults.useSat,
    satAxis = defaults.satAxis,
    lightAxis = defaults.lightAxis,

    hueFore = 0.0,
    satFore = 1.0,
    lightFore = 0.5,

    redFore = 1.0,
    greenFore = 1.0,
    blueFore = 1.0,

    alphaFore = 1.0,

    hueBack = 0.5,
    satBack = 1.0,
    lightBack = 0.5,

    redBack = 0.0,
    greenBack = 0.0,
    blueBack = 0.0,

    alphaBack = 1.0,
}

---@param event { context: GraphicsContext }
local function onPaintAxis(event)
    local ctx <const> = event.context
    ctx.antialias = false
    ctx.blendMode = BlendMode.SRC

    local wCanvas <const> = ctx.width
    local hCanvas <const> = ctx.height
    if wCanvas <= 1 or hCanvas <= 1 then return end

    local useSat <const> = active.useSat
    local useBack <const> = active.useBack

    local satAxis <const> = active.satAxis
    local lightAxis <const> = active.lightAxis

    local hueFore <const> = active.hueFore
    local satFore <const> = active.satFore
    local lightFore <const> = active.lightFore

    local hueBack <const> = active.hueBack
    local satBack <const> = active.satBack
    local lightBack <const> = active.lightBack

    local hueActive <const> = useBack and hueBack or hueFore
    local satActive <const> = useBack and satBack or satFore
    local lightActive <const> = useBack and lightBack or lightFore

    local needsRepaint <const> = active.triggerAxisRepaint
        or active.wCanvasAxis ~= wCanvas
        or active.hCanvasAxis ~= hCanvas
        or (useSat and satAxis ~= satActive
            or lightAxis ~= lightActive)

    active.wCanvasAxis = wCanvas
    active.hCanvasAxis = hCanvas

    if needsRepaint then
        ---@type string[]
        local byteStrs <const> = {}

        local hslToRgb <const> = ok_color.okhsl_to_srgb
        local strpack <const> = string.pack
        local min <const> = math.min
        local max <const> = math.max
        local floor <const> = math.floor

        local xToFac <const> = 1.0 / (wCanvas - 1.0)

        local x = 0
        while x < wCanvas do
            local fac <const> = x * xToFac
            local xs <const> = useSat and fac or satActive
            local xl <const> = useSat and lightActive or fac
            local r01 <const>, g01 <const>, b01 <const> = hslToRgb(
                hueActive, xs, xl)

            -- Values still go out of gamut, particularly for
            -- saturated blues at medium light.
            local r01cl = min(max(r01, 0), 1)
            local g01cl = min(max(g01, 0), 1)
            local b01cl = min(max(b01, 0), 1)

            local r8 <const> = floor(r01cl * 255 + 0.5)
            local g8 <const> = floor(g01cl * 255 + 0.5)
            local b8 <const> = floor(b01cl * 255 + 0.5)

            local byteStr <const> = strpack("B B B B", r8, g8, b8, 255)

            x = x + 1
            byteStrs[x] = byteStr
        end -- End image loop.

        active.byteStrAxis = table.concat(byteStrs)
        active.triggerAxisRepaint = false
    end -- End needs repaint.

    -- Draw axis canvas.
    local imgSpec <const> = ImageSpec {
        width = wCanvas,
        height = 1,
        transparentColor = 0,
        colorMode = ColorMode.RGB
    }
    local img <const> = Image(imgSpec)
    img.bytes = active.byteStrAxis
    ctx:drawImage(img,
        Rectangle(0, 0, wCanvas, 1),
        Rectangle(0, 0, wCanvas, hCanvas))

    -- Draw reticle.
    local x01 <const> = useSat and satAxis or lightAxis
    local xReticle <const> = math.floor(x01 * wCanvas + 0.5)
    local yReticle <const> = hCanvas // 2

    local reticleSize <const> = defaults.circleReticleSize
    local reticleHalf <const> = reticleSize // 2
    local comparisand <const> = useSat and lightActive or lightAxis
    local reticleColor <const> = comparisand < 0.5
        and Color(255, 255, 255, 255)
        or Color(0, 0, 0, 255)
    ctx.color = reticleColor
    ctx.strokeWidth = defaults.circleReticleStroke
    ctx:strokeRect(Rectangle(
        xReticle - reticleHalf, yReticle - reticleHalf,
        reticleSize, reticleSize))
end

---@param event { context: GraphicsContext }
local function onPaintCircle(event)
    local ctx <const> = event.context
    ctx.antialias = false
    ctx.blendMode = BlendMode.SRC

    local wCanvas <const> = ctx.width
    local hCanvas <const> = ctx.height
    if wCanvas <= 1 or hCanvas <= 1 then return end

    local useSat <const> = active.useSat
    local useBack <const> = active.useBack

    local satAxis <const> = active.satAxis
    local lightAxis <const> = active.lightAxis

    local hueFore <const> = active.hueFore
    local satFore <const> = active.satFore
    local lightFore <const> = active.lightFore

    local hueBack <const> = active.hueBack
    local satBack <const> = active.satBack
    local lightBack <const> = active.lightBack

    local hueActive <const> = useBack and hueBack or hueFore
    local satActive <const> = useBack and satBack or satFore
    local lightActive <const> = useBack and lightBack or lightFore

    local needsRepaint <const> = active.triggerCircleRepaint
        or active.wCanvasCircle ~= wCanvas
        or active.hCanvasCircle ~= hCanvas
        or (useSat and satAxis ~= satActive
            or lightAxis ~= lightActive)

    active.wCanvasCircle = wCanvas
    active.hCanvasCircle = hCanvas

    local xCenter <const> = wCanvas * 0.5
    local yCenter <const> = hCanvas * 0.5
    local shortEdge <const> = math.min(wCanvas, hCanvas)
    local radiusCanvas <const> = (shortEdge - 1.0) * 0.5

    local themeColors <const> = app.theme.color
    local radiansOffset <const> = active.radiansOffset

    if needsRepaint then
        ---@type string[]
        local byteStrs <const> = {}

        -- Cache method used in while loop.
        local strpack <const> = string.pack
        local min <const> = math.min
        local max <const> = math.max
        local floor <const> = math.floor
        local atan2 <const> = math.atan
        local sqrt <const> = math.sqrt
        local hslToRgb <const> = ok_color.okhsl_to_srgb

        -- local diamCanvasInv <const> = 1.0 / diamCanvas
        local radiusCanvasInv <const> = 1.0 / radiusCanvas
        local bkgColor <const> = themeColors.window_face
        local packZero <const> = strpack("B B B B",
            bkgColor.red, bkgColor.green, bkgColor.blue, 255)

        local lenCanvas <const> = wCanvas * hCanvas
        local i = 0
        while i < lenCanvas do
            local yCanvas <const> = i // wCanvas
            local yDlt <const> = yCenter - yCanvas
            local yNrm <const> = yDlt * radiusCanvasInv

            local xCanvas <const> = i % wCanvas
            local xDlt <const> = xCanvas - xCenter
            local xNrm <const> = xDlt * radiusCanvasInv

            local sqMag <const> = xNrm * xNrm + yNrm * yNrm

            local byteStr = packZero
            if sqMag <= 1.0 then
                local radiansSigned <const> = atan2(yNrm, xNrm)
                local rSgnOffset <const> = radiansSigned + radiansOffset
                local rUnsigned <const> = rSgnOffset % tau
                local hue <const> = rUnsigned * oneTau
                -- If you want to support quantize, use signed q here.

                local mag <const> = sqrt(sqMag)
                local light <const> = useSat and 1.0 - mag or lightAxis
                local sat <const> = useSat and satAxis or mag
                -- If you want to support quantize, use unsigned q here.

                local r01 <const>, g01 <const>, b01 <const> = hslToRgb(
                    hue, sat, light)

                -- Values still go out of gamut, particularly for
                -- saturated blues at medium light.
                local r01cl = min(max(r01, 0), 1)
                local g01cl = min(max(g01, 0), 1)
                local b01cl = min(max(b01, 0), 1)

                local r8 <const> = floor(r01cl * 255 + 0.5)
                local g8 <const> = floor(g01cl * 255 + 0.5)
                local b8 <const> = floor(b01cl * 255 + 0.5)

                byteStr = strpack("B B B B", r8, g8, b8, 255)
            end -- End within circle.

            i = i + 1
            byteStrs[i] = byteStr
        end -- End image loop.

        active.byteStrCircle = table.concat(byteStrs)
        active.triggerCircleRepaint = false
    end -- End needs repaint.

    -- Draw picker canvas.
    local imgSpec <const> = ImageSpec {
        width = wCanvas,
        height = hCanvas,
        transparentColor = 0,
        colorMode = ColorMode.RGB
    }
    local img <const> = Image(imgSpec)
    img.bytes = active.byteStrCircle
    local drawRect <const> = Rectangle(0, 0, wCanvas, hCanvas)
    ctx:drawImage(img, drawRect, drawRect)

    local swatchSize <const> = defaults.swatchSize
    local offset <const> = swatchSize // 2

    local redBack <const> = active.redBack or 0.0
    local greenBack <const> = active.greenBack or 0.0
    local blueBack <const> = active.blueBack or 0.0
    local alphaBack <const> = active.alphaBack or 1.0

    local r8Back <const> = math.floor(redBack * 255 + 0.5)
    local g8Back <const> = math.floor(greenBack * 255 + 0.5)
    local b8Back <const> = math.floor(blueBack * 255 + 0.5)

    local redFore <const> = active.redFore or 0.0
    local greenFore <const> = active.greenFore or 0.0
    local blueFore <const> = active.blueFore or 0.0
    local alphaFore <const> = active.alphaFore or 1.0

    local r8Fore <const> = math.floor(redFore * 255 + 0.5)
    local g8Fore <const> = math.floor(greenFore * 255 + 0.5)
    local b8Fore <const> = math.floor(blueFore * 255 + 0.5)

    -- Draw background color swatch.
    ctx.color = Color { r = r8Back, g = g8Back, b = b8Back, a = 255 }
    ctx:fillRect(Rectangle(
        offset, hCanvas - swatchSize - 1,
        swatchSize, swatchSize))

    -- Draw foreground color swatch.
    ctx.color = Color { r = r8Fore, g = g8Fore, b = b8Fore, a = 255 }
    ctx:fillRect(Rectangle(
        0, hCanvas - swatchSize - 1 - offset,
        swatchSize, swatchSize))

    -- Draw reticle.
    local radiansActive <const> = hueActive * tau - radiansOffset
    local magActive <const> = useSat
        and 1.0 - lightActive
        or satActive
    local magCanvas <const> = magActive * radiusCanvas
    local xReticle <const> = xCenter + math.cos(radiansActive) * magCanvas
    local yReticle <const> = yCenter - math.sin(radiansActive) * magCanvas

    local reticleSize <const> = defaults.circleReticleSize
    local reticleHalf <const> = reticleSize // 2
    local reticleColor <const> = lightActive < 0.5
        and Color(255, 255, 255, 255)
        or Color(0, 0, 0, 255)
    ctx.color = reticleColor
    ctx.strokeWidth = defaults.circleReticleStroke
    ctx:strokeRect(Rectangle(
        xReticle - reticleHalf, yReticle - reticleHalf,
        reticleSize, reticleSize))

    -- Draw diagnostic text.
    if (wCanvas - hCanvas) > defaults.textDisplayLimit then
        local textSize <const> = ctx:measureText("E")
        local yIncr <const> = textSize.height + 4
        local textColor <const> = themeColors.text
        ctx.color = textColor

        if lightActive > 0.0
            and lightActive < 1.0 then
            if satActive > 0.0 then
                ctx:fillText(string.format(
                    "H: %.2f", hueActive * 360), 2, 2)
            end

            ctx:fillText(string.format(
                "S: %.2f%%", satActive * 100), 2, 2 + yIncr)
        end

        ctx:fillText(string.format(
            "L: %.2f%%", lightActive * 100), 2, 2 + yIncr * 2)

        local redActive <const> = useBack
            and redBack
            or redFore
        local greenActive <const> = useBack
            and greenBack
            or greenFore
        local blueActive <const> = useBack
            and blueBack
            or blueFore
        local alphaActive <const> = useBack
            and alphaBack
            or alphaFore

        ctx:fillText(string.format(
            "R: %.2f%%", redActive * 100), 2, 2 + yIncr * 4)
        ctx:fillText(string.format(
            "G: %.2f%%", greenActive * 100), 2, 2 + yIncr * 5)
        ctx:fillText(string.format(
            "B: %.2f%%", blueActive * 100), 2, 2 + yIncr * 6)
        ctx:fillText(string.format(
            "A: %.2f%%", alphaActive * 100), 2, 2 + yIncr * 8)

        local r8Active <const> = useBack and r8Back or r8Fore
        local g8Active <const> = useBack and g8Back or g8Fore
        local b8Active <const> = useBack and b8Back or b8Fore

        ctx:fillText(string.format(
            "#%06X", r8Active << 0x10|g8Active << 0x08|b8Active), 2, 2 + yIncr * 10)
    end
end

---@param r8 integer
---@param g8 integer
---@param b8 integer
---@param t8 integer
---@param useBack boolean
local function updateFromAse(r8, g8, b8, t8, useBack)
    local r01 <const>, g01 <const>, b01 <const> = r8 / 255.0, g8 / 255.0, b8 / 255.0
    local h <const>, s <const>, l <const> = ok_color.srgb_to_okhsl(r01, g01, b01)

    if l > 0.0 and l < 1.0 then
        if s > 0.0 then
            active[useBack and "hueBack" or "hueFore"] = h
        end
        active[useBack and "satBack" or "satFore"] = s
    end
    active[useBack and "lightBack" or "lightFore"] = l

    active[useBack and "redBack" or "redFore"] = r01
    active[useBack and "greenBack" or "greenFore"] = g01
    active[useBack and "blueBack" or "blueFore"] = b01
    active[useBack and "alphaBack" or "alphaFore"] = t8 / 255.0

    if not useBack then
        active.satAxis = s
        active.lightAxis = l
    end
end

local dlg <const> = Dialog { title = "OkHsl Color Picker" }

---@param event MouseEvent
local function onMouseMoveCircle(event)
    if event.button == MouseButton.NONE then return end

    local wCanvas <const> = active.wCanvasCircle
    local hCanvas <const> = active.hCanvasCircle
    if wCanvas <= 1 or hCanvas <= 1 then return end

    local xCenter <const> = wCanvas * 0.5
    local yCenter <const> = hCanvas * 0.5
    local shortEdge <const> = math.min(wCanvas, hCanvas)
    local radiusCanvas <const> = (shortEdge - 1.0) * 0.5
    local radiusCanvasInv <const> = 1.0 / radiusCanvas

    local yCanvas <const> = event.y
    local yDlt <const> = yCenter - yCanvas
    local yNrm <const> = yDlt * radiusCanvasInv

    local xCanvas <const> = event.x
    local xDlt <const> = xCanvas - xCenter
    local xNrm <const> = xDlt * radiusCanvasInv

    -- If sqMag is clamped to [epsilon, 1.0] instead of returning early,
    -- then this interferes with swapping the fore and background colors.
    -- However, a little grace is needed to move along the circumference.
    local sqMag <const> = xNrm * xNrm + yNrm * yNrm
    if sqMag < 0.00001 then return end
    if sqMag > 1.125 then return end

    local radiansOffset <const> = active.radiansOffset
    local useSat <const> = active.useSat
    local satAxis <const> = active.satAxis
    local lightAxis <const> = active.lightAxis

    local radiansSigned <const> = math.atan(yNrm, xNrm)
    local rSgnOffset <const> = radiansSigned + radiansOffset
    local rUnsigned <const> = rSgnOffset % tau
    local hueMouse <const> = rUnsigned * oneTau

    local mag <const> = math.sqrt(math.min(sqMag, 1.0))
    local lightMouse <const> = useSat and 1.0 - mag or lightAxis
    local satMouse <const> = useSat and satAxis or mag

    -- TODO: Use mouse button click. Assign to active use back.
    local useBack <const> = active.useBack

    active[useBack and "hueBack" or "hueFore"] = hueMouse
    active[useBack and "satBack" or "satFore"] = satMouse
    active[useBack and "lightBack" or "lightFore"] = lightMouse

    local r01 <const>, g01 <const>, b01 <const> = ok_color.okhsl_to_srgb(
        hueMouse, satMouse, lightMouse)

    -- Values still go out of gamut, particularly for
    -- saturated blues at medium light.
    local r01cl = math.min(math.max(r01, 0), 1)
    local g01cl = math.min(math.max(g01, 0), 1)
    local b01cl = math.min(math.max(b01, 0), 1)

    active[useBack and "redBack" or "redFore"] = r01cl
    active[useBack and "greenBack" or "greenFore"] = g01cl
    active[useBack and "blueBack" or "blueFore"] = b01cl

    local alphaActive <const> = useBack
        and active.alphaBack
        or active.alphaFore

    local r8 <const> = math.floor(r01cl * 255 + 0.5)
    local g8 <const> = math.floor(g01cl * 255 + 0.5)
    local b8 <const> = math.floor(b01cl * 255 + 0.5)
    local a8 <const> = math.floor(alphaActive * 255 + 0.5)

    if useBack then
        app.command.SwitchColors()
        app.fgColor = Color { r = r8, g = g8, b = b8, a = a8 }
        app.command.SwitchColors()
    else
        app.fgColor = Color { r = r8, g = g8, b = b8, a = a8 }
    end

    active.triggerAxisRepaint = true
    dlg:repaint()
end

---@param event MouseEvent
local function onMouseUpCircle(event)
    local xMouseUp <const> = event.x
    local yMouseUp <const> = event.y

    local swatchSize <const> = defaults.swatchSize
    local offset <const> = swatchSize // 2
    local hCanvas <const> = active.hCanvasCircle
    if xMouseUp >= 0 and xMouseUp < offset + swatchSize
        and yMouseUp >= hCanvas - swatchSize - 1 - offset
        and yMouseUp < hCanvas then
        local hTemp <const> = active.hueBack
        local sTemp <const> = active.satBack
        local lTemp <const> = active.lightBack

        local rTemp <const> = active.redBack
        local gTemp <const> = active.greenBack
        local bTemp <const> = active.blueBack

        local aTemp <const> = active.alphaBack

        active.hueBack = active.hueFore
        active.satBack = active.satFore
        active.lightBack = active.lightFore

        active.redBack = active.redFore
        active.greenBack = active.greenFore
        active.blueBack = active.blueFore

        active.alphaBack = active.alphaFore

        active.hueFore = hTemp
        active.satFore = sTemp
        active.lightFore = lTemp

        active.redFore = rTemp
        active.greenFore = gTemp
        active.blueFore = bTemp

        active.alphaFore = aTemp

        active.lightAxis = lTemp
        active.satAxis = sTemp

        active.triggerAxisRepaint = true
        active.triggerCircleRepaint = true
        active.triggerAlphaRepaint = true
        dlg:repaint()

        app.fgColor = Color {
            r = math.floor(active.redFore * 255 + 0.5),
            g = math.floor(active.greenFore * 255 + 0.5),
            b = math.floor(active.blueFore * 255 + 0.5),
            a = 255
        }
        app.command.SwitchColors()
        app.fgColor = Color {
            r = math.floor(active.redBack * 255 + 0.5),
            g = math.floor(active.greenBack * 255 + 0.5),
            b = math.floor(active.blueBack * 255 + 0.5),
            a = 255
        }
        app.command.SwitchColors()
    end
end

dlg:canvas {
    id = "circleCanvas",
    focus = true,
    width = defaults.wCanvas,
    height = defaults.hCanvasCircle,
    onmousedown = onMouseMoveCircle,
    onmousemove = onMouseMoveCircle,
    onmouseup = onMouseUpCircle,
    onpaint = onPaintCircle,
}

dlg:newrow { always = false }

dlg:canvas {
    id = "axisCanvas",
    focus = false,
    width = defaults.wCanvas,
    height = defaults.hCanvasAxis,
    onpaint = onPaintAxis,
}

dlg:newrow { always = false }

dlg:button {
    id = "getForeButton",
    text = defaults.foreKey,
    onclick = function()
        local fgColor <const> = app.fgColor
        local r8fg <const> = fgColor.red
        local g8fg <const> = fgColor.green
        local b8fg <const> = fgColor.blue
        local t8fg <const> = fgColor.alpha

        updateFromAse(r8fg, g8fg, b8fg, t8fg, false)
        active.triggerCircleRepaint = true
        active.triggerAxisRepaint = true
        active.triggerAlphaRepaint = true
        dlg:repaint()
    end
}

dlg:button {
    id = "getBackButton",
    text = defaults.backKey,
    onclick = function()
        app.command.SwitchColors()
        local bgColor <const> = app.fgColor
        local r8bg <const> = bgColor.red
        local g8bg <const> = bgColor.green
        local b8bg <const> = bgColor.blue
        local t8bg <const> = bgColor.alpha
        app.command.SwitchColors()

        updateFromAse(r8bg, g8bg, b8bg, t8bg, true)
        active.triggerCircleRepaint = true
        active.triggerAxisRepaint = true
        active.triggerAlphaRepaint = true
        dlg:repaint()
    end
}

dlg:button {
    id = "canvasButton",
    text = defaults.canvasKey,
    onclick = function()
    end
}

dlg:button {
    id = "exitButton",
    text = defaults.closeKey,
    onclick = function()
        dlg:close()
    end
}

do
    local fgColor <const> = app.fgColor
    local r8fg <const> = fgColor.red
    local g8fg <const> = fgColor.green
    local b8fg <const> = fgColor.blue
    local t8fg <const> = fgColor.alpha
    updateFromAse(r8fg, g8fg, b8fg, t8fg, false)

    app.command.SwitchColors()
    local bgColor <const> = app.fgColor
    local r8bg <const> = bgColor.red
    local g8bg <const> = bgColor.green
    local b8bg <const> = bgColor.blue
    local t8bg <const> = bgColor.alpha
    app.command.SwitchColors()
    updateFromAse(r8bg, g8bg, b8bg, t8bg, true)

    active.triggerCircleRepaint = true
    active.triggerAxisRepaint = true
    active.triggerAlphaRepaint = true

    dlg:repaint()
end

dlg:show {
    autoscrollbars = false,
    wait = false
}