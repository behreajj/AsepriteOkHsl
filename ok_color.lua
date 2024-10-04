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

ok_color = {}
ok_color.__index = ok_color

function ok_color.new()
    return setmetatable({}, ok_color)
end

-- Finds the maximum saturation possible for a given hue that fits in sRGB
-- Saturation here is defined as S = C/L
-- a and b must be normalized so a^2 + b^2 == 1
---@param a number
---@param b number
---@return number
---@nodiscard
function ok_color.compute_max_saturation(a, b)
    if a ~= 0.0 or b ~= 0.0 then
        -- Max saturation will be when one of r, g or b goes below zero.
        -- Select different coefficients depending on which component
        -- goes below zero first

        -- Blue component (default)
        local k0 = 1.35733652
        local k1 = -0.00915799
        local k2 = -1.1513021
        local k3 = -0.50559606
        local k4 = 0.00692167
        local wl = -0.0041960863
        local wm = -0.7034186147
        local ws = 1.707614701

        if -1.88170328 * a - 0.80936493 * b > 1 then
            -- Red component
            k0 = 1.19086277
            k1 = 1.76576728
            k2 = 0.59662641
            k3 = 0.75515197
            k4 = 0.56771245
            wl = 4.0767416621
            wm = -3.3077115913
            ws = 0.2309699292
        elseif 1.81444104 * a - 1.19445276 * b > 1 then
            -- Green component
            k0 = 0.73956515
            k1 = -0.45954404
            k2 = 0.08285427
            k3 = 0.1254107
            k4 = 0.14503204
            wl = -1.2684380046
            wm = 2.6097574011
            ws = -0.3413193965
        end

        -- Approximate max saturation using a polynomial:
        local S = k0 + k1 * a + k2 * b + k3 * a * a + k4 * a * b

        -- Do one step Halley's method to get closer
        -- This gives an error less than 10e6, except for
        -- some blue hues where the dS / dh is close to infinite.
        -- this should be sufficient for most applications,
        -- otherwise do two to three steps.

        local k_l <const> = 0.3963377774 * a + 0.2158037573 * b
        local k_m <const> = -0.1055613458 * a - 0.0638541728 * b
        local k_s <const> = -0.0894841775 * a - 1.291485548 * b

        do
            local l_ <const> = 1.0 + S * k_l
            local m_ <const> = 1.0 + S * k_m
            local s_ <const> = 1.0 + S * k_s

            local l_sq <const> = l_ * l_
            local m_sq <const> = m_ * m_
            local s_sq <const> = s_ * s_

            local l <const> = l_sq * l_
            local m <const> = m_sq * m_
            local s <const> = s_sq * s_

            local l_dS <const> = 3.0 * k_l * l_sq
            local m_dS <const> = 3.0 * k_m * m_sq
            local s_dS <const> = 3.0 * k_s * s_sq

            local l_dS2 <const> = 6.0 * k_l * k_l * l_
            local m_dS2 <const> = 6.0 * k_m * k_m * m_
            local s_dS2 <const> = 6.0 * k_s * k_s * s_

            local f <const> = wl * l + wm * m + ws * s
            local f1 <const> = wl * l_dS + wm * m_dS + ws * s_dS
            local f2 <const> = wl * l_dS2 + wm * m_dS2 + ws * s_dS2

            local s_denom <const> = f1 * f1 - 0.5 * f * f2
            if s_denom ~= 0.0 then S = S - f * f1 / s_denom end
        end

        return S
    else
        return 0.0
    end
end

-- finds L_cusp and C_cusp for a given hue
-- a and b must be normalized so a^2 + b^2 == 1
---@param a number
---@param b number
---@return number L
---@return number C
---@nodiscard
function ok_color.find_cusp(a, b)
    -- First, find the maximum saturation (saturation S = C/L)
    local S_cusp <const> = ok_color.compute_max_saturation(a, b)

    -- Convert to linear sRGB to find the first point
    -- where at least one of r,g or b >= 1:
    local r_at_max <const>,
    g_at_max <const>,
    b_at_max <const> = ok_color.oklab_to_linear_srgb(
        1.0, S_cusp * a, S_cusp * b)
    local max_comp <const> = math.max(r_at_max, g_at_max, b_at_max)
    if max_comp ~= 0.0 then
        local L_cusp <const> = (1.0 / max_comp) ^ 0.3333333333333333
        return L_cusp, L_cusp * S_cusp
    else
        return 0.0, 0.0
    end
end

-- Finds intersection of the line defined by
-- L = L0 * (1 - t) + t * L1
-- C = t * C1
-- a and b must be normalized so a^2 + b^2 == 1
---@param a number
---@param b number
---@param L1 number
---@param C1 number
---@param L0 number
---@param xL number?
---@param xC number?
---@return number
---@nodiscard
function ok_color.find_gamut_intersection(a, b, L1, C1, L0, xL, xC)
    -- Find the cusp of the gamut triangle
    local cuspL, cuspC = xL, xC
    if (not cuspL) or (not cuspC) then
        cuspL, cuspC = ok_color.find_cusp(a, b)
    end

    -- Find the intersection for upper and lower half separately
    local t = 0.0
    if ((L1 - L0) * cuspC - (cuspL - L0) * C1) <= 0.0 then
        -- Lower half
        local t_denom <const> = C1 * cuspL + cuspC * (L0 - L1)
        if t_denom ~= 0.0 then t = cuspC * L0 / t_denom end
    else
        -- Upper half
        -- First intersect with triangle
        local t_denom <const> = C1 * (cuspL - 1.0) + cuspC * (L0 - L1)
        if t_denom ~= 0.0 then t = cuspC * (L0 - 1.0) / t_denom end

        -- Then one step Halley's method
        do
            local dL <const> = L1 - L0
            local dC <const> = C1

            local k_l <const> = 0.3963377774 * a + 0.2158037573 * b
            local k_m <const> = -0.1055613458 * a - 0.0638541728 * b
            local k_s <const> = -0.0894841775 * a - 1.291485548 * b

            local l_dt <const> = dL + dC * k_l
            local m_dt <const> = dL + dC * k_m
            local s_dt <const> = dL + dC * k_s

            -- If higher accuracy is required, 2 or 3 iterations
            -- of the following block can be used:
            do
                local L <const> = (1.0 - t) * L0 + t * L1
                local C <const> = t * C1

                local l_ <const> = L + C * k_l
                local m_ <const> = L + C * k_m
                local s_ <const> = L + C * k_s

                local l_sq <const> = l_ * l_
                local m_sq <const> = m_ * m_
                local s_sq <const> = s_ * s_

                local l <const> = l_sq * l_
                local m <const> = m_sq * m_
                local s <const> = s_sq * s_

                local ldt <const> = 3.0 * l_dt * l_sq
                local mdt <const> = 3.0 * m_dt * m_sq
                local sdt <const> = 3.0 * s_dt * s_sq

                local ldt2 <const> = 6.0 * (l_dt * l_dt) * l_
                local mdt2 <const> = 6.0 * (m_dt * m_dt) * m_
                local sdt2 <const> = 6.0 * (s_dt * s_dt) * s_

                local r0 <const> = 4.076741661347994 * l - 3.3077115904081933 * m + 0.23096992872942793 * s - 1.0
                local r1 <const> = 4.076741661347994 * ldt - 3.3077115904081933 * mdt + 0.23096992872942793 * sdt
                local r2 <const> = 4.076741661347994 * ldt2 - 3.3077115904081933 * mdt2 + 0.23096992872942793 * sdt2

                local r_denom <const> = r1 * r1 - 0.5 * r0 * r2
                local u_r <const> = r_denom ~= 0.0 and r1 / r_denom or 0.0
                local t_r = -r0 * u_r

                local g0 <const> = -1.2684380040921763 * l + 2.6097574006633715 * m - 0.3413193963102196 * s - 1.0
                local g1 <const> = -1.2684380040921763 * ldt + 2.6097574006633715 * mdt - 0.3413193963102196 * sdt
                local g2 <const> = -1.2684380040921763 * ldt2 + 2.6097574006633715 * mdt2 - 0.3413193963102196 * sdt2

                local g_denom <const> = g1 * g1 - 0.5 * g0 * g2
                local u_g <const> = g_denom ~= 0.0 and g1 / g_denom or 0.0
                local t_g = -g0 * u_g

                local b0 <const> = -0.004196086541837079 * l - 0.7034186144594495 * m + 1.7076147009309446 * s - 1.0
                local b1 <const> = -0.004196086541837079 * ldt - 0.7034186144594495 * mdt + 1.7076147009309446 * sdt
                local b2 <const> = -0.004196086541837079 * ldt2 - 0.7034186144594495 * mdt2 + 1.7076147009309446 * sdt2

                local b_denom <const> = b1 * b1 - 0.5 * b0 * b2
                local u_b <const> = b_denom ~= 0.0 and b1 / b_denom or 0.0
                local t_b = -b0 * u_b

                if u_r < 0.0 then t_r = 3.40282347e+38 end
                if u_g < 0.0 then t_g = 3.40282347e+38 end
                if u_b < 0.0 then t_b = 3.40282347e+38 end

                t = t + math.min(t_r, t_g, t_b)
            end
        end
    end

    return t
end

---@param L number
---@param a_ number
---@param b_ number
---@return number C_0
---@return number C_mid
---@return number C_max
---@nodiscard
function ok_color.get_Cs(L, a_, b_)
    local cuspL, cuspC <const> = ok_color.find_cusp(a_, b_)
    local C_max <const> = ok_color.find_gamut_intersection(
        a_, b_, L, 1.0, L, cuspL, cuspC)
    local S_max <const>, T_max <const> = ok_color.to_ST(cuspL, cuspC)

    -- Scale factor to compensate for the curved part of gamut shape:
    local k = 0.0
    local k_denom <const> = math.min(L * S_max, (1.0 - L) * T_max)
    if k_denom ~= 0.0 then k = C_max / k_denom end

    local C_mid = 0.0
    do
        local S_mid <const>, T_mid <const> = ok_color.get_ST_mid(a_, b_)

        -- Use a soft minimum function, instead of a sharp triangle
        -- shape to get a smooth value for chroma.
        local C_a <const> = L * S_mid
        local C_b <const> = (1.0 - L) * T_mid

        local cae4 <const> = (C_a * C_a) * (C_a * C_a)
        local cbe4 <const> = (C_b * C_b) * (C_b * C_b)
        C_mid = 0.9 * k * ((1.0 / (1.0 / cae4 + 1.0 / cbe4)) ^ 0.25)
    end

    local C_0 = 0.0
    do
        -- for C_0, the shape is independent of hue, so ST are constant.
        -- Values picked to roughly be the average values of ST.
        local C_a <const> = L * 0.4
        local C_b <const> = (1.0 - L) * 0.8

        -- Use a soft minimum function, instead of a sharp triangle
        -- shape to get a smooth value for chroma.
        local cae2 <const> = C_a * C_a
        local cbe2 <const> = C_b * C_b
        C_0 = math.sqrt(1.0 / (1.0 / cae2 + 1.0 / cbe2))
    end

    return C_0, C_mid, C_max
end

-- Returns a smooth approximation of the location of the cusp
-- This polynomial was created by an optimization process
-- It has been designed so that S_mid < S_max and T_mid < T_max
---@param a_ number
---@param b_ number
---@return number S
---@return number T
---@nodiscard
function ok_color.get_ST_mid(a_, b_)
    local S = 0.11516993
    local s_denom <const> = 7.4477897 + 4.1590124 * b_
        + a_ * (-2.19557347 + 1.75198401 * b_
            + a_ * (-2.13704948 - 10.02301043 * b_
                + a_ * (-4.24894561 + 5.38770819 * b_
                    + a_ * 4.69891013)))
    if s_denom ~= 0.0 then
        S = 0.11516993 + 1.0 / s_denom
    end

    local T = 0.11239642
    local t_denom <const> = 1.6132032 - 0.68124379 * b_
        + a_ * (0.40370612 + 0.90148123 * b_
            + a_ * (-0.27087943 + 0.6122399 * b_
                + a_ * (0.00299215 - 0.45399568 * b_
                    - a_ * 0.14661872)))
    if t_denom ~= 0.0 then
        T = 0.11239642 + 1.0 / t_denom
    end

    return S, T
end

---@param cr number
---@param cg number
---@param cb number
---@return number L
---@return number a
---@return number b
---@nodiscard
function ok_color.linear_srgb_to_oklab(cr, cg, cb)
    -- See https://github.com/svgeesus/svgeesus.github.io/blob/master/
    -- Color/OKLab-notes.md#comparing-standard-code-to-published-matrices
    -- https://github.com/w3c/csswg-drafts/issues/6642#issuecomment-943521484
    -- for discussions about precision.
    local l <const> = (0.4121764591770371 * cr
        + 0.5362739742695891 * cg
        + 0.05144037229550143 * cb) ^ 0.3333333333333333
    local m <const> = (0.21190919958804857 * cr
        + 0.6807178709823131 * cg
        + 0.10739984387775398 * cb) ^ 0.3333333333333333
    local s <const> = (0.08834481407213204 * cr
        + 0.28185396309857735 * cg
        + 0.6302808688015096 * cb) ^ 0.3333333333333333

    return 0.2104542553 * l
        + 0.793617785 * m
        - 0.0040720468 * s,
        1.9779984951 * l
        - 2.428592205 * m
        + 0.4505937099 * s,
        0.0259040371 * l
        + 0.7827717662 * m
        - 0.808675766 * s
end

---@param h number
---@param s number
---@param l number
---@return number L
---@return number a
---@return number b
---@nodiscard
function ok_color.okhsl_to_oklab(h, s, l)
    if l >= 1.0 then return 1.0, 0.0, 0.0 end
    if l <= 0.0 then return 0.0, 0.0, 0.0 end

    local sCl <const> = math.min(math.max(s, 0.0), 1.0)

    local h_rad <const> = h * 6.283185307179586
    local a_ <const> = math.cos(h_rad)
    local b_ <const> = math.sin(h_rad)
    local L <const> = ok_color.toe_inv(l)

    local C_0 <const>,
    C_mid <const>,
    C_max <const> = ok_color.get_Cs(L, a_, b_)

    local mid <const> = 0.8
    local mid_inv <const> = 1.25

    local C = 0.0
    local t = 0.0
    local k_0 = 0.0
    local k_1 = 0.0
    local k_2 = 0.0
    if sCl < mid then
        t = mid_inv * sCl

        k_1 = mid * C_0
        if C_mid ~= 0.0 then
            k_2 = 1.0 - k_1 / C_mid
        end

        local k_denom <const> = 1.0 - k_2 * t
        if k_denom ~= 0.0 then
            C = t * k_1 / k_denom
        end
    else
        local t_denom <const> = 1.0 - mid
        if t_denom ~= 0.0 then
            t = (sCl - mid) / t_denom
        end

        k_0 = C_mid
        if C_0 ~= 0.0 then
            k_1 = (1.0 - mid) * C_mid * C_mid * mid_inv * mid_inv / C_0
        end

        local C_denom <const> = C_max - C_mid
        k_2 = 1.0
        if C_denom ~= 0.0 then
            k_2 = 1.0 - k_1 / C_denom
        end

        local k_denom <const> = 1.0 - k_2 * t
        if k_denom ~= 0.0 then
            C = k_0 + t * k_1 / k_denom
        end
    end

    return L,
        C * a_,
        C * b_
end

---@param h number
---@param s number
---@param l number
---@return number r
---@return number g
---@return number b
---@nodiscard
function ok_color.okhsl_to_srgb(h, s, l)
    local L <const>, a <const>, b <const> = ok_color.okhsl_to_oklab(h, s, l)
    return ok_color.oklab_to_srgb(L, a, b)
end

---@param h number
---@param s number
---@param v number
---@return number L
---@return number a
---@return number b
---@nodiscard
function ok_color.okhsv_to_oklab(h, s, v)
    if v <= 0.0 then return 0.0, 0.0, 0.0 end
    if v > 1.0 then v = 1.0 end

    local sCl <const> = math.min(math.max(s, 0.0), 1.0)

    local h_rad <const> = h * 6.283185307179586
    local a_ <const> = math.cos(h_rad)
    local b_ <const> = math.sin(h_rad)

    local cuspL <const>, cuspC <const> = ok_color.find_cusp(a_, b_)
    local S_max <const>, T_max <const> = ok_color.to_ST(cuspL, cuspC)
    local S_0 <const> = 0.5
    local k <const> = S_max ~= 0.0 and 1.0 - S_0 / S_max or 1.0

    -- First, we compute L and V as if the gamut is a perfect triangle:

    -- L, C when v==1:
    local v_denom <const> = S_0 + T_max - T_max * k * sCl
    local L_v = 1.0
    local C_v = 0.0
    if v_denom ~= 0.0 then
        L_v = 1.0 - sCl * S_0 / v_denom
        C_v = sCl * T_max * S_0 / v_denom
    end

    local L = v * L_v
    local C = v * C_v

    -- Then we compensate for both toe and the curved top part of the triangle:
    local L_vt <const> = ok_color.toe_inv(L_v)
    local C_vt <const> = L_v ~= 0.0 and C_v * L_vt / L_v or 0.0

    local L_new <const> = ok_color.toe_inv(L)
    if L ~= 0.0 then
        C = C * L_new / L
    else
        C = 0.0
    end
    L = L_new

    local r_scale <const>,
    g_scale <const>,
    b_scale <const> = ok_color.oklab_to_linear_srgb(L_vt, a_ * C_vt, b_ * C_vt)
    local max_comp <const> = math.max(
        r_scale,
        g_scale,
        b_scale, 0.0)
    local scale_L <const> = max_comp ~= 0.0
        and (1.0 / max_comp) ^ 0.3333333333333333
        or 0.0

    C = C * scale_L
    return L * scale_L,
        C * a_,
        C * b_
end

---@param h number
---@param s number
---@param v number
---@return number r
---@return number g
---@return number b
---@nodiscard
function ok_color.okhsv_to_srgb(h, s, v)
    local L <const>, a <const>, b <const> = ok_color.okhsv_to_oklab(h, s, v)
    return ok_color.oklab_to_srgb(L, a, b)
end

---@param lgt number
---@param a number
---@param b number
---@return number red
---@return number green
---@return number blue
---@nodiscard
function ok_color.oklab_to_linear_srgb(lgt, a, b)
    local l_cbrt <const> = 0.9999999984505196 * lgt
        + 0.39633779217376774 * a
        + 0.2158037580607588 * b
    local m_cbrt <const> = 1.0000000088817607 * lgt
        - 0.10556134232365633 * a
        - 0.0638541747717059 * b
    local s_cbrt <const> = 1.0000000546724108 * lgt
        - 0.08948418209496574 * a
        - 1.2914855378640917 * b

    local l <const> = (l_cbrt * l_cbrt) * l_cbrt
    local m <const> = (m_cbrt * m_cbrt) * m_cbrt
    local s <const> = (s_cbrt * s_cbrt) * s_cbrt

    return 4.076741661347994 * l
        - 3.3077115904081933 * m
        + 0.23096992872942793 * s,
        -1.2684380040921763 * l
        + 2.6097574006633715 * m
        - 0.3413193963102196 * s,
        -0.004196086541837079 * l
        - 0.7034186144594495 * m
        + 1.7076147009309446 * s
end

---@param L number
---@param a number
---@param b number
---@return number h
---@return number s
---@return number l
---@nodiscard
function ok_color.oklab_to_okhsl(L, a, b)
    if L >= 1.0 then return 0.0, 0.0, 1.0 end
    if L <= 0.0 then return 0.0, 0.0, 0.0 end

    local a_ = a
    local b_ = b
    local Csq = a_ * a_ + b_ * b_
    if Csq > 0.0 then
        local C <const> = math.sqrt(Csq)
        a_ = a_ / C
        b_ = b_ / C

        -- 1.0 / tau = 0.1591549430919
        local h <const> = math.atan(-b_, -a_) * 0.1591549430919 + 0.5

        local C_0 <const>,
        C_mid <const>,
        C_max <const> = ok_color.get_Cs(L, a_, b_)

        -- Inverse of the interpolation in okhsl_to_srgb:
        local mid <const> = 0.8
        local mid_inv <const> = 1.25

        local s = 0.0
        if C < C_mid then
            local k_1 <const> = mid * C_0
            local k_2 = 1.0
            if C_mid ~= 0.0 then
                k_2 = (1.0 - k_1 / C_mid)
            end

            local t_denom <const> = k_1 + k_2 * C
            local t = 0.0
            if t_denom ~= 0.0 then
                t = C / t_denom
            end

            s = t * mid
        else
            local k_0 <const> = C_mid
            local k_1 = 0.0
            if C_0 ~= 0.0 then
                k_1 = (1.0 - mid) * C_mid * C_mid * mid_inv * mid_inv / C_0
            end

            local C_denom <const> = C_max - C_mid
            local k_2 = 1.0
            if C_denom ~= 0.0 then
                k_2 = 1.0 - k_1 / C_denom
            end

            local t_denom <const> = k_1 + k_2 * (C - k_0)
            local t = 0.0
            if t_denom ~= 0.0 then
                t = (C - k_0) / t_denom
            end

            s = mid + (1.0 - mid) * t
        end

        return h, s, ok_color.toe(L)
    else
        return 0.0, 0.0, L
    end
end

---@param L number
---@param a number
---@param b number
---@return number h
---@return number s
---@return number v
---@nodiscard
function ok_color.oklab_to_okhsv(L, a, b)
    if L >= 1.0 then return 0.0, 0.0, 1.0 end
    if L <= 0.0 then return 0.0, 0.0, 0.0 end

    local a_ = a
    local b_ = b
    local Csq <const> = a_ * a_ + b_ * b_
    if Csq > 0.0 then
        local C = math.sqrt(Csq)
        a_ = a_ / C
        b_ = b_ / C

        -- 1.0 / tau = 0.1591549430919
        local h <const> = math.atan(-b_, -a_) * 0.1591549430919 + 0.5

        local cuspL <const>, cuspC <const> = ok_color.find_cusp(a_, b_)
        local S_max <const>, T_max <const> = ok_color.to_ST(cuspL, cuspC)
        local S_0 <const> = 0.5
        local k <const> = S_max ~= 0.0 and 1.0 - S_0 / S_max or 1.0

        -- first we find L_v, C_v, L_vt and C_vt
        local t_denom <const> = C + L * T_max
        local t <const> = t_denom ~= 0.0 and T_max / t_denom or 0.0
        local L_v <const> = t * L
        local C_v <const> = t * C

        local L_vt <const> = ok_color.toe_inv(L_v)
        local C_vt <const> = L_v ~= 0.0 and C_v * L_vt / L_v or 0.0

        -- we can then use these to invert the step that compensates
        -- for the toe and the curved top part of the triangle:
        local r_scale <const>, g_scale <const>, b_scale <const> = ok_color.oklab_to_linear_srgb(
            L_vt, a_ * C_vt, b_ * C_vt)
        local scale_denom <const> = math.max(
            r_scale,
            g_scale,
            b_scale, 0.0)
        local scale_L = 0.0
        if scale_denom ~= 0.0 then
            scale_L = (1.0 / scale_denom) ^ 0.3333333333333333
            L = L / scale_L
            C = C / scale_L
        end

        local toel <const> = ok_color.toe(L)
        C = C * toel / L
        L = toel

        -- we can now compute v and s:
        local v = 0.0
        if L_v ~= 0.0 then v = L / L_v end

        local s = 0.0
        local s_denom <const> = ((T_max * S_0) + T_max * k * C_v)
        if s_denom ~= 0.0 then
            s = (S_0 + T_max) * C_v / s_denom
        end

        return h, s, v
    else
        return 0.0, 0.0, L
    end
end

---@param L number
---@param a number
---@param b number
---@return number r
---@return number g
---@return number b
---@nodiscard
function ok_color.oklab_to_srgb(L, a, b)
    local lr <const>, lg <const>, lb <const> = ok_color.oklab_to_linear_srgb(
        L, a, b)
    return ok_color.srgb_transfer_function(lr),
        ok_color.srgb_transfer_function(lg),
        ok_color.srgb_transfer_function(lb)
end

---@param red number
---@param green number
---@param blue number
---@return number h
---@return number s
---@return number l
---@nodiscard
function ok_color.srgb_to_okhsl(red, green, blue)
    local L <const>, a <const>, b <const> = ok_color.srgb_to_oklab(
        red, green, blue)
    return ok_color.oklab_to_okhsl(L, a, b)
end

---@param red number
---@param green number
---@param blue number
---@return number h
---@return number s
---@return number v
---@nodiscard
function ok_color.srgb_to_okhsv(red, green, blue)
    local L <const>, a <const>, b <const> = ok_color.srgb_to_oklab(
        red, green, blue)
    return ok_color.oklab_to_okhsv(L, a, b)
end

---@param red number
---@param green number
---@param blue number
---@return number L
---@return number a
---@return number b
---@nodiscard
function ok_color.srgb_to_oklab(red, green, blue)
    return ok_color.linear_srgb_to_oklab(
        ok_color.srgb_transfer_function_inv(red),
        ok_color.srgb_transfer_function_inv(green),
        ok_color.srgb_transfer_function_inv(blue))
end

---@param a number
---@return number
---@nodiscard
function ok_color.srgb_transfer_function(a)
    if 0.0031308 >= a then
        return 12.92 * a
    else
        return 1.055 * (a ^ 0.4166666666666667) - 0.055
    end
end

---@param a number
---@return number
---@nodiscard
function ok_color.srgb_transfer_function_inv(a)
    if 0.04045 < a then
        return ((a + 0.055) * 0.9478672985781991) ^ 2.4
    else
        return a * 0.07739938080495357
    end
end

---@param L number
---@param C number
---@return number S
---@return number T
---@nodiscard
function ok_color.to_ST(L, C)
    if L ~= 0.0 and L ~= 1.0 then
        return C / L, C / (1.0 - L)
    elseif L ~= 0.0 then
        return C / L, 0.0
    elseif L ~= 1.0 then
        return 0.0, C / (1.0 - L)
    else
        return 0.0, 0.0
    end
end

---@param x number
---@return number
---@nodiscard
function ok_color.toe(x)
    local y <const> = 1.170873786407767 * x - 0.206
    return 0.5 * (y + math.sqrt(y * y + 0.14050485436893204 * x))
end

---@param x number
---@return number
---@nodiscard
function ok_color.toe_inv(x)
    local denom <const> = 1.170873786407767 * (x + 0.03)
    if denom ~= 0.0 then
        return (x * x + 0.206 * x) / denom
    else
        return 0.0
    end
end

return ok_color