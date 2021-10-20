dofile("./ok_color.lua")

-- Copyright(c) 2021 Bj�rn Ottosson
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

local defaults = {
    colorMode = "HSL",

    hslHue = 0,
    hslSat = 100,
    hslLgt = 50,

    hsvHue = 0,
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
}

local dlg = Dialog { title = "OkLab Color Picker" }

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
    visible = defaults.colorMode == "HSL"
}

dlg:newrow { always = false }

dlg:slider {
    id = "hslSat",
    label = "Saturation:",
    min = 0,
    max = 100,
    value = defaults.hslSat,
    visible = defaults.colorMode == "HSL"
}

dlg:newrow { always = false }

dlg:slider {
    id = "hslLgt",
    label = "Lightness:",
    min = 0,
    max = 100,
    value = defaults.hslLgt,
    visible = defaults.colorMode == "HSL"
}

dlg:newrow { always = false }

dlg:slider {
    id = "hsvHue",
    label = "Hue:",
    min = 0,
    max = 360,
    value = defaults.hsvHue,
    visible = defaults.colorMode == "HSV"
}

dlg:newrow { always = false }

dlg:slider {
    id = "hsvSat",
    label = "Saturation:",
    min = 0,
    max = 100,
    value = defaults.hsvSat,
    visible = defaults.colorMode == "HSV"
}

dlg:newrow { always = false }

dlg:slider {
    id = "hsvVal",
    label = "Value:",
    min = 0,
    max = 100,
    value = defaults.hsvVal,
    visible = defaults.colorMode == "HSV"
}

dlg:newrow { always = false }

dlg:slider {
    id = "labLgt",
    label = "Lightness:",
    min = 0,
    max = 100,
    value = defaults.labLgt,
    visible = defaults.colorMode == "LAB"
}

dlg:newrow { always = false }

dlg:slider {
    id = "labA",
    label = "A:",
    min = -110,
    max = 110,
    value = defaults.labA,
    visible = defaults.colorMode == "LAB"
}

dlg:newrow { always = false }

dlg:slider {
    id = "labB",
    label = "B:",
    min = -110,
    max = 110,
    value = defaults.labB,
    visible = defaults.colorMode == "LAB"
}

dlg:newrow { always = false }

dlg:button {
    id = "wheel",
    text = "&WHEEL",
    focus = false,
    onclick = function()
        local args = dlg.data

        -- Cache methods.
        -- atan is atan2 in newer Lua; older atan2 is deprecated.
        local atan2 = math.atan
        local sqrt = math.sqrt
        local trunc = math.tointeger

        -- Unpack arguments.
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
                    local rgbtuple = { 0.0, 0.0, 0.0 }

                    if sqSat > 0.0 then

                        -- Convert square magnitude to magnitude.
                        local sat = sqrt(sqSat)
                        local hue = atan2(ySgn, xSgn) + angleOffset

                        -- Convert from [-PI, PI] to [0.0, 1.0].
                        -- 1 / TAU approximately equals 0.159.
                        -- % operator is floor modulo.
                        hue = hue * 0.15915494309189535
                        hue = hue % 1.0

                        hue = quantizeSigned(hue, sectorCount)
                        sat = quantizeUnsigned(sat, ringCount)

                        -- hue = hue * 360
                        -- sat = sat * 100

                        rgbtuple = ok_color.okhsl_to_srgb({h = hue, s = sat, l = light})
                    else
                        rgbtuple = ok_color.okhsl_to_srgb({h = 0.0, s = 0.0, l = light})
                    end

                    -- Round [0.0, 1.0] up to [0, 255] unsigned byte.
                    local r255 = trunc(0.5 + rgbtuple.r * 255.0)
                    local g255 = trunc(0.5 + rgbtuple.g * 255.0)
                    local b255 = trunc(0.5 + rgbtuple.b * 255.0)

                    -- Composite into a 32-bit integer.
                    local hex = 0xff000000
                        | b255 << 0x10
                        | g255 << 0x08
                        | r255

                    -- Assign to iterator.
                    elm(hex)
                else
                    elm(0)
                end
            end
            wheelImgs[i] = wheelImg
        end

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
        local pal = Palette(#palColors)
        for i = 1, #palColors, 1 do
            pal:setColor(i - 1, palColors[i])
        end
        sprite:setPalette(pal)

        -- Because light correlates to frames, the middle
        -- frame should be the default.
        app.activeFrame = sprite.frames[
            math.ceil(#sprite.frames / 2)]
        app.refresh()
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }