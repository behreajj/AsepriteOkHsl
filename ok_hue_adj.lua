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

local targets <const> = { "ACTIVE", "ALL" }
local grayHues <const> = { "COOL", "OMIT", "WARM", "ZERO" }
local clrModes <const> = { "HSL", "HSV" }

local defaults <const> = {
    target = "ACTIVE",
    clrMode = "HSL",
    hAdj = 0,
    sAdj = 0,
    lAdj = 0,
    vAdj = 0,
    aAdj = 0,
    grayHue = "OMIT",
    hYel = 110.0 / 360.0,
    hVio = 290.0 / 360.0,
    hZero = 0.0
}

---@param r8 integer
---@param g8 integer
---@param b8 integer
---@param a8 integer
---@param hScl number
---@param sScl number
---@param lScl number
---@param vScl number
---@param aAdj integer
---@param useHsv boolean
---@param useCool boolean
---@param useOmit boolean
---@param useZero boolean
---@param useWarm boolean
---@param hVio number
---@param hYel number
---@param hZero number
---@return integer r8n
---@return integer g8n
---@return integer b8n
---@return integer a8n
local function adjustColor(
    r8, g8, b8, a8,
    hScl, sScl, lScl, vScl, aAdj,
    useHsv,
    useCool, useOmit, useZero, useWarm,
    hVio, hYel, hZero)
    local r8n, g8n, b8n, a8n = 0, 0, 0, 0

    if a8 > 0 then
        local alphaNew <const> = a8 + aAdj
        a8n = math.min(math.max(alphaNew, 0), 255)

        if a8n > 0 then
            local isGray <const> = r8 == g8 and r8 == b8

            local okl <const>, oka <const>, okb <const> = ok_color.srgb_to_oklab(
                r8 / 255.0, g8 / 255.0, b8 / 255.0)

            local hNew, sNew, xNew = 0.0, 0.0, 0.0
            if useHsv then
                hNew, sNew, xNew = ok_color.oklab_to_okhsv(okl, oka, okb)
            else
                hNew, sNew, xNew = ok_color.oklab_to_okhsl(okl, oka, okb)
            end

            if isGray then
                if useCool then
                    local t <const> = okl
                    local u <const> = 1.0 - t
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
                    local t <const> = okl
                    local u <const> = 1.0 - t
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

            local oklNew, okaNew, okbNew = 0.0, 0.0, 0.0
            if useHsv then
                oklNew, okaNew, okbNew = ok_color.okhsv_to_oklab(hNew, sNew, xNew + vScl)
            else
                oklNew, okaNew, okbNew = ok_color.okhsl_to_oklab(hNew, sNew, xNew + lScl)
            end

            local rNew <const>, gNew <const>, bNew <const> = ok_color.oklab_to_srgb(
                oklNew, okaNew, okbNew)
            b8n = math.floor(math.min(math.max(
                bNew, 0.0), 1.0) * 255.0 + 0.5)
            g8n = math.floor(math.min(math.max(
                gNew, 0.0), 1.0) * 255.0 + 0.5)
            r8n = math.floor(math.min(math.max(
                rNew, 0.0), 1.0) * 255.0 + 0.5)
        end
    end

    return r8n, g8n, b8n, a8n
end

---@param srcImg Image
---@param xtl integer
---@param ytl integer
---@param mask Selection
---@param hScl number
---@param sScl number
---@param lScl number
---@param vScl number
---@param aAdj integer
---@param useHsv boolean
---@param useCool boolean
---@param useOmit boolean
---@param useZero boolean
---@param useWarm boolean
---@param hVio number
---@param hYel number
---@param hZero number
---@return Image
local function adjustImage(
    srcImg, xtl, ytl, mask,
    hScl, sScl, lScl, vScl, aAdj,
    useHsv,
    useCool, useOmit, useZero, useWarm,
    hVio, hYel, hZero)
    ---@type table<integer, integer[]>
    local srcDict <const> = {}

    local strpack <const> = string.pack
    local strsub <const> = string.sub
    local strunpack <const> = string.unpack

    local srcSpec <const> = srcImg.spec
    local srcWidth <const> = srcSpec.width
    local srcHeight <const> = srcSpec.height
    local srcBpp <const> = srcImg.bytesPerPixel
    local srcBytes <const> = srcImg.bytes
    local fmt <const> = "<I" .. srcBpp

    local srcArea <const> = srcWidth * srcHeight
    local i = 0
    while i < srcArea do
        local iBpp <const> = i * srcBpp
        local srcPixel <const> = strunpack(fmt, strsub(
            srcBytes, 1 + iBpp, srcBpp + iBpp))
        local arr <const> = srcDict[srcPixel]
        if arr then
            arr[#arr + 1] = i
        else
            srcDict[srcPixel] = { i }
        end
        i = i + 1
    end

    ---@type string[]
    local trgByteArr <const> = {}
    local pixelColor <const> = app.pixelColor
    local srcColorMode <const> = srcSpec.colorMode
    if srcColorMode == ColorMode.GRAY then
        local decompAGray <const> = pixelColor.grayaA
        local decompVGray <const> = pixelColor.grayaV
        local composeGray <const> = pixelColor.graya

        for srcPixel, srcIndices in pairs(srcDict) do
            local v8 <const> = decompVGray(srcPixel)
            local a8 <const> = decompAGray(srcPixel)

            local r8n <const>,
            g8n <const>,
            b8n <const>,
            a8n <const> = adjustColor(
                v8, v8, v8, a8,
                hScl, sScl, lScl, vScl, aAdj,
                useHsv,
                false, true, false, false,
                hVio, hYel, hZero)
            local n <const> = composeGray(b8n, a8n)

            local lenSrcIndices <const> = #srcIndices
            local j = 0
            while j < lenSrcIndices do
                j = j + 1
                local index <const> = srcIndices[j]
                local x <const> = index % srcWidth
                local y <const> = index // srcWidth

                if mask:contains(xtl + x, ytl + y) then
                    trgByteArr[1 + index] = strpack(fmt, n)
                else
                    trgByteArr[1 + index] = strpack(fmt, srcPixel)
                end
            end
        end
    else
        local decompA <const> = pixelColor.rgbaA
        local decompB <const> = pixelColor.rgbaB
        local decompG <const> = pixelColor.rgbaG
        local decompR <const> = pixelColor.rgbaR
        local composeRgba <const> = pixelColor.rgba

        for srcPixel, srcIndices in pairs(srcDict) do
            local r8 <const> = decompR(srcPixel)
            local g8 <const> = decompG(srcPixel)
            local b8 <const> = decompB(srcPixel)
            local a8 <const> = decompA(srcPixel)

            local r8n <const>,
            g8n <const>,
            b8n <const>,
            a8n <const> = adjustColor(
                r8, g8, b8, a8,
                hScl, sScl, lScl, vScl, aAdj,
                useHsv,
                useCool, useOmit, useZero, useWarm,
                hVio, hYel, hZero)
            local n <const> = composeRgba(r8n, g8n, b8n, a8n)

            local lenSrcIndices <const> = #srcIndices
            local j = 0
            while j < lenSrcIndices do
                j = j + 1
                local index <const> = srcIndices[j]
                local x <const> = index % srcWidth
                local y <const> = index // srcWidth

                if mask:contains(xtl + x, ytl + y) then
                    trgByteArr[1 + index] = strpack(fmt, n)
                else
                    trgByteArr[1 + index] = strpack(fmt, srcPixel)
                end
            end
        end
    end

    local trgImg <const> = Image(srcImg.spec)
    trgImg.bytes = table.concat(trgByteArr)
    return trgImg
end

local dlg <const> = Dialog { title = "Adjust OkColor" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = defaults.target,
    options = targets
}

dlg:newrow { always = false }

dlg:combobox {
    id = "clrMode",
    label = "Mode:",
    option = defaults.clrMode,
    options = clrModes,
    onchange = function()
        local args <const> = dlg.data
        local clrMode <const> = args.clrMode --[[@as string]]
        local isHsv <const> = clrMode == "HSV"
        local isHsl <const> = clrMode == "HSL"
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

dlg:button {
    id = "confirm",
    text = "&OK",
    onclick = function()
        local activeSprite <const> = app.sprite
        if not activeSprite then
            app.alert { title = "Error", text = "There is no active sprite." }
            return
        end

        local activeFrame <const> = app.frame
            or activeSprite.frames[1]

        local args <const> = dlg.data
        local target <const> = args.target or defaults.target --[[@as string]]
        local clrMode <const> = args.clrMode or defaults.clrMode --[[@as string]]
        local hAdj <const> = args.hAdj or defaults.hAdj --[[@as integer]]
        local sAdj <const> = args.sAdj or defaults.sAdj --[[@as integer]]
        local lAdj <const> = args.lAdj or defaults.lAdj --[[@as integer]]
        local vAdj <const> = args.vAdj or defaults.vAdj --[[@as integer]]
        local aAdj <const> = args.aAdj or defaults.aAdj --[[@as integer]]
        local grayHue <const> = args.grayHue or defaults.grayHue --[[@as string]]

        -- How to handle grays.
        local useCool <const> = grayHue == "COOL"
        local useOmit <const> = grayHue == "OMIT"
        local useWarm <const> = grayHue == "WARM"
        local useZero <const> = grayHue == "ZERO"
        local useHsv <const> = clrMode == "HSV"

        -- For use in cool and warm options.
        local hYel <const> = defaults.hYel
        local hVio <const> = defaults.hVio
        local hZero <const> = defaults.hZero

        -- Scale adjustments appropriately.
        local hScl <const> = hAdj / 360.0
        local sScl <const> = sAdj / 255.0
        local lScl <const> = lAdj / 255.0
        local vScl <const> = vAdj / 255.0

        -- Prevent uncommitted selection transformation (drop pixels) from
        -- raising an error. Also prevent slice tool context bar in the UI.
        local appTool <const> = app.tool
        if appTool then
            local toolName <const> = appTool.id
            if toolName == "slice" then
                app.tool = "hand"
            end
        end

        local specSprite <const> = activeSprite.spec
        local colorMode <const> = specSprite.colorMode
        if colorMode == ColorMode.INDEXED then
            -- Prevent background images from containing transparency.
            local aAdjCurr <const> = activeSprite.backgroundLayer
                and 0 or aAdj

            local alphaIdx <const> = specSprite.transparentColor

            local spritePalettes <const> = activeSprite.palettes
            local chosenPalettes = spritePalettes
            if target == "ACTIVE" then
                local frIdx <const> = activeFrame.frameNumber
                local lenSpritePalettes <const> = #spritePalettes
                local palIdx <const> = frIdx <= lenSpritePalettes and frIdx or 1
                local palette <const> = activeSprite.palettes[palIdx]
                chosenPalettes = { palette }
            end

            app.transaction("OKHSL Adjust Palette", function()
                local lenChosenPalettes <const> = #chosenPalettes
                local h = 0
                while h < lenChosenPalettes do
                    h = h + 1
                    local palette <const> = chosenPalettes[h]
                    local lenPalette <const> = #palette

                    local i = 0
                    while i < lenPalette do
                        if i ~= alphaIdx then
                            local aseColor <const> = palette:getColor(i)
                            local r8 <const> = aseColor.red
                            local g8 <const> = aseColor.green
                            local b8 <const> = aseColor.blue
                            local a8 <const> = aseColor.alpha

                            local r8n <const>,
                            g8n <const>,
                            b8n <const>,
                            a8n <const> = adjustColor(
                                r8, g8, b8, a8,
                                hScl, sScl, lScl, vScl, aAdjCurr,
                                useHsv,
                                useCool, useOmit, useZero, useWarm,
                                hVio, hYel, hZero)

                            palette:setColor(i, Color {
                                red = r8n,
                                green = g8n,
                                blue = b8n,
                                alpha = a8n })
                        end
                        i = i + 1
                    end
                end
            end)

            app.refresh()
            return
        end

        -- Tile sets need to have a unique identifier so that they can be
        -- adjusted only once in case they are used by multiple layers.
        local tilesets <const> = activeSprite.tilesets
        local lenTilesets <const> = tilesets and #tilesets or 0
        if lenTilesets > 0 then
            app.transaction("Set Tileset IDs", function()
                math.randomseed(os.time())
                local minint64 <const> = 0x1000000000000000
                local maxint64 <const> = 0x7fffffffffffffff

                local rng <const> = math.random
                local i = 0
                while i < lenTilesets do
                    i = i + 1
                    local tileset <const> = tilesets[i]
                    tileset.properties["id"] = rng(minint64, maxint64)
                end
            end)
        end

        ---@type Cel[]
        local chosenCels = {}
        if target == "ALL" then
            local spriteCels <const> = activeSprite.cels
            local lenSpriteCels <const> = #spriteCels
            ---@type table<integer, Cel>
            local uniqueCelsDict <const> = {}
            local i = 0
            while i < lenSpriteCels do
                i = i + 1
                local spriteCel <const> = spriteCels[i]
                local layer <const> = spriteCel.layer

                if (not layer.isReference)
                    and layer.isEditable
                    and layer.isVisible then
                    -- Warning: Images will not have an id attribute in older
                    -- versions of Aseprite.
                    uniqueCelsDict[spriteCel.image.id] = spriteCel
                end
            end

            for _, cel in pairs(uniqueCelsDict) do
                chosenCels[#chosenCels + 1] = cel
            end
        else
            local activeLayer <const> = app.layer
                or activeSprite.layers[1]

            if (not activeLayer.isReference)
                and activeLayer.isEditable
                and activeLayer.isVisible then
                local activeCel <const> = activeLayer:cel(activeFrame)
                if activeCel then
                    chosenCels = { activeCel }
                end
            end
        end

        local lenChosenCels <const> = #chosenCels
        if lenChosenCels <= 0 then
            app.alert {
                title = "Error",
                text = "No visible, editable cels were selected."
            }
        end

        ---@type table<integer, Tileset>
        local usedTilesets <const> = {}
        local lenTsUsed = 0

        local mask = activeSprite.selection
        if mask == nil or mask.isEmpty then
            mask = Selection(activeSprite.bounds)
        end

        app.transaction("OKHSL Adjust Cels", function()
            local h = 0
            while h < lenChosenCels do
                h = h + 1
                local srcCel <const> = chosenCels[h]
                local srcLayer <const> = srcCel.layer

                if srcLayer.isTilemap then
                    local tileset <const> = srcLayer.tileset --[[@as Tileset]]
                    local tsid <const> = tileset.properties["id"]
                    if not usedTilesets[tsid] then
                        lenTsUsed = lenTsUsed + 1
                        usedTilesets[tsid] = tileset
                    end
                else
                    -- Prevent background images from containing transparency.
                    local aAdjCurr <const> = srcLayer.isBackground
                        and 0 or aAdj
                    local srcPos <const> = srcCel.position
                    local xtlSrc <const> = srcPos.x
                    local ytlSrc <const> = srcPos.y
                    srcCel.image = adjustImage(
                        srcCel.image, xtlSrc, ytlSrc, mask, hScl, sScl, lScl,
                        vScl, aAdjCurr, useHsv, useCool, useOmit, useZero,
                        useWarm, hVio, hYel, hZero)
                end
            end
        end)

        if lenTsUsed > 0 then
            app.transaction("OKHSL Adjust Tilesets", function()
                for _, tileset in pairs(usedTilesets) do
                    local tileSize <const> = tileset.grid.tileSize
                    local wTile <const> = tileSize.width
                    local hTile <const> = tileSize.height
                    local tileMask <const> = Selection(Rectangle(
                        0, 0, wTile, hTile))

                    local lenTileset <const> = #tileset
                    local i = 0
                    while i < lenTileset do
                        local tile <const> = tileset:tile(i)
                        if tile then
                            tile.image = adjustImage(
                                tile.image, 0, 0, tileMask, hScl, sScl, lScl,
                                vScl, aAdj, useHsv, useCool, useOmit, useZero,
                                useWarm, hVio, hYel, hZero)
                        end
                        i = i + 1
                    end
                end
            end)
        end

        app.refresh()
    end
}

dlg:button {
    id = "cancel",
    text = "&X",
    focus = true,
    onclick = function()
        dlg:close()
    end
}

dlg:show {
    autoscrollbars = false,
    wait = false
}