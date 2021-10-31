dofile("./ok_color.lua")

-- Copyright(c) 2021 Bjorn Ottosson
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this softwareand associated documentation files(the "Software"), to deal in
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

local defaults = {
    base = Color(255, 0, 0, 255),

    colorMode = "HSL",
    alpha = 255,

    hslHue = 29,
    hslSat = 100,
    hslLgt = 57,

    hsvHue = 29,
    hsvSat = 100,
    hsvVal = 100,

    labLgt = 50,
    labA = 0,
    labB = 0,

    showWheelSettings = false,
    size = 256,
    minLight = 5,
    maxLight = 95,
    sectorCount = 0,
    ringCount = 0,
    frames = 32,
    fps = 24,

    harmonyType = "NONE",
    analogies = {
        Color(244,   0, 132, 255),
        Color(200, 110,   0, 255) },
    complement = { Color(  0, 154, 172, 255) },
    splits = {
        Color(  0, 159, 138, 255),
        Color(  0, 146, 212, 255) },
    squares = {
        Color(127, 148,   0, 255),
        Color(  0, 154, 172, 255),
        Color(160,  88, 255, 255) },
    triads = {
        Color( 89, 123, 255, 255),
        Color(  0, 164,  71, 255) },

    shadingCount = 7,
    shadowLight = 0.1,
    dayLight = 0.9,
    hYel = 110.0 / 360.0,
    minChroma = 0.01,
    lgtDesatFac = 0.75,
    shdDesatFac = 0.75,
    srcLightWeight = 0.3333333333333333,
    greenHue = 146 / 360.0,
    minGreenOffset = 0.3,
    maxGreenOffset = 0.6,
    shadowHue = 291.0 / 360.0,
    dayHue = 96.0 / 360.0,

    gradWidth = 256,
    gradHeight = 32,
    swatchCount = 8
}

local function copyColorByValue(aseColor)
    return Color(
        aseColor.red,
        aseColor.green,
        aseColor.blue,
        aseColor.alpha)
end

local function aseColorToRgb01(ase)
    return {
        r = ase.red * 0.00392156862745098,
        g = ase.green * 0.00392156862745098,
        b = ase.blue * 0.00392156862745098 }
end

local function assignColor(aseColor)
    if aseColor.alpha > 0 then
        return copyColorByValue(aseColor)
    else
        return Color(0, 0, 0, 0)
    end
end

local function colorToHexWeb(aseColor)
    return string.format("%06x",
        aseColor.red << 0x10
        | aseColor.green << 0x08
        | aseColor.blue)
end

local function createNewFrames(sprite, count, duration)
    if not sprite then
        app.alert("Sprite could not be found.")
        return {}
    end

    if count < 1 then return {} end
    if count > 256 then
        local response = app.alert {
            title = "Warning",
            text = {
                string.format(
                    "This script will create %d frames,",
                    count),
                string.format(
                    "%d beyond the limit of %d.",
                    count - 256,
                    256),
                "Do you wish to proceed?"
            },
            buttons = { "&YES", "&NO" }
        }

        if response == 2 then
            return {}
        end
    end

    local valDur = duration or 1
    local valCount = count or 1
    if valCount < 1 then valCount = 1 end

    local frames = {}
    app.transaction(function()
        for i = 1, valCount, 1 do
            local frame = sprite:newEmptyFrame()
            frame.duration = valDur
            frames[i] = frame
        end
    end)
    return frames
end

local function distAngleUnsigned(a, b, range)
    local valRange = range or 360.0
    local halfRange = valRange * 0.5
    return halfRange - math.abs(math.abs(
        (b % valRange) - (a % valRange))
        - halfRange)
end

local function lerpAngleNear(origin, dest, t, range)
    local valRange = range or 360.0
    local halfRange = valRange * 0.5

    local o = origin % valRange
    local d = dest % valRange
    local diff = d - o
    local u = 1.0 - t

    if diff == 0.0 then
        return o
    elseif o < d and diff > halfRange then
        return (u * (o + valRange) + t * d) % valRange
    elseif o > d and diff < -halfRange then
        return (u * o + t * (d + valRange)) % valRange
    else
        return u * o + t * d
    end
end

local function lerpAngleCcw(origin, dest, t, range)
    local valRange = range or 360.0
    local o = origin % valRange
    local d = dest % valRange
    local diff = d - o
    local u = 1.0 - t

    if diff == 0.0 then
        return o
    elseif o > d then
        return (u * o + t * (d + valRange)) % valRange
    else
        return u * o + t * d
    end
end

local function lerpAngleCw(origin, dest, t, range)
    local valRange = range or 360.0
    local o = origin % valRange
    local d = dest % valRange
    local diff = d - o
    local u = 1.0 - t

    if diff == 0.0 then
        return d
    elseif o < d then
        return (u * (o + valRange) + t * d) % valRange
    else
        return u * o + t * d
    end
end

local function quantizeSigned(a, levels)
    if levels ~= 0 then
        return math.floor(0.5 + a * levels) / levels
    else
        return a
    end
end

local function quantizeUnsigned(a, levels)
    if levels > 1 then
        return math.max(0.0,
            (math.ceil(a * levels) - 1.0)
            / (levels - 1.0))
    else
        return math.max(0.0, a)
    end
end

local function srgb01ToHex(srgb, alpha)
    local va = alpha or 255
    return (va << 0x18)
        | math.tointeger(0.5 + 0xff * math.min(math.max(srgb.b, 0.0), 1.0)) << 0x10
        | math.tointeger(0.5 + 0xff * math.min(math.max(srgb.g, 0.0), 1.0)) << 0x08
        | math.tointeger(0.5 + 0xff * math.min(math.max(srgb.r, 0.0), 1.0))
end

local function srgb01ToAseColor(srgb, alpha)
    return Color(
        math.tointeger(0.5 + 0xff * math.min(math.max(srgb.r, 0.0), 1.0)),
        math.tointeger(0.5 + 0xff * math.min(math.max(srgb.g, 0.0), 1.0)),
        math.tointeger(0.5 + 0xff * math.min(math.max(srgb.b, 0.0), 1.0)),
        alpha or 255)
end

local function round(v)
    if v < -0.0 then return math.tointeger(v - 0.5) end
    if v > 0.0 then return math.tointeger(v + 0.5) end
    return 0.0
end

local function zigZag(t)
    local a = t * 0.5
    local b = a - math.floor(a)
    return 1.0 - math.abs(b + b - 1.0)
end

local function updateShades(dialog, primary, shades, reserveHue)
    local srgb = aseColorToRgb01(primary)
    local srcHsl = ok_color.srgb_to_okhsl(srgb)

    local alpha = primary.alpha
    local l = srcHsl.l
    local s = srcHsl.s
    local h = srcHsl.h

    -- Decide on clockwise or counter-clockwise based
    -- on color's warmth or coolness.
    -- The LCh hue for yellow is 103 degrees.
    local hYel = defaults.hYel
    local hBlu = hYel + 0.5
    local lerpFunc = nil
    if h < hYel or h >= hBlu then
        lerpFunc = lerpAngleCcw
    else
        lerpFunc = lerpAngleCw
    end

    -- Minimum and maximum light based on place in loop.
    local shadowLight = defaults.shadowLight
    local dayLight = defaults.dayLight

        -- Yellows are very saturated at high light;
    -- Desaturate them to get a better shade.
    -- Conversely, blues easily fall out of gamut
    -- so the shade factor is separate.
    local lgtDesatFac = defaults.lgtDesatFac
    local shdDesatFac = defaults.shdDesatFac
    local minChroma = defaults.minChroma
    local cVal = math.max(minChroma, s)
    local desatChromaLgt = cVal * lgtDesatFac
    local desatChromaShd = cVal * shdDesatFac

    -- Amount to mix between base light and loop light.
    local srcLightWeight = defaults.srcLightWeight
    local cmpLightWeight = 1.0 - srcLightWeight

    -- The warm-cool dichotomy works poorly for greens.
    -- For that reason, the closer a hue is to green,
    -- the more it uses absolute hue shifting.
    -- Green is approximately at hue 140.
    local offsetMix = distAngleUnsigned(h, defaults.greenHue, 1.0)
    local offsetScale = (1.0 - offsetMix) * defaults.maxGreenOffset
                              + offsetMix * defaults.minGreenOffset

    -- Absolute hues for shadow and light.
    -- This could also be combined with the origin hue +/-
    -- a shift which is then mixed with the absolute hue.
    local shadowHue = defaults.shadowHue
    local dayHue = defaults.dayHue

    local shadingCount = defaults.shadingCount
    local toFac = 1.0 / (shadingCount - 1.0)
    for i = 1, shadingCount, 1 do
        local iFac = (i - 1) * toFac
        local lItr = (1.0 - iFac) * shadowLight
                           + iFac * dayLight

        -- Idealized hue from violet shadow to
        -- off-yellow daylight.
        local hAbs = lerpFunc(shadowHue, dayHue, lItr, 1.0)

        -- The middle sample should be closest to base color.
        -- The fac needs to be 0.0. That's why zigzag is
        -- used to convert to an oscillation.
        local lMixed = srcLightWeight * l
                     + cmpLightWeight * lItr
        local lZig = zigZag(lMixed)
        local fac = offsetScale * lZig
        local hMixed = lerpAngleNear(h, hAbs, fac, 1.0)

        -- Desaturate brights and darks.
        -- Min chroma gives even grays a slight chroma.
        local chromaTarget = desatChromaLgt
        if lMixed < 0.5 then chromaTarget = desatChromaShd end
        local cMixed = (1.0 - lZig) * cVal + lZig * chromaTarget
        cMixed = math.max(minChroma, cMixed)

        -- local clr = lchToRgb(lMixed * 100.0, cMixed, hMixed, a)
        local clr = ok_color.okhsl_to_srgb({
            h = hMixed,
            s = cMixed,
            l = lMixed })
        local aseColor = srgb01ToAseColor(clr, alpha)
        shades[i] = aseColor
    end

    dialog:modify { id = "shading", colors = shades }
end

local function updateHarmonies(dialog, primary)
    local h30 = 0.08333333333333333
    local h90 = 0.25
    local h120 = 0.3333333333333333
    local h150 = 0.4166666666666667
    local h180 = 0.5
    local h210 = 0.5833333333333333
    local h270 = 0.75

    local srgb = aseColorToRgb01(primary)
    local srcHsl = ok_color.srgb_to_okhsl(srgb)
    local h = srcHsl.h
    local s = srcHsl.s
    local l = srcHsl.l

    local ana0 = ok_color.okhsl_to_srgb({ h = h - h30, s = s, l = l })
    local ana1 = ok_color.okhsl_to_srgb({ h = h + h30, s = s, l = l })

    local tri0 = ok_color.okhsl_to_srgb({ h = h - h120, s = s, l = l })
    local tri1 = ok_color.okhsl_to_srgb({ h = h + h120, s = s, l = l })

    local split0 = ok_color.okhsl_to_srgb({ h = h + h150, s = s, l = l })
    local split1 = ok_color.okhsl_to_srgb({ h = h + h210, s = s, l = l })

    local square0 = ok_color.okhsl_to_srgb({ h = h + h90, s = s, l = l })
    local square1 = ok_color.okhsl_to_srgb({ h = h + h180, s = s, l = l })
    local square2 = ok_color.okhsl_to_srgb({ h = h + h270, s = s, l = l })

    local tris = {
        srgb01ToAseColor(tri0),
        srgb01ToAseColor(tri1)
    }

    local analogues = {
        srgb01ToAseColor(ana0),
        srgb01ToAseColor(ana1)
    }

    local splits = {
        srgb01ToAseColor(split0),
        srgb01ToAseColor(split1)
    }

    local squares = {
        srgb01ToAseColor(square0),
        srgb01ToAseColor(square1),
        srgb01ToAseColor(square2)
    }

    dialog:modify { id = "complement", colors = { squares[2] } }
    dialog:modify { id = "triadic", colors = tris }
    dialog:modify { id = "analogous", colors = analogues }
    dialog:modify { id = "split", colors = splits }
    dialog:modify { id = "square", colors = squares }
end

local function setLab(dialog, lab)
    local labLgtInt = math.tointeger(0.5 + 100.0 * lab.L)
    local labAInt = round(100.0 * lab.a)
    local labBInt = round(100.0 * lab.b)
    dialog:modify { id = "labLgt", value = labLgtInt }
    dialog:modify { id = "labA", value = labAInt }
    dialog:modify { id = "labB", value = labBInt }
end

local function setHsl(dialog, hsl)
    local hslLgtInt = math.tointeger(0.5 + 100.0 * hsl.l)
    local hslSatInt = math.tointeger(0.5 + 100.0 * hsl.s)
    local hslHueInt = math.tointeger(0.5 + 360.0 * hsl.h)
    if hslSatInt > 0
        and hslLgtInt > 0
        and hslLgtInt < 100 then
        dialog:modify { id = "hslHue", value = hslHueInt }
    end
    dialog:modify { id = "hslSat", value = hslSatInt }
    dialog:modify { id = "hslLgt", value = hslLgtInt }
end

local function setHsv(dialog, hsv)
    local hsvValInt = math.tointeger(0.5 + 100.0 * hsv.v)
    local hsvSatInt = math.tointeger(0.5 + 100.0 * hsv.s)
    local hsvHueInt = math.tointeger(0.5 + 360.0 * hsv.h)
    if hsvSatInt > 0 and hsvValInt > 0 then
        dialog:modify { id = "hsvHue", value = hsvHueInt }
    end
    dialog:modify { id = "hsvSat", value = hsvSatInt }
    dialog:modify { id = "hsvVal", value = hsvValInt }
end

local function setFromAse(dialog, aseColor, primary, shades)
    primary = copyColorByValue(aseColor)
    dialog:modify { id = "baseColor", colors = { primary } }
    dialog:modify { id = "alpha", value = primary.alpha }
    dialog:modify { id = "hexCode", text = colorToHexWeb(primary) }

    local srgb = aseColorToRgb01(primary)
    local lab = ok_color.srgb_to_oklab(srgb)
    local hsl = ok_color.oklab_to_okhsl(lab)
    local hsv = ok_color.oklab_to_okhsv(lab)

    -- print(string.format(
    --     "L: %.6f a: %.6f b: %.6f",
    --     lab.L, lab.a, lab.b))

    setLab(dialog, lab)
    setHsl(dialog, hsl)
    setHsv(dialog, hsv)

    updateHarmonies(dialog, primary)
    updateShades(dialog, primary, shades,
        dialog.data.hslHue * 0.002777777777777778)
end

local function updateColor(dialog, primary, shades)
    local args = dialog.data
    local alpha = args.alpha
    local colorMode = args.colorMode

    if colorMode == "HSV" then
        local lab = ok_color.okhsv_to_oklab({
            h = args.hsvHue * 0.002777777777777778,
            s = args.hsvSat * 0.01,
            v = args.hsvVal * 0.01 })
        local rgb01 = ok_color.oklab_to_srgb(lab)
        primary = srgb01ToAseColor(rgb01, alpha)

        -- Update other color sliders.
        local hsl = ok_color.oklab_to_okhsl(lab)
        setHsl(dialog, hsl)
        setLab(dialog, lab)
    elseif colorMode == "LAB" then
        local lab = {
            L = args.labLgt * 0.01,
            a = args.labA * 0.01,
            b = args.labB * 0.01 }
        local rgb01 = ok_color.oklab_to_srgb(lab)
        primary = srgb01ToAseColor(rgb01, alpha)

        -- Update other color sliders.
        local hsl = ok_color.oklab_to_okhsl(lab)
        local hsv = ok_color.oklab_to_okhsv(lab)
        setHsl(dialog, hsl)
        setHsv(dialog, hsv)
    else
        local lab = ok_color.okhsl_to_oklab({
            h = args.hslHue * 0.002777777777777778,
            s = args.hslSat * 0.01,
            l = args.hslLgt * 0.01 })
        local rgb01 = ok_color.oklab_to_srgb(lab)
        primary = srgb01ToAseColor(rgb01, alpha)

        -- Update other color sliders.
        local hsv = ok_color.oklab_to_okhsv(lab)
        setHsv(dialog, hsv)
        setLab(dialog, lab)
    end

    dialog:modify {
        id = "baseColor",
        colors = { primary }
    }

    dialog:modify {
        id = "hexCode",
        text = colorToHexWeb(primary)
    }

    updateHarmonies(dialog, primary)
    updateShades(dialog, primary, shades,
        args.hslHue * 0.002777777777777778)
end

local palColors = {
    Color(  0,   0,   0,   0),
    Color(  0,   0,   0, 255),
    Color(255, 255, 255, 255),
    Color(255,   0,   0, 255),
    Color(255, 255,   0, 255),
    Color(  0, 255,   0, 255),
    Color(  0, 255, 255, 255),
    Color(  0,   0, 255, 255),
    Color(255,   0, 255, 255)
}

local colorModes = { "HSL", "HSV", "LAB" }

local harmonies = {
    "ANALOGOUS",
    "COMPLEMENT",
    "NONE",
    "SHADING",
    "SPLIT",
    "SQUARE",
    "TRIADIC"
}

local primary = Color(255, 0, 0, 255)
local shades = {
    Color(113,   9,  30, 255),
    Color(148,  21,  43, 255),
    Color(183,  37,  54, 255),
    Color(214,  62,  62, 255),
    Color(234,  99,  78, 255),
    Color(244, 139, 104, 255),
    Color(248, 178, 139, 255)
}
local dlg = Dialog { title = "OkHsl Color Picker" }

dlg:button {
    id = "fgGet",
    label = "Get:",
    text = "&FORE",
    focus = false,
    onclick = function()
       setFromAse(dlg, app.fgColor, primary, shades)
    end
}

dlg:button {
    id = "bgGet",
    text = "&BACK",
    focus = false,
    onclick = function()
       app.command.SwitchColors()
       setFromAse(dlg, app.fgColor, primary, shades)
       app.command.SwitchColors()
    end
}

dlg:newrow { always = false }

dlg:entry {
    id = "hexCode",
    label = "Hex: #",
    text = "ff0000",
    focus = false
}

dlg:newrow { always = false }

dlg:shades {
    id = "baseColor",
    label = "Color:",
    mode = "pick",
    colors = { defaults.base },
    onclick = function(ev)
        local button = ev.button
        if button == MouseButton.LEFT then
            app.fgColor = assignColor(ev.color)
        elseif button == MouseButton.RIGHT then
            app.command.SwitchColors()
            app.fgColor = assignColor(ev.color)
            app.command.SwitchColors()
        end
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "colorMode",
    label = "Mode:",
    option = defaults.colorMode,
    options = colorModes,
    onchange = function()
        local args = dlg.data
        local colorMode = args.colorMode

        local isHsl = colorMode == "HSL"
        dlg:modify { id = "hslHue", visible = isHsl }
        dlg:modify { id = "hslSat", visible = isHsl }
        dlg:modify { id = "hslLgt", visible = isHsl }

        local isHsv = colorMode == "HSV"
        dlg:modify { id = "hsvHue", visible = isHsv }
        dlg:modify { id = "hsvSat", visible = isHsv }
        dlg:modify { id = "hsvVal", visible = isHsv }

        local isLab = colorMode == "LAB"
        dlg:modify { id = "labLgt", visible = isLab }
        dlg:modify { id = "labA", visible = isLab }
        dlg:modify { id = "labB", visible = isLab }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "hslHue",
    label = "Hue:",
    min = 0,
    max = 360,
    value = defaults.hslHue,
    visible = defaults.colorMode == "HSL",
    onchange = function()
        updateColor(dlg, primary, shades)
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "hslSat",
    label = "Saturation:",
    min = 0,
    max = 100,
    value = defaults.hslSat,
    visible = defaults.colorMode == "HSL",
    onchange = function()
        updateColor(dlg, primary, shades)
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "hslLgt",
    label = "Lightness:",
    min = 0,
    max = 100,
    value = defaults.hslLgt,
    visible = defaults.colorMode == "HSL",
    onchange = function()
        updateColor(dlg, primary, shades)
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "hsvHue",
    label = "Hue:",
    min = 0,
    max = 360,
    value = defaults.hsvHue,
    visible = defaults.colorMode == "HSV",
    onchange = function()
        updateColor(dlg, primary, shades)
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "hsvSat",
    label = "Saturation:",
    min = 0,
    max = 100,
    value = defaults.hsvSat,
    visible = defaults.colorMode == "HSV",
    onchange = function()
        updateColor(dlg, primary, shades)
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "hsvVal",
    label = "Value:",
    min = 0,
    max = 100,
    value = defaults.hsvVal,
    visible = defaults.colorMode == "HSV",
    onchange = function()
        updateColor(dlg, primary, shades)
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "labLgt",
    label = "Lightness:",
    min = 0,
    max = 100,
    value = defaults.labLgt,
    visible = defaults.colorMode == "LAB",
    onchange = function()
        updateColor(dlg, primary, shades)
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "labA",
    label = "A:",
    min = -32,
    max = 32,
    value = defaults.labA,
    visible = defaults.colorMode == "LAB",
    onchange = function()
        updateColor(dlg, primary, shades)
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "labB",
    label = "B:",
    min = -32,
    max = 32,
    value = defaults.labB,
    visible = defaults.colorMode == "LAB",
    onchange = function()
        updateColor(dlg, primary, shades)
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "alpha",
    label = "Alpha:",
    min = 0,
    max = 255,
    value = defaults.alpha,
    onchange = function()
        updateColor(dlg, primary, shades)
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "harmonyType",
    label = "Harmony:",
    option = defaults.harmonyType,
    options = harmonies,
    visible = defaults.showHarmonies,
    onchange = function()
        local args = dlg.data
        local md = args.harmonyType
        if md == "NONE" then
            dlg:modify { id = "analogous", visible = false }
            dlg:modify { id = "complement", visible = false }
            dlg:modify { id = "shading", visible = false }
            dlg:modify { id = "append", visible = false }
            dlg:modify { id = "split", visible = false }
            dlg:modify { id = "square", visible = false }
            dlg:modify { id = "triadic", visible = false }
        else
            dlg:modify { id = "analogous", visible = md == "ANALOGOUS" }
            dlg:modify { id = "complement", visible = md == "COMPLEMENT" }
            dlg:modify { id = "shading", visible = md == "SHADING" }
            dlg:modify { id = "append", visible = md == "SHADING" }
            dlg:modify { id = "split", visible = md == "SPLIT" }
            dlg:modify { id = "square", visible = md == "SQUARE" }
            dlg:modify { id = "triadic", visible = md == "TRIADIC" }
        end
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "analogous",
    label = "Analogous:",
    mode = "pick",
    colors = defaults.analogies,
    visible = defaults.harmonyType == "ANALOGOUS",
    onclick = function(ev)
        local button = ev.button
        if button == MouseButton.LEFT then
            app.fgColor = assignColor(ev.color)
        elseif button == MouseButton.RIGHT then
            app.command.SwitchColors()
            app.fgColor = assignColor(ev.color)
            app.command.SwitchColors()
        end
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "complement",
    label = "Complement:",
    mode = "pick",
    colors = defaults.complement,
    visible = defaults.harmonyType == "COMPLEMENT",
    onclick = function(ev)
        local button = ev.button
        if button == MouseButton.LEFT then
            app.fgColor = assignColor(ev.color)
        elseif button == MouseButton.RIGHT then
            app.command.SwitchColors()
            app.fgColor = assignColor(ev.color)
            app.command.SwitchColors()
        end
    end
}

dlg:shades {
    id = "shading",
    label = "Shading:",
    mode = "pick",
    colors = shades,
    visible = defaults.harmonyType == "SHADING",
    onclick = function(ev)
        local button = ev.button
        if button == MouseButton.LEFT then
            app.fgColor = assignColor(ev.color)
        elseif button == MouseButton.RIGHT then
            app.command.SwitchColors()
            app.fgColor = assignColor(ev.color)
            app.command.SwitchColors()
        end
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "append",
    text = "&APPEND",
    focus = false,
    visible = defaults.harmonyType == "SHADING",
    onclick = function()
        local activeSprite = app.activeSprite
        if activeSprite then
            local palette = activeSprite.palettes[1]
            local oldLen = #palette
            local shadingCount = defaults.shadingCount
            local newLen = oldLen + shadingCount

            app.transaction(function()
                palette:resize(newLen)
                for i = 0, shadingCount - 1, 1 do
                    palette:setColor(
                        oldLen + i,
                        copyColorByValue(
                            shades[i + 1]))
                end
            end)

            app.refresh()
        else
            app.alert("No active sprite.")
        end
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "split",
    label = "Split:",
    mode = "pick",
    colors = defaults.splits,
    visible = defaults.harmonyType == "SPLIT",
    onclick = function(ev)
        local button = ev.button
        if button == MouseButton.LEFT then
            app.fgColor = assignColor(ev.color)
        elseif button == MouseButton.RIGHT then
            app.command.SwitchColors()
            app.fgColor = assignColor(ev.color)
            app.command.SwitchColors()
        end
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "square",
    label = "Square:",
    mode = "pick",
    colors = defaults.squares,
    visible = defaults.harmonyType == "SQUARE",
    onclick = function(ev)
        local button = ev.button
        if button == MouseButton.LEFT then
            app.fgColor = assignColor(ev.color)
        elseif button == MouseButton.RIGHT then
            app.command.SwitchColors()
            app.fgColor = assignColor(ev.color)
            app.command.SwitchColors()
        end
    end
}

dlg:newrow { always = false }

dlg:shades {
    id = "triadic",
    label = "Triadic:",
    mode = "pick",
    colors = defaults.triads,
    visible = defaults.harmonyType == "TRIADIC",
    onclick = function(ev)
        local button = ev.button
        if button == MouseButton.LEFT then
            app.fgColor = assignColor(ev.color)
        elseif button == MouseButton.RIGHT then
            app.command.SwitchColors()
            app.fgColor = assignColor(ev.color)
            app.command.SwitchColors()
        end
    end
}

dlg:newrow { always = false }

dlg:check {
    id = "showWheelSettings",
    label = "Show:",
    text = "Wheel Settings",
    selected = defaults.showWheelSettings,
    onclick = function()
        local state = dlg.data.showWheelSettings
        dlg:modify { id = "size", visible = state }
        dlg:modify { id = "minLight", visible = state }
        dlg:modify { id = "maxLight", visible = state }
        dlg:modify { id = "frames", visible = state }
        dlg:modify { id = "sectorCount", visible = state }
        dlg:modify { id = "ringCount", visible = state }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "size",
    label = "Size:",
    min = 64,
    max = 512,
    value = defaults.size,
    visible = defaults.showWheelSettings
}

dlg:newrow { always = false }

dlg:slider {
    id = "minLight",
    label = "Light:",
    min = 1,
    max = 98,
    value = defaults.minLight,
    visible = defaults.showWheelSettings
}

dlg:slider {
    id = "maxLight",
    min = 2,
    max = 99,
    value = defaults.maxLight,
    visible = defaults.showWheelSettings
}

dlg:newrow { always = false }

dlg:slider {
    id = "frames",
    label = "Frames:",
    min = 1,
    max = 96,
    value = defaults.frames,
    visible = defaults.showWheelSettings
}

dlg:newrow { always = false }

dlg:slider {
    id = "sectorCount",
    label = "Sectors:",
    min = 0,
    max = 32,
    value = defaults.sectorCount,
    visible = defaults.showWheelSettings
}

dlg:newrow { always = false }

dlg:slider {
    id = "ringCount",
    label = "Rings:",
    min = 0,
    max = 32,
    value = defaults.ringCount,
    visible = defaults.showWheelSettings
}

dlg:newrow { always = false }

dlg:button {
    id = "gradient",
    text = "&GRADIENT",
    focus = false,
    onclick = function()

        local gradWidth = defaults.gradWidth
        local gradHeight = defaults.gradHeight
        local swatchCount = defaults.swatchCount

        local args = dlg.data
        local colorMode = args.colorMode

        local foreColor = app.fgColor
        local foreHex = 0xff000000 | foreColor.rgbaPixel
        local foreSrgb01 = aseColorToRgb01(foreColor)
        local foreLab = ok_color.srgb_to_oklab(foreSrgb01)

        local backColor = app.bgColor
        local backHex = 0xff000000 | backColor.rgbaPixel
        local backSrgb01 = aseColorToRgb01(backColor)
        local backLab = ok_color.srgb_to_oklab(backSrgb01)

        local lerpLab = function(fac)
            local u = 1.0 - fac
            local cL = u * backLab.L + fac * foreLab.L
            local ca = u * backLab.a + fac * foreLab.a
            local cb = u * backLab.b + fac * foreLab.b
            local csrgb01 = ok_color.oklab_to_srgb({ L = cL, a = ca, b = cb })
            return srgb01ToHex(csrgb01)
        end

        local lerpFunc = lerpLab
        if colorMode == "HSL" then
            local foreHsl = ok_color.oklab_to_okhsl(foreLab)
            local backHsl = ok_color.oklab_to_okhsl(backLab)
            if foreHsl.s < 0.00001 or backHsl.s < 0.00001 then
                lerpFunc = lerpLab
            else
                lerpFunc = function(fac)
                    if fac <= 0.0 then return backHex end
                    if fac >= 1.0 then return foreHex end
                    local u = 1.0 - fac
                    local ch = lerpAngleNear(backHsl.h, foreHsl.h, fac, 1.0)
                    local cs = u * backHsl.s + fac * foreHsl.s
                    local cl = u * backHsl.l + fac * foreHsl.l
                    local csrgb01 = ok_color.okhsl_to_srgb({ h = ch, s = cs, l = cl })
                    return srgb01ToHex(csrgb01)
                end
            end
        elseif colorMode == "HSV" then
            local foreHsv = ok_color.oklab_to_okhsv(foreLab)
            local backHsv = ok_color.oklab_to_okhsv(backLab)
            if foreHsv.s < 0.00001 or backHsv.s < 0.00001 then
                lerpFunc = lerpLab
            else
                lerpFunc = function(fac)
                    if fac <= 0.0 then return backHex end
                    if fac >= 1.0 then return foreHex end
                    local u = 1.0 - fac
                    local ch = lerpAngleNear(backHsv.h, foreHsv.h, fac, 1.0)
                    local cs = u * backHsv.s + fac * foreHsv.s
                    local cv = u * backHsv.v + fac * foreHsv.v
                    local csrgb01 = ok_color.okhsv_to_srgb({ h = ch, s = cs, v = cv })
                    return srgb01ToHex(csrgb01)
                end
            end
        end

        local gradSprite = Sprite(gradWidth, gradHeight)
        local firstCel = gradSprite.cels[1]
        local gradImg = Image(gradWidth, gradHeight)
        local gradImgPxItr = gradImg:pixels()
        local xToFac = 1.0 / (gradWidth - 1.0)
        for elm in gradImgPxItr do
            elm(lerpFunc(elm.x * xToFac))
        end

        firstCel.image = gradImg

        local pal = Palette(swatchCount)
        local iToFac = 1.0 / (swatchCount - 1.0)
        local swatchHexes = {}
        for i = 0, swatchCount - 1, 1 do
            local fac = i * iToFac
            local swatchHex = lerpFunc(fac)
            swatchHexes[1 + i] = swatchHex
            pal:setColor(i, swatchHex)
        end
        gradSprite:setPalette(pal)

        app.fgColor = Color(foreHex)
        app.command.SwitchColors()
        app.fgColor = Color(backHex)
        app.command.SwitchColors()

        app.refresh()
    end
}

dlg:button {
    id = "wheel",
    text = "&WHEEL",
    focus = false,
    onclick = function()
        -- There is some known discontinuity for saturated dark blues.
        -- See { h = 264.0 / 360.0, s = 100.0 / 100.0, l = 28.0 / 100.0 },
        -- hex code #0009c5.

        -- Cache methods.
        local atan2 = math.atan
        local sqrt = math.sqrt
        local trunc = math.tointeger
        local max = math.max
        local min = math.min
        local hsl_to_srgb = ok_color.okhsl_to_srgb

        -- Unpack arguments.
        local args = dlg.data
        local size = args.size or defaults.size
        local szInv = 1.0 / (size - 1.0)
        local iToStep = 1.0
        local reqFrames = args.frames or defaults.frames
        if reqFrames > 1 then iToStep = 1.0 / (reqFrames - 1.0) end
        local minLight = args.minLight or defaults.minLight
        local maxLight = args.maxLight or defaults.maxLight
        local ringCount = args.ringCount or defaults.ringCount
        local sectorCount = args.sectorCount or defaults.sectorCount

        -- Offset by 30 degrees to match Aseprite's color wheel.
        local angleOffset = math.rad(30.0)

        minLight = minLight * 0.01
        maxLight = maxLight * 0.01

        local wheelImgs = {}
        for i = 1, reqFrames, 1 do
            local wheelImg = Image(size, size)

            -- Calculate light from frame count.
            local t = (i - 1.0) * iToStep
            local light = (1.0 - t) * minLight + t * maxLight

            -- Iterate over image pixels.
            local pxItr = wheelImg:pixels()
            for elm in pxItr do

                -- Find rise.
                local y = elm.y
                local yNrm = y * szInv
                local ySgn = 1.0 - (yNrm + yNrm)

                -- Find run.
                local x = elm.x
                local xNrm = x * szInv
                local xSgn = xNrm + xNrm - 1.0

                -- Find square magnitude.
                -- Magnitude correlates with saturation.
                local sqSat = xSgn * xSgn + ySgn * ySgn
                if sqSat <= 1.0 then
                    local srgb = { r = 0.0, g = 0.0, b = 0.0 }

                    if sqSat > 0.0 then

                        -- Convert from [-PI, PI] to [0.0, 1.0].
                        -- 1 / TAU approximately equals 0.159.
                        -- % operator is floor modulo.
                        local hue = atan2(ySgn, xSgn) + angleOffset
                        hue = hue * 0.15915494309189535

                        srgb = hsl_to_srgb({
                            h = quantizeSigned(hue % 1.0, sectorCount),
                            s = quantizeUnsigned(sqrt(sqSat), ringCount),
                            l = light })
                    else
                        srgb = hsl_to_srgb({ h = 0.0, s = 0.0, l = light })
                    end

                    -- Values still go out of gamut, particularly for
                    -- saturated blues at medium light.
                    srgb.r = min(max(srgb.r, 0.0), 1.0)
                    srgb.g = min(max(srgb.g, 0.0), 1.0)
                    srgb.b = min(max(srgb.b, 0.0), 1.0)

                    -- Composite into a 32-bit integer.
                    local hex = 0xff000000
                        | trunc(0.5 + srgb.b * 255) << 0x10
                        | trunc(0.5 + srgb.g * 255) << 0x08
                        | trunc(0.5 + srgb.r * 255)

                    -- Assign to iterator.
                    elm(hex)
                else
                    elm(0)
                end
            end
            wheelImgs[i] = wheelImg
        end

        local pal = nil
        -- In case this causes pass by ref vs.
        -- pass by value problems, comment out.
        -- local oldSprite = app.activeSprite
        -- if oldSprite then
        --     pal = oldSprite.palettes[1]
        -- end

        -- Create frames.
        local sprite = Sprite(size, size)
        local oldFrameLen = #sprite.frames
        local needed = math.max(0, reqFrames - oldFrameLen)
        local fps = args.fps or defaults.fps
        local duration = 1.0 / math.max(1, fps)
        sprite.frames[1].duration = duration
        local newFrames = createNewFrames(sprite, needed, duration)

        -- Set first layer to gamut.
        local gamutLayer = sprite.layers[1]
        gamutLayer.name = "Color Wheel"

        -- Create gamut layer cels.
        app.transaction(function()
            for i = 1, reqFrames, 1 do
                sprite:newCel(
                    gamutLayer,
                    sprite.frames[i],
                    wheelImgs[i])
            end
        end)

        -- Assign a palette.
        if not pal then
            pal = Palette(#palColors)
            for i = 1, #palColors, 1 do
                pal:setColor(i - 1, palColors[i])
            end
        end
        sprite:setPalette(pal)

        -- Because light correlates to frames, the middle
        -- frame should be the default.
        app.activeFrame = sprite.frames[
            math.ceil(#sprite.frames / 2)]
        app.refresh()
    end
}

dlg:show { wait = false }