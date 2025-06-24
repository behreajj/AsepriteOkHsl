dofile("./ok_color.lua")

-- Copyright(c) 2021 Bjorn Ottosson
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files(the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and /or sell copies
-- of the Software, and to permit persons to whom the Software is furnished to do
-- so, subject to the following conditions:
--
-- The above copyright noticeand this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

local axes <const> = { "LIGHTNESS", "SATURATION" }
local harmonyTypes <const> = {
    "ANALOGOUS",
    "COMPLEMENT",
    "NONE",
    "SHADING",
    "SPLIT",
    "SQUARE",
    "TETRADIC",
    "TRIADIC"
}
local huePresets <const> = { "CCW", "CW", "FAR", "NEAR" }

local tau <const> = 6.2831853071796
local oneTau <const> = 0.1591549430919
local sqrt32 <const> = 0.86602540378444

local abs <const> = math.abs
local ceil <const> = math.ceil
local floor <const> = math.floor
local max <const> = math.max
local min <const> = math.min

local screenScale = 1
if app.preferences then
    local generalPrefs <const> = app.preferences.general
    if generalPrefs then
        local ssCand <const> = generalPrefs.screen_scale --[[@as integer]]
        if ssCand and ssCand > 0 then
            screenScale = ssCand
        end
    end
end

local defaults <const> = {
    -- TODO: Allow for keyboard movement to handle multiple simultaneous
    -- key presses for diagonals?

    wCanvas = max(16, 350 // screenScale),
    hCanvasAxis = max(6, 12 // screenScale),
    hCanvasAlpha = max(6, 12 // screenScale),
    hCanvasCircle = max(16, 200 // screenScale),
    hCanvasHarmony = max(6, 12 // screenScale),

    aCheck = 0.5, -- 0x80 / 0xff
    bCheck = 0.8, -- 0xca / 0xff
    wCheck = max(1, 6 // screenScale),
    hCheck = max(1, 6 // screenScale),

    reticleSize = max(3, 8 // screenScale),
    reticleStroke = max(1, 1 // screenScale),
    harmonyReticleSize = max(2, 4 // screenScale),
    harmonyReticleStroke = 1,
    swatchSize = max(4, 17 // screenScale),
    swatchMargin = max(3, 6 // screenScale),
    textDisplayLimit = 50,
    radiansOffset = math.rad(60),

    useSat = false,
    satAxis = 1.0,
    lightAxis = 0.5,

    harmonyType = "NONE",
    showHarmonyOnWheel = true,

    shadingCount = 7,
    shadowLight = 0.1,
    dayLight = 0.9,
    shadowHue = 291.0 / 360.0,
    dayHue = 96.0 / 360.0,
    hYel = 109.79 / 360.0,
    srcLightWeight = 0.3333333333333333,
    greenHue = 146.0 / 360.0,
    minGreenOffset = 0.3,
    maxGreenOffset = 0.6,
    minChroma = 0.01,
    lgtDesatFac = 0.75,
    shdDesatFac = 0.75,

    foreKey = "FO&RE",
    backKey = "&BACK",
    palAppendKey = "&!",
    sampleKey = "S&AMPLE",
    gradientKey = "&GRADIENT",
    optionsKey = "&+",
    exitKey = "&X",

    showForeButton = true,
    showBackButton = true,
    showPalAppendButton = false,
    showSampleButton = false,
    showGradientButton = false,
    showExitButton = true,

    swatchCount = 5,
    huePreset = "NEAR",

    -- For unsigned quantize levels, add one.
    keyShiftAmount = 0.01,
    hLevels = 24,
    sLevels = 13,
    lLevels = 13,
    axisLevels = 21,
}

local active <const> = {
    radiansOffset = defaults.radiansOffset,
    useSat = defaults.useSat,

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

    wCanvasHarmony = defaults.wCanvas,
    hCanvasHarmony = defaults.hCanvasHarmony,
    triggerHarmonyRepaint = false,
    byteStrHarmony = "",
    harmonyType = defaults.harmonyType,
    showHarmonyOnWheel = defaults.showHarmonyOnWheel,
    shadingCount = defaults.shadingCount,

    satAxis = defaults.satAxis,
    lightAxis = defaults.lightAxis,

    hueFore = 0.0,
    satFore = 0.0,
    lightFore = 1.0,

    redFore = 1.0,
    greenFore = 1.0,
    blueFore = 1.0,

    alphaFore = 1.0,

    hueBack = 0.0,
    satBack = 0.0,
    lightBack = 0.0,

    redBack = 0.0,
    greenBack = 0.0,
    blueBack = 0.0,

    alphaBack = 1.0,

    hLevels = defaults.hLevels,
    sLevels = defaults.sLevels,
    lLevels = defaults.lLevels,
    axisLevels = defaults.axisLevels,
}

---@param a number value
---@param levels number levels
---@param delta number inverse levels
---@return number
---@nodiscard
local function quantizeSignedInternal(a, levels, delta)
    return floor(0.5 + a * levels) * delta
end

---@param a number value
---@param levels number levels
---@return number
---@nodiscard
local function quantizeSigned(a, levels)
    if levels ~= 0 then
        return quantizeSignedInternal(
            a, levels, 1.0 / levels)
    end
    return a
end

---@param a number value
---@param levels number levels
---@param delta number inverse levels
---@return number
---@nodiscard
local function quantizeUnsignedInternal(a, levels, delta)
    return max(0.0, (ceil(a * levels) - 1.0) * delta)
end

---@param a number value
---@param levels number levels
---@return number
---@nodiscard
local function quantizeUnsigned(a, levels)
    if levels > 1 then
        return quantizeUnsignedInternal(
            a, levels, 1.0 / (levels - 1.0))
    end
    return max(0.0, a)
end

---@param a number
---@param b number
---@param range number
---@return number
---@nodiscard
local function distAngleUnsigned(a, b, range)
    local halfRange <const> = range * 0.5
    return halfRange - abs(abs(
            (b % range) - (a % range))
        - halfRange)
end

---@param orig number origin angle
---@param dest number destination angle
---@param t number factor
---@param range number? range
---@return number
---@nodiscard
local function lerpAngleCcw(orig, dest, t, range)
    local valRange <const> = range or 360.0
    local o <const> = orig % valRange
    local d <const> = dest % valRange
    local diff <const> = d - o
    if diff == 0.0 then return o end

    local u <const> = 1.0 - t
    if o > d then
        return (u * o + t * (d + valRange)) % valRange
    else
        return u * o + t * d
    end
end

---@param orig number origin angle
---@param dest number destination angle
---@param t number factor
---@param range number? range
---@return number
---@nodiscard
local function lerpAngleCw(orig, dest, t, range)
    local valRange <const> = range or 360.0
    local o <const> = orig % valRange
    local d <const> = dest % valRange
    local diff <const> = d - o
    if diff == 0.0 then return d end

    local u <const> = 1.0 - t
    if o < d then
        return (u * (o + valRange) + t * d) % valRange
    else
        return u * o + t * d
    end
end

---@param orig number origin angle
---@param dest number destination angle
---@param t number factor
---@param range number? range
---@return number
---@nodiscard
local function lerpAngleFar(orig, dest, t, range)
    local valRange <const> = range or 360.0
    local halfRange <const> = valRange * 0.5
    local o <const> = orig % valRange
    local d <const> = dest % valRange
    local diff <const> = d - o
    local u <const> = 1.0 - t

    if diff == 0.0 or (o < d and diff < halfRange) then
        return (u * (o + valRange) + t * d) % valRange
    elseif o > d and diff > -halfRange then
        return (u * o + t * (d + valRange)) % valRange
    else
        return u * o + t * d
    end
end

---@param orig number origin angle
---@param dest number destination angle
---@param t number factor
---@param range number? range
---@return number
---@nodiscard
local function lerpAngleNear(orig, dest, t, range)
    local valRange <const> = range or 360.0
    local o <const> = orig % valRange
    local d <const> = dest % valRange
    local diff <const> = d - o
    if diff == 0.0 then return o end

    local u <const> = 1.0 - t
    local halfRange <const> = valRange * 0.5
    if o < d and diff > halfRange then
        return (u * (o + valRange) + t * d) % valRange
    elseif o > d and diff < -halfRange then
        return (u * o + t * (d + valRange)) % valRange
    else
        return u * o + t * d
    end
end

---@param t number
---@return number
---@nodiscard
local function zigZag(t)
    local a <const> = t * 0.5
    local b <const> = a - floor(a)
    return 1.0 - abs(b + b - 1.0)
end

---@param h number hue
---@param s number saturation
---@param l number lightness
---@return integer r8
---@return integer g8
---@return integer b8
---@return number r01
---@return number g01
---@return number b01
local function okhslToRgb24(h, s, l)
    local r01 <const>, g01 <const>, b01 <const> = ok_color.okhsl_to_srgb(
        h, s, l)

    -- Values still go out of gamut, particularly for
    -- saturated blues at medium light.
    local r01cl = min(max(r01, 0), 1)
    local g01cl = min(max(g01, 0), 1)
    local b01cl = min(max(b01, 0), 1)

    local r8 <const> = floor(r01cl * 255 + 0.5)
    local g8 <const> = floor(g01cl * 255 + 0.5)
    local b8 <const> = floor(b01cl * 255 + 0.5)

    return r8, g8, b8, r01cl, g01cl, b01cl
end

---@param event { context: GraphicsContext }
local function onPaintAlpha(event)
    local ctx <const> = event.context
    ctx.antialias = false
    ctx.blendMode = BlendMode.SRC

    local wCanvas <const> = ctx.width
    local hCanvas <const> = ctx.height
    if wCanvas <= 1 or hCanvas <= 1 then return end

    local needsRepaint <const> = active.triggerAlphaRepaint
        or active.wCanvasAlpha ~= wCanvas
        or active.hCanvasAlpha ~= hCanvas

    active.wCanvasAlpha = wCanvas
    active.hCanvasAlpha = hCanvas

    if needsRepaint then
        ---@type string[]
        local byteStrs <const> = {}

        local strpack <const> = string.pack

        local redActive <const> = active.redFore
        local greenActive <const> = active.greenFore
        local blueActive <const> = active.blueFore

        local wCheck <const> = defaults.wCheck
        local hCheck <const> = defaults.hCheck
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

    local alphaActive <const> = active.alphaFore
    local xReticle <const> = floor(alphaActive * (wCanvas - 1.0) + 0.5)
    local yReticle <const> = hCanvas // 2

    local reticleSize <const> = defaults.reticleSize
    local reticleHalf <const> = reticleSize // 2
    local reticleColor <const> = active.lightFore < 0.5
        and Color { r = 255, g = 255, b = 255, a = 255 }
        or Color { r = 0, g = 0, b = 0, a = 255 }
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
    local satAxis <const> = active.satAxis
    local lightAxis <const> = active.lightAxis

    local hueFore <const> = active.hueFore
    local satFore <const> = active.satFore
    local lightFore <const> = active.lightFore

    local hueActive <const> = hueFore
    local satActive <const> = satFore
    local lightActive <const> = lightFore

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

        local strpack <const> = string.pack
        local xToFac <const> = 1.0 / (wCanvas - 1.0)

        local x = 0
        while x < wCanvas do
            local fac <const> = x * xToFac
            local xs <const> = useSat and fac or satActive
            local xl <const> = useSat and lightActive or fac

            local r8 <const>, g8 <const>, b8 <const>,
            _ <const>, _ <const>, _ <const> = okhslToRgb24(
                hueActive, xs, xl)
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
    local xReticle <const> = floor(x01 * (wCanvas - 1.0) + 0.5)
    local yReticle <const> = hCanvas // 2

    local reticleSize <const> = defaults.reticleSize
    local reticleHalf <const> = reticleSize // 2
    local comparisand <const> = useSat and lightActive or lightAxis
    local aseWhite <const> = Color { r = 255, g = 255, b = 255, a = 255 }
    local aseBlack <const> = Color { r = 0, g = 0, b = 0, a = 255 }
    local reticleColor <const> = comparisand < 0.5
        and aseWhite
        or aseBlack
    ctx.color = reticleColor
    ctx.strokeWidth = defaults.reticleStroke
    ctx:strokeRect(Rectangle(
        xReticle - reticleHalf, yReticle - reticleHalf,
        reticleSize, reticleSize))

    if (not useSat)
        and active.showHarmonyOnWheel then
        local harmonyType <const> = active.harmonyType
        local harmRetSize = defaults.harmonyReticleSize
        local harmRetHalf = harmRetSize // 2

        local harmRetColor <const> = lightActive < 0.5
            and aseBlack
            or aseWhite
        ctx.color = harmRetColor
        ctx.strokeWidth = defaults.harmonyReticleStroke

        if harmonyType == "ANALOGOUS" then
            local lAna <const> = (lightActive * 2.0 + 0.5) / 3.0
            ctx:strokeRect(Rectangle(
                floor(lAna * (wCanvas - 1.0) + 0.5) - harmRetHalf,
                yReticle - harmRetHalf,
                harmRetSize, harmRetSize))
        elseif harmonyType == "COMPLEMENT" then
            local lCmp <const> = 1.0 - lightActive
            ctx:strokeRect(Rectangle(
                floor(lCmp * (wCanvas - 1.0) + 0.5) - harmRetHalf,
                yReticle - harmRetHalf,
                harmRetSize, harmRetSize))
        elseif harmonyType == "SPLIT" then
            local lSpl <const> = (2.5 - lightActive * 2.0) / 3.0
            ctx:strokeRect(Rectangle(
                floor(lSpl * (wCanvas - 1.0) + 0.5) - harmRetHalf,
                yReticle - harmRetHalf,
                harmRetSize, harmRetSize))
        elseif harmonyType == "SQUARE" then
            local lCmp <const> = 1.0 - lightActive
            local lSqr <const> = 0.5
            ctx:strokeRect(Rectangle(
                floor(lCmp * (wCanvas - 1.0) + 0.5) - harmRetHalf,
                yReticle - harmRetHalf,
                harmRetSize, harmRetSize))
            ctx:strokeRect(Rectangle(
                floor(lSqr * (wCanvas - 1.0) + 0.5) - harmRetHalf,
                yReticle - harmRetHalf,
                harmRetSize, harmRetSize))
        elseif harmonyType == "TETRADIC" then
            local lTri <const> = (2.0 - lightActive) / 3.0
            local lCmp <const> = 1.0 - lightActive
            local lTet <const> = (1.0 + lightActive) / 3.0
            ctx:strokeRect(Rectangle(
                floor(lTri * (wCanvas - 1.0) + 0.5) - harmRetHalf,
                yReticle - harmRetHalf,
                harmRetSize, harmRetSize))
            ctx:strokeRect(Rectangle(
                floor(lCmp * (wCanvas - 1.0) + 0.5) - harmRetHalf,
                yReticle - harmRetHalf,
                harmRetSize, harmRetSize))
            ctx:strokeRect(Rectangle(
                floor(lTet * (wCanvas - 1.0) + 0.5) - harmRetHalf,
                yReticle - harmRetHalf,
                harmRetSize, harmRetSize))
        elseif harmonyType == "TRIADIC" then
            local lTri <const> = (2.0 - lightActive) / 3.0
            ctx:strokeRect(Rectangle(
                floor(lTri * (wCanvas - 1.0) + 0.5) - harmRetHalf,
                yReticle - harmRetHalf,
                harmRetSize, harmRetSize))
        end
    end
end

---@param event { context: GraphicsContext }
local function onPaintCircle(event)
    local ctx <const> = event.context
    ctx.antialias = false
    ctx.blendMode = BlendMode.SRC

    local wCanvas <const> = ctx.width
    local hCanvas <const> = ctx.height
    if wCanvas <= 1 or hCanvas <= 1 then return end

    local needsRepaint <const> = active.triggerCircleRepaint
        or active.wCanvasCircle ~= wCanvas
        or active.hCanvasCircle ~= hCanvas

    active.wCanvasCircle = wCanvas
    active.hCanvasCircle = hCanvas

    local xCenter <const> = wCanvas * 0.5
    local yCenter <const> = hCanvas * 0.5
    local shortEdge <const> = min(wCanvas, hCanvas)
    local radiusCanvas <const> = (shortEdge - 1.0) * 0.5

    local themeColors <const> = app.theme.color
    local radiansOffset <const> = active.radiansOffset

    local useSat <const> = active.useSat

    local hueFore <const> = active.hueFore
    local satFore <const> = active.satFore
    local lightFore <const> = active.lightFore

    local hueActive <const> = hueFore
    local satActive <const> = satFore
    local lightActive <const> = lightFore

    if needsRepaint then
        ---@type string[]
        local byteStrs <const> = {}

        -- Cache method used in while loop.
        local strpack <const> = string.pack
        local atan2 <const> = math.atan
        local sqrt <const> = math.sqrt

        -- local diamCanvasInv <const> = 1.0 / diamCanvas
        local radiusCanvasInv <const> = 1.0 / radiusCanvas
        local bkgColor <const> = themeColors.window_face
        local packZero <const> = strpack("B B B B",
            bkgColor.red, bkgColor.green, bkgColor.blue, 255)

        local satAxis <const> = active.satAxis
        local lightAxis <const> = active.lightAxis

        local lenCanvas <const> = wCanvas * hCanvas
        local i = 0
        while i < lenCanvas do
            local x <const> = (i % wCanvas - xCenter) * radiusCanvasInv
            local y <const> = (yCenter - i // wCanvas) * radiusCanvasInv
            local sqMag <const> = x * x + y * y

            local byteStr = packZero
            if sqMag <= 1.0 then
                local radiansSigned <const> = atan2(y, x)
                local rSgnOffset <const> = radiansSigned + radiansOffset
                local rUnsigned <const> = rSgnOffset % tau
                local hue <const> = rUnsigned * oneTau
                -- If you want to support quantize, use signed q here.

                local mag <const> = sqrt(sqMag)
                local light <const> = useSat and 1.0 - mag or lightAxis
                local sat <const> = useSat and satAxis or mag
                -- If you want to support quantize, use unsigned q here.

                local r8 <const>, g8 <const>, b8 <const>,
                _ <const>, _ <const>, _ <const> = okhslToRgb24(
                    hue, sat, light)
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
    local swatchMargin <const> = defaults.swatchMargin
    local offset <const> = swatchSize // 2
    local xSwatch <const> = wCanvas - swatchSize - swatchMargin
    local ySwatch <const> = hCanvas - swatchSize - swatchMargin

    local redBack <const> = active.redBack
    local greenBack <const> = active.greenBack
    local blueBack <const> = active.blueBack

    local redFore <const> = active.redFore
    local greenFore <const> = active.greenFore
    local blueFore <const> = active.blueFore

    -- Draw background color swatch.
    ctx.color = Color {
        r = floor(redBack * 255 + 0.5),
        g = floor(greenBack * 255 + 0.5),
        b = floor(blueBack * 255 + 0.5),
        a = 255
    }
    ctx:fillRect(Rectangle(
        xSwatch - offset, ySwatch,
        swatchSize, swatchSize))

    -- Draw foreground color swatch.
    ctx.color = Color {
        r = floor(redFore * 255 + 0.5),
        g = floor(greenFore * 255 + 0.5),
        b = floor(blueFore * 255 + 0.5),
        a = 255
    }
    ctx:fillRect(Rectangle(
        xSwatch, ySwatch - offset,
        swatchSize, swatchSize))

    -- Draw reticle.
    local magActive <const> = useSat
        and 1.0 - lightActive
        or satActive
    local magCanvas <const> = magActive * radiusCanvas
    local radiansActive <const> = hueActive * tau - radiansOffset
    local xReticle <const> = math.cos(radiansActive)
    local yReticle <const> = math.sin(radiansActive)

    local reticleSize <const> = defaults.reticleSize
    local reticleHalf <const> = reticleSize // 2
    local aseWhite <const> = Color { r = 255, g = 255, b = 255, a = 255 }
    local aseBlack <const> = Color { r = 0, g = 0, b = 0, a = 255 }
    local reticleColor <const> = lightActive < 0.5
        and aseWhite
        or aseBlack
    ctx.color = reticleColor
    ctx.strokeWidth = defaults.reticleStroke
    ctx:strokeRect(Rectangle(
        floor(0.5 + (xCenter + xReticle * magCanvas) - reticleHalf),
        floor(0.5 + (yCenter - yReticle * magCanvas) - reticleHalf),
        reticleSize, reticleSize))

    -- Draw harmony reticles.
    local harmonyType <const> = active.harmonyType
    local showHarmonyOnWheel <const> = active.showHarmonyOnWheel
    if showHarmonyOnWheel
        and harmonyType ~= "NONE"
        and harmonyType ~= "SHADING" then
        local harmRetSize = defaults.harmonyReticleSize
        local harmRetHalf = harmRetSize // 2

        ---@type Point[]
        local pts <const> = {}
        if harmonyType == "ANALOGOUS" then
            -- 30, 330 degrees
            local rt32x <const> = sqrt32 * xReticle
            local rt32y <const> = sqrt32 * yReticle
            local halfx <const> = 0.5 * xReticle
            local halfy <const> = 0.5 * yReticle

            local xAna0 <const>, yAna0 <const> = rt32x - halfy, rt32y + halfx
            local xAna1 <const>, yAna1 <const> = rt32x + halfy, rt32y - halfx

            local lAna <const> = useSat
                and ((magActive * 2.0 + 0.5) / 3.0) * radiusCanvas
                or magCanvas

            pts[1] = Point(
                floor(0.5 + (xCenter + xAna0 * lAna) - harmRetHalf),
                floor(0.5 + (yCenter - yAna0 * lAna) - harmRetHalf))
            pts[2] = Point(
                floor(0.5 + (xCenter + xAna1 * lAna) - harmRetHalf),
                floor(0.5 + (yCenter - yAna1 * lAna) - harmRetHalf))
        elseif harmonyType == "COMPLEMENT" then
            -- 180 degrees
            local lCmp <const> = useSat
                and (1.0 - magActive) * radiusCanvas
                or magCanvas

            pts[1] = Point(
                floor(0.5 + (xCenter - xReticle * lCmp) - harmRetHalf),
                floor(0.5 + (yCenter + yReticle * lCmp) - harmRetHalf))
        elseif harmonyType == "SPLIT" then
            -- 150, 210 degrees
            local rt32x <const> = -sqrt32 * xReticle
            local rt32y <const> = -sqrt32 * yReticle
            local halfx <const> = 0.5 * xReticle
            local halfy <const> = 0.5 * yReticle

            local xSpl0 <const>, ySpl0 <const> = rt32x - halfy, rt32y + halfx
            local xSpl1 <const>, ySpl1 <const> = rt32x + halfy, rt32y - halfx

            local lSpl <const> = useSat
                and ((2.5 - magActive * 2.0) / 3.0) * radiusCanvas
                or magCanvas

            pts[1] = Point(
                floor(0.5 + (xCenter + xSpl0 * lSpl) - harmRetHalf),
                floor(0.5 + (yCenter - ySpl0 * lSpl) - harmRetHalf))
            pts[2] = Point(
                floor(0.5 + (xCenter + xSpl1 * lSpl) - harmRetHalf),
                floor(0.5 + (yCenter - ySpl1 * lSpl) - harmRetHalf))
        elseif harmonyType == "SQUARE" then
            -- 90, 180, 270 degrees
            local lCmp <const> = useSat
                and (1.0 - magActive) * radiusCanvas
                or magCanvas
            local lSqr <const> = useSat
                and 0.5 * radiusCanvas
                or magCanvas

            pts[1] = Point(
                floor(0.5 + (xCenter - yReticle * lSqr) - harmRetHalf),
                floor(0.5 + (yCenter - xReticle * lSqr) - harmRetHalf))
            pts[2] = Point(
                floor(0.5 + (xCenter - xReticle * lCmp) - harmRetHalf),
                floor(0.5 + (yCenter + yReticle * lCmp) - harmRetHalf))
            pts[3] = Point(
                floor(0.5 + (xCenter + yReticle * lSqr) - harmRetHalf),
                floor(0.5 + (yCenter + xReticle * lSqr) - harmRetHalf))
        elseif harmonyType == "TETRADIC" then
            -- 120, 300 degrees
            local rt32x <const> = sqrt32 * xReticle
            local rt32y <const> = sqrt32 * yReticle
            local halfx <const> = 0.5 * xReticle
            local halfy <const> = 0.5 * yReticle

            local xTet0 <const>, yTet0 <const> = -halfx - rt32y, -halfy + rt32x
            local xTet2 <const>, yTet2 <const> = halfx + rt32y, halfy - rt32x

            local lTri <const> = useSat
                and ((2.0 - magActive) / 3.0) * radiusCanvas
                or magCanvas
            local lCmp <const> = useSat
                and (1.0 - magActive) * radiusCanvas
                or magCanvas
            local lTet <const> = useSat
                and ((1.0 + magActive) / 3.0) * radiusCanvas
                or magCanvas

            pts[1] = Point(
                floor(0.5 + (xCenter + xTet0 * lTri) - harmRetHalf),
                floor(0.5 + (yCenter - yTet0 * lTri) - harmRetHalf))
            pts[2] = Point(
                floor(0.5 + (xCenter - xReticle * lCmp) - harmRetHalf),
                floor(0.5 + (yCenter + yReticle * lCmp) - harmRetHalf))
            pts[3] = Point(
                floor(0.5 + (xCenter + xTet2 * lTet) - harmRetHalf),
                floor(0.5 + (yCenter - yTet2 * lTet) - harmRetHalf))
        elseif harmonyType == "TRIADIC" then
            -- 120, 240 degrees
            local rt32x <const> = sqrt32 * xReticle
            local rt32y <const> = sqrt32 * yReticle
            local halfx <const> = -0.5 * xReticle
            local halfy <const> = -0.5 * yReticle

            local xTri0 <const>, yTri0 <const> = halfx - rt32y, halfy + rt32x
            local xTri1 <const>, yTri1 <const> = halfx + rt32y, halfy - rt32x

            local lTri <const> = useSat
                and ((2.0 - magActive) / 3.0) * radiusCanvas
                or magCanvas

            pts[1] = Point(
                floor(0.5 + (xCenter + xTri0 * lTri) - harmRetHalf),
                floor(0.5 + (yCenter - yTri0 * lTri) - harmRetHalf))
            pts[2] = Point(
                floor(0.5 + (xCenter + xTri1 * lTri) - harmRetHalf),
                floor(0.5 + (yCenter - yTri1 * lTri) - harmRetHalf))
        end

        local harmRetColor <const> = lightActive < 0.5
            and aseBlack
            or aseWhite
        ctx.color = harmRetColor
        ctx.strokeWidth = defaults.harmonyReticleStroke

        local lenPts <const> = #pts
        local i = 0
        while i < lenPts do
            i = i + 1
            local pt <const> = pts[i]
            ctx:strokeRect(Rectangle(
                pt.x, pt.y, harmRetSize, harmRetSize))
        end
    end

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

        local redActive <const> = redFore
        local greenActive <const> = greenFore
        local blueActive <const> = blueFore
        local alphaActive <const> = active.alphaFore

        ctx:fillText(string.format(
            "R: %.2f%%", redActive * 100), 2, 2 + yIncr * 4)
        ctx:fillText(string.format(
            "G: %.2f%%", greenActive * 100), 2, 2 + yIncr * 5)
        ctx:fillText(string.format(
            "B: %.2f%%", blueActive * 100), 2, 2 + yIncr * 6)
        ctx:fillText(string.format(
            "A: %.2f%%", alphaActive * 100), 2, 2 + yIncr * 8)

        local hex <const> = math.floor(redActive * 255 + 0.5) << 0x10
            | math.floor(greenActive * 255 + 0.5) << 0x08
            | math.floor(blueActive * 255 + 0.5) << 0x00

        local hexPad <const> = 6

        ctx:fillText(string.format("#%0" .. hexPad .. "X", hex),
            2, 2 + yIncr * 10)
    end
end

---@param event { context: GraphicsContext }
local function onPaintHarmony(event)
    local ctx <const> = event.context
    ctx.antialias = false
    ctx.blendMode = BlendMode.SRC

    local wCanvas <const> = ctx.width
    local hCanvas <const> = ctx.height
    if wCanvas <= 1 or hCanvas <= 1 then return end

    local needsRepaint <const> = active.triggerHarmonyRepaint
        or active.wCanvasHarmony ~= wCanvas
        or active.hCanvasHarmony ~= hCanvas

    active.wCanvasHarmony = wCanvas
    active.hCanvasHarmony = hCanvas

    local harmonyType <const> = active.harmonyType
    local isAnalog <const> = harmonyType == "ANALOGOUS"
    local isCompl <const> = harmonyType == "COMPLEMENT"
    local isNone <const> = harmonyType == "NONE"
    local isShading <const> = harmonyType == "SHADING"
    local isSplit <const> = harmonyType == "SPLIT"
    local isSquare <const> = harmonyType == "SQUARE"
    local isTetradic <const> = harmonyType == "TETRADIC"
    local isTriadic <const> = harmonyType == "TRIADIC"

    if needsRepaint then
        local hActive <const> = active.hueFore
        local sActive <const> = active.satFore
        local lActive <const> = active.lightFore

        if isAnalog then
            local lAna <const> = (lActive * 2.0 + 0.5) / 3.0
            local h030 <const> = hActive + 0.083333333333333
            local h330 <const> = hActive - 0.083333333333333

            local r0 <const>, g0 <const>, b0 <const> = okhslToRgb24(h030, sActive, lAna)
            local r1 <const>, g1 <const>, b1 <const> = okhslToRgb24(h330, sActive, lAna)

            active.byteStrHarmony = string.pack(
                "B B B B B B B B",
                r0, g0, b0, 255, r1, g1, b1, 255)
        elseif isCompl then
            local lCmp <const> = 1.0 - lActive
            local h180 <const> = hActive + 0.5

            local r0 <const>, g0 <const>, b0 <const> = okhslToRgb24(h180, sActive, lCmp)

            active.byteStrHarmony = string.pack(
                "B B B B",
                r0, g0, b0, 255)
        elseif isNone then
            local themeColors <const> = app.theme.color
            local bkgColor <const> = themeColors.window_face
            active.byteStrHarmony = string.pack(
                "B B B B",
                bkgColor.red, bkgColor.green, bkgColor.blue, 255)
        elseif isShading then
            ---@type string[]
            local byteStrArr <const> = {}
            local shadingCount <const> = active.shadingCount
            local iToFac <const> = 1.0 / (shadingCount - 1.0)
            local lOrig <const> = defaults.shadowLight
            local lDest <const> = defaults.dayLight

            -- Decide on clockwise or counter-clockwise based
            -- on color's warmth or coolness.
            -- The LCh hue for yellow is 103 degrees.
            local hYel <const> = defaults.hYel
            local hBlu <const> = hYel + 0.5
            local hueFunc = nil
            if hActive < hYel or hActive >= hBlu then
                hueFunc = lerpAngleCcw
            else
                hueFunc = lerpAngleCw
            end

            -- Absolute hues for shadow and light.
            -- This could also be combined with the origin hue +/-
            -- a shift which is then mixed with the absolute hue.
            local shadowHue <const> = defaults.shadowHue
            local dayHue <const> = defaults.dayHue

            -- Amount to mix between base light and loop light.
            local srcLightWeight <const> = defaults.srcLightWeight
            local cmpLightWeight <const> = 1.0 - srcLightWeight

            -- The warm-cool dichotomy works poorly for greens.
            -- For that reason, the closer a hue is to green,
            -- the more it uses absolute hue shifting.
            -- Green is approximately at hue 140.
            local offsetMix <const> = 2.0 * distAngleUnsigned(
                hActive, defaults.greenHue, 1.0)
            local offsetScale <const> = (1.0 - offsetMix) * defaults.maxGreenOffset
                + offsetMix * defaults.minGreenOffset

            -- Yellows are very saturated at high light;
            -- Desaturate them to get a better shade.
            -- Conversely, blues easily fall out of gamut
            -- so the shade factor is separate.
            local lgtDesatFac <const> = defaults.lgtDesatFac
            local shdDesatFac <const> = defaults.shdDesatFac
            local minChroma <const> = defaults.minChroma
            local cVal <const> = math.max(minChroma, sActive)
            local desatChromaLgt <const> = cVal * lgtDesatFac
            local desatChromaShd <const> = cVal * shdDesatFac

            local strpack <const> = string.pack

            local i = 0
            while i < shadingCount do
                local iFac <const> = i * iToFac
                local cmplFac <const> = 1.0 - iFac
                local lItr <const> = cmplFac * lOrig + iFac * lDest

                -- Idealized hue from violet shadow to
                -- off-yellow daylight.
                local hAbs <const> = hueFunc(shadowHue, dayHue, lItr, 1.0)

                -- The middle sample should be closest to base color.
                -- The fac needs to be 0.0. That's why zigzag is
                -- used to convert to an oscillation.
                local lMixed <const> = srcLightWeight * lActive
                    + cmpLightWeight * lItr
                local lZig <const> = zigZag(lMixed)
                local fac <const> = offsetScale * lZig
                local hMixed <const> = lerpAngleNear(hActive, hAbs, fac, 1.0)

                -- Desaturate brights and darks.
                -- Min chroma gives even grays a slight chroma.
                local chromaTarget = desatChromaLgt
                if lMixed < 0.5 then chromaTarget = desatChromaShd end
                local cMixed = (1.0 - lZig) * cVal + lZig * chromaTarget
                cMixed = max(minChroma, cMixed)

                local r8 <const>, g8 <const>, b8 <const> = okhslToRgb24(
                    hMixed, cMixed, lMixed)

                i = i + 1
                byteStrArr[i] = strpack("B B B B", r8, g8, b8, 255)
            end

            active.byteStrHarmony = table.concat(byteStrArr)
        elseif isSplit then
            local lSpl <const> = (2.5 - lActive * 2.0) / 3.0
            local h150 = hActive + 0.41666666666667
            local h210 = hActive - 0.41666666666667

            local r0 <const>, g0 <const>, b0 <const> = okhslToRgb24(h150, sActive, lSpl)
            local r1 <const>, g1 <const>, b1 <const> = okhslToRgb24(h210, sActive, lSpl)

            active.byteStrHarmony = string.pack(
                "B B B B B B B B",
                r0, g0, b0, 255, r1, g1, b1, 255)
        elseif isSquare then
            local lCmp <const> = 1.0 - lActive
            local lSqr <const> = 0.5
            local h090 = hActive + 0.25
            local h180 = hActive + 0.5
            local h270 = hActive - 0.25

            local r0 <const>, g0 <const>, b0 <const> = okhslToRgb24(h090, sActive, lSqr)
            local r1 <const>, g1 <const>, b1 <const> = okhslToRgb24(h180, sActive, lCmp)
            local r2 <const>, g2 <const>, b2 <const> = okhslToRgb24(h270, sActive, lSqr)

            active.byteStrHarmony = string.pack(
                "B B B B B B B B B B B B",
                r0, g0, b0, 255, r1, g1, b1, 255, r2, g2, b2, 255)
        elseif isTetradic then
            local lTri <const> = (2.0 - lActive) / 3.0
            local lCmp <const> = 1.0 - lActive
            local lTet <const> = (1.0 + lActive) / 3.0
            local h120 <const> = hActive + 0.33333333333333
            local h180 <const> = hActive + 0.5
            local h300 <const> = hActive - 0.16666666666667

            local r0 <const>, g0 <const>, b0 <const> = okhslToRgb24(h120, sActive, lTri)
            local r1 <const>, g1 <const>, b1 <const> = okhslToRgb24(h180, sActive, lCmp)
            local r2 <const>, g2 <const>, b2 <const> = okhslToRgb24(h300, sActive, lTet)

            active.byteStrHarmony = string.pack(
                "B B B B B B B B B B B B",
                r0, g0, b0, 255, r1, g1, b1, 255, r2, g2, b2, 255)
        elseif isTriadic then
            local lTri <const> = (2.0 - lActive) / 3.0
            local h120 <const> = hActive + 0.33333333333333
            local h240 <const> = hActive - 0.33333333333333

            local r0 <const>, g0 <const>, b0 <const> = okhslToRgb24(h120, sActive, lTri)
            local r1 <const>, g1 <const>, b1 <const> = okhslToRgb24(h240, sActive, lTri)

            active.byteStrHarmony = string.pack(
                "B B B B B B B B",
                r0, g0, b0, 255, r1, g1, b1, 255)
        end
    end

    local wCanvasNative = 1
    if isAnalog then
        wCanvasNative = 2
    elseif isCompl then
        wCanvasNative = 1
    elseif isNone then
        wCanvasNative = 1
    elseif isShading then
        wCanvasNative = active.shadingCount
    elseif isSplit then
        wCanvasNative = 2
    elseif isSquare then
        wCanvasNative = 3
    elseif isTetradic then
        wCanvasNative = 3
    elseif isTriadic then
        wCanvasNative = 2
    end

    -- Draw harmony canvas.
    local imgSpec <const> = ImageSpec {
        width = wCanvasNative,
        height = 1,
        transparentColor = 0,
        colorMode = ColorMode.RGB
    }
    local img <const> = Image(imgSpec)
    img.bytes = active.byteStrHarmony
    ctx:drawImage(img,
        Rectangle(0, 0, wCanvasNative, 1),
        Rectangle(0, 0, wCanvas, hCanvas))
end

---@param r8 integer
---@param g8 integer
---@param b8 integer
---@param t8 integer
---@param isBackActive boolean
local function updateFromRgba8(r8, g8, b8, t8, isBackActive)
    -- Keep usage of isBackActive here.

    local r01 <const>,
    g01 <const>,
    b01 <const> = r8 / 255.0, g8 / 255.0, b8 / 255.0
    local h <const>,
    s <const>,
    l <const> = ok_color.srgb_to_okhsl(r01, g01, b01)

    if l > 0.0 and l < 1.0 then
        if s > 0.0 then
            active[isBackActive and "hueBack" or "hueFore"] = h
        end
        active[isBackActive and "satBack" or "satFore"] = s
    end
    active[isBackActive and "lightBack" or "lightFore"] = l

    active[isBackActive and "redBack" or "redFore"] = r01
    active[isBackActive and "greenBack" or "greenFore"] = g01
    active[isBackActive and "blueBack" or "blueFore"] = b01
    active[isBackActive and "alphaBack" or "alphaFore"] = t8 / 255.0

    if not isBackActive then
        active.satAxis = s
        active.lightAxis = l
    end
end

---@param isBackActive boolean
---@return Color
local function toAseColor(isBackActive)
    -- Keep usage of isBackActive here.

    local redActive <const> = isBackActive
        and active.redBack
        or active.redFore
    local greenActive <const> = isBackActive
        and active.greenBack
        or active.greenFore
    local blueActive <const> = isBackActive
        and active.blueBack
        or active.blueFore
    local alphaActive <const> = isBackActive
        and active.alphaBack
        or active.alphaFore

    return Color {
        r = floor(redActive * 255 + 0.5),
        g = floor(greenActive * 255 + 0.5),
        b = floor(blueActive * 255 + 0.5),
        a = floor(alphaActive * 255 + 0.5),
    }
end

---@param isBackActive boolean
local function updateColorBar(isBackActive)
    local aseColor <const> = toAseColor(isBackActive)
    if isBackActive then
        app.command.SwitchColors()
        app.fgColor = aseColor
        app.command.SwitchColors()
    else
        app.fgColor = aseColor
    end
end

local dlgMain <const> = Dialog { title = "OkHsl Color Picker" }

local dlgOptions <const> = Dialog {
    title = "Okhsl Options",
    parent = dlgMain
}

local function genGradient()
    local sprite <const> = app.sprite
    if not sprite then return end

    if sprite.colorMode == ColorMode.GRAY then
        app.alert {
            title = "Error",
            text = "Grayscale mode not supported."
        }
        return
    end

    local argsOptions <const> = dlgOptions.data
    local swatchCount <const> = argsOptions.swatchCount --[[@as integer]]
    local huePreset <const> = argsOptions.huePreset --[[@as string]]

    local toFac <const> = 1.0 / (swatchCount - 1.0)
    local hueEasing = lerpAngleNear
    if huePreset == "CCW" then
        hueEasing = lerpAngleCcw
    elseif huePreset == "CW" then
        hueEasing = lerpAngleCw
    elseif huePreset == "FAR" then
        hueEasing = lerpAngleFar
    end

    local hOrig <const> = active.hueFore
    local sOrig <const> = active.satFore
    local lOrig <const> = active.lightFore
    local tOrig <const> = active.alphaFore

    local hDest <const> = active.hueBack
    local sDest <const> = active.satBack
    local lDest <const> = active.lightBack
    local tDest <const> = active.alphaBack

    local oIsGray <const> = sOrig < 0.00001
    local dIsGray <const> = sDest < 0.00001
    local useLabMix <const> = oIsGray or dIsGray
    local lLabOrig <const>,
    aLabOrig <const>,
    bLabOrig <const> = ok_color.okhsl_to_oklab(hOrig, sOrig, lOrig)
    local lLabDest <const>,
    aLabDest <const>,
    bLabDest <const> = ok_color.okhsl_to_oklab(hDest, sDest, lDest)

    local hslToRgb <const> = ok_color.okhsl_to_srgb
    local labToRgb <const> = ok_color.oklab_to_srgb

    ---@type Color[]
    local aseColors <const> = {}
    local i = 0
    while i < swatchCount do
        local fac <const> = i * toFac
        local cmplFac <const> = 1.0 - fac

        local tMix <const> = cmplFac * tOrig + fac * tDest

        local r01, g01, b01 = 0.0, 0.0, 0.0
        if useLabMix then
            r01, g01, b01 = labToRgb(
                cmplFac * lLabOrig + fac * lLabDest,
                cmplFac * aLabOrig + fac * aLabDest,
                cmplFac * bLabOrig + fac * bLabDest)
        else
            r01, g01, b01 = hslToRgb(
                hueEasing(hOrig, hDest, fac, 1.0),
                cmplFac * sOrig + fac * sDest,
                cmplFac * lOrig + fac * lDest)
        end

        local r01cl = min(max(r01, 0), 1)
        local g01cl = min(max(g01, 0), 1)
        local b01cl = min(max(b01, 0), 1)

        local r8 <const> = floor(r01cl * 255 + 0.5)
        local g8 <const> = floor(g01cl * 255 + 0.5)
        local b8 <const> = floor(b01cl * 255 + 0.5)
        local t8 <const> = floor(tMix * 255 + 0.5)

        i = i + 1
        aseColors[i] = Color { r = r8, g = g8, b = b8, a = t8 }
    end

    local spritePalettes <const> = sprite.palettes
    local lenSpritePalettes <const> = #spritePalettes

    local frame <const> = app.frame or sprite.frames[1]
    local frIdx <const> = frame.frameNumber
    local palIdx <const> = frIdx <= lenSpritePalettes and frIdx or 1

    local palette <const> = spritePalettes[palIdx]
    local lenPaletteOld <const> = #palette
    local lenPaletteNew <const> = lenPaletteOld + swatchCount

    app.transaction("Palette Gradient", function()
        palette:resize(lenPaletteNew)
        local j = 0
        while j < swatchCount do
            local aseColor <const> = aseColors[1 + j]
            palette:setColor(lenPaletteOld + j, aseColor)
            j = j + 1
        end
    end)
end

local function getFromCanvas()
    -- TODO: If you ever wanted to sample from just the
    -- active layer, see app.preferences.eyedropper.sample.
    -- However, this raises numerous problems, e.g., with
    -- tile map layers, hidden layers, etc.

    local editor <const> = app.editor
    if not editor then return end

    local sprite <const> = app.sprite
    if not sprite then return end

    local frame <const> = app.frame or sprite.frames[1]

    local mouse <const> = editor.spritePos
    local x = mouse.x
    local y = mouse.y

    local prefs <const> = app.preferences
    local docPrefs <const> = prefs.document(sprite)
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
        local v8 <const> = pixel & 0xff
        r8, g8, b8 = v8, v8, v8
        t8 = pixel >> 0x08 & 0xff
    else
        r8 = pixel & 0xff
        g8 = pixel >> 0x08 & 0xff
        b8 = pixel >> 0x10 & 0xff
        t8 = pixel >> 0x18 & 0xff
    end

    if t8 > 0 then
        updateFromRgba8(r8, g8, b8, t8, false)
        active.triggerAlphaRepaint = true
        active.triggerAxisRepaint = true
        active.triggerCircleRepaint = true
        active.triggerHarmonyRepaint = true
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

    local xCanvas <const> = min(max(event.x, 0), wCanvas - 1)
    local xNrm = xCanvas / (wCanvas - 1.0)
    if event.ctrlKey then
        xNrm = 1.0
    elseif event.shiftKey then
        xNrm = quantizeUnsigned(xNrm, active.axisLevels)
    end
    active["alphaFore"] = xNrm

    updateColorBar(false)
    dlgMain:repaint()
end

---@param event MouseEvent
local function onMouseMoveAxis(event)
    if event.button == MouseButton.NONE then return end

    local wCanvas <const> = active.wCanvasAxis
    local hCanvas <const> = active.hCanvasAxis
    if wCanvas <= 1 or hCanvas <= 1 then return end

    local useSat <const> = active.useSat

    local xCanvas <const> = min(max(event.x, 0), wCanvas - 1)
    local xNrm = xCanvas / (wCanvas - 1.0)
    if event.shiftKey then
        xNrm = quantizeUnsigned(xNrm, active.axisLevels)
    end
    local xNew <const> = event.ctrlKey
        and (useSat and 1.0 or 0.5)
        or xNrm

    -- TODO: All that follows here can become its own function and be used
    -- for both key down and mouse move.
    if useSat then
        active.satAxis = xNew
        active["satFore"] = xNew
    else
        active.lightAxis = xNew
        active["lightFore"] = xNew
    end

    local hActive <const> = active.hueFore
    local sActive <const> = active.satFore
    local lActive <const> = active.lightFore

    local _ <const>, _ <const>, _ <const>,
    r01 <const>, g01 <const>, b01 <const> = okhslToRgb24(
        hActive, sActive, lActive)

    active["redFore"] = r01
    active["greenFore"] = g01
    active["blueFore"] = b01

    updateColorBar(false)
    active.triggerCircleRepaint = true
    active.triggerAlphaRepaint = true
    active.triggerHarmonyRepaint = true
    dlgMain:repaint()
end

---@param event KeyEvent
local function onKeyPressCircle(event)
    local wCanvas <const> = active.wCanvasCircle
    local hCanvas <const> = active.hCanvasCircle
    if wCanvas <= 1 or hCanvas <= 1 then return end

    local code <const> = event.code
    local isLeft <const> = code == "ArrowLeft"
    local isRight <const> = code == "ArrowRight"
    local isUp <const> = code == "ArrowUp"
    local isDown <const> = code == "ArrowDown"
    local recognized <const> = isLeft or isRight or isUp or isDown

    if not recognized then return end

    local useSat <const> = active.useSat
    local radiansOffset <const> = active.radiansOffset
    local satAxis <const> = active.satAxis
    local lightAxis <const> = active.lightAxis

    local hueActive <const> = active.hueFore
    local satActive <const> = active.satFore
    local lightActive <const> = active.lightFore

    local magActive <const> = useSat
        and 1.0 - lightActive
        or satActive
    local radiansActive <const> = hueActive * tau - radiansOffset
    local x <const> = math.cos(radiansActive) * magActive
    local y <const> = math.sin(radiansActive) * magActive

    local xShift = x
    local yShift = y
    local shiftAmount <const> = defaults.keyShiftAmount
    if isLeft then xShift = xShift - shiftAmount end
    if isRight then xShift = xShift + shiftAmount end
    if isUp then yShift = yShift + shiftAmount end
    if isDown then yShift = yShift - shiftAmount end

    local radiansSigned <const> = math.atan(yShift, xShift)
    local rSgnOffset <const> = radiansSigned + radiansOffset
    local rUnsigned <const> = rSgnOffset % tau
    local hueKey <const> = rUnsigned * oneTau

    local sqMag <const> = min(max(xShift * xShift + yShift * yShift, 0), 1)
    local mag <const> = math.sqrt(sqMag)
    local lightKey <const> = useSat and 1.0 - mag or lightAxis
    local satKey <const> = useSat and satAxis or mag

    local _ <const>, _ <const>, _ <const>,
    r01 <const>, g01 <const>, b01 <const> = okhslToRgb24(
        hueKey, satKey, lightKey)

    active["hueFore"] = hueKey
    active["satFore"] = satKey
    active["lightFore"] = lightKey

    active["redFore"] = r01
    active["greenFore"] = g01
    active["blueFore"] = b01

    updateColorBar(false)
    active.triggerAxisRepaint = true
    active.triggerAlphaRepaint = true
    active.triggerHarmonyRepaint = true
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
    local shortEdge <const> = min(wCanvas, hCanvas)
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
    local hueMouse = rUnsigned * oneTau

    local mag <const> = math.sqrt(min(sqMag, 1.0))
    local lightMouse = useSat and 1.0 - mag or lightAxis
    local satMouse = useSat and satAxis or mag

    local shiftKey <const> = event.shiftKey
    local hLevels = shiftKey and active.hLevels or 0
    local sLevels = shiftKey and active.sLevels or 0
    local lLevels = shiftKey and active.lLevels or 0

    hueMouse = quantizeSigned(hueMouse, hLevels)
    satMouse = quantizeUnsigned(satMouse, sLevels)
    lightMouse = quantizeUnsigned(lightMouse, lLevels)

    local _ <const>, _ <const>, _ <const>,
    r01 <const>, g01 <const>, b01 <const> = okhslToRgb24(
        hueMouse, satMouse, lightMouse)

    active["hueFore"] = hueMouse
    active["satFore"] = satMouse
    active["lightFore"] = lightMouse

    active["redFore"] = r01
    active["greenFore"] = g01
    active["blueFore"] = b01

    updateColorBar(false)
    active.triggerAxisRepaint = true
    active.triggerAlphaRepaint = true
    active.triggerHarmonyRepaint = true
    dlgMain:repaint()
end

---@param event MouseEvent
local function onMouseUpHarmony(event)
    if event.button == MouseButton.NONE then return end

    local wCanvas <const> = active.wCanvasHarmony
    local hCanvas <const> = active.hCanvasHarmony
    if wCanvas <= 1 or hCanvas <= 1 then return end

    local shadingCount = 1
    local harmonyType <const> = active.harmonyType
    if harmonyType == "ANALOGOUS" then
        shadingCount = 2
    elseif harmonyType == "COMPLEMENT" then
        shadingCount = 1
    elseif harmonyType == "NONE" then
        shadingCount = 1
    elseif harmonyType == "SHADING" then
        shadingCount = active.shadingCount
    elseif harmonyType == "SPLIT" then
        shadingCount = 2
    elseif harmonyType == "SQUARE" then
        shadingCount = 3
    elseif harmonyType == "TETRADIC" then
        shadingCount = 3
    elseif harmonyType == "TRIADIC" then
        shadingCount = 2
    end

    local xNrm <const> = event.x / (wCanvas - 1.0)
    local xIdx <const> = min(max(floor(xNrm * shadingCount),
        0), shadingCount - 1)
    local r8 <const>,
    g8 <const>,
    b8 <const> = string.byte(
        active.byteStrHarmony, 1 + xIdx * 4, 3 + xIdx * 4)
    local t8 <const> = floor(active.alphaFore * 255.0 + 0.5)

    updateFromRgba8(r8, g8, b8, t8, false)
    updateColorBar(false)
    active.triggerAlphaRepaint = true
    active.triggerAxisRepaint = true
    active.triggerCircleRepaint = true
    dlgMain:repaint()
end

---@param event MouseEvent
local function onMouseUpCircle(event)
    local xMouseUp <const> = event.x
    local yMouseUp <const> = event.y

    local swatchSize <const> = defaults.swatchSize
    local swatchMargin <const> = defaults.swatchMargin
    local wCanvas <const> = active.wCanvasCircle
    local hCanvas <const> = active.hCanvasCircle

    local offset <const> = swatchSize // 2
    local xSwatch <const> = wCanvas - swatchSize - swatchMargin
    local ySwatch <const> = hCanvas - swatchSize - swatchMargin
    local offSizeSum <const> = offset + swatchSize - swatchMargin

    if xMouseUp >= xSwatch - offset
        and xMouseUp < xSwatch + offSizeSum
        and yMouseUp >= ySwatch - offset
        and yMouseUp < ySwatch + offSizeSum then
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

        updateColorBar(false)
        updateColorBar(true)

        active.triggerAlphaRepaint = true
        active.triggerAxisRepaint = true
        active.triggerCircleRepaint = true
        active.triggerHarmonyRepaint = true
        dlgMain:repaint()
    end
end

-- region Main Dialog

dlgMain:canvas {
    id = "circleCanvas",
    focus = true,
    width = defaults.wCanvas,
    height = defaults.hCanvasCircle,
    onkeydown = onKeyPressCircle,
    onmousedown = onMouseMoveCircle,
    onmousemove = onMouseMoveCircle,
    onmouseup = onMouseUpCircle,
    onpaint = onPaintCircle,
    hexpand = true,
    vexpand = true,
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
    hexpand = true,
    vexpand = false,
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
    hexpand = true,
    vexpand = false,
}

dlgMain:newrow { always = false }

dlgMain:canvas {
    id = "harmonyCanvas",
    focus = false,
    width = defaults.wCanvas,
    height = defaults.hCanvasHarmony,
    visible = defaults.harmonyType ~= "NONE",
    onmouseup = onMouseUpHarmony,
    onpaint = onPaintHarmony,
    hexpand = true,
    vexpand = false,
}

dlgMain:newrow { always = false }

dlgMain:button {
    id = "getForeButton",
    text = defaults.foreKey,
    focus = false,
    visible = defaults.showForeButton,
    onclick = function()
        if not app.sprite then return end

        local fgColor <const> = app.fgColor
        local r8fg <const> = fgColor.red
        local g8fg <const> = fgColor.green
        local b8fg <const> = fgColor.blue
        local t8fg <const> = fgColor.alpha

        updateFromRgba8(r8fg, g8fg, b8fg, t8fg, false)
        active.triggerAlphaRepaint = true
        active.triggerAxisRepaint = true
        active.triggerCircleRepaint = true
        active.triggerHarmonyRepaint = true
        dlgMain:repaint()
    end
}

dlgMain:button {
    id = "getBackButton",
    text = defaults.backKey,
    focus = false,
    visible = defaults.showBackButton,
    onclick = function()
        if not app.sprite then return end

        app.command.SwitchColors()
        local bgColor <const> = app.fgColor
        local r8bg <const> = bgColor.red
        local g8bg <const> = bgColor.green
        local b8bg <const> = bgColor.blue
        local t8bg <const> = bgColor.alpha
        app.command.SwitchColors()

        updateFromRgba8(r8bg, g8bg, b8bg, t8bg, true)
        active.triggerAlphaRepaint = true
        active.triggerAxisRepaint = true
        active.triggerCircleRepaint = true
        active.triggerHarmonyRepaint = true
        dlgMain:repaint()
    end
}

dlgMain:button {
    id = "palAppendButton",
    text = defaults.palAppendKey,
    focus = false,
    visible = defaults.showPalAppendButton,
    onclick = function()
        local sprite <const> = app.sprite
        if not sprite then return end

        local activeFrIdx = 1
        local activeFrObj <const> = app.frame
        if activeFrObj then
            activeFrIdx = activeFrObj.frameNumber
        end

        local palettes <const> = sprite.palettes
        local lenPalettes <const> = #palettes
        local palIdx <const> = (activeFrIdx >= 1
                and activeFrIdx <= lenPalettes)
            and activeFrIdx
            or 1
        local palette <const> = palettes[palIdx]
        local lenPalette <const> = #palette

        local aseColor <const> = toAseColor(false)
        palette:resize(lenPalette + 1)
        palette:setColor(lenPalette, aseColor)
    end
}

dlgMain:button {
    id = "sampleButton",
    text = defaults.sampleKey,
    focus = false,
    visible = defaults.showSampleButton,
    onclick = getFromCanvas
}

dlgMain:button {
    id = "gradientButton",
    text = defaults.gradientKey,
    focus = false,
    visible = defaults.showGradientButton,
    onclick = genGradient
}

dlgMain:button {
    id = "optionsButton",
    text = defaults.optionsKey,
    focus = false,
    visible = true,
    onclick = function()
        dlgOptions:show { autoscrollbars = true, wait = true }
    end
}

dlgMain:button {
    id = "exitMainButton",
    text = defaults.exitKey,
    focus = false,
    visible = defaults.showExitButton,
    onclick = function()
        dlgMain:close()
    end
}

-- endregion

-- region Options Menu

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
    focus = false,
    hexpand = false,
}

dlgOptions:newrow { always = false }

dlgOptions:combobox {
    id = "harmonyType",
    label = "Harmony:",
    option = defaults.harmonyType,
    options = harmonyTypes,
    focus = false,
    hexpand = false,
    onchange = function()
        local args <const> = dlgOptions.data
        local harmonyType <const> = args.harmonyType --[[@as string]]
        local isShading = harmonyType == "SHADING"
        local displayOption = (not isShading) and harmonyType ~= "NONE"
        dlgOptions:modify {
            id = "showHarmonyOnWheel",
            visible = displayOption
        }
        dlgOptions:modify {
            id = "shadingCount",
            visible = isShading
        }
    end
}

dlgOptions:newrow { always = false }

dlgOptions:check {
    id = "showHarmonyOnWheel",
    label = "Display:",
    text = "Reticle",
    selected = defaults.showHarmonyOnWheel,
    focus = false,
    visible = defaults.harmonyType ~= "SHADING"
        and defaults.harmonyType ~= "NONE",
    hexpand = false,
}

dlgOptions:newrow { always = false }

dlgOptions:slider {
    id = "shadingCount",
    label = "Shades:",
    value = defaults.shadingCount,
    min = 3,
    max = 15,
    focus = false,
    visible = defaults.harmonyType == "SHADING"
}

dlgOptions:separator {}

dlgOptions:check {
    id = "showFore",
    label = "Buttons:",
    text = "Fore",
    selected = defaults.showForeButton,
    focus = false,
    hexpand = false,
}

dlgOptions:check {
    id = "showBack",
    text = "Back",
    selected = defaults.showBackButton,
    focus = false,
    hexpand = false,
}

dlgOptions:check {
    id = "showExit",
    text = "X",
    selected = defaults.showExitButton,
    focus = false,
    hexpand = false,
}

dlgOptions:newrow { always = false }

dlgOptions:check {
    id = "showPalAppendButton",
    text = "Append",
    selected = defaults.showPalAppendButton,
    focus = false,
    hexpand = false,
}

dlgOptions:check {
    id = "showSample",
    text = "Sample",
    selected = defaults.showSampleButton,
    focus = false,
    hexpand = false,
}

dlgOptions:check {
    id = "showGradient",
    text = "Gradient",
    selected = defaults.showGradientButton,
    focus = false,
    hexpand = false,
    onclick = function()
        local args <const> = dlgOptions.data
        local showGradient <const> = args.showGradient --[[@as boolean]]
        dlgOptions:modify { id = "swatchCount", visible = showGradient }
        dlgOptions:modify { id = "huePreset", visible = showGradient }
    end
}

dlgOptions:newrow { always = false }

dlgOptions:slider {
    id = "swatchCount",
    label = "Swatches:",
    value = defaults.swatchCount,
    min = 3,
    max = 64,
    focus = false,
    visible = defaults.showGradientButton
}

dlgOptions:newrow { always = false }

dlgOptions:combobox {
    id = "huePreset",
    label = "Easing:",
    option = defaults.huePreset,
    options = huePresets,
    focus = false,
    visible = defaults.showGradientButton,
    hexpand = false,
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
        local harmonyType <const> = args.harmonyType --[[@as string]]
        local showHarmonyOnWheel <const> = args.showHarmonyOnWheel --[[@as boolean]]
        local shadingCount <const> = args.shadingCount --[[@as integer]]

        local showFore <const> = args.showFore --[[@as boolean]]
        local showBack <const> = args.showBack --[[@as boolean]]
        local showGradient <const> = args.showGradient --[[@as boolean]]
        local showPalAppend <const> = args.showPalAppendButton --[[@as boolean]]
        local showSample <const> = args.showSample --[[@as boolean]]
        local showExit <const> = args.showExit --[[@as boolean]]

        active.radiansOffset = (-math.rad(degreesOffset)) % tau
        active.useSat = axis == "SATURATION"
        active.harmonyType = harmonyType
        active.showHarmonyOnWheel = showHarmonyOnWheel
        active.shadingCount = shadingCount

        active.triggerAlphaRepaint = true
        active.triggerAxisRepaint = true
        active.triggerCircleRepaint = true
        active.triggerHarmonyRepaint = true

        dlgMain:repaint()

        dlgMain:modify { id = "getForeButton", visible = showFore }
        dlgMain:modify { id = "getBackButton", visible = showBack }
        dlgMain:modify { id = "palAppendButton", visible = showPalAppend }
        dlgMain:modify { id = "gradientButton", visible = showGradient }
        dlgMain:modify { id = "sampleButton", visible = showSample }
        dlgMain:modify { id = "exitMainButton", visible = showExit }
        dlgMain:modify { id = "harmonyCanvas", visible = harmonyType ~= "NONE" }

        updateColorBar(false)

        dlgOptions:close()
    end
}

dlgOptions:button {
    id = "exitOptionsButton",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        -- TODO: Modify as many dlgOptions widgets as you can to reset them to
        -- active when dialog is canceled.

        dlgOptions:close()
    end
}

-- endregion

do
    local fgColor <const> = app.fgColor
    local r8fg <const> = fgColor.red
    local g8fg <const> = fgColor.green
    local b8fg <const> = fgColor.blue
    local t8fg <const> = fgColor.alpha
    updateFromRgba8(r8fg, g8fg, b8fg, t8fg, false)

    local r8bg = 255 - r8fg
    local g8bg = 255 - g8fg
    local b8bg = 255 - b8fg
    local t8bg = t8fg
    if app.sprite then
        app.command.SwitchColors()
        local bgColor <const> = app.fgColor
        r8bg = bgColor.red
        g8bg = bgColor.green
        b8bg = bgColor.blue
        t8bg = bgColor.alpha
        app.command.SwitchColors()
    end
    updateFromRgba8(r8bg, g8bg, b8bg, t8bg, true)

    active.triggerAlphaRepaint = true
    active.triggerAxisRepaint = true
    active.triggerCircleRepaint = true
    active.triggerHarmonyRepaint = true
    dlgMain:repaint()
end

dlgMain:show {
    autoscrollbars = false,
    wait = false
}