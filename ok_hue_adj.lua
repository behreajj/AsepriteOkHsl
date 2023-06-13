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

local grayHues = { "OMIT", "ZERO" }
local clrModes = { "HSL", "HSV" }

local defaults = {
    clrMode = "HSL",
    hAdj = 0,
    sAdj = 0,
    lAdj = 0,
    vAdj = 0,
    aAdj = 0,
    grayHue = "OMIT",
    copyToLayer = true,
    pullFocus = false
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
    min = -100,
    max = 100,
    value = defaults.sAdj
}

dlg:newrow { always = false }

dlg:slider {
    id = "lAdj",
    label = "Lightness:",
    min = -100,
    max = 100,
    value = defaults.lAdj,
    visible = defaults.clrMode == "HSL"
}

dlg:newrow { always = false }

dlg:slider {
    id = "vAdj",
    label = "Value:",
    min = -100,
    max = 100,
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
        local activeSprite = app.activeSprite
        if not activeSprite then
            app.alert("There is no active sprite.")
            return
        end

        local activeLayer = app.activeLayer
        if not activeLayer then
            app.alert("There is no active layer.")
            return
        end

        local apiVersion = app.apiVersion
        if apiVersion >= 15 then
            if activeLayer.isReference then
                app.alert("Reference layers are not supported.")
                return
            end
        end

        local version = app.version
        if version.major >= 1
            and version.minor >= 3 then
            if activeLayer.isTilemap then
                app.alert("Tile map layers are not supported.")
                return
            end
        end

        local srcCel = app.activeCel
        if not srcCel then
            app.alert("There is no active cel.")
            return
        end

        local specSprite = activeSprite.spec
        local colorMode = specSprite.colorMode
        if colorMode ~= ColorMode.RGB then
            app.alert("Only RGB color mode is supported.")
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

        local useOmit = grayHue == "OMIT"
        local useZero = grayHue == "ZERO"
        local useHsv = clrMode == "HSV"
        local grayZero = 0.0

        -- Scale adjustments appropriately.
        local hScl = hAdj / 360.0
        local sScl = sAdj * 0.01
        local lScl = lAdj * 0.01
        local vScl = vAdj * 0.01

        -- Cache loop methods.
        -- local abs = math.abs
        local max = math.max
        local min = math.min
        local trunc = math.floor
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
        for elm in srcpxitr do
            srcDict[elm()] = true
        end

        ---@type table<integer, integer>
        local trgDict = {}
        for k, _ in pairs(srcDict) do
            local alpha = k >> 0x18 & 0xff
            if alpha > 0 then
                local srgb = {
                    r = (k & 0xff) / 255.0,
                    g = (k >> 0x08 & 0xff) / 255.0,
                    b = (k >> 0x10 & 0xff) / 255.0
                }
                local oklab = srgb_to_oklab(srgb)

                local okhsx = nil
                if useHsv then
                    okhsx = oklab_to_okhsv(oklab)
                else
                    okhsx = oklab_to_okhsl(oklab)
                end

                local alphaNew = alpha + aAdj
                local sNew = okhsx.s
                local hNew = okhsx.h

                if sNew <= 0.0 then
                    if useOmit then
                        hNew = 0.0
                        sNew = 0.0
                    elseif useZero then
                        hNew = grayZero + hScl
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
                local a255 = min(max(alphaNew, 0), 255)
                local b255 = trunc(min(max(srgbNew.b, 0.0), 1.0) * 255 + 0.5)
                local g255 = trunc(min(max(srgbNew.g, 0.0), 1.0) * 255 + 0.5)
                local r255 = trunc(min(max(srgbNew.r, 0.0), 1.0) * 255 + 0.5)

                trgDict[k] = (a255 << 0x18) | (b255 << 0x10) | (g255 << 0x08) | r255
            else
                trgDict[k] = 0
            end
        end

        local trgImg = srcImg:clone()
        local trgpxitr = trgImg:pixels()
        for elm in trgpxitr do
            elm(trgDict[elm()])
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
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show { wait = false }