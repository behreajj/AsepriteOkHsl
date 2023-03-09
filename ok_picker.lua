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

local defaults = {
    base = Color { r = 255, g = 0, b = 0, a = 255 },
    colorMode = "HSL",
    alpha = 255,
    hslHue = 29,
    hslSat = 100,
    hslLgt = 57,
    hsvHue = 29,
    hsvSat = 100,
    hsvVal = 100,
    labLgt = 63,
    labA = 23,
    labB = 13,
    showGradientSettings = false,
    gradWidth = 256,
    gradHeight = 32,
    swatchCount = 8,
    hueDir = "NEAR",
    showWheelSettings = false,
    remapHue = false,
    size = 256,
    hslAxis = "LIGHTNESS",
    hsvAxis = "VALUE",
    minSat = 0,
    maxSat = 97,
    minLight = 7,
    maxLight = 93,
    minValue = 7,
    maxValue = 93,
    sectorCount = 0,
    ringCount = 0,
    frames = 32,
    fps = 24,
    harmonyType = "NONE",
    analogies = {
        Color { r = 244, g = 0, b = 132 },
        Color { r = 200, g = 110, b = 0 }
    },
    complement = { Color { r = 0, g = 154, b = 172 } },
    splits = {
        Color { r = 0, g = 159, b = 138 },
        Color { r = 0, g = 146, b = 212 }
    },
    squares = {
        Color { r = 127, g = 148, b = 0 },
        Color { r = 0, g = 154, b = 172 },
        Color { r = 160, g = 88, b = 255 }
    },
    triads = {
        Color { r = 89, g = 123, b = 255 },
        Color { r = 0, g = 164, b = 71 }
    },
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
}

local rybHueRemapTable = {
    0.081205236645396,  -- ff0000ff
    0.12435157961211,   -- ff006aff
    0.19200283257828,   -- ff00a2ff
    0.25491649730713,   -- ff00cfff
    0.30491453354589,   -- ff00ffff
    0.36815839311704,   -- ff1ad481
    0.40458493819958,   -- ff33a900
    0.46893967259811,   -- ff668415
    0.70734287202901,   -- ffa65911
    0.78714840881823,   -- ff922a3c
    0.87751578482349,   -- ff850c69
    1.0044874689047147, -- ff5500aa
    1.081205236645396   -- ff0000ff
}

local function copyColorByValue(aseColor)
    return Color {
        r = aseColor.red,
        g = aseColor.green,
        b = aseColor.blue,
        a = aseColor.alpha
    }
end

local function aseColorToRgb01(ase)
    return {
        r = ase.red * 0.00392156862745098,
        g = ase.green * 0.00392156862745098,
        b = ase.blue * 0.00392156862745098
    }
end

local function assignColor(aseColor)
    if aseColor.alpha > 0 then
        return copyColorByValue(aseColor)
    else
        return Color { r = 0, g = 0, b = 0, a = 0 }
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
    local halfRange = range * 0.5
    return halfRange - math.abs(math.abs(
            (b % range) - (a % range))
        - halfRange)
end

local function lerpAngleNear(origin, dest, t, range)
    local halfRange = range * 0.5

    local o = origin % range
    local d = dest % range
    local diff = d - o
    local u = 1.0 - t

    if diff == 0.0 then
        return o
    elseif o < d and diff > halfRange then
        return (u * (o + range) + t * d) % range
    elseif o > d and diff < -halfRange then
        return (u * o + t * (d + range)) % range
    else
        return u * o + t * d
    end
end

local function lerpAngleCcw(origin, dest, t, range)
    local o = origin % range
    local d = dest % range
    local diff = d - o
    local u = 1.0 - t

    if diff == 0.0 then
        return o
    elseif o > d then
        return (u * o + t * (d + range)) % range
    else
        return u * o + t * d
    end
end

local function lerpAngleCw(origin, dest, t, range)
    local o = origin % range
    local d = dest % range
    local diff = d - o
    local u = 1.0 - t

    if diff == 0.0 then
        return d
    elseif o < d then
        return (u * (o + range) + t * d) % range
    else
        return u * o + t * d
    end
end

local function preserveForeBack()
    app.fgColor = copyColorByValue(app.fgColor)
    app.command.SwitchColors()
    app.fgColor = copyColorByValue(app.fgColor)
    app.command.SwitchColors()
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
        | math.floor(0.5 + 0xff * math.min(math.max(srgb.b, 0.0), 1.0)) << 0x10
        | math.floor(0.5 + 0xff * math.min(math.max(srgb.g, 0.0), 1.0)) << 0x08
        | math.floor(0.5 + 0xff * math.min(math.max(srgb.r, 0.0), 1.0))
end

local function srgb01ToAseColor(srgb, alpha)
    return Color {
        r = math.floor(0.5 + 0xff * math.min(math.max(srgb.r, 0.0), 1.0)),
        g = math.floor(0.5 + 0xff * math.min(math.max(srgb.g, 0.0), 1.0)),
        b = math.floor(0.5 + 0xff * math.min(math.max(srgb.b, 0.0), 1.0)),
        a = alpha or 255
    }
end

local function round(v)
    local iv, fv = math.modf(v)
    if iv <= 0 and fv <= -0.5 then
        return iv - 1
    elseif iv >= 0 and fv >= 0.5 then
        return iv + 1
    else
        return iv
    end
end

local function zigZag(t)
    local a = t * 0.5
    local b = a - math.floor(a)
    return 1.0 - math.abs(b + b - 1.0)
end

local function updateShades(dialog, shades)
    -- TODO: This causes problems with gray patches
    -- when using LAB mode.
    local alpha = dialog.data.alpha
    local l = dialog.data.hslLgt / 100.0
    l = math.min(math.max(l, 0.01), 0.99)
    local s = dialog.data.hslSat / 100.0
    local h = dialog.data.hslHue / 360.0

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
    local offsetMix = 2.0 * distAngleUnsigned(h, defaults.greenHue, 1.0)
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

        local clr = ok_color.okhsl_to_srgb({
            h = hMixed,
            s = cMixed,
            l = lMixed
        })
        local aseColor = srgb01ToAseColor(clr, alpha)
        shades[i] = aseColor
    end

    dialog:modify { id = "shading", colors = shades }
end

local function updateHarmonies(dialog, primary)
    local srgb = aseColorToRgb01(primary)
    local srcHsl = ok_color.srgb_to_okhsl(srgb)
    local l = srcHsl.l
    local s = srcHsl.s
    local h = srcHsl.h

    local h30 = 0.08333333333333333
    local h90 = 0.25
    local h120 = 0.3333333333333333
    local h150 = 0.4166666666666667
    local h180 = 0.5
    local h210 = 0.5833333333333333
    local h270 = 0.75

    local lOpp = 1.0 - l
    local lTri = (2.0 - l) / 3.0
    local lAna = (2.0 * l + 0.5) / 3.0
    local lSpl = (2.5 - 2.0 * l) / 3.0
    local lSqr = 0.5

    local ana0 = ok_color.okhsl_to_srgb({ h = h - h30, s = s, l = lAna })
    local ana1 = ok_color.okhsl_to_srgb({ h = h + h30, s = s, l = lAna })

    local tri0 = ok_color.okhsl_to_srgb({ h = h - h120, s = s, l = lTri })
    local tri1 = ok_color.okhsl_to_srgb({ h = h + h120, s = s, l = lTri })

    local split0 = ok_color.okhsl_to_srgb({ h = h + h150, s = s, l = lSpl })
    local split1 = ok_color.okhsl_to_srgb({ h = h + h210, s = s, l = lSpl })

    local square0 = ok_color.okhsl_to_srgb({ h = h + h90, s = s, l = lSqr })
    local square1 = ok_color.okhsl_to_srgb({ h = h + h180, s = s, l = lOpp })
    local square2 = ok_color.okhsl_to_srgb({ h = h + h270, s = s, l = lSqr })

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
    local labLgtInt = math.floor(lab.L * 100.0 + 0.5)
    local labAInt = round(lab.a * 100.0)
    local labBInt = round(lab.b * 100.0)
    dialog:modify { id = "labLgt", value = labLgtInt }
    dialog:modify { id = "labA", value = labAInt }
    dialog:modify { id = "labB", value = labBInt }
end

local function setHsl(dialog, hsl)
    local hslLgtInt = math.floor(hsl.l * 100.0 + 0.5)
    local hslSatInt = math.floor(hsl.s * 100.0 + 0.5)
    local hslHueInt = math.floor(hsl.h * 360.0 + 0.5)
    if hslSatInt > 0
        and hslLgtInt > 0
        and hslLgtInt < 100 then
        dialog:modify { id = "hslHue", value = hslHueInt }
    end
    dialog:modify { id = "hslSat", value = hslSatInt }
    dialog:modify { id = "hslLgt", value = hslLgtInt }
end

local function setHsv(dialog, hsv)
    local hsvValInt = math.floor(0.5 + 100.0 * hsv.v)
    local hsvSatInt = math.floor(0.5 + 100.0 * hsv.s)
    local hsvHueInt = math.floor(0.5 + 360.0 * hsv.h)
    if hsvSatInt > 0 and hsvValInt > 0 then
        dialog:modify { id = "hsvHue", value = hsvHueInt }
    end
    dialog:modify { id = "hsvSat", value = hsvSatInt }
    dialog:modify { id = "hsvVal", value = hsvValInt }
end

local function setFromHexStr(dialog, primary, shades)
    local args = dialog.data
    local hexStr = args.hexCode
    if #hexStr > 5 then
        local hexRgb = tonumber(hexStr, 16)
        if hexRgb then
            local r255 = hexRgb >> 0x10 & 0xff
            local g255 = hexRgb >> 0x08 & 0xff
            local b255 = hexRgb & 0xff

            -- Add a previous and mix with previous.
            primary = Color { r = r255, g = g255, b = b255, a = 255 }
            dialog:modify { id = "baseColor", colors = { primary } }
            dialog:modify { id = "alpha", value = 255 }

            local srgb = aseColorToRgb01(primary)
            local lab = ok_color.srgb_to_oklab(srgb)

            setLab(dialog, lab)
            setHsl(dialog, ok_color.oklab_to_okhsl(lab))
            setHsv(dialog, ok_color.oklab_to_okhsv(lab))

            updateHarmonies(dialog, primary)
            updateShades(dialog, shades)
        end
    end
end

local function setFromAse(dialog, aseColor, primary, shades)
    primary = copyColorByValue(aseColor)
    dialog:modify { id = "baseColor", colors = { primary } }
    dialog:modify { id = "alpha", value = primary.alpha }
    dialog:modify { id = "hexCode", text = colorToHexWeb(primary) }

    local srgb = aseColorToRgb01(primary)
    local lab = ok_color.srgb_to_oklab(srgb)

    setLab(dialog, lab)
    setHsl(dialog, ok_color.oklab_to_okhsl(lab))
    setHsv(dialog, ok_color.oklab_to_okhsv(lab))

    updateHarmonies(dialog, primary)
    updateShades(dialog, shades)
end

local function updateColor(dialog, primary, shades)
    local args = dialog.data
    local alpha = args.alpha
    local colorMode = args.colorMode

    if colorMode == "HSV" then
        local lab = ok_color.okhsv_to_oklab({
            h = args.hsvHue * 0.002777777777777778,
            s = args.hsvSat * 0.01,
            v = args.hsvVal * 0.01
        })
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
            b = args.labB * 0.01
        }
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
            l = args.hslLgt * 0.01
        })
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
    updateShades(dialog, shades)
end

local palColors = {
    Color { r = 0, g = 0, b = 0, a = 0 },
    Color { r = 0, g = 0, b = 0 },
    Color { r = 255, g = 255, b = 255 },
    Color { r = 255, g = 0, b = 0 },
    Color { r = 255, g = 255, b = 0 },
    Color { r = 0, g = 255, b = 0 },
    Color { r = 0, g = 255, b = 255 },
    Color { r = 0, g = 0, b = 255 },
    Color { r = 255, g = 0, b = 255 }
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

local primary = Color { r = 255, g = 0, b = 0 }
local shades = {
    Color { r = 113, g = 9, b = 30 },
    Color { r = 148, g = 21, b = 43 },
    Color { r = 183, g = 37, b = 54 },
    Color { r = 214, g = 62, b = 62 },
    Color { r = 234, g = 99, b = 78 },
    Color { r = 244, g = 139, b = 104 },
    Color { r = 248, g = 178, b = 139 }
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
    focus = false,
    onchange = function()
        setFromHexStr(dlg, primary, shades)
    end
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

        local showWheel = args.showWheelSettings
        local hslAxis = args.hslAxis
        local hsvAxis = args.hsvAxis
        local isLight = hslAxis == "LIGHTNESS"
        local isValue = hsvAxis == "VALUE"

        local isSat = false
        if isHsl or isLab then
            isSat = hslAxis == "SATURATION"
        elseif isHsv then
            isSat = hsvAxis == "SATURATION"
        end

        dlg:modify { id = "hslAxis", visible = (isHsl or isLab) and showWheel }
        dlg:modify { id = "minLight", visible = (isHsl or isLab) and showWheel and isLight }
        dlg:modify { id = "maxLight", visible = (isHsl or isLab) and showWheel and isLight }

        dlg:modify { id = "hsvAxis", visible = isHsv and showWheel }
        dlg:modify { id = "minValue", visible = isHsv and showWheel and isValue }
        dlg:modify { id = "maxValue", visible = isHsv and showWheel and isValue }

        dlg:modify { id = "minSat", visible = showWheel and isSat }
        dlg:modify { id = "maxSat", visible = showWheel and isSat }
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
    id = "showGradientSettings",
    label = "Settings:",
    text = "Gradient",
    selected = defaults.showGradientSettings,
    onclick = function()
        local args = dlg.data
        local state = args.showGradientSettings
        dlg:modify { id = "swatchCount", visible = state }
        dlg:modify { id = "hueDir", visible = state }
    end
}

dlg:check {
    id = "showWheelSettings",
    text = "Wheel",
    selected = defaults.showWheelSettings,
    onclick = function()
        local args = dlg.data
        local state = args.showWheelSettings
        local colorMode = args.colorMode
        local isLab = colorMode == "LAB"
        local isHsl = colorMode == "HSL"
        local isHsv = colorMode == "HSV"
        local hslAxis = args.hslAxis
        local hsvAxis = args.hsvAxis
        local isLight = hslAxis == "LIGHTNESS"
        local isValue = hsvAxis == "VALUE"

        local isSat = false
        if isHsl or isLab then
            isSat = hslAxis == "SATURATION"
        elseif isHsv then
            isSat = hsvAxis == "SATURATION"
        end

        dlg:modify { id = "minSat", visible = state and isSat }
        dlg:modify { id = "maxSat", visible = state and isSat }

        dlg:modify { id = "hslAxis", visible = state and (isHsl or isLab) }
        dlg:modify { id = "minLight", visible = (isHsl or isLab) and state and isLight }
        dlg:modify { id = "maxLight", visible = (isHsl or isLab) and state and isLight }

        dlg:modify { id = "hsvAxis", visible = state and isHsv }
        dlg:modify { id = "minValue", visible = isHsv and state and isValue }
        dlg:modify { id = "maxValue", visible = isHsv and state and isValue }

        dlg:modify { id = "frames", visible = state }
        dlg:modify { id = "sectorCount", visible = state }
        dlg:modify { id = "ringCount", visible = state }
        dlg:modify { id = "remapHue", visible = state }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "swatchCount",
    label = "Swatches:",
    min = 3,
    max = 32,
    value = defaults.swatchCount,
    visible = defaults.showGradientSettings
}

dlg:newrow { always = false }

dlg:combobox {
    id = "hueDir",
    label = "Direction:",
    option = defaults.hueDir,
    options = { "CW", "CCW", "NEAR" },
    visible = defaults.showGradientSettings
}

dlg:newrow { always = false }

dlg:combobox {
    id = "hslAxis",
    label = "Time Axis:",
    option = defaults.hslAxis,
    options = { "SATURATION", "LIGHTNESS" },
    visible = defaults.showWheelSettings
        and (defaults.colorMode == "HSL"
        or defaults.colorMode == "LAB"),
    onchange = function()
        local args = dlg.data
        local hslAxis = args.hslAxis
        local isLight = hslAxis == "LIGHTNESS"
        local isSat = hslAxis == "SATURATION"
        dlg:modify { id = "minSat", visible = isSat }
        dlg:modify { id = "maxSat", visible = isSat }
        dlg:modify { id = "minLight", visible = isLight }
        dlg:modify { id = "maxLight", visible = isLight }
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "hsvAxis",
    label = "Time Axis:",
    option = defaults.hsvAxis,
    options = { "SATURATION", "VALUE" },
    visible = defaults.showWheelSettings
        and defaults.colorMode == "HSV",
    onchange = function()
        local args = dlg.data
        local hsvAxis = args.hsvAxis
        local isValue = hsvAxis == "VALUE"
        local isSat = hsvAxis == "SATURATION"
        dlg:modify { id = "minSat", visible = isSat }
        dlg:modify { id = "maxSat", visible = isSat }
        dlg:modify { id = "minValue", visible = isValue }
        dlg:modify { id = "maxValue", visible = isValue }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "minSat",
    label = "Saturation:",
    min = 0,
    max = 99,
    value = defaults.minSat,
    visible = defaults.showWheelSettings
        and defaults.hslAxis == "SATURATION"
        or defaults.hsvAxis == "SATURATION"
}

dlg:slider {
    id = "maxSat",
    min = 1,
    max = 100,
    value = defaults.maxSat,
    visible = defaults.showWheelSettings
        and defaults.hslAxis == "SATURATION"
        or defaults.hsvAxis == "SATURATION"
}

dlg:newrow { always = false }

dlg:slider {
    id = "minLight",
    label = "Light:",
    min = 0,
    max = 99,
    value = defaults.minLight,
    visible = defaults.showWheelSettings
        and (defaults.colorMode == "HSL"
        or defaults.colorMode == "LAB")
        and defaults.hslAxis == "LIGHTNESS"
}

dlg:slider {
    id = "maxLight",
    min = 1,
    max = 100,
    value = defaults.maxLight,
    visible = defaults.showWheelSettings
        and (defaults.colorMode == "HSL"
        or defaults.colorMode == "LAB")
        and defaults.hslAxis == "LIGHTNESS"
}

dlg:newrow { always = false }

dlg:slider {
    id = "minValue",
    label = "Value:",
    min = 0,
    max = 99,
    value = defaults.minValue,
    visible = defaults.showWheelSettings
        and defaults.colorMode == "HSV"
        and defaults.hslAxis == "VALUE"
}

dlg:slider {
    id = "maxValue",
    min = 1,
    max = 100,
    value = defaults.maxValue,
    visible = defaults.showWheelSettings
        and defaults.colorMode == "HSV"
        and defaults.hslAxis == "VALUE"
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
    max = 72,
    value = defaults.sectorCount,
    visible = defaults.showWheelSettings
}

dlg:newrow { always = false }

dlg:slider {
    id = "ringCount",
    label = "Rings:",
    min = 0,
    max = 64,
    value = defaults.ringCount,
    visible = defaults.showWheelSettings
}

dlg:newrow { always = false }

dlg:check {
    id = "remapHue",
    label = "Remap:",
    text = "Hue",
    selected = defaults.remapHue,
    visible = defaults.showGradientSettings
}

dlg:newrow { always = false }

dlg:button {
    id = "gradient",
    text = "&GRADIENT",
    focus = false,
    onclick = function()
        local args = dlg.data
        local gradWidth = defaults.gradWidth
        local gradHeight = defaults.gradHeight
        local colorMode = args.colorMode or defaults.colorMode
        local swatchCount = args.swatchCount or defaults.swatchCount
        local hueDir = args.hueDir or defaults.hueDir

        -- TODO: How to handle the case where fore and
        -- background colors are the same?
        local foreColor = app.fgColor
        local foreHex = 0xff000000 | foreColor.rgbaPixel
        local foreSrgb01 = aseColorToRgb01(foreColor)
        local foreLab = ok_color.srgb_to_oklab(foreSrgb01)

        local backColor = app.bgColor
        local backHex = 0xff000000 | backColor.rgbaPixel
        local backSrgb01 = aseColorToRgb01(backColor)
        local backLab = ok_color.srgb_to_oklab(backSrgb01)

        local hueFunc = lerpAngleNear
        if hueDir == "CW" then
            hueFunc = lerpAngleCw
        elseif hueDir == "CCW" then
            hueFunc = lerpAngleCcw
        end

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
                    local ch = hueFunc(backHsl.h, foreHsl.h, fac, 1.0)
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
                    local ch = hueFunc(backHsv.h, foreHsv.h, fac, 1.0)
                    local cs = u * backHsv.s + fac * foreHsv.s
                    local cv = u * backHsv.v + fac * foreHsv.v
                    local csrgb01 = ok_color.okhsv_to_srgb({ h = ch, s = cs, v = cv })
                    return srgb01ToHex(csrgb01)
                end
            end
        end

        preserveForeBack()
        local gradSprite = Sprite(gradWidth, gradHeight)
        gradSprite.filename = string.format(
            "Ok Gradient (%s)",
            colorMode)

        -- Create smooth image.
        local halfHeight = gradHeight // 2
        local smoothImg = Image(gradWidth, halfHeight)
        local smoothPxItr = smoothImg:pixels()
        local xToFac = 1.0 / (gradWidth - 1.0)
        for elm in smoothPxItr do
            elm(lerpFunc(elm.x * xToFac))
        end

        gradSprite.cels[1].image = smoothImg
        gradSprite.layers[1].name = "Gradient.Smooth"

        -- Create swatches.
        local segLayer = gradSprite:newLayer()
        segLayer.name = "Gradient.Swatches"
        local segImg = Image(gradWidth, gradHeight - halfHeight)
        local segImgPxItr = segImg:pixels()

        local swatchesDict = {}
        swatchesDict[0x00000000] = 0
        local palIdx = 1
        local swatchesInv = 1.0 / (swatchCount - 1.0)
        for elm in segImgPxItr do
            local t = elm.x * xToFac
            t = math.max(0.0,
                (math.ceil(t * swatchCount) - 1.0)
                * swatchesInv)
            local hex = lerpFunc(t)
            elm(hex)

            if not swatchesDict[hex] then
                swatchesDict[hex] = palIdx
                palIdx = palIdx + 1
            end
        end
        gradSprite:newCel(
            segLayer, gradSprite.frames[1],
            segImg, Point(0, halfHeight))

        -- Set palette.
        local pal = Palette(palIdx)
        for k, v in pairs(swatchesDict) do
            pal:setColor(v, k)
        end
        gradSprite:setPalette(pal)

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
        local trunc = math.floor
        local max = math.max
        local min = math.min
        local hsl_to_srgb = ok_color.okhsl_to_srgb
        local hsv_to_srgb = ok_color.okhsv_to_srgb

        -- Unpack arguments.
        local args = dlg.data
        local size = args.size or defaults.size --[[@as integer]]
        local szInv = 1.0 / (size - 1.0)
        local iToStep = 1.0
        local reqFrames = args.frames or defaults.frames
        if reqFrames > 1 then iToStep = 1.0 / (reqFrames - 1.0) end
        local colorMode = args.colorMode or defaults.colorMode
        local hslAxis = args.hslAxis or defaults.hslAxis
        local hsvAxis = args.hsvAxis or defaults.hsvAxis
        local minLight = args.minLight or defaults.minLight
        local maxLight = args.maxLight or defaults.maxLight
        local minValue = args.minValue or defaults.minValue
        local maxValue = args.maxValue or defaults.maxValue
        local minSat = args.minSat or defaults.minSat
        local maxSat = args.maxSat or defaults.maxSat
        local ringCount = args.ringCount or defaults.ringCount
        local sectorCount = args.sectorCount or defaults.sectorCount
        local remapHue = args.remapHue

        -- Offset by 30 degrees to match Aseprite's color wheel.
        local angleOffset = math.rad(30.0)
        local lenRemapTable = #rybHueRemapTable

        minSat = minSat * 0.01
        maxSat = maxSat * 0.01
        minLight = minLight * 0.01
        maxLight = maxLight * 0.01
        minValue = minValue * 0.01
        maxValue = maxValue * 0.01

        local useHsv = colorMode == "HSV"
        local useSat = false
        if colorMode == "HSV" then
            useSat = hsvAxis == "SATURATION"
        else
            useSat = hslAxis == "SATURATION"
        end

        local wheelImgs = {}
        for i = 1, reqFrames, 1 do
            local wheelImg = Image(size, size)

            -- Calculate light from frame count.
            local fac0 = (i - 1.0) * iToStep
            local sat = minSat
            local light = minLight
            local value = minValue

            if useSat then
                sat = (1.0 - fac0) * minSat + fac0 * maxSat
            elseif useHsv then
                value = (1.0 - fac0) * minValue + fac0 * maxValue
            else
                light = (1.0 - fac0) * minLight + fac0 * maxLight
            end

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
                local magSq = xSgn * xSgn + ySgn * ySgn
                if magSq <= 1.0 then
                    local srgb = { r = 0.0, g = 0.0, b = 0.0 }

                    -- Convert from [-PI, PI] to [0.0, 1.0].
                    -- 1 / TAU approximately equals 0.159.
                    -- % operator is floor modulo.
                    local hue = atan2(ySgn, xSgn) + angleOffset
                    hue = hue % 6.283185307179586
                    hue = hue * 0.15915494309189535
                    hue = quantizeSigned(hue, sectorCount)

                    -- Remap hue to RYB color wheel.
                    if remapHue then
                        local hueScaled = hue * (lenRemapTable - 1)
                        local hueIdx = trunc(hueScaled)
                        local hueFrac = hueScaled - hueIdx
                        local aHue = rybHueRemapTable[1 + hueIdx]
                        local bHue = rybHueRemapTable[1 + (hueIdx + 1) % lenRemapTable]
                        hue = (1.0 - hueFrac) * aHue + hueFrac * bHue
                    end

                    local mag = sqrt(magSq)
                    if useSat then
                        if useHsv then
                            value = (1.0 - mag) * maxValue + mag * minValue
                            value = quantizeUnsigned(value, ringCount)
                        else
                            light = (1.0 - mag) * maxLight + mag * minLight
                            light = quantizeUnsigned(light, ringCount)
                        end
                    else
                        sat = (1.0 - mag) * minSat + mag * maxSat
                        sat = quantizeUnsigned(sat, ringCount)
                    end

                    if useHsv then
                        srgb = hsv_to_srgb({
                            h = hue,
                            s = sat,
                            v = value
                        })
                    else
                        srgb = hsl_to_srgb({
                            h = hue,
                            s = sat,
                            l = light
                        })
                    end

                    -- Values still go out of gamut, particularly for
                    -- saturated blues at medium light.
                    srgb.r = min(max(srgb.r, 0.0), 1.0)
                    srgb.g = min(max(srgb.g, 0.0), 1.0)
                    srgb.b = min(max(srgb.b, 0.0), 1.0)

                    -- Composite into a 32-bit integer.
                    local hex = 0xff000000
                        | trunc(srgb.b * 255 + 0.5) << 0x10
                        | trunc(srgb.g * 255 + 0.5) << 0x08
                        | trunc(srgb.r * 255 + 0.5)

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

        preserveForeBack()
        local sprite = Sprite(size, size)
        local oldFrameLen = #sprite.frames
        local needed = math.max(0, reqFrames - oldFrameLen)
        local fps = args.fps or defaults.fps --[[@as integer]]
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
        if useSat or useHsv then
            app.activeFrame = sprite.frames[#sprite.frames]
        else
            app.activeFrame = sprite.frames[
            math.ceil(#sprite.frames / 2)]
        end
        app.refresh()
    end
}

dlg:show { wait = false }