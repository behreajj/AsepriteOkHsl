dofile("./ok_color.lua")

local axes <const> = { "LIGHTNESS", "SATURATION" }
local harmonyTypes <const> = {
    "ANALOGOUS",
    "COMPLEMENT",
    "NONE",
    -- "SHADING",
    "SPLIT",
    "SQUARE",
    "TETRADIC",
    "TRIADIC"
}
local huePresets <const> = { "CCW", "CW", "FAR", "NEAR" }

local tau <const> = 6.2831853071796
local oneTau <const> = 0.1591549430919
local sqrt32 <const> = 0.86602540378444

local defaults <const> = {
    -- TODO: Account for screen scale?
    wCanvas = 180,
    hCanvasAxis = 12,
    hCanvasAlpha = 12,
    hCanvasCircle = 180,
    hCanvasHarmony = 12,

    aCheck = 0.5,
    bCheck = 0.8,
    wCheck = 6,
    hCheck = 6,

    reticleSize = 8,
    reticleStroke = 2,
    harmonyReticleSize = 4,
    harmonyReticleStroke = 1,
    swatchSize = 17,
    textDisplayLimit = 50,
    radiansOffset = math.rad(60),

    useBack = false,
    useSat = false,
    satAxis = 1.0,
    lightAxis = 0.5,
    harmonyType = "NONE",

    foreKey = "&FORE",
    backKey = "&BACK",
    sampleKey = "S&AMPLE",
    gradientKey = "&GRADIENT",
    optionsKey = "&+",
    exitKey = "&X",

    showForeButton = true,
    showBackButton = true,
    showSampleButton = false,
    showGradientButton = false,
    showExitButton = true,

    swatchCount = 5,
    shadingCount = 7,
    huePreset = "NEAR",
    rBitDepth = 8,
    gBitDepth = 8,
    bBitDepth = 8,
    tBitDepth = 8,
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

    useBack = defaults.useBack,
    satAxis = defaults.satAxis,
    lightAxis = defaults.lightAxis,

    rBitDepth = defaults.rBitDepth,
    gBitDepth = defaults.gBitDepth,
    bBitDepth = defaults.bBitDepth,
    tBitDepth = defaults.tBitDepth,

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
    local r01cl = math.min(math.max(r01, 0), 1)
    local g01cl = math.min(math.max(g01, 0), 1)
    local b01cl = math.min(math.max(b01, 0), 1)

    local r8 <const> = math.floor(r01cl * 255 + 0.5)
    local g8 <const> = math.floor(g01cl * 255 + 0.5)
    local b8 <const> = math.floor(b01cl * 255 + 0.5)

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

    local needsRepaint <const> = active.triggerCircleRepaint
        or active.wCanvasCircle ~= wCanvas
        or active.hCanvasCircle ~= hCanvas

    active.wCanvasCircle = wCanvas
    active.hCanvasCircle = hCanvas

    local xCenter <const> = wCanvas * 0.5
    local yCenter <const> = hCanvas * 0.5
    local shortEdge <const> = math.min(wCanvas, hCanvas)
    local radiusCanvas <const> = (shortEdge - 1.0) * 0.5

    local themeColors <const> = app.theme.color
    local radiansOffset <const> = active.radiansOffset

    local useSat <const> = active.useSat
    local useBack <const> = active.useBack

    local hueFore <const> = active.hueFore
    local satFore <const> = active.satFore
    local lightFore <const> = active.lightFore

    local hueBack <const> = active.hueBack
    local satBack <const> = active.satBack
    local lightBack <const> = active.lightBack

    local hueActive <const> = useBack and hueBack or hueFore
    local satActive <const> = useBack and satBack or satFore
    local lightActive <const> = useBack and lightBack or lightFore

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
    local xReticle <const> = math.cos(radiansActive)
    local yReticle <const> = math.sin(radiansActive)

    local reticleSize <const> = defaults.reticleSize
    local reticleHalf <const> = reticleSize // 2
    local reticleColor <const> = lightActive < 0.5
        and Color(255, 255, 255, 255)
        or Color(0, 0, 0, 255)
    ctx.color = reticleColor
    ctx.strokeWidth = defaults.reticleStroke
    ctx:strokeRect(Rectangle(
        (xCenter + xReticle * magCanvas) - reticleHalf,
        (yCenter - yReticle * magCanvas) - reticleHalf,
        reticleSize, reticleSize))

    -- Draw harmony reticles.
    local harmonyType <const> = active.harmonyType
    if harmonyType ~= "NONE" and harmonyType ~= "SHADING" then
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
                (xCenter + xAna0 * lAna) - harmRetHalf,
                (yCenter - yAna0 * lAna) - harmRetHalf)
            pts[2] = Point(
                (xCenter + xAna1 * lAna) - harmRetHalf,
                (yCenter - yAna1 * lAna) - harmRetHalf)
        elseif harmonyType == "COMPLEMENT" then
            -- 180 degrees
            local lCmp <const> = useSat
                and (1.0 - magActive) * radiusCanvas
                or magCanvas

            pts[1] = Point(
                (xCenter - xReticle * lCmp) - harmRetHalf,
                (yCenter + yReticle * lCmp) - harmRetHalf)
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
                (xCenter + xSpl0 * lSpl) - harmRetHalf,
                (yCenter - ySpl0 * lSpl) - harmRetHalf)
            pts[2] = Point(
                (xCenter + xSpl1 * lSpl) - harmRetHalf,
                (yCenter - ySpl1 * lSpl) - harmRetHalf)
        elseif harmonyType == "SQUARE" then
            -- 90, 180, 270 degrees
            local lCmp <const> = useSat
                and (1.0 - magActive) * radiusCanvas
                or magCanvas
            local lSqr <const> = useSat
                and 0.5 * radiusCanvas
                or magCanvas

            pts[1] = Point(
                (xCenter - yReticle * lSqr) - harmRetHalf,
                (yCenter - xReticle * lSqr) - harmRetHalf)
            pts[2] = Point(
                (xCenter - xReticle * lCmp) - harmRetHalf,
                (yCenter + yReticle * lCmp) - harmRetHalf)
            pts[3] = Point(
                (xCenter + yReticle * lSqr) - harmRetHalf,
                (yCenter + xReticle * lSqr) - harmRetHalf)
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
                (xCenter + xTet0 * lTri) - harmRetHalf,
                (yCenter - yTet0 * lTri) - harmRetHalf)
            pts[2] = Point(
                (xCenter - xReticle * lCmp) - harmRetHalf,
                (yCenter + yReticle * lCmp) - harmRetHalf)
            pts[3] = Point(
                (xCenter + xTet2 * lTet) - harmRetHalf,
                (yCenter - yTet2 * lTet) - harmRetHalf)
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
                (xCenter + xTri0 * lTri) - harmRetHalf,
                (yCenter - yTri0 * lTri) - harmRetHalf)
            pts[2] = Point(
                (xCenter + xTri1 * lTri) - harmRetHalf,
                (yCenter - yTri1 * lTri) - harmRetHalf)
        end

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

        local rBitDepth <const> = active.rBitDepth
        local gBitDepth <const> = active.gBitDepth
        local bBitDepth <const> = active.bBitDepth

        local bShift <const> = 0
        local gShift <const> = bShift + bBitDepth
        local rShift <const> = gShift + gBitDepth
        local hexPad <const> = math.ceil((rShift + rBitDepth) * 0.25)

        local bMax <const> = (1 << bBitDepth) - 1
        local gMax <const> = (1 << gBitDepth) - 1
        local rMax <const> = (1 << rBitDepth) - 1

        local hex <const> = math.floor(redActive * rMax + 0.5) << rShift
            | math.floor(greenActive * gMax + 0.5) << gShift
            | math.floor(blueActive * bMax + 0.5) << bShift

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
        local useBack <const> = active.useBack

        local hueFore <const> = active.hueFore
        local satFore <const> = active.satFore
        local lightFore <const> = active.lightFore

        local hueBack <const> = active.hueBack
        local satBack <const> = active.satBack
        local lightBack <const> = active.lightBack

        local hueActive <const> = useBack and hueBack or hueFore
        local satActive <const> = useBack and satBack or satFore
        local lightActive <const> = useBack and lightBack or lightFore

        if isAnalog then
            local lAna <const> = (lightActive * 2.0 + 0.5) / 3.0
            local h030 <const> = hueActive + 0.083333333
            local h330 <const> = hueActive - 0.083333333

            local r0 <const>, g0 <const>, b0 <const> = okhslToRgb24(h030, satActive, lAna)
            local r1 <const>, g1 <const>, b1 <const> = okhslToRgb24(h330, satActive, lAna)

            active.byteStrHarmony = string.pack(
                "B B B B B B B B",
                r0, g0, b0, 255, r1, g1, b1, 255)
        elseif isCompl then
            local lCmp <const> = 1.0 - lightActive
            local h180 <const> = hueActive + 0.5

            local r0 <const>, g0 <const>, b0 <const> = okhslToRgb24(h180, satActive, lCmp)

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
            -- TODO: Implement.

            -- TODO: This should be adjustable.
            local shadingCount <const> = defaults.shadingCount
        elseif isSplit then
            local lSpl <const> = (2.5 - lightActive * 2.0) / 3.0
            local h150 = hueActive + 0.41666667
            local h210 = hueActive - 0.41666667

            local r0 <const>, g0 <const>, b0 <const> = okhslToRgb24(h150, satActive, lSpl)
            local r1 <const>, g1 <const>, b1 <const> = okhslToRgb24(h210, satActive, lSpl)

            active.byteStrHarmony = string.pack(
                "B B B B B B B B",
                r0, g0, b0, 255, r1, g1, b1, 255)
        elseif isSquare then
            local lCmp <const> = 1.0 - lightActive
            local lSqr <const> = 0.5
            local h090 = hueActive + 0.25
            local h180 = hueActive + 0.5
            local h270 = hueActive - 0.25

            local r0 <const>, g0 <const>, b0 <const> = okhslToRgb24(h090, satActive, lSqr)
            local r1 <const>, g1 <const>, b1 <const> = okhslToRgb24(h180, satActive, lCmp)
            local r2 <const>, g2 <const>, b2 <const> = okhslToRgb24(h270, satActive, lSqr)

            active.byteStrHarmony = string.pack(
                "B B B B B B B B B B B B",
                r0, g0, b0, 255, r1, g1, b1, 255, r2, g2, b2, 255)
        elseif isTetradic then
            local lTri <const> = (2.0 - lightActive) / 3.0
            local lCmp <const> = 1.0 - lightActive
            local lTet <const> = (1.0 + lightActive) / 3.0
            local h120 <const> = hueActive + 0.33333333
            local h180 <const> = hueActive + 0.5
            local h300 <const> = hueActive - 0.16666667

            local r0 <const>, g0 <const>, b0 <const> = okhslToRgb24(h120, satActive, lTri)
            local r1 <const>, g1 <const>, b1 <const> = okhslToRgb24(h180, satActive, lCmp)
            local r2 <const>, g2 <const>, b2 <const> = okhslToRgb24(h300, satActive, lTet)

            active.byteStrHarmony = string.pack(
                "B B B B B B B B B B B B",
                r0, g0, b0, 255, r1, g1, b1, 255, r2, g2, b2, 255)
        elseif isTriadic then
            local lTri <const> = (2.0 - lightActive) / 3.0
            local h120 <const> = hueActive + 0.33333333
            local h240 <const> = hueActive - 0.33333333

            local r0 <const>, g0 <const>, b0 <const> = okhslToRgb24(h120, satActive, lTri)
            local r1 <const>, g1 <const>, b1 <const> = okhslToRgb24(h240, satActive, lTri)

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
        -- TODO: This should be adjustable.
        wCanvasNative = defaults.shadingCount
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
---@param useBack boolean
local function updateFromRgba8(r8, g8, b8, t8, useBack)
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
    local min <const> = math.min
    local max <const> = math.max
    local floor <const> = math.floor

    ---@type Color[]
    local aseColors <const> = {}
    local i = 0
    while i < swatchCount do
        local t <const> = i * toFac
        local u <const> = 1.0 - t

        local tMix <const> = u * tOrig + t * tDest

        local r01, g01, b01 = 0.0, 0.0, 0.0
        if useLabMix then
            local lMix <const> = u * lLabOrig + t * lLabDest
            local aMix <const> = u * aLabOrig + t * aLabDest
            local bMix <const> = u * bLabOrig + t * bLabDest
            r01, g01, b01 = labToRgb(lMix, aMix, bMix)
        else
            local hMix <const> = hueEasing(hOrig, hDest, t, 1.0)
            local sMix <const> = u * sOrig + t * sDest
            local lMix <const> = u * lOrig + t * lDest
            r01, g01, b01 = hslToRgb(hMix, sMix, lMix)
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

    local xCanvas <const> = math.min(math.max(event.x, 0), wCanvas - 1)
    local xNrm <const> = event.ctrlKey
        and 1.0
        or xCanvas / (wCanvas - 1.0)

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

    local useBack <const> = active.useBack

    if useSat then
        active.satAxis = xNrm
        active[useBack and "satBack" or "satFore"] = xNrm
    else
        active.lightAxis = xNrm
        active[useBack and "lightBack" or "lightFore"] = xNrm
    end

    local hActive <const> = useBack and active.hueBack or active.hueFore
    local sActive <const> = useBack and active.satBack or active.satFore
    local lActive <const> = useBack and active.lightBack or active.lightFore

    local r8 <const>, g8 <const>, b8 <const>,
    r01 <const>, g01 <const>, b01 <const> = okhslToRgb24(
        hActive, sActive, lActive)

    active[useBack and "redBack" or "redFore"] = r01
    active[useBack and "greenBack" or "greenFore"] = g01
    active[useBack and "blueBack" or "blueFore"] = b01

    local alphaActive <const> = useBack
        and active.alphaBack
        or active.alphaFore
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

    local useBack <const> = active.useBack

    active[useBack and "hueBack" or "hueFore"] = hueMouse
    active[useBack and "satBack" or "satFore"] = satMouse
    active[useBack and "lightBack" or "lightFore"] = lightMouse

    local r8 <const>, g8 <const>, b8 <const>,
    r01 <const>, g01 <const>, b01 <const> = okhslToRgb24(
        hueMouse, satMouse, lightMouse)

    active[useBack and "redBack" or "redFore"] = r01
    active[useBack and "greenBack" or "greenFore"] = g01
    active[useBack and "blueBack" or "blueFore"] = b01

    local alphaActive <const> = useBack
        and active.alphaBack
        or active.alphaFore
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
    active.triggerHarmonyRepaint = true
    dlgMain:repaint()
end

---@param event MouseEvent
local function onMouseUpHarmony(event)
    if event.button == MouseButton.NONE then return end

    local wCanvas <const> = active.wCanvasHarmony
    local hCanvas <const> = active.hCanvasHarmony
    if wCanvas <= 1 or hCanvas <= 1 then return end

    local harmonyType <const> = active.harmonyType
    local isAnalog <const> = harmonyType == "ANALOGOUS"
    local isCompl <const> = harmonyType == "COMPLEMENT"
    local isNone <const> = harmonyType == "NONE"
    local isShading <const> = harmonyType == "SHADING"
    local isSplit <const> = harmonyType == "SPLIT"
    local isSquare <const> = harmonyType == "SQUARE"
    local isTetradic <const> = harmonyType == "TETRADIC"
    local isTriadic <const> = harmonyType == "TRIADIC"

    local shadingCount = 1
    if isAnalog then
        shadingCount = 2
    elseif isCompl then
        shadingCount = 1
    elseif isNone then
        shadingCount = 1
    elseif isShading then
        -- TODO: This should be adjustable.
        shadingCount = defaults.shadingCount
    elseif isSplit then
        shadingCount = 2
    elseif isSquare then
        shadingCount = 3
    elseif isTetradic then
        shadingCount = 3
    elseif isTriadic then
        shadingCount = 2
    end

    local xCanvas <const> = math.min(math.max(event.x, 0), wCanvas - 1)
    local xNrm <const> = event.ctrlKey
        and 1.0
        or xCanvas / (wCanvas - 1.0)
    local xIdx <const> = math.floor(xNrm * (shadingCount - 1) + 0.5)
    local r8 <const>,
    g8 <const>,
    b8 <const> = string.byte(
        active.byteStrHarmony, 1 + xIdx * 4, 3 + xIdx * 4)

    local useBack <const> = active.useBack
    local alphaActive <const> = useBack
        and active.alphaBack
        or active.alphaFore
    local t8 <const> = math.floor(alphaActive * 255.0 + 0.5)

    updateFromRgba8(r8, g8, b8, t8, useBack)

    active.triggerAlphaRepaint = true
    active.triggerAxisRepaint = true
    active.triggerCircleRepaint = true
    dlgMain:repaint()

    if useBack then
        app.command.SwitchColors()
        app.fgColor = Color { r = r8, g = g8, b = b8, a = t8 }
        app.command.SwitchColors()
    else
        app.fgColor = Color { r = r8, g = g8, b = b8, a = t8 }
    end
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
        active.triggerHarmonyRepaint = true
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

dlgMain:canvas {
    id = "harmonyCanvas",
    focus = false,
    width = defaults.wCanvas,
    height = defaults.hCanvasHarmony,
    visible = defaults.harmonyType ~= "NONE",
    onmouseup = onMouseUpHarmony,
    onpaint = onPaintHarmony,
}

dlgMain:newrow { always = false }

dlgMain:button {
    id = "getForeButton",
    text = defaults.foreKey,
    focus = false,
    visible = defaults.showForeButton,
    onclick = function()
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

dlgOptions:combobox {
    id = "harmonyType",
    label = "Harmony:",
    option = defaults.harmonyType,
    options = harmonyTypes,
    focus = false
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
    visible = defaults.showGradientButton
}

dlgOptions:separator { text = "Hex Depth" }

dlgOptions:slider {
    id = "rBitDepth",
    label = "Red:",
    value = defaults.rBitDepth,
    min = 1,
    max = 8,
    focus = false
}

dlgOptions:newrow { always = false }

dlgOptions:slider {
    id = "gBitDepth",
    label = "Green:",
    value = defaults.gBitDepth,
    min = 1,
    max = 8,
    focus = false
}

dlgOptions:newrow { always = false }

dlgOptions:slider {
    id = "bBitDepth",
    label = "Blue:",
    value = defaults.bBitDepth,
    min = 1,
    max = 8,
    focus = false
}

dlgOptions:newrow { always = false }

dlgOptions:slider {
    id = "tBitDepth",
    label = "Alpha:",
    value = defaults.tBitDepth,
    min = 1,
    max = 8,
    focus = false,
    -- TODO: For now this is unused.
    visible = false,
}

dlgOptions:separator {}

dlgOptions:check {
    id = "showFore",
    label = "Buttons:",
    text = "Fore",
    selected = defaults.showForeButton,
    focus = false
}

dlgOptions:check {
    id = "showBack",
    text = "Back",
    selected = defaults.showBackButton,
    focus = false
}

dlgOptions:check {
    id = "showExit",
    text = "X",
    selected = defaults.showExitButton,
    focus = false
}

dlgOptions:newrow { always = false }

dlgOptions:check {
    id = "showSample",
    text = "Sample",
    selected = defaults.showSampleButton,
    focus = false
}

dlgOptions:check {
    id = "showGradient",
    text = "Gradient",
    selected = defaults.showGradientButton,
    focus = false,
    onclick = function()
        local args <const> = dlgOptions.data
        local showGradient <const> = args.showGradient --[[@as boolean]]
        dlgOptions:modify { id = "swatchCount", visible = showGradient }
        dlgOptions:modify { id = "huePreset", visible = showGradient }
    end
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

        local showFore <const> = args.showFore --[[@as boolean]]
        local showBack <const> = args.showBack --[[@as boolean]]
        local showGradient <const> = args.showGradient --[[@as boolean]]
        local showSample <const> = args.showSample --[[@as boolean]]
        local showExit <const> = args.showExit --[[@as boolean]]

        local rBitDepth <const> = args.rBitDepth --[[@as integer]]
        local gBitDepth <const> = args.gBitDepth --[[@as integer]]
        local bBitDepth <const> = args.bBitDepth --[[@as integer]]
        local tBitDepth <const> = args.tBitDepth --[[@as integer]]

        active.radiansOffset = (-math.rad(degreesOffset)) % tau
        active.useSat = axis == "SATURATION"
        active.harmonyType = harmonyType
        active.rBitDepth = rBitDepth
        active.gBitDepth = gBitDepth
        active.bBitDepth = bBitDepth
        active.tBitDepth = tBitDepth

        active.triggerAlphaRepaint = true
        active.triggerAxisRepaint = true
        active.triggerCircleRepaint = true
        active.triggerHarmonyRepaint = true

        dlgMain:repaint()

        dlgMain:modify { id = "getForeButton", visible = showFore }
        dlgMain:modify { id = "getBackButton", visible = showBack }
        dlgMain:modify { id = "gradientButton", visible = showGradient }
        dlgMain:modify { id = "sampleButton", visible = showSample }
        dlgMain:modify { id = "exitMainButton", visible = showExit }
        dlgMain:modify { id = "harmonyCanvas", visible = harmonyType ~= "NONE" }

        dlgOptions:close()
    end
}

dlgOptions:button {
    id = "exitOptionsButton",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        -- TODO: If show gradient button check box is ticked when dialog is
        -- open, then it is closed and reopened, the button check is still
        -- ticked, even though OK hasn't been pressed and the option has not
        -- been applied to the main dialog.
        dlgOptions:close()
    end
}

do
    local fgColor <const> = app.fgColor
    local r8fg <const> = fgColor.red
    local g8fg <const> = fgColor.green
    local b8fg <const> = fgColor.blue
    local t8fg <const> = fgColor.alpha
    updateFromRgba8(r8fg, g8fg, b8fg, t8fg, false)

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

dlgMain:show {
    autoscrollbars = false,
    wait = false
}