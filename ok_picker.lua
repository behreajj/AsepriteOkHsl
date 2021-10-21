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

local function copyColorByValue(aseColor)
    return Color(
        aseColor.red,
        aseColor.green,
        aseColor.blue,
        aseColor.alpha)
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

local function rgb01ToAseColor(rgb, alpha)
    return Color(
        math.tointeger(0.5 + 0xff * rgb.r),
        math.tointeger(0.5 + 0xff * rgb.g),
        math.tointeger(0.5 + 0xff * rgb.b),
        alpha or 255)
end

local function setFromAse(dialog, aseColor, primary)
    primary = copyColorByValue(aseColor)
    dialog:modify { id = "baseColor", colors = { primary } }
    dialog:modify { id = "alpha", value = primary.alpha }
    dialog:modify { id = "hexCode", text = colorToHexWeb(primary) }

    local sr01 = primary.red * 0.00392156862745098
    local sg01 = primary.green * 0.00392156862745098
    local sb01 = primary.blue * 0.00392156862745098
    local srgb = { r = sr01, g = sg01, b = sb01 }

    -- TODO This could be more efficient if srgb is
    -- converted to lab, then lab is converted to hsl,hsv.
    local lab = ok_color.linear_srgb_to_oklab({
		r = ok_color.srgb_transfer_function_inv(sr01),
		g = ok_color.srgb_transfer_function_inv(sg01),
		b = ok_color.srgb_transfer_function_inv(sb01)
		})
    -- print(string.format(
    --     "L: %.6f a: %.6f b: %.6f",
    --     lab.L, lab.a, lab.b))

    local labLgtInt = math.tointeger(0.5 + 100.0 * lab.L)
    local labAInt = math.tointeger(0.5 + 100.0 * lab.a)
    local labBInt = math.tointeger(0.5 + 100.0 * lab.b)
    dialog:modify { id = "labLgt", value = labLgtInt }
    dialog:modify { id = "labA", value = labAInt }
    dialog:modify { id = "labB", value = labBInt }

    local hsl = ok_color.srgb_to_okhsl(srgb)
    local hslHueInt = math.tointeger(0.5 + 360.0 * hsl.h)
    local hslSatInt = math.tointeger(0.5 + 100.0 * hsl.s)
    local hslLgtInt = math.tointeger(0.5 + 100.0 * hsl.l)

    if hslSatInt > 0 then
        dialog:modify { id = "hslHue", value = hslHueInt }
    end
    dialog:modify { id = "hslSat", value = hslSatInt }
    dialog:modify { id = "hslLgt", value = hslLgtInt }

    local hsv = ok_color.srgb_to_okhsv(srgb)
    local hsvHueInt = math.tointeger(0.5 + 360.0 * hsv.h)
    local hsvSatInt = math.tointeger(0.5 + 100.0 * hsv.s)
    local hsvValInt = math.tointeger(0.5 + 100.0 * hsv.v)

    if hsvSatInt > 0 then
        dialog:modify { id = "hsvHue", value = hsvHueInt }
    end
    dialog:modify { id = "hsvSat", value = hsvSatInt }
    dialog:modify { id = "hsvVal", value = hsvValInt }
end

local function updateColor(dialog, primary)
    local args = dialog.data
    local alpha = args.alpha
    -- if alpha > 0 then
    local colorMode = args.colorMode
    if colorMode == "HSV" then
        local h = args.hsvHue
        local s = args.hsvSat
        local v = args.hsvVal

        local rgb01 = ok_color.okhsv_to_srgb({
            h = h * 0.002777777777777778,
            s = s * 0.01,
            v = v * 0.01
        })
        primary = rgb01ToAseColor(rgb01, alpha)
    elseif colorMode == "LAB" then
        local l = args.labLgt
        local a = args.labA
        local b = args.labB

        -- TODO Implement.
    else
        local h = args.hslHue
        local s = args.hslSat
        local l = args.hslLgt

        local rgb01 = ok_color.okhsl_to_srgb({
            h = h * 0.002777777777777778,
            s = s * 0.01,
            l = l * 0.01
        })
        primary = rgb01ToAseColor(rgb01, alpha)
    end
    -- else
    --     primary = Color(0, 0, 0, 0)
    -- end

    dialog:modify {
        id = "baseColor",
        colors = { primary }
    }

    dialog:modify {
        id = "hexCode",
        text = colorToHexWeb(primary)
    }
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

local primary = Color(255, 0, 0, 255)

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
}

local dlg = Dialog { title = "OkLab Color Picker" }

dlg:button {
    id = "fgGet",
    label = "Get:",
    text = "&FORE",
    focus = false,
    onclick = function()
       setFromAse(dlg, app.fgColor, primary)
    end
}

dlg:button {
    id = "bgGet",
    text = "&BACK",
    focus = false,
    onclick = function()
       app.command.SwitchColors()
       setFromAse(dlg, app.fgColor, primary)
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
        updateColor(dlg, primary)
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
        updateColor(dlg, primary)
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
        updateColor(dlg, primary)
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
        updateColor(dlg, primary)
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
        updateColor(dlg, primary)
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
        updateColor(dlg, primary)
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
        updateColor(dlg, primary)
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
        updateColor(dlg, primary)
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
        updateColor(dlg, primary)
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
        updateColor(dlg, primary)
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

-- dlg:newrow { always = false }

-- dlg:slider {
--     id = "fps",
--     label = "FPS:",
--     min = 1,
--     max = 90,
--     value = defaults.fps,
--     visible = defaults.showWheelSettings
-- }

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
        -- dlg:modify { id = "fps", visible = state }
        dlg:modify { id = "sectorCount", visible = state }
        dlg:modify { id = "ringCount", visible = state }
    end
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