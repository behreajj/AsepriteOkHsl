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

local defaults <const> = {
    base = Color { r = 255, g = 0, b = 0, a = 255 },
    colorMode = "HSL",
    alpha = 255,
    hslHue = 29,
    hslSat = 255,
    hslLgt = 145,
    hsvHue = 29,
    hsvSat = 255,
    hsvVal = 255,
    labLgt = 160,
    labA = 225,
    labB = 126,
    showGradientSettings = false,
    gradWidth = 256,
    gradHeight = 32,
    swatchCount = 7,
    hueDir = "NEAR",
    showWheelSettings = false,
    remapHue = "OKLAB",
    size = 256,
    hslAxis = "LIGHTNESS",
    hsvAxis = "VALUE",
    minSat = 0,
    maxSat = 250,
    minLight = 5,
    maxLight = 250,
    minValue = 5,
    maxValue = 250,
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
    greenHue = 146.0 / 360.0,
    minGreenOffset = 0.3,
    maxGreenOffset = 0.6,
    shadowHue = 291.0 / 360.0,
    dayHue = 96.0 / 360.0,
}

local rybHueRemapTable24 <const> = {
    0.081186489951701, --ff0000bc
    0.088543402729094, --ff0021c9
    0.10262364680987,  --ff0040d9
    0.13403629399108,  --ff0066e2

    0.17916243354554,  --ff008ae7
    0.21949160794204,  --ff00a8ed
    0.25320328186974,  --ff05c4f3
    0.28293666595694,  --ff20e7fe

    0.3045570947557,   --ff33fefe
    0.36503532781409,  --ff00ffa1
    0.39128411126471,  --ff00ff43
    0.397020150612,    --ff1cff00

    0.41735542065514,  --ff7aff00
    0.48945464109323,  --ffd8ff00
    0.62758432515209,  --ffa68200
    0.71322973397372,  --ffce6401

    0.73231601426016,  --fff24100
    0.74106567631729,  --ffe7241b
    0.75326079486957,  --ffc61528
    0.79484301474327,  --ff97043b

    0.86508195598932,  --ff6a004b
    0.94537622442158,  --ff510367
    1.016379461501466, --ff3c008a
    1.062861707421092, --ff2100a7

    1.081186489951701, --ff0000bc
}

local rgbHueRemapTable24 <const> = {
    0.081186489951701,  --ff0000ff
    0.095766555555779,  --ff0040ff
    0.14659018427134,   --ff0080ff
    0.23391826905505,   --ff00bfff

    0.30496513648794,   --ff00ffff
    0.34959701375912,   --ff00ffbf
    0.37768750974757,   --ff00ff80
    0.39166456136257,   --ff00ff40

    0.39586436900711,   --ff00ff00
    0.40113237655716,   --ff40ff00
    0.41979583005808,   --ff80ff00
    0.4629578833159,    --ffbfff00

    0.54114119023916,   --ffffff00
    0.64313742175205,   --ffffbf00
    0.71173624990824,   --ffff8000
    0.73287799718808,   --ffff4000

    0.73349594598298,   --ffff0000
    0.76053438187642,   --ffff0040
    0.81602187489686,   --ffff0080
    0.8694399396202,    --ffff00bf

    0.91207209774771,   --ffff00ff
    0.95478525659029,   --ffbf00ff
    1.0072520521085758, --ff8000ff
    1.058046802990062,  --ff4000ff

    1.081186489951701,  --ff0000ff
}

local rygbHueRemapTable24 <const> = {
    0.072237063394159,
    0.095280383412942,
    0.13208035564017,
    0.16773270414916,

    0.20028989647507,
    0.23379645010808,
    0.26494353051784,
    0.29321548131135,

    0.32196570822139,
    0.34926312018934,
    0.38151093005415,
    0.40002040933732,

    0.43068663559305,
    0.45901928198972,
    0.49871093920573,
    0.54434781369171,

    0.5969853889193,
    0.67811627795289,
    0.73479009641358,
    0.78756293049826,

    0.83860181840028,
    0.89205663524978,
    0.95304453455657,
    1.021032964650062,

    1.072237063394159,
}

---@param ase Color
---@return Color
local function copyColorByValue(ase)
    return Color {
        r = ase.red,
        g = ase.green,
        b = ase.blue,
        a = ase.alpha
    }
end

---@param ase Color
---@return number r
---@return number g
---@return number b
---@nodiscard
local function aseColorToRgb01(ase)
    return ase.red / 255.0,
        ase.green / 255.0,
        ase.blue / 255.0
end

---@param ase Color
---@return Color
local function assignColor(ase)
    if ase.alpha > 0 then
        return copyColorByValue(ase)
    else
        return Color { r = 0, g = 0, b = 0, a = 0 }
    end
end

---@param ase Color
---@return string
local function colorToHexWeb(ase)
    return string.format("%06x",
        ase.red << 0x10
        | ase.green << 0x08
        | ase.blue)
end

---@param sprite Sprite
---@param count integer
---@param duration number
---@return Frame[]
local function createNewFrames(sprite, count, duration)
    if not sprite then
        app.alert { title = "Error", text = "Sprite could not be found." }
        return {}
    end

    if count < 1 then return {} end
    if count > 256 then
        local response <const> = app.alert {
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

    local valDur <const> = duration or 1
    local valCount = count or 1
    if valCount < 1 then valCount = 1 end

    ---@type Frame[]
    local frames <const> = {}
    app.transaction("Create Frames", function()
        for i = 1, valCount, 1 do
            local frame <const> = sprite:newEmptyFrame()
            frame.duration = valDur
            frames[i] = frame
        end
    end)
    return frames
end

---@param a number
---@param b number
---@param range number
---@return number
local function distAngleUnsigned(a, b, range)
    local halfRange <const> = range * 0.5
    return halfRange - math.abs(math.abs(
            (b % range) - (a % range))
        - halfRange)
end

---@param orig number
---@param dest number
---@param t number
---@param range number
---@return number
local function lerpAngleNear(orig, dest, t, range)
    local halfRange <const> = range * 0.5

    local o <const> = orig % range
    local d <const> = dest % range
    local diff <const> = d - o
    local u <const> = 1.0 - t

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

---@param orig number
---@param dest number
---@param t number
---@param range number
---@return number
local function lerpAngleCcw(orig, dest, t, range)
    local o <const> = orig % range
    local d <const> = dest % range
    local diff <const> = d - o
    local u <const> = 1.0 - t

    if diff == 0.0 then
        return o
    elseif o > d then
        return (u * o + t * (d + range)) % range
    else
        return u * o + t * d
    end
end

---@param orig number
---@param dest number
---@param t number
---@param range number
---@return number
local function lerpAngleCw(orig, dest, t, range)
    local o <const> = orig % range
    local d <const> = dest % range
    local diff <const> = d - o
    local u <const> = 1.0 - t

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

---@param a number
---@param levels integer
---@return number
local function quantizeSigned(a, levels)
    if levels ~= 0 then
        return math.floor(0.5 + a * levels) / levels
    else
        return a
    end
end

---@param a number
---@param levels integer
---@return number
local function quantizeUnsigned(a, levels)
    if levels > 1 then
        return math.max(0.0,
            (math.ceil(a * levels) - 1.0)
            / (levels - 1.0))
    else
        return math.max(0.0, a)
    end
end

---@param r number
---@param g number
---@param b number
---@param a integer?
---@return integer
local function srgb01ToHex(r, g, b, a)
    return ((a or 255) << 0x18)
        | math.floor(math.min(math.max(b, 0.0), 1.0) * 255.0 + 0.5) << 0x10
        | math.floor(math.min(math.max(g, 0.0), 1.0) * 255.0 + 0.5) << 0x08
        | math.floor(math.min(math.max(r, 0.0), 1.0) * 255.0 + 0.5)
end

---@param r number
---@param g number
---@param b number
---@param a integer?
---@return Color
local function srgb01ToAseColor(r, g, b, a)
    return Color {
        r = math.floor(math.min(math.max(r, 0.0), 1.0) * 255.0 + 0.5),
        g = math.floor(math.min(math.max(g, 0.0), 1.0) * 255.0 + 0.5),
        b = math.floor(math.min(math.max(b, 0.0), 1.0) * 255.0 + 0.5),
        a = a or 255
    }
end

---@param v number
---@return integer
local function round(v)
    local iv <const>, fv <const> = math.modf(v)
    if iv <= 0 and fv <= -0.5 then
        return iv - 1
    elseif iv >= 0 and fv >= 0.5 then
        return iv + 1
    else
        return iv
    end
end

---@param t number
---@return number
local function zigZag(t)
    local a <const> = t * 0.5
    local b <const> = a - math.floor(a)
    return 1.0 - math.abs(b + b - 1.0)
end

---@param dialog Dialog
---@param shades Color[]
local function updateShades(dialog, shades)
    -- TODO: This causes problems with gray patches
    -- when using LAB mode.
    local args <const> = dialog.data
    local alpha <const> = args.alpha --[[@as integer]]
    local hslLgt <const> = args.hslLgt --[[@as integer]]
    local hslSat <const> = args.hslSat --[[@as integer]]
    local hslHue <const> = args.hslHue --[[@as integer]]

    local l <const> = math.min(math.max(hslLgt / 255.0, 0.01), 0.99)
    local s <const> = hslSat / 255.0
    local h <const> = hslHue / 360.0

    -- Decide on clockwise or counter-clockwise based
    -- on color's warmth or coolness.
    -- The LCh hue for yellow is 103 degrees.
    local hYel <const> = defaults.hYel
    local hBlu <const> = hYel + 0.5
    local lerpFunc = nil
    if h < hYel or h >= hBlu then
        lerpFunc = lerpAngleCcw
    else
        lerpFunc = lerpAngleCw
    end

    -- Minimum and maximum light based on place in loop.
    local shadowLight <const> = defaults.shadowLight
    local dayLight <const> = defaults.dayLight

    -- Yellows are very saturated at high light;
    -- Desaturate them to get a better shade.
    -- Conversely, blues easily fall out of gamut
    -- so the shade factor is separate.
    local lgtDesatFac <const> = defaults.lgtDesatFac
    local shdDesatFac <const> = defaults.shdDesatFac
    local minChroma <const> = defaults.minChroma
    local cVal <const> = math.max(minChroma, s)
    local desatChromaLgt <const> = cVal * lgtDesatFac
    local desatChromaShd <const> = cVal * shdDesatFac

    -- Amount to mix between base light and loop light.
    local srcLightWeight <const> = defaults.srcLightWeight
    local cmpLightWeight <const> = 1.0 - srcLightWeight

    -- The warm-cool dichotomy works poorly for greens.
    -- For that reason, the closer a hue is to green,
    -- the more it uses absolute hue shifting.
    -- Green is approximately at hue 140.
    local offsetMix <const> = 2.0 * distAngleUnsigned(h, defaults.greenHue, 1.0)
    local offsetScale <const> = (1.0 - offsetMix) * defaults.maxGreenOffset
        + offsetMix * defaults.minGreenOffset

    -- Absolute hues for shadow and light.
    -- This could also be combined with the origin hue +/-
    -- a shift which is then mixed with the absolute hue.
    local shadowHue <const> = defaults.shadowHue
    local dayHue <const> = defaults.dayHue

    local shadingCount <const> = defaults.shadingCount
    local toFac <const> = 1.0 / (shadingCount - 1.0)
    for i = 1, shadingCount, 1 do
        local iFac <const> = (i - 1) * toFac
        local lItr <const> = (1.0 - iFac) * shadowLight
            + iFac * dayLight

        -- Idealized hue from violet shadow to
        -- off-yellow daylight.
        local hAbs <const> = lerpFunc(shadowHue, dayHue, lItr, 1.0)

        -- The middle sample should be closest to base color.
        -- The fac needs to be 0.0. That's why zigzag is
        -- used to convert to an oscillation.
        local lMixed <const> = srcLightWeight * l
            + cmpLightWeight * lItr
        local lZig <const> = zigZag(lMixed)
        local fac <const> = offsetScale * lZig
        local hMixed <const> = lerpAngleNear(h, hAbs, fac, 1.0)

        -- Desaturate brights and darks.
        -- Min chroma gives even grays a slight chroma.
        local chromaTarget = desatChromaLgt
        if lMixed < 0.5 then chromaTarget = desatChromaShd end
        local cMixed = (1.0 - lZig) * cVal + lZig * chromaTarget
        cMixed = math.max(minChroma, cMixed)

        local r <const>, g <const>, b <const> = ok_color.okhsl_to_srgb(
            hMixed, cMixed, lMixed)
        local aseColor <const> = srgb01ToAseColor(r, g, b, alpha)
        shades[i] = aseColor
    end

    dialog:modify { id = "shading", colors = shades }
end

---@param dialog Dialog
---@param primary Color
local function updateHarmonies(dialog, primary)
    local r01 <const>, g01 <const>, b01 <const> = aseColorToRgb01(primary)
    local h <const>, s <const>, l <const> = ok_color.srgb_to_okhsl(r01, g01, b01)

    local h30 <const> = 0.08333333333333333
    local h90 <const> = 0.25
    local h120 <const> = 0.3333333333333333
    local h150 <const> = 0.4166666666666667
    local h180 <const> = 0.5
    local h210 <const> = 0.5833333333333333
    local h270 <const> = 0.75

    local lOpp <const> = 1.0 - l
    local lTri <const> = (2.0 - l) / 3.0
    local lAna <const> = (2.0 * l + 0.5) / 3.0
    local lSpl <const> = (2.5 - 2.0 * l) / 3.0
    local lSqr <const> = 0.5

    local rAna0 <const>, gAna0 <const>, bAna0 <const> = ok_color.okhsl_to_srgb(h - h30, s, lAna)
    local rAna1 <const>, gAna1 <const>, bAna1 <const> = ok_color.okhsl_to_srgb(h + h30, s, lAna)

    local rTri0 <const>, gTri0 <const>, bTri0 <const> = ok_color.okhsl_to_srgb(h - h120, s, lTri)
    local rTri1 <const>, gTri1 <const>, bTri1 <const> = ok_color.okhsl_to_srgb(h + h120, s, lTri)

    local rSpl0 <const>, gSpl0 <const>, bSpl0 <const> = ok_color.okhsl_to_srgb(h + h150, s, lSpl)
    local rSpl1 <const>, gSpl1 <const>, bSpl1 <const> = ok_color.okhsl_to_srgb(h + h210, s, lSpl)

    local rSqr0 <const>, gSqr0 <const>, bSqr0 <const> = ok_color.okhsl_to_srgb(h + h90, s, lSqr)
    local rSqr1 <const>, gSqr1 <const>, bSqr1 <const> = ok_color.okhsl_to_srgb(h + h180, s, lOpp)
    local rSqr2 <const>, gSqr2 <const>, bSqr2 <const> = ok_color.okhsl_to_srgb(h + h270, s, lSqr)

    local tris <const> = {
        srgb01ToAseColor(rTri0, gTri0, bTri0),
        srgb01ToAseColor(rTri1, gTri1, bTri1)
    }

    local analogues <const> = {
        srgb01ToAseColor(rAna0, gAna0, bAna0),
        srgb01ToAseColor(rAna1, gAna1, bAna1)
    }

    local splits <const> = {
        srgb01ToAseColor(rSpl0, gSpl0, bSpl0),
        srgb01ToAseColor(rSpl1, gSpl1, bSpl1)
    }

    local squares <const> = {
        srgb01ToAseColor(rSqr0, gSqr0, bSqr0),
        srgb01ToAseColor(rSqr1, gSqr1, bSqr1),
        srgb01ToAseColor(rSqr2, gSqr2, bSqr2)
    }

    dialog:modify { id = "complement", colors = { squares[2] } }
    dialog:modify { id = "triadic", colors = tris }
    dialog:modify { id = "analogous", colors = analogues }
    dialog:modify { id = "split", colors = splits }
    dialog:modify { id = "square", colors = squares }
end

---@param dialog Dialog
---@param l number
---@param a number
---@param b number
local function setLab(dialog, l, a, b)
    local labLgtInt <const> = math.floor(l * 255.0 + 0.5)
    local labAInt <const> = round(a * 1000.0)
    local labBInt <const> = round(b * 1000.0)
    dialog:modify { id = "labLgt", value = labLgtInt }
    dialog:modify { id = "labA", value = labAInt }
    dialog:modify { id = "labB", value = labBInt }
end

---@param dialog Dialog
---@param h number
---@param s number
---@param l number
local function setHsl(dialog, h, s, l)
    local hslLgtInt <const> = math.floor(l * 255.0 + 0.5)
    local hslSatInt <const> = math.floor(s * 255.0 + 0.5)
    local hslHueInt <const> = math.floor(h * 360.0 + 0.5)
    if hslSatInt > 0
        and hslLgtInt > 0
        and hslLgtInt < 255 then
        dialog:modify { id = "hslHue", value = hslHueInt }
    end
    dialog:modify { id = "hslSat", value = hslSatInt }
    dialog:modify { id = "hslLgt", value = hslLgtInt }
end

---@param dialog Dialog
---@param h number
---@param s number
---@param v number
local function setHsv(dialog, h, s, v)
    local hsvValInt <const> = math.floor(v * 255.0 + 0.5)
    local hsvSatInt <const> = math.floor(s * 255.0 + 0.5)
    local hsvHueInt <const> = math.floor(h * 360.0 + 0.5)
    if hsvSatInt > 0 and hsvValInt > 0 then
        dialog:modify { id = "hsvHue", value = hsvHueInt }
    end
    dialog:modify { id = "hsvSat", value = hsvSatInt }
    dialog:modify { id = "hsvVal", value = hsvValInt }
end

---@param dialog Dialog
---@param primary Color
---@param shades Color[]
local function setFromHexStr(dialog, primary, shades)
    local args <const> = dialog.data
    local hexStr <const> = args.hexCode --[[@as string]]

    local s = hexStr
    if string.sub(s, 1, 1) == '#' then
        s = string.sub(s, 2)
    end

    local r8, g8, b8, a8 = 0, 0, 0, 0

    local sn <const> = tonumber(s, 16)
    if sn then
        local lens <const> = #s
        if lens == 3 then
            local r4 <const> = sn >> 0x8 & 0xf
            local g4 <const> = sn >> 0x4 & 0xf
            local b4 <const> = sn & 0xf

            r8 = r4 << 0x4 | r4
            g8 = g4 << 0x4 | g4
            b8 = b4 << 0x4 | b4
            a8 = 255
        elseif lens == 4 then
            local r5 <const> = sn >> 0xb & 0x1f
            local g6 <const> = sn >> 0x5 & 0x3f
            local b5 <const> = sn & 0x1f

            r8 = math.floor(r5 * 255.0 / 31.0 + 0.5)
            g8 = math.floor(g6 * 255.0 / 63.0 + 0.5)
            b8 = math.floor(b5 * 255.0 / 31.0 + 0.5)
            a8 = 255
        elseif lens == 6 then
            r8 = sn >> 0x10 & 0xff
            g8 = sn >> 0x08 & 0xff
            b8 = sn & 0xff
            a8 = 255
        elseif lens >= 8 then
            r8 = sn >> 0x18 & 0xff
            g8 = sn >> 0x10 & 0xff
            b8 = sn >> 0x08 & 0xff
            a8 = sn & 0xff
        end
    end

    if a8 > 0 then
        -- Add a previous and mix with previous.
        primary = Color { r = r8, g = g8, b = b8, a = a8 }
        dialog:modify { id = "baseColor", colors = { primary } }
        dialog:modify { id = "alpha", value = a8 }

        local r01 <const>, g01 <const>, b01 <const> = aseColorToRgb01(primary)
        local l <const>, a <const>, b <const> = ok_color.srgb_to_oklab(r01, g01, b01)

        setLab(dialog, l, a, b)
        setHsl(dialog, ok_color.oklab_to_okhsl(l, a, b))
        setHsv(dialog, ok_color.oklab_to_okhsv(l, a, b))

        updateHarmonies(dialog, primary)
        updateShades(dialog, shades)
    end
end

---@param dialog Dialog
---@param aseColor Color
---@param primary Color
---@param shades Color[]
local function setFromAse(dialog, aseColor, primary, shades)
    primary = copyColorByValue(aseColor)
    dialog:modify { id = "baseColor", colors = { primary } }
    dialog:modify { id = "alpha", value = primary.alpha }
    dialog:modify { id = "hexCode", text = colorToHexWeb(primary) }

    local r01 <const>, g01 <const>, b01 <const> = aseColorToRgb01(primary)
    local l <const>, a <const>, b <const> = ok_color.srgb_to_oklab(r01, g01, b01)

    setLab(dialog, l, a, b)
    setHsl(dialog, ok_color.oklab_to_okhsl(l, a, b))
    setHsv(dialog, ok_color.oklab_to_okhsv(l, a, b))

    updateHarmonies(dialog, primary)
    updateShades(dialog, shades)
end

---@param dialog Dialog
---@param primary Color
---@param shades Color[]
local function updateColor(dialog, primary, shades)
    local args <const> = dialog.data
    local alpha <const> = args.alpha --[[@as integer]]
    local colorMode <const> = args.colorMode --[[@as string]]

    if colorMode == "HSV" then
        local hsvHue <const> = args.hsvHue --[[@as integer]]
        local hsvSat <const> = args.hsvSat --[[@as integer]]
        local hsvVal <const> = args.hsvVal --[[@as integer]]

        local l <const>, a <const>, b <const> = ok_color.okhsv_to_oklab(
            hsvHue / 360.0, hsvSat / 255.0, hsvVal / 255.0)
        local r01 <const>, g01 <const>, b01 <const> = ok_color.oklab_to_srgb(l, a, b)
        primary = srgb01ToAseColor(r01, g01, b01, alpha)

        -- Update other color sliders.
        local hHsl <const>, sHsl <const>, lHsl <const> = ok_color.oklab_to_okhsl(l, a, b)
        setHsl(dialog, hHsl, sHsl, lHsl)
        setLab(dialog, l, a, b)
    elseif colorMode == "LAB" then
        local labLgt <const> = args.labLgt --[[@as integer]]
        local labA <const> = args.labA --[[@as integer]]
        local labB <const> = args.labB --[[@as integer]]

        local l <const> = labLgt / 255.0
        local a <const> = labA * 0.001
        local b <const> = labB * 0.001
        local r01 <const>, g01 <const>, b01 <const> = ok_color.oklab_to_srgb(l, a, b)
        primary = srgb01ToAseColor(r01, g01, b01, alpha)

        -- Update other color sliders.
        local hHsl <const>, sHsl <const>, lHsl <const> = ok_color.oklab_to_okhsl(l, a, b)
        local hHsv <const>, sHsv <const>, vHsv <const> = ok_color.oklab_to_okhsv(l, a, b)
        setHsl(dialog, hHsl, sHsl, lHsl)
        setHsv(dialog, hHsv, sHsv, vHsv)
    else
        local hslHue <const> = args.hslHue --[[@as integer]]
        local hslSat <const> = args.hslSat --[[@as integer]]
        local hslLgt <const> = args.hslLgt --[[@as integer]]

        local l <const>, a <const>, b <const> = ok_color.okhsl_to_oklab(
            hslHue / 360.0, hslSat / 255.0, hslLgt / 255.0)
        local r01 <const>, g01 <const>, b01 <const> = ok_color.oklab_to_srgb(l, a, b)
        primary = srgb01ToAseColor(r01, g01, b01, alpha)

        -- Update other color sliders.
        local hHsv <const>, sHsv <const>, vHsv <const> = ok_color.oklab_to_okhsv(l, a, b)
        setHsv(dialog, hHsv, sHsv, vHsv)
        setLab(dialog, l, a, b)
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

local colorModes <const> = { "HSL", "HSV", "LAB" }

local harmonies <const> = {
    "ANALOGOUS",
    "COMPLEMENT",
    "NONE",
    "SHADING",
    "SPLIT",
    "SQUARE",
    "TRIADIC"
}

local primary <const> = Color { r = 255, g = 0, b = 0 }
local shades <const> = {
    Color { r = 113, g = 9, b = 30 },
    Color { r = 148, g = 21, b = 43 },
    Color { r = 183, g = 37, b = 54 },
    Color { r = 214, g = 62, b = 62 },
    Color { r = 234, g = 99, b = 78 },
    Color { r = 244, g = 139, b = 104 },
    Color { r = 248, g = 178, b = 139 }
}
local dlg <const> = Dialog { title = "OkHsl Color Picker" }

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
        local button <const> = ev.button
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
        local args <const> = dlg.data
        local colorMode <const> = args.colorMode --[[@as string]]

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

        local showWheel <const> = args.showWheelSettings --[[@as boolean]]
        local hslAxis <const> = args.hslAxis --[[@as string]]
        local hsvAxis <const> = args.hsvAxis --[[@as string]]
        local isLight <const> = hslAxis == "LIGHTNESS"
        local isValue <const> = hsvAxis == "VALUE"

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

        local showGradient <const> = args.showGradientSettings --[[@as boolean]]
        if showGradient then
            dlg:modify { id = "hueDir", visible = not isLab }
        end
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
    max = 255,
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
    max = 255,
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
    max = 255,
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
    max = 255,
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
    max = 255,
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
    min = -320,
    max = 320,
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
    min = -320,
    max = 320,
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
        local args <const> = dlg.data
        local md <const> = args.harmonyType --[[@as string]]
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
        local button <const> = ev.button
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
        local button <const> = ev.button
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
        local button <const> = ev.button
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
        local activeSprite <const> = app.sprite
        if activeSprite then
            local palette <const> = activeSprite.palettes[1]
            local oldLen <const> = #palette
            local shadingCount <const> = defaults.shadingCount
            local newLen <const> = oldLen + shadingCount

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
        local button <const> = ev.button
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
        local button <const> = ev.button
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
        local button <const> = ev.button
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
        local args <const> = dlg.data
        local state <const> = args.showGradientSettings --[[@as boolean]]
        local colorMode <const> = args.colorMode --[[@as string]]
        dlg:modify { id = "swatchCount", visible = state }
        dlg:modify { id = "hueDir", visible = state and colorMode ~= "LAB" }
    end
}

dlg:check {
    id = "showWheelSettings",
    text = "Wheel",
    selected = defaults.showWheelSettings,
    onclick = function()
        local args <const> = dlg.data
        local state <const> = args.showWheelSettings --[[@as boolean]]
        local colorMode <const> = args.colorMode --[[@as string]]
        local isLab <const> = colorMode == "LAB"
        local isHsl <const> = colorMode == "HSL"
        local isHsv <const> = colorMode == "HSV"
        local hslAxis <const> = args.hslAxis --[[@as string]]
        local hsvAxis <const> = args.hsvAxis --[[@as string]]
        local isLight <const> = hslAxis == "LIGHTNESS"
        local isValue <const> = hsvAxis == "VALUE"

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
        local args <const> = dlg.data
        local hslAxis <const> = args.hslAxis --[[@as string]]
        local isLight <const> = hslAxis == "LIGHTNESS"
        local isSat <const> = hslAxis == "SATURATION"
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
        local args <const> = dlg.data
        local hsvAxis <const> = args.hsvAxis --[[@as string]]
        local isValue <const> = hsvAxis == "VALUE"
        local isSat <const> = hsvAxis == "SATURATION"
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
    max = 254,
    value = defaults.minSat,
    visible = defaults.showWheelSettings
        and defaults.hslAxis == "SATURATION"
        or defaults.hsvAxis == "SATURATION"
}

dlg:slider {
    id = "maxSat",
    min = 1,
    max = 255,
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
    max = 254,
    value = defaults.minLight,
    visible = defaults.showWheelSettings
        and (defaults.colorMode == "HSL"
            or defaults.colorMode == "LAB")
        and defaults.hslAxis == "LIGHTNESS"
}

dlg:slider {
    id = "maxLight",
    min = 1,
    max = 255,
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
    max = 254,
    value = defaults.minValue,
    visible = defaults.showWheelSettings
        and defaults.colorMode == "HSV"
        and defaults.hslAxis == "VALUE"
}

dlg:slider {
    id = "maxValue",
    min = 1,
    max = 255,
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

dlg:combobox {
    id = "remapHue",
    label = "Hue:",
    option = defaults.remapHue,
    options = { "RGB", "RYB", "RYGB", "OKLAB" },
    visible = defaults.showWheelSettings
}

dlg:newrow { always = false }

dlg:button {
    id = "gradient",
    text = "&GRD",
    focus = false,
    onclick = function()
        local args <const> = dlg.data
        local gradWidth <const> = defaults.gradWidth
        local gradHeight <const> = defaults.gradHeight
        local colorMode <const> = args.colorMode or defaults.colorMode --[[@as string]]
        local swatchCount <const> = args.swatchCount or defaults.swatchCount --[[@as integer]]
        local hueDir <const> = args.hueDir or defaults.hueDir --[[@as string]]

        local foreColor <const> = app.fgColor
        local foreHex <const> = 0xff000000 | foreColor.rgbaPixel
        local r01Fore <const>, g01Fore <const>, b01Fore <const> = aseColorToRgb01(foreColor)
        local lFore <const>, aFore <const>, bFore <const> = ok_color.srgb_to_oklab(r01Fore, g01Fore, b01Fore)

        local backColor <const> = app.bgColor
        local backHex <const> = 0xff000000 | backColor.rgbaPixel
        local r01Back <const>, g01Back <const>, b01Back <const> = aseColorToRgb01(backColor)
        local lBack <const>, aBack <const>, bBack <const> = ok_color.srgb_to_oklab(r01Back, g01Back, b01Back)

        local hueFunc = lerpAngleNear
        if hueDir == "CW" then
            hueFunc = lerpAngleCw
        elseif hueDir == "CCW" then
            hueFunc = lerpAngleCcw
        end

        ---@type fun(fac: number): integer
        local lerpLab <const> = function(fac)
            local u <const> = 1.0 - fac
            local cr <const>, cg <const>, cb <const> = ok_color.oklab_to_srgb(
                u * lBack + fac * lFore,
                u * aBack + fac * aFore,
                u * bBack + fac * bFore
            )
            return srgb01ToHex(cr, cg, cb)
        end

        local lerpFunc = lerpLab
        if colorMode == "HSL" then
            local hHslFore <const>, sHslFore <const>, lHslFore <const> = ok_color.oklab_to_okhsl(lFore, aFore, bFore)
            local hHslBack <const>, sHslBack <const>, lHslBack <const> = ok_color.oklab_to_okhsl(lBack, aBack, bBack)
            if sHslFore < 0.00001 or sHslBack < 0.00001 then
                lerpFunc = lerpLab
            else
                lerpFunc = function(fac)
                    if fac <= 0.0 then return backHex end
                    if fac >= 1.0 then return foreHex end
                    local u <const> = 1.0 - fac
                    local cr <const>, cg <const>, cb <const> = ok_color.okhsl_to_srgb(
                        hueFunc(hHslBack, hHslFore, fac, 1.0),
                        u * sHslBack + fac * sHslFore,
                        u * lHslBack + fac * lHslFore)
                    return srgb01ToHex(cr, cg, cb)
                end
            end
        elseif colorMode == "HSV" then
            local hHsvFore <const>, sHsvFore <const>, vHsvFore <const> = ok_color.oklab_to_okhsv(lFore, aFore, bFore)
            local hHsvBack <const>, sHsvBack <const>, vHsvBack <const> = ok_color.oklab_to_okhsb(lBack, aBack, bBack)
            if sHsvFore < 0.00001 or sHsvBack < 0.00001 then
                lerpFunc = lerpLab
            else
                lerpFunc = function(fac)
                    if fac <= 0.0 then return backHex end
                    if fac >= 1.0 then return foreHex end
                    local u <const> = 1.0 - fac
                    local cr <const>, cg <const>, cb <const> = ok_color.okhsv_to_srgb(
                        hueFunc(hHsvBack, hHsvFore, fac, 1.0),
                        u * sHsvBack + fac * sHsvFore,
                        u * vHsvBack + fac * vHsvFore)
                    return srgb01ToHex(cr, cg, cb)
                end
            end
        end

        preserveForeBack()

        -- As a precaution against crashes, do not allow slices UI interface
        -- to be active.
        local appTool <const> = app.tool
        if appTool then
            local toolName <const> = appTool.id
            if toolName == "slice" then
                app.tool = "hand"
            end
        end

        local gradSpec <const> = ImageSpec {
            width = gradWidth,
            height = gradHeight,
            colorMode = ColorMode.RGB,
            transparentColor = 0
        }
        gradSpec.colorSpace = ColorSpace { sRGB = true }
        local gradSprite <const> = Sprite(gradSpec)
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

        ---@type table<integer, integer>
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
        local pal <const> = Palette(palIdx)
        for k, v in pairs(swatchesDict) do
            pal:setColor(v, k)
        end
        gradSprite:setPalette(pal)

        -- Turn off onion skin loop through tag frames.
        local appPrefs <const> = app.preferences
        if appPrefs then
            local docPrefs <const> = appPrefs.document(gradSprite)
            if docPrefs then
                local onionSkinPrefs <const> = docPrefs.onionskin
                if onionSkinPrefs then
                    onionSkinPrefs.loop_tag = false
                end

                local thumbPrefs <const> = docPrefs.thumbnails
                if thumbPrefs then
                    thumbPrefs.enabled = true
                    thumbPrefs.zoom = 1
                    thumbPrefs.overlay_enabled = true
                end
            end
        end

        app.sprite = gradSprite
        app.layer = segLayer
        app.refresh()
    end
}

dlg:button {
    id = "wheel",
    text = "&WHL",
    focus = false,
    onclick = function()
        -- There is some known discontinuity for saturated dark blues.
        -- See { h = 264.0 / 360.0, s = 100.0 / 100.0, l = 28.0 / 100.0 },
        -- hex code #0009c5.

        -- Cache methods.
        local atan2 <const> = math.atan
        local sqrt <const> = math.sqrt
        local floor <const> = math.floor
        local max <const> = math.max
        local min <const> = math.min
        local strpack <const> = string.pack
        local tconcat <const> = table.concat
        local hsl_to_srgb <const> = ok_color.okhsl_to_srgb
        local hsv_to_srgb <const> = ok_color.okhsv_to_srgb

        -- Unpack arguments.
        local args <const> = dlg.data
        local size <const> = args.size or defaults.size --[[@as integer]]
        local szSq <const> = size * size
        local szInv <const> = 1.0 / (size - 1.0)
        local iToStep = 1.0
        local iOffset = 0.5
        local reqFrames <const> = args.frames or defaults.frames --[[@as integer]]
        if reqFrames > 1 then
            iToStep = 1.0 / (reqFrames - 1.0)
            iOffset = 0.0
        end
        local colorMode <const> = args.colorMode or defaults.colorMode --[[@as string]]
        local hslAxis <const> = args.hslAxis or defaults.hslAxis --[[@as string]]
        local hsvAxis <const> = args.hsvAxis or defaults.hsvAxis --[[@as string]]
        local minLgt = args.minLight or defaults.minLight --[[@as number]]
        local maxLgt = args.maxLight or defaults.maxLight --[[@as number]]
        local minVal = args.minValue or defaults.minValue --[[@as number]]
        local maxVal = args.maxValue or defaults.maxValue --[[@as number]]
        local minSat = args.minSat or defaults.minSat --[[@as number]]
        local maxSat = args.maxSat or defaults.maxSat --[[@as number]]
        local ringCount <const> = args.ringCount or defaults.ringCount --[[@as integer]]
        local sectorCount <const> = args.sectorCount or defaults.sectorCount --[[@as integer]]
        local remapHue <const> = args.remapHue or defaults.remapHue --[[@as string]]

        -- Offset by 30 degrees to match Aseprite's color wheel.
        local useRemapHue <const> = remapHue ~= "OKLAB"
        local useRgbHue <const> = remapHue == "RGB"
        local useRybHue <const> = remapHue == "RYB"
        local useRygbHue <const> = remapHue == "RYGB"

        local angleOffset <const> = useRygbHue and 0.0 or math.rad(30.0)

        local hueRemapTable = {}
        local lenRemapTable = 0
        if useRgbHue then
            hueRemapTable = rgbHueRemapTable24
            lenRemapTable = #rgbHueRemapTable24
        elseif useRygbHue then
            hueRemapTable = rygbHueRemapTable24
            lenRemapTable = #rygbHueRemapTable24
        elseif useRybHue then
            hueRemapTable = rybHueRemapTable24
            lenRemapTable = #rybHueRemapTable24
        end

        minSat = minSat / 255.0
        maxSat = maxSat / 255.0
        minLgt = minLgt / 255.0
        maxLgt = maxLgt / 255.0
        minVal = minVal / 255.0
        maxVal = maxVal / 255.0

        local useHsv = colorMode == "HSV"
        local useSat = false
        if colorMode == "HSV" then
            useSat = hsvAxis == "SATURATION"
        else
            useSat = hslAxis == "SATURATION"
        end

        ---@type Image[]
        local wheelImgs <const> = {}
        for i = 1, reqFrames, 1 do
            local wheelImg <const> = Image(size, size)

            -- Calculate light from frame count.
            local fac0 <const> = (i - 1.0) * iToStep + iOffset
            local sat = minSat
            local light = minLgt
            local value = minVal

            if useSat then
                sat = (1.0 - fac0) * minSat + fac0 * maxSat
            elseif useHsv then
                value = (1.0 - fac0) * minVal + fac0 * maxVal
            else
                light = (1.0 - fac0) * minLgt + fac0 * maxLgt
            end

            ---@type string[]
            local pixels = {}
            local j = 0
            while j < szSq do
                -- Find rise.
                local y <const> = j // size
                local yNrm <const> = y * szInv
                local ySgn <const> = 1.0 - (yNrm + yNrm)

                -- Find run.
                local x = j % size
                local xNrm <const> = x * szInv
                local xSgn <const> = xNrm + xNrm - 1.0

                local r8 = 0
                local g8 = 0
                local b8 = 0
                local a8 = 0

                -- Find square magnitude.
                -- Magnitude correlates with saturation.
                local magSq <const> = xSgn * xSgn + ySgn * ySgn
                if magSq <= 1.0 then
                    local r01, g01, b01 = 0, 0, 0

                    -- Convert from [-PI, PI] to [0.0, 1.0].
                    -- 1 / TAU approximately equals 0.159.
                    -- % operator is floor modulo.
                    local hue = atan2(ySgn, xSgn) + angleOffset
                    hue = hue % 6.283185307179586
                    hue = hue * 0.15915494309189535
                    hue = quantizeSigned(hue, sectorCount)

                    -- Remap hue to RYB color wheel.
                    if useRemapHue then
                        local hueScaled <const> = hue * (lenRemapTable - 1)
                        local hueIdx <const> = floor(hueScaled)
                        local hueFrac <const> = hueScaled - hueIdx
                        local oHue <const> = hueRemapTable[1 + hueIdx]
                        local dHue <const> = hueRemapTable[1 + (hueIdx + 1) % lenRemapTable]
                        hue = (1.0 - hueFrac) * oHue + hueFrac * dHue
                    end

                    local mag <const> = sqrt(magSq)
                    local complMag <const> = 1.0 - mag
                    if useSat then
                        if useHsv then
                            value = complMag * maxVal + mag * minVal
                            value = quantizeUnsigned(value, ringCount)
                        else
                            light = complMag * maxLgt + mag * minLgt
                            light = quantizeUnsigned(light, ringCount)
                        end
                    else
                        sat = complMag * minSat + mag * maxSat
                        sat = quantizeUnsigned(sat, ringCount)
                    end

                    if useHsv then
                        r01, g01, b01 = hsv_to_srgb(hue, sat, value)
                    else
                        r01, g01, b01 = hsl_to_srgb(hue, sat, light)
                    end

                    -- Values still go out of gamut, particularly for
                    -- saturated blues at medium light.
                    r8 = floor(min(max(r01, 0.0), 1.0) * 255 + 0.5)
                    g8 = floor(min(max(g01, 0.0), 1.0) * 255 + 0.5)
                    b8 = floor(min(max(b01, 0.0), 1.0) * 255 + 0.5)
                    a8 = 255
                end

                j = j + 1
                pixels[j] = strpack("B B B B", r8, g8, b8, a8)
            end

            wheelImg.bytes = tconcat(pixels)

            wheelImgs[i] = wheelImg
        end

        preserveForeBack()

        -- As a precaution against crashes, do not allow slices UI interface
        -- to be active.
        local appTool <const> = app.tool
        if appTool then
            local toolName <const> = appTool.id
            if toolName == "slice" then
                app.tool = "hand"
            end
        end

        local wheelSpec <const> = ImageSpec {
            width = size,
            height = size,
            colorMode = ColorMode.RGB,
            transparentColor = 0
        }
        wheelSpec.colorSpace = ColorSpace { sRGB = true }
        local sprite <const> = Sprite(wheelSpec)
        sprite.filename = string.format(
            "OK Wheel %d (%s Hue)",
            reqFrames,
            remapHue)
        local oldFrameLen <const> = #sprite.frames
        local needed <const> = math.max(0, reqFrames - oldFrameLen)
        local fps <const> = args.fps or defaults.fps --[[@as integer]]
        local duration <const> = 1.0 / math.max(1, fps)
        sprite.frames[1].duration = duration
        createNewFrames(sprite, needed, duration)

        -- Set first layer to gamut.
        local gamutLayer <const> = sprite.layers[1]
        gamutLayer.name = "Color Wheel"

        -- Create gamut layer cels.
        app.transaction("Create Cels", function()
            for i = 1, reqFrames, 1 do
                sprite:newCel(
                    gamutLayer,
                    sprite.frames[i],
                    wheelImgs[i])
            end
        end)

        -- Assign a palette.
        -- Do not use defaultPalette.
        app.transaction("Set Palette", function()
            local palette <const> = sprite.palettes[1]
            palette:resize(10)
            palette:setColor(0, Color { r = 0, g = 0, b = 0, a = 0 })
            palette:setColor(1, Color { r = 0, g = 0, b = 0, a = 255 })
            palette:setColor(2, Color { r = 255, g = 255, b = 255, a = 255 })
            palette:setColor(3, Color { r = 254, g = 91, b = 89, a = 255 })
            palette:setColor(4, Color { r = 247, g = 165, b = 71, a = 255 })
            palette:setColor(5, Color { r = 243, g = 206, b = 82, a = 255 })
            palette:setColor(6, Color { r = 106, g = 205, b = 91, a = 255 })
            palette:setColor(7, Color { r = 87, g = 185, b = 242, a = 255 })
            palette:setColor(8, Color { r = 209, g = 134, b = 223, a = 255 })
            palette:setColor(9, Color { r = 165, g = 165, b = 167, a = 255 })
        end)

        -- Turn off onion skin loop through tag frames.
        local appPrefs <const> = app.preferences
        if appPrefs then
            local docPrefs <const> = appPrefs.document(sprite)
            if docPrefs then
                local onionSkinPrefs <const> = docPrefs.onionskin
                if onionSkinPrefs then
                    onionSkinPrefs.loop_tag = false
                end

                local thumbPrefs <const> = docPrefs.thumbnails
                if thumbPrefs then
                    thumbPrefs.enabled = true
                    thumbPrefs.zoom = 1
                    thumbPrefs.overlay_enabled = true
                end
            end
        end

        app.sprite = sprite
        app.layer = gamutLayer

        -- Because light correlates to frames, the middle
        -- frame should be the default.
        if useSat or useHsv then
            app.frame = sprite.frames[#sprite.frames]
        else
            app.frame = sprite.frames[
            math.ceil(#sprite.frames / 2)]
        end

        app.refresh()
    end
}

dlg:button {
    id = "cancel",
    text = "&X",
    onclick = function()
        dlg:close()
    end
}

dlg:show {
    autoscrollbars = false,
    wait = false
}

local dlgBounds <const> = dlg.bounds
dlg.bounds = Rectangle(
    16, dlgBounds.y,
    dlgBounds.w, dlgBounds.h)