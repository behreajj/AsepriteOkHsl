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

local grayHues = { "COOL", "OMIT", "WARM", "ZERO" }
local clrModes = { "HSL", "HSV" }

local defaults = {
    -- TODO: Warn when color profile is not sRGB?
    clrMode = "HSL",
    hAdj = 0,
    sAdj = 0,
    lAdj = 0,
    vAdj = 0,
    aAdj = 0,
    grayHue = "OMIT",
    copyToLayer = true,
    pullFocus = false,
    hYel = 110.0 / 360.0,
    hVio = 290.0 / 360.0,
    hZero = 0.0
}

local dlg = Dialog { title = "Adjust OkColor" }

dlg:combobox {
    id = "clrMode",
    label = "Mode:",
    option = defaults.clrMode,
    options = clrModes,
    onchange = function()
        local args = dlg.data
        local clrMode = args.clrMode --[[@as string]]
        local isHsv = clrMode == "HSV"
        local isHsl = clrMode == "HSL"
        dlg:modify { id = "lAdj", visible = isHsl }
        dlg:modify { id = "vAdj", visible = isHsv }
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "hAdj",
    label = "Hue:",
    min = -180,
    max = 180,
    value = defaults.hAdj
}

dlg:newrow { always = false }

dlg:slider {
    id = "sAdj",
    label = "Saturation:",
    min = -255,
    max = 255,
    value = defaults.sAdj
}

dlg:newrow { always = false }

dlg:slider {
    id = "lAdj",
    label = "Lightness:",
    min = -255,
    max = 255,
    value = defaults.lAdj,
    visible = defaults.clrMode == "HSL"
}

dlg:newrow { always = false }

dlg:slider {
    id = "vAdj",
    label = "Value:",
    min = -255,
    max = 255,
    value = defaults.vAdj,
    visible = defaults.clrMode == "HSV"
}

dlg:newrow { always = false }

dlg:slider {
    id = "aAdj",
    label = "Alpha:",
    min = -255,
    max = 255,
    value = defaults.aAdj
}

dlg:newrow { always = false }

dlg:combobox {
    id = "grayHue",
    label = "Grays:",
    option = defaults.grayHue,
    options = grayHues
}

dlg:newrow { always = false }

dlg:check {
    id = "copyToLayer",
    label = "As New Layer:",
    selected = defaults.copyToLayer
}

dlg:newrow { always = false }

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = defaults.pullFocus,
    onclick = function()
        ---@diagnostic disable-next-line: deprecated
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert { title = "Error", text = "There is no active sprite." }
            return
        end

        ---@diagnostic disable-next-line: deprecated
        local activeLayer = app.activeLayer
        if not activeLayer then
            app.alert { title = "Error", text = "There is no active layer." }
            return
        end

        local apiVersion = app.apiVersion
        if apiVersion >= 15 then
            if activeLayer.isReference then
                app.alert {
                    title = "Error",
                    text = "Reference layers are not supported."
                }
                return
            end
        end

        local version = app.version
        if (version.major >= 1
                and version.minor >= 3)
            or version.prereleaseLabel == "dev" then
            if activeLayer.isTilemap then
                app.alert {
                    title = "Error",
                    text = "Tile map layers are not supported."
                }
                return
            end
        end

        ---@diagnostic disable-next-line: deprecated
        local srcCel = app.activeCel
        if not srcCel then
            app.alert { title = "Error", text = "There is no active cel." }
            return
        end

        local specSprite = activeSprite.spec
        local colorMode = specSprite.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert {
                title = "Error",
                text = "Only RGB color mode is supported."
            }
            return
        end

        local args = dlg.data
        local clrMode = args.clrMode or defaults.clrMode --[[@as string]]
        local hAdj = args.hAdj or defaults.hAdj --[[@as integer]]
        local sAdj = args.sAdj or defaults.sAdj --[[@as integer]]
        local lAdj = args.lAdj or defaults.lAdj --[[@as integer]]
        local vAdj = args.vAdj or defaults.vAdj --[[@as integer]]
        local aAdj = args.aAdj or defaults.aAdj --[[@as integer]]
        local grayHue = args.grayHue or defaults.grayHue --[[@as string]]
        local copyToLayer = args.copyToLayer --[[@as boolean]]

        -- How to handle grays.
        local useCool = grayHue == "COOL"
        local useOmit = grayHue == "OMIT"
        local useWarm = grayHue == "WARM"
        local useZero = grayHue == "ZERO"
        local useHsv = clrMode == "HSV"

        -- For use in cool and warm options.
        local hYel = defaults.hYel
        local hVio = defaults.hVio
        local hZero = defaults.hZero

        -- Scale adjustments appropriately.
        local hScl = hAdj / 360.0
        local sScl = sAdj / 255.0
        local lScl = lAdj / 255.0
        local vScl = vAdj / 255.0

        -- Prevent background images from containing transparency.
        if activeLayer.isBackground and (not copyToLayer) then
            aAdj = 0
        end

        -- Cache loop methods.
        local max = math.max
        local min = math.min
        local floor = math.floor

        local pixelColor = app.pixelColor
        local decompA = pixelColor.rgbaA
        local decompB = pixelColor.rgbaB
        local decompG = pixelColor.rgbaG
        local decompR = pixelColor.rgbaR
        local composeRgba = pixelColor.rgba

        local srgb_to_oklab = ok_color.srgb_to_oklab
        local oklab_to_okhsl = ok_color.oklab_to_okhsl
        local oklab_to_okhsv = ok_color.oklab_to_okhsv
        local okhsl_to_oklab = ok_color.okhsl_to_oklab
        local okhsv_to_oklab = ok_color.okhsv_to_oklab
        local oklab_to_srgb = ok_color.oklab_to_srgb

        local srcImg = srcCel.image
        local srcpxitr = srcImg:pixels()
        ---@type table<integer, boolean>
        local srcDict = {}
        for pixel in srcpxitr do
            srcDict[pixel()] = true
        end

        ---@type table<integer, integer>
        local trgDict = {}
        for k, _ in pairs(srcDict) do
            local a255 = decompA(k)
            if a255 > 0 then
                local alphaNew = a255 + aAdj
                local a255n = min(max(alphaNew, 0), 255)

                if a255n > 0 then
                    local b255 = decompB(k)
                    local g255 = decompG(k)
                    local r255 = decompR(k)
                    local isGray = r255 == g255 and r255 == b255

                    local srgb = {
                        r = r255 / 255.0,
                        g = g255 / 255.0,
                        b = b255 / 255.0
                    }
                    local oklab = srgb_to_oklab(srgb)

                    local okhsx = nil
                    if useHsv then
                        okhsx = oklab_to_okhsv(oklab)
                    else
                        okhsx = oklab_to_okhsl(oklab)
                    end

                    local sNew = okhsx.s
                    local hNew = okhsx.h

                    if isGray then
                        if useCool then
                            local t = oklab.L
                            local u = 1.0 - t
                            hNew = u * hVio + t * hYel
                            hNew = hNew + hScl
                            sNew = sNew + sScl
                        elseif useOmit then
                            hNew = 0.0
                            sNew = 0.0
                        elseif useZero then
                            hNew = hZero + hScl
                            sNew = sNew + sScl
                        elseif useWarm then
                            local t = oklab.L
                            local u = 1.0 - t
                            hNew = u * hVio + t * (hYel + 1.0)
                            hNew = hNew + hScl
                            sNew = sNew + sScl
                        else
                            hNew = hNew + hScl
                            sNew = sNew + sScl
                        end
                    else
                        hNew = hNew + hScl
                        sNew = sNew + sScl
                    end

                    local oklabNew = nil
                    if useHsv then
                        local okhsvNew = {
                            h = hNew,
                            s = sNew,
                            v = okhsx.v + vScl
                        }
                        oklabNew = okhsv_to_oklab(okhsvNew)
                    else
                        local okhslNew = {
                            h = hNew,
                            s = sNew,
                            l = okhsx.l + lScl
                        }
                        oklabNew = okhsl_to_oklab(okhslNew)
                    end

                    local srgbNew = oklab_to_srgb(oklabNew)
                    local b255n = floor(min(max(srgbNew.b, 0.0), 1.0) * 255 + 0.5)
                    local g255n = floor(min(max(srgbNew.g, 0.0), 1.0) * 255 + 0.5)
                    local r255n = floor(min(max(srgbNew.r, 0.0), 1.0) * 255 + 0.5)
                    trgDict[k] = composeRgba(r255n, g255n, b255n, a255n)
                else
                    trgDict[k] = 0
                end
            else
                trgDict[k] = 0
            end
        end

        local trgImg = srcImg:clone()
        local trgpxitr = trgImg:pixels()
        for pixel in trgpxitr do
            pixel(trgDict[pixel()])
        end

        if copyToLayer then
            app.transaction(function()
                local srcLayer = srcCel.layer

                -- Copy layer.
                local trgLayer = activeSprite:newLayer()
                local srcLayerName = "Layer"
                if #srcLayer.name > 0 then
                    srcLayerName = srcLayer.name
                end
                trgLayer.name = string.format(
                    "%s.Adjusted", srcLayerName)
                if srcLayer.opacity then
                    trgLayer.opacity = srcLayer.opacity
                end
                if srcLayer.blendMode then
                    trgLayer.blendMode = srcLayer.blendMode
                end

                -- Copy cel.
                local srcFrame = srcCel.frame or activeSprite.frames[1]
                local trgCel = activeSprite:newCel(
                    trgLayer, srcFrame,
                    trgImg, srcCel.position)
                trgCel.opacity = srcCel.opacity
            end)
        else
            srcCel.image = trgImg
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