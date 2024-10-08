dofile("./ok_color.lua")

local tau <const> = 6.2831853071796
local oneTau <const> = 0.1591549430919

local defaults <const> = {
    -- TODO: Account for screen scale?
    wheelReticleSize = 8,
    wheelReticleStroke = 2,
    wCanvasWheel = 180,
    hCanvasWheel = 180,
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
    wCanvasWheel = defaults.wCanvasWheel,
    hCanvasWheel = defaults.hCanvasWheel,
    radiansOffset = defaults.radiansOffset,
    triggerWheelRepaint = true,
    byteStrWheel = "",

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
local function onPaintWheel(event)
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

    local needsRepaint <const> = active.triggerWheelRepaint
        or active.wCanvasWheel ~= wCanvas
        or active.hCanvasWheel ~= hCanvas
        or (useSat and satAxis ~= satActive
            or lightAxis ~= lightActive)
    active.wCanvasWheel = wCanvas
    active.hCanvasWheel = hCanvas

    local xCenter <const> = wCanvas * 0.5
    local yCenter <const> = hCanvas * 0.5
    local shortEdge <const> = math.min(wCanvas, hCanvas)
    -- local diamCanvas <const> = shortEdge - 1.0
    local radiusCanvas <const> = (shortEdge - 1.0) * 0.5

    local themeColors <const> = app.theme.color
    local radiansOffset <const> = active.radiansOffset

    if needsRepaint then
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

        ---@type string[]
        local byteStrs <const> = {}
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

        active.byteStrWheel = table.concat(byteStrs)
        active.triggerWheelRepaint = false
    end

    -- Draw picker canvas.
    local imgSpec <const> = ImageSpec {
        width = wCanvas,
        height = hCanvas,
        transparentColor = 0,
        colorMode = ColorMode.RGB
    }
    local img <const> = Image(imgSpec)
    img.bytes = active.byteStrWheel
    local drawRect <const> = Rectangle(0, 0, wCanvas, hCanvas)
    ctx:drawImage(img, drawRect, drawRect)

    -- Draw reticle.
    local radiansActive <const> = hueActive * tau - radiansOffset
    local magActive <const> = useSat
        and 1.0 - lightActive
        or satActive
    local magCanvas <const> = magActive * radiusCanvas
    local xReticle <const> = xCenter + math.cos(radiansActive) * magCanvas
    local yReticle <const> = yCenter - math.sin(radiansActive) * magCanvas

    local reticleSize <const> = defaults.wheelReticleSize
    local reticleHalf <const> = reticleSize // 2
    local reticleColor <const> = lightActive < 0.5
        and Color(255, 255, 255, 255)
        or Color(0, 0, 0, 255)
    ctx.color = reticleColor
    ctx.strokeWidth = defaults.wheelReticleStroke
    ctx:strokeRect(Rectangle(
        xReticle - reticleHalf, yReticle - reticleHalf,
        reticleSize, reticleSize))

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

local dlg <const> = Dialog { title = "OkHsl Color Picker" }

---@param event KeyEvent
local function onKeyDownWheel(event)
end

---@param event MouseEvent
local function onMouseDownWheel(event)
end

---@param event MouseEvent
local function onMouseMoveWheel(event)
    if event.button == MouseButton.NONE then return end

    local wCanvas <const> = active.wCanvasWheel
    local hCanvas <const> = active.hCanvasWheel
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

    local sqMag <const> = math.min(math.max(
        xNrm * xNrm + yNrm * yNrm, 0.00001), 1.0)

    local radiansOffset <const> = active.radiansOffset
    local useSat <const> = active.useSat
    local satAxis <const> = active.satAxis
    local lightAxis <const> = active.lightAxis

    local radiansSigned <const> = math.atan(yNrm, xNrm)
    local rSgnOffset <const> = radiansSigned + radiansOffset
    local rUnsigned <const> = rSgnOffset % tau
    local hueMouse <const> = rUnsigned * oneTau

    local mag <const> = math.sqrt(sqMag)
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

    dlg:repaint()
end

---@param event MouseEvent
local function onMouseUpWheel(event)
end

dlg:canvas {
    id = "wheelCanvas",
    focus = true,
    width = defaults.wCanvasWheel,
    height = defaults.hCanvasWheel,
    onkeydown = onKeyDownWheel,
    onmousedown = onMouseDownWheel,
    onmousemove = onMouseMoveWheel,
    onmouseup = onMouseUpWheel,
    onpaint = onPaintWheel,
}

dlg:newrow { always = false }

dlg:button {
    id = "getForeButton",
    text = defaults.foreKey,
    onclick = function()
    end
}

dlg:button {
    id = "getBackButton",
    text = defaults.backKey,
    onclick = function()
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
    -- TODO: Initialize picker fore and back color
    -- from Aseprite fore and back color.
end

dlg:show {
    autoscrollbars = false,
    wait = false
}