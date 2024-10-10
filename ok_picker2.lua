dofile("./ok_color.lua")

local axes <const> = { "LIGHTNESS", "SATURATION" }

local tau <const> = 6.2831853071796
local oneTau <const> = 0.1591549430919

local defaults <const> = {
    -- TODO: Account for screen scale?
    -- TODO: Make a shades/harmonies canvas. Then have a button in the bottom
    -- row which cycles through them: none, shades, complement, etc.
    wCanvas = 180,
    hCanvasCircle = 180,
    hCanvasAxis = 12,
    hCanvasAlpha = 12,

    aCheck = 0.5,
    bCheck = 0.8,
    wCheck = 6,
    hCheck = 6,

    reticleSize = 8,
    reticleStroke = 2,
    swatchSize = 17,
    textDisplayLimit = 50,
    radiansOffset = math.rad(60),

    useBack = false,
    useSat = false,
    satAxis = 1.0,
    lightAxis = 0.5,

    foreKey = "&FORE",
    backKey = "&BACK",
    -- optionsKey = "&OPTIONS",
    optionsKey = "&+",
    sampleKey = "S&AMPLE",
    closeKey = "&X",
}

local active <const> = {
    radiansOffset = defaults.radiansOffset,
    useSat = defaults.useSat,
    showSampleButton = true,
    showForeButton = true,
    showBackButton = true,

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
local function onPaintAlpha(event)
    local ctx <const> = event.context
    ctx.antialias = false
    ctx.blendMode = BlendMode.SRC

    local wCanvas <const> = ctx.width
    local hCanvas <const> = ctx.height
    if wCanvas <= 1 or hCanvas <= 1 then return end

    local useBack <const> = active.useBack

    local alphaActive <const> = useBack
        and active.alphaBack
        or active.alphaFore

    local needsRepaint <const> = active.triggerAlphaRepaint
        or active.wCanvasAlpha ~= wCanvas
        or active.hCanvasAlpha ~= hCanvas

    active.wCanvasAlpha = wCanvas
    active.hCanvasAlpha = hCanvas

    if needsRepaint then
        ---@type string[]
        local byteStrs <const> = {}

        local strpack <const> = string.pack
        local floor <const> = math.floor

        local redActive <const> = useBack
            and active.redBack
            or active.redFore
        local greenActive <const> = useBack
            and active.greenBack
            or active.greenFore
        local blueActive <const> = useBack
            and active.blueBack
            or active.blueFore

        local wCheck <const> = defaults.wCheck
        local hCheck <const> = defaults.hCheck
        -- local aCheck <const> = 0x80 / 0xff
        -- local bCheck <const> = 0xca / 0xff
        local aCheck <const> = defaults.aCheck
        local bCheck <const> = defaults.bCheck
        local xToFac <const> = 1.0 / (wCanvas - 1.0)

        local lenCanvas <const> = wCanvas * hCanvas
        local i = 0
        while i < lenCanvas do
            local y <const> = i // wCanvas
            local x <const> = i % wCanvas
            local t <const> = x * xToFac

            local cCheck = bCheck
            if (((x // wCheck) + (y // hCheck)) % 2) ~= 1 then
                cCheck = aCheck
            end

            local ucCheck <const> = (1.0 - t) * cCheck
            local rMix <const> = ucCheck + t * redActive
            local gMix <const> = ucCheck + t * greenActive
            local bMix <const> = ucCheck + t * blueActive

            local r8 <const> = floor(rMix * 255 + 0.5)
            local g8 <const> = floor(gMix * 255 + 0.5)
            local b8 <const> = floor(bMix * 255 + 0.5)

            local byteStr <const> = strpack("B B B B", r8, g8, b8, 255)

            i = i + 1
            byteStrs[i] = byteStr
        end -- End image loop.

        active.byteStrAlpha = table.concat(byteStrs)
        active.triggerAlphaRepaint = false
    end -- End needs repaint.

    -- Draw alpha canvas.
    local imgSpec <const> = ImageSpec {
        width = wCanvas,
        height = hCanvas,
        transparentColor = 0,
        colorMode = ColorMode.RGB
    }
    local img <const> = Image(imgSpec)
    img.bytes = active.byteStrAlpha
    local drawRect <const> = Rectangle(0, 0, wCanvas, hCanvas)
    ctx:drawImage(img, drawRect, drawRect)

    local xReticle <const> = math.floor(alphaActive * (wCanvas - 1.0) + 0.5)
    local yReticle <const> = hCanvas // 2

    local reticleSize <const> = defaults.reticleSize
    local reticleHalf <const> = reticleSize // 2
    local reticleColor <const> = Color(255, 255, 255, 255)
    ctx.color = reticleColor
    ctx.strokeWidth = defaults.reticleStroke
    ctx:strokeRect(Rectangle(
        xReticle - reticleHalf, yReticle - reticleHalf,
        reticleSize, reticleSize))
end

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
    local xReticle <const> = math.floor(x01 * (wCanvas - 1.0) + 0.5)
    local yReticle <const> = hCanvas // 2

    local reticleSize <const> = defaults.reticleSize
    local reticleHalf <const> = reticleSize // 2
    local comparisand <const> = useSat and lightActive or lightAxis
    local reticleColor <const> = comparisand < 0.5
        and Color(255, 255, 255, 255)
        or Color(0, 0, 0, 255)
    ctx.color = reticleColor
    ctx.strokeWidth = defaults.reticleStroke
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

    local redBack <const> = active.redBack
    local greenBack <const> = active.greenBack
    local blueBack <const> = active.blueBack
    local alphaBack <const> = active.alphaBack

    local r8Back <const> = math.floor(redBack * 255 + 0.5)
    local g8Back <const> = math.floor(greenBack * 255 + 0.5)
    local b8Back <const> = math.floor(blueBack * 255 + 0.5)

    local redFore <const> = active.redFore
    local greenFore <const> = active.greenFore
    local blueFore <const> = active.blueFore
    local alphaFore <const> = active.alphaFore

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

    local reticleSize <const> = defaults.reticleSize
    local reticleHalf <const> = reticleSize // 2
    local reticleColor <const> = lightActive < 0.5
        and Color(255, 255, 255, 255)
        or Color(0, 0, 0, 255)
    ctx.color = reticleColor
    ctx.strokeWidth = defaults.reticleStroke
    ctx:strokeRect(Rectangle(
        xReticle - reticleHalf, yReticle - reticleHalf,
        reticleSize, reticleSize))

    -- Draw diagnostic text.
    if (wCanvas - hCanvas) > defaults.textDisplayLimit then
        -- TODO: Display OK LAB values?

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

        ctx:fillText(string.format("#%06X",
                r8Active << 0x10|g8Active << 0x08|b8Active),
            2, 2 + yIncr * 10)
    end
end

---@param r8 integer
---@param g8 integer
---@param b8 integer
---@param t8 integer
---@param useBack boolean
local function updateFromAse(r8, g8, b8, t8, useBack)
    local r01 <const>,
    g01 <const>,
    b01 <const> = r8 / 255.0, g8 / 255.0, b8 / 255.0
    local h <const>,
    s <const>,
    l <const> = ok_color.srgb_to_okhsl(r01, g01, b01)

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

local dlgMain <const> = Dialog { title = "OkHsl Color Picker" }

local dlgOptions <const> = Dialog {
    title = "Options",
    parent = dlgMain
}

local function getFromCanvas()
    local editor <const> = app.editor
    if not editor then return end

    local sprite <const> = app.sprite
    if not sprite then return end

    local frame <const> = app.frame or sprite.frames[1]

    local mouse <const> = editor.spritePos
    local x = mouse.x
    local y = mouse.y

    local docPrefs <const> = app.preferences.document(sprite)
    local tiledMode <const> = docPrefs.tiled.mode

    if tiledMode == 3 then
        -- Tiling on both axes.
        x = x % sprite.width
        y = y % sprite.height
    elseif tiledMode == 2 then
        -- Vertical tiling.
        y = y % sprite.height
    elseif tiledMode == 1 then
        -- Horizontal tiling.
        x = x % sprite.width
    end

    local spriteSpec <const> = sprite.spec
    local colorMode <const> = spriteSpec.colorMode
    local alphaIndex <const> = spriteSpec.transparentColor
    local mouseSpec <const> = ImageSpec {
        width = 1,
        height = 1,
        colorMode = colorMode,
        transparentColor = alphaIndex
    }
    mouseSpec.colorSpace = spriteSpec.colorSpace
    local flat <const> = Image(mouseSpec)
    flat:drawSprite(sprite, frame, Point(-x, -y))
    local bpp <const> = flat.bytesPerPixel
    local bytes <const> = flat.bytes
    local pixel <const> = string.unpack("<I" .. bpp, bytes)

    -- print(string.format("x: %d, y: %d, p: %x", x, y, pixel))

    local r8, g8, b8, t8 = 0, 0, 0, 0
    if colorMode == ColorMode.INDEXED then
        local hasBkg <const> = sprite.backgroundLayer ~= nil
            and sprite.backgroundLayer.isVisible
        local palette <const> = sprite.palettes[1]
        local lenPalette <const> = #palette
        if (hasBkg or pixel ~= alphaIndex)
            and pixel >= 0 and pixel < lenPalette then
            local aseColor <const> = palette:getColor(pixel)
            r8 = aseColor.red
            g8 = aseColor.green
            b8 = aseColor.blue
            t8 = aseColor.alpha
        end
    elseif colorMode == ColorMode.GRAY then
        local v8 <const> = pixel >> 0x00 & 0xff
        r8, g8, b8 = v8, v8, v8
        t8 = pixel >> 0x08 & 0xff
    else
        r8 = pixel >> 0x00 & 0xff
        g8 = pixel >> 0x08 & 0xff
        b8 = pixel >> 0x10 & 0xff
        t8 = pixel >> 0x18 & 0xff
    end

    if t8 > 0 then
        updateFromAse(r8, g8, b8, t8, false)
        active.triggerAlphaRepaint = true
        active.triggerAxisRepaint = true
        active.triggerCircleRepaint = true
        dlgMain:repaint()
        app.fgColor = Color { r = r8, g = g8, b = b8, a = t8 }
    end
end

---@param event MouseEvent
local function onMouseMoveAlpha(event)
    if event.button == MouseButton.NONE then return end

    local wCanvas <const> = active.wCanvasAxis
    local hCanvas <const> = active.hCanvasAxis
    if wCanvas <= 1 or hCanvas <= 1 then return end

    local xCanvas <const> = math.min(math.max(event.x, 0), wCanvas - 1)
    local xNrm <const> = event.ctrlKey
        and 1.0
        or xCanvas / (wCanvas - 1.0)

    -- TODO: Use mouse button click. Assign to active use back.
    local useBack <const> = active.useBack
    active[useBack and "alphaBack" or "alphaFore"] = xNrm

    local redActive <const> = useBack
        and active.redBack
        or active.redFore
    local greenActive <const> = useBack
        and active.greenBack
        or active.greenFore
    local blueActive <const> = useBack
        and active.blueBack
        or active.blueFore

    local r8 <const> = math.floor(redActive * 255 + 0.5)
    local g8 <const> = math.floor(greenActive * 255 + 0.5)
    local b8 <const> = math.floor(blueActive * 255 + 0.5)
    local a8 <const> = math.floor(xNrm * 255 + 0.5)

    if useBack then
        app.command.SwitchColors()
        app.fgColor = Color { r = r8, g = g8, b = b8, a = a8 }
        app.command.SwitchColors()
    else
        app.fgColor = Color { r = r8, g = g8, b = b8, a = a8 }
    end

    dlgMain:repaint()
end

---@param event MouseEvent
local function onMouseMoveAxis(event)
    if event.button == MouseButton.NONE then return end

    local wCanvas <const> = active.wCanvasAxis
    local hCanvas <const> = active.hCanvasAxis
    if wCanvas <= 1 or hCanvas <= 1 then return end

    local useSat <const> = active.useSat
    local xCanvas <const> = math.min(math.max(event.x, 0), wCanvas - 1)
    local xNrm <const> = event.ctrlKey
        and (useSat and 1.0 or 0.5)
        or xCanvas / (wCanvas - 1.0)

    -- TODO: Use mouse button click. Assign to active use back.
    local useBack <const> = active.useBack

    if useSat then
        active.satAxis = xNrm
        active[useBack and "satBack" or "satFore"] = xNrm
    else
        active.lightAxis = xNrm
        active[useBack and "lightBack" or "lightFore"] = xNrm
    end

    -- TODO: Much of this can become its own function hsl->rgb32
    local hActive <const> = useBack and active.hueBack or active.hueFore
    local sActive <const> = useBack and active.satBack or active.satFore
    local lActive <const> = useBack and active.lightBack or active.lightFore
    local r01 <const>, g01 <const>, b01 <const> = ok_color.okhsl_to_srgb(
        hActive, sActive, lActive)

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

    active.triggerCircleRepaint = true
    active.triggerAlphaRepaint = true
    dlgMain:repaint()
end

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
    local yNrm <const> = event.ctrlKey
        and 0.0
        or yDlt * radiusCanvasInv

    local xCanvas <const> = event.x
    local xDlt <const> = xCanvas - xCenter
    local xNrm <const> = event.ctrlKey
        and 0.0
        or xDlt * radiusCanvasInv

    -- If sqMag is clamped to [epsilon, 1.0] instead of returning early,
    -- then this interferes with swapping the fore and background colors.
    -- However, a little grace is needed to move along the circumference.
    local sqMag <const> = xNrm * xNrm + yNrm * yNrm

    if sqMag < 0.0 then return end
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
    active.triggerAlphaRepaint = true
    dlgMain:repaint()
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

        active.triggerAlphaRepaint = true
        active.triggerAxisRepaint = true
        active.triggerCircleRepaint = true
        dlgMain:repaint()

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

dlgMain:canvas {
    id = "circleCanvas",
    focus = true,
    width = defaults.wCanvas,
    height = defaults.hCanvasCircle,
    onmousedown = onMouseMoveCircle,
    onmousemove = onMouseMoveCircle,
    onmouseup = onMouseUpCircle,
    onpaint = onPaintCircle,
}

dlgMain:newrow { always = false }

dlgMain:canvas {
    id = "axisCanvas",
    focus = false,
    width = defaults.wCanvas,
    height = defaults.hCanvasAxis,
    onmousedown = onMouseMoveAxis,
    onmousemove = onMouseMoveAxis,
    onpaint = onPaintAxis,
}

dlgMain:newrow { always = false }

dlgMain:canvas {
    id = "alphaCanvas",
    focus = false,
    width = defaults.wCanvas,
    height = defaults.hCanvasAlpha,
    onmousedown = onMouseMoveAlpha,
    onmousemove = onMouseMoveAlpha,
    onpaint = onPaintAlpha,
}

dlgMain:newrow { always = false }

dlgMain:button {
    id = "getForeButton",
    text = defaults.foreKey,
    visible = true,
    focus = false,
    onclick = function()
        local fgColor <const> = app.fgColor
        local r8fg <const> = fgColor.red
        local g8fg <const> = fgColor.green
        local b8fg <const> = fgColor.blue
        local t8fg <const> = fgColor.alpha

        updateFromAse(r8fg, g8fg, b8fg, t8fg, false)
        active.triggerAlphaRepaint = true
        active.triggerAxisRepaint = true
        active.triggerCircleRepaint = true
        dlgMain:repaint()
    end
}

dlgMain:button {
    id = "getBackButton",
    text = defaults.backKey,
    visible = true,
    focus = false,
    onclick = function()
        app.command.SwitchColors()
        local bgColor <const> = app.fgColor
        local r8bg <const> = bgColor.red
        local g8bg <const> = bgColor.green
        local b8bg <const> = bgColor.blue
        local t8bg <const> = bgColor.alpha
        app.command.SwitchColors()

        updateFromAse(r8bg, g8bg, b8bg, t8bg, true)
        active.triggerAlphaRepaint = true
        active.triggerAxisRepaint = true
        active.triggerCircleRepaint = true
        dlgMain:repaint()
    end
}

dlgMain:button {
    id = "sampleButton",
    text = defaults.sampleKey,
    focus = false,
    onclick = getFromCanvas
}

dlgMain:button {
    id = "optionsButton",
    text = defaults.optionsKey,
    focus = false,
    onclick = function()
        dlgOptions:show { autoscrollbars = true, wait = true }
    end
}

dlgMain:button {
    id = "exitMainButton",
    text = defaults.closeKey,
    focus = false,
    onclick = function()
        dlgMain:close()
    end
}

dlgOptions:slider {
    id = "degreesOffset",
    label = "Angle:",
    value = 300,
    min = 0,
    max = 360,
    focus = false,
}

dlgOptions:newrow { always = false }

dlgOptions:combobox {
    id = "axis",
    label = "Axis:",
    option = "LIGHTNESS",
    options = axes,
    focus = false
}

dlgOptions:newrow { always = false }

dlgOptions:check {
    id = "showFore",
    label = "Buttons:",
    text = "Fore",
    selected = true
}

dlgOptions:check {
    id = "showBack",
    text = "Back",
    selected = true
}

dlgOptions:check {
    id = "showSample",
    text = "Sample",
    selected = true
}

dlgOptions:newrow { always = false }

dlgOptions:button {
    id = "confirmOptionsButton",
    text = "&OK",
    focus = false,
    onclick = function()
        local args <const> = dlgOptions.data
        local degreesOffset <const> = args.degreesOffset --[[@as integer]]
        local axis <const> = args.axis --[[@as string]]
        local showFore <const> = args.showFore --[[@as boolean]]
        local showBack <const> = args.showBack --[[@as boolean]]
        local showSample <const> = args.showSample --[[@as boolean]]

        local oldRadiansOffset <const> = active.radiansOffset
        local oldUseSat <const> = active.useSat

        active.radiansOffset = (-math.rad(degreesOffset)) % tau
        active.useSat = axis == "SATURATION"

        if oldUseSat ~= active.useSat
            or oldRadiansOffset ~= active.radiansOffset then
            active.triggerAlphaRepaint = true
            active.triggerAxisRepaint = true
            active.triggerCircleRepaint = true
        end

        dlgMain:repaint()

        dlgMain:modify { id = "getForeButton", visible = showFore }
        dlgMain:modify { id = "getBackButton", visible = showBack }
        dlgMain:modify { id = "sampleButton", visible = showSample }

        dlgOptions:close()
    end
}

dlgOptions:button {
    id = "exitOptionsButton",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlgOptions:close()
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

    active.triggerAlphaRepaint = true
    active.triggerAxisRepaint = true
    active.triggerCircleRepaint = true
    dlgMain:repaint()
end

dlgMain:show {
    autoscrollbars = false,
    wait = false
}