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

ok_color = {}
ok_color.__index = ok_color

function ok_color.new()
    local inst = setmetatable({}, ok_color)
    return inst
end

function ok_color.clamp(x, min, max)
    if x < min then return min end
    if x > max then return max end
    return x
end

function ok_color.sgn(x)
    if x < -0.0 then return -1.0 end
    if x > 0.0 then return 1.0 end
    return 0.0
end

function ok_color.srgb_transfer_function(a)
    if 0.0031308 >= a then
        return 12.92 * a
    else
        return 1.055 * (a ^ 0.4166666666666667) - 0.055
    end
end

function ok_color.srgb_transfer_function_inv(a)
    if 0.04045 < a then
        return ((a + 0.055) * 0.9478672985781991) ^ 2.4
    else
        return a * 0.07739938080495357
    end
end

function ok_color.srgb_to_oklab(srgb)
    return ok_color.linear_srgb_to_oklab({
		r = ok_color.srgb_transfer_function_inv(srgb.r),
		g = ok_color.srgb_transfer_function_inv(srgb.g),
		b = ok_color.srgb_transfer_function_inv(srgb.b) })
end

function ok_color.linear_srgb_to_oklab(c)
    local l = 0.4122214708 * c.r
            + 0.5363325363 * c.g
            + 0.0514459929 * c.b
	local m = 0.2119034982 * c.r
            + 0.6806995451 * c.g
            + 0.1073969566 * c.b
	local s = 0.0883024619 * c.r
            + 0.2817188376 * c.g
            + 0.6299787005 * c.b

    local l_ = l ^ 0.3333333333333333
    local m_ = m ^ 0.3333333333333333
    local s_ = s ^ 0.3333333333333333

    return {
        L = 0.2104542553 * l_
          + 0.7936177850 * m_
          - 0.0040720468 * s_,
        a = 1.9779984951 * l_
          - 2.4285922050 * m_
          + 0.4505937099 * s_,
        b = 0.0259040371 * l_
          + 0.7827717662 * m_
          - 0.8086757660 * s_ }
end

function ok_color.oklab_to_srgb(lab)
    local lrgb = ok_color.oklab_to_linear_srgb(lab)
	return {
		r = ok_color.srgb_transfer_function(lrgb.r),
		g = ok_color.srgb_transfer_function(lrgb.g),
		b = ok_color.srgb_transfer_function(lrgb.b) }
end

function ok_color.oklab_to_linear_srgb(lab)
    local l_ = lab.L
        + 0.3963377774 * lab.a
        + 0.2158037573 * lab.b
	local m_ = lab.L
        - 0.1055613458 * lab.a
        - 0.0638541728 * lab.b
	local s_ = lab.L
        - 0.0894841775 * lab.a
        - 1.2914855480 * lab.b

    local l = l_ * l_ * l_
    local m = m_ * m_ * m_
    local s = s_ * s_ * s_

    return {
        r = 4.0767416621 * l
          - 3.3077115913 * m
          + 0.2309699292 * s,
        g = -1.2684380046 * l
           + 2.6097574011 * m
           - 0.3413193965 * s,
        b = -0.0041960863 * l
           - 0.7034186147 * m
           + 1.7076147010 * s }
end

-- Finds the maximum saturation possible for a given hue that fits in sRGB
-- Saturation here is defined as S = C/L
-- a and b must be normalized so a^2 + b^2 == 1
function ok_color.compute_max_saturation(a, b)
    if a ~= 0.0 or b ~= 0.0 then
    	-- Max saturation will be when one of r, g or b goes below zero.
        -- Select different coefficients depending on which component goes below zero first

        -- Blue component (default)
        local k0 = 1.35733652
        local k1 = -0.00915799
        local k2 = -1.15130210
        local k3 = -0.50559606
        local k4 = 0.00692167
        local wl = -0.0041960863
        local wm = -0.7034186147
        local ws = 1.7076147010

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
            k3 = 0.12541070
            k4 = 0.14503204
            wl = -1.2684380046
            wm = 2.6097574011
            ws = -0.3413193965
        end

        -- Approximate max saturation using a polynomial:
        local S = k0 + k1 * a + k2 * b + k3 * a * a + k4 * a * b

        -- Do one step Halley's method to get closer
        -- this gives an error less than 10e6, except for some blue hues where the dS/dh is close to infinite
        -- this should be sufficient for most applications, otherwise do two/three steps

        local k_l = 0.3963377774 * a + 0.2158037573 * b
        local k_m = -0.1055613458 * a - 0.0638541728 * b
        local k_s = -0.0894841775 * a - 1.2914855480 * b

        do
            local l_ = 1.0 + S * k_l
            local m_ = 1.0 + S * k_m
            local s_ = 1.0 + S * k_s

            local l = l_ * l_ * l_
            local m = m_ * m_ * m_
            local s = s_ * s_ * s_

            local l_dS = 3.0 * k_l * l_ * l_
            local m_dS = 3.0 * k_m * m_ * m_
            local s_dS = 3.0 * k_s * s_ * s_

            local l_dS2 = 6.0 * k_l * k_l * l_
            local m_dS2 = 6.0 * k_m * k_m * m_
            local s_dS2 = 6.0 * k_s * k_s * s_

            local f = wl * l + wm * m + ws * s
            local f1 = wl * l_dS + wm * m_dS + ws * s_dS
            local f2 = wl * l_dS2 + wm * m_dS2 + ws * s_dS2

            S = S - f * f1 / (f1 * f1 - 0.5 * f * f2)
        end

        return S
    else
        return 0.0
    end
end

-- finds L_cusp and C_cusp for a given hue
-- a and b must be normalized so a^2 + b^2 == 1
function ok_color.find_cusp(a, b)
	-- First, find the maximum saturation (saturation S = C/L)
    local S_cusp = ok_color.compute_max_saturation(a, b)

    -- Convert to linear sRGB to find the first point where at least one of r,g or b >= 1:
    local rgb_at_max = ok_color.oklab_to_linear_srgb({L = 1, a = S_cusp * a, b = S_cusp * b })
    local L_cusp = (1.0 / math.max(rgb_at_max.r, rgb_at_max.g, rgb_at_max.b)) ^ 0.3333333333333333
    local C_cusp = L_cusp * S_cusp

    return { L = L_cusp, C = C_cusp }
end

-- Finds intersection of the line defined by
-- L = L0 * (1 - t) + t * L1
-- C = t * C1
-- a and b must be normalized so a^2 + b^2 == 1
function ok_color.find_gamut_intersection(a, b, L1, C1, L0, x)
    -- Find the cusp of the gamut triangle
    local cusp = x or ok_color.find_cusp(a, b)

    -- Find the intersection for upper and lower half separately
    local t = 0.0
    if ((L1 - L0) * cusp.C - (cusp.L - L0) * C1) <= 0.0 then
        -- Lower half
        t = cusp.C * L0 / (C1 * cusp.L + cusp.C * (L0 - L1))
    else
        -- Upper half

        --First intersect with triangle
		t = cusp.C * (L0 - 1.0) / (C1 * (cusp.L - 1.0) + cusp.C * (L0 - L1))

        -- Then one step Halley's method
        do
            local dL = L1 - L0
            local dC = C1

            local k_l = 0.3963377774 * a + 0.2158037573 * b
            local k_m = -0.1055613458 * a - 0.0638541728 * b
            local k_s = -0.0894841775 * a - 1.2914855480 * b

            local l_dt = dL + dC * k_l
            local m_dt = dL + dC * k_m
            local s_dt = dL + dC * k_s

            -- If higher accuracy is required, 2 or 3 iterations of the following block can be used:
            do
                local L = L0 * (1.0 - t) + t * L1
				local C = t * C1

				local l_ = L + C * k_l
				local m_ = L + C * k_m
				local s_ = L + C * k_s

				local l = l_ * l_ * l_
				local m = m_ * m_ * m_
				local s = s_ * s_ * s_

				local ldt = 3.0 * l_dt * l_ * l_
				local mdt = 3.0 * m_dt * m_ * m_
				local sdt = 3.0 * s_dt * s_ * s_

				local ldt2 = 6.0 * l_dt * l_dt * l_
				local mdt2 = 6.0 * m_dt * m_dt * m_
				local sdt2 = 6.0 * s_dt * s_dt * s_

                local r0 = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s - 1
				local r1 = 4.0767416621 * ldt - 3.3077115913 * mdt + 0.2309699292 * sdt
				local r2 = 4.0767416621 * ldt2 - 3.3077115913 * mdt2 + 0.2309699292 * sdt2

                local u_r = r1 / (r1 * r1 - 0.5 * r0 * r2)
				local t_r = -r0 * u_r

                local g0 = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s - 1
				local g1 = -1.2684380046 * ldt + 2.6097574011 * mdt - 0.3413193965 * sdt
				local g2 = -1.2684380046 * ldt2 + 2.6097574011 * mdt2 - 0.3413193965 * sdt2

                local u_g = g1 / (g1 * g1 - 0.5 * g0 * g2)
				local t_g = -g0 * u_g

                local b0 = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s - 1
				local b1 = -0.0041960863 * ldt - 0.7034186147 * mdt + 1.7076147010 * sdt
				local b2 = -0.0041960863 * ldt2 - 0.7034186147 * mdt2 + 1.7076147010 * sdt2

                local u_b = b1 / (b1 * b1 - 0.5 * b0 * b2)
				local t_b = -b0 * u_b

                if u_r < 0.0 then t_r = 3.402823466e+38 end
                if u_g < 0.0 then t_g = 3.402823466e+38 end
                if u_b < 0.0 then t_b = 3.402823466e+38 end

                t = t + math.min(t_r, t_g, t_b)
            end
        end
    end

    return t
end

function ok_color.gamut_clip_preserve_chroma(rgb)
	if rgb.r <= 1.0
        and rgb.g <= 1.0
        and rgb.b <= 1.0
        and rgb.r >= 0.0
        and rgb.g >= 0.0
        and rgb.b >= 0.0 then
		return rgb
    end

    local lab = ok_color.linear_srgb_to_oklab(rgb)

    local L = lab.L
	local C = math.max(0.00001, math.sqrt(lab.a * lab.a + lab.b * lab.b))
	local a_ = lab.a / C
	local b_ = lab.b / C

    local L0 = ok_color.clamp(L, 0.0, 1.0)

    local t = ok_color.find_gamut_intersection(a_, b_, L, C, L0)
	local L_clipped = L0 * (1.0 - t) + t * L
	local C_clipped = t * C

    return ok_color.oklab_to_linear_srgb({
        L = L_clipped,
        a = C_clipped * a_,
        b = C_clipped * b_ })
end

function ok_color.gamut_clip_project_to_0_5(rgb)
    if rgb.r <= 1.0
        and rgb.g <= 1.0
        and rgb.b <= 1.0
        and rgb.r >= 0.0
        and rgb.g >= 0.0
        and rgb.b >= 0.0 then
        return rgb
    end

    local lab = ok_color.linear_srgb_to_oklab(rgb)

    local L = lab.L
	local C = math.max(0.00001, math.sqrt(lab.a * lab.a + lab.b * lab.b))
	local a_ = lab.a / C
	local b_ = lab.b / C

    local L0 = 0.5

    local t = ok_color.find_gamut_intersection(a_, b_, L, C, L0)
    local C_clipped = t * C

    return ok_color.oklab_to_linear_srgb({
        L = L0 * (1.0 - t) + t * L,
        a = C_clipped * a_,
        b = C_clipped * b_ })
end

function ok_color.gamut_clip_project_to_L_cusp(rgb)
    if rgb.r <= 1.0
        and rgb.g <= 1.0
        and rgb.b <= 1.0
        and rgb.r >= 0.0
        and rgb.g >= 0.0
        and rgb.b >= 0.0 then
        return rgb
    end

    local lab = ok_color.linear_srgb_to_oklab(rgb)

    local L = lab.L
	local C = math.max(0.00001, math.sqrt(lab.a * lab.a + lab.b * lab.b))
	local a_ = lab.a / C
	local b_ = lab.b / C

    local cusp = ok_color.find_cusp(a_, b_)
    local L0 = cusp.L
    local t = ok_color.find_gamut_intersection(a_, b_, L, C, L0, cusp)
	local C_clipped = t * C

    return ok_color.oklab_to_linear_srgb({
        L = L0 * (1.0 - t) + t * L,
        a = C_clipped * a_,
        b = C_clipped * b_ })
end

function ok_color.gamut_clip_adaptive_L0_0_5(rgb, x)
    if rgb.r <= 1.0
        and rgb.g <= 1.0
        and rgb.b <= 1.0
        and rgb.r >= 0.0
        and rgb.g >= 0.0
        and rgb.b >= 0.0 then
        return rgb
    end

    local lab = ok_color.linear_srgb_to_oklab(rgb)

    local L = lab.L
	local C = math.max(0.00001, math.sqrt(lab.a * lab.a + lab.b * lab.b))
	local a_ = lab.a / C
	local b_ = lab.b / C

    local alpha = x or 0.05
    local Ld = L - 0.5
	local e1 = 0.5 + math.abs(Ld) + alpha * C
	local L0 = 0.5 * (1.0 + ok_color.sgn(Ld) * (e1 - math.sqrt(e1 * e1 - 2.0 * math.abs(Ld))))

    local t = ok_color.find_gamut_intersection(a_, b_, L, C, L0)
	local C_clipped = t * C

    return ok_color.oklab_to_linear_srgb({
        L = L0 * (1.0 - t) + t * L,
        a = C_clipped * a_,
        b = C_clipped * b_ })
end

function ok_color.gamut_clip_adaptive_L0_L_cusp(rgb, x)
    if rgb.r <= 1.0
        and rgb.g <= 1.0
        and rgb.b <= 1.0
        and rgb.r >= 0.0
        and rgb.g >= 0.0
        and rgb.b >= 0.0 then
        return rgb
    end

    local lab = ok_color.linear_srgb_to_oklab(rgb)

    local L = lab.L
	local C = math.max(0.00001, math.sqrt(lab.a * lab.a + lab.b * lab.b))
	local a_ = lab.a / C
	local b_ = lab.b / C

    local cusp = ok_color.find_cusp(a_, b_)

    local Ld = L - cusp.L
    local k = 0.0
    if Ld > 0 then
        k = 2.0 * (1.0 - cusp.L)
    else
        k = 2.0 * cusp.L
    end

    local alpha = x or 0.05
    local e1 = 0.5 * k + math.abs(Ld) + alpha * C / k
	local L0 = cusp.L + 0.5 * (ok_color.sgn(Ld) * (e1 - math.sqrt(e1 * e1 - 2.0 * k * math.abs(Ld))))

    local t = ok_color.find_gamut_intersection(a_, b_, L, C, L0, cusp)
	local C_clipped = t * C

    return ok_color.oklab_to_linear_srgb({
        L = L0 * (1.0 - t) + t * L,
        a = C_clipped * a_,
        b = C_clipped * b_ })
end

function ok_color.toe(x)
    local k_1 = 0.206
    local k_2 = 0.03
    local k_3 = (1.0 + k_1) / (1.0 + k_2)
	return 0.5 * (k_3 * x - k_1 + math.sqrt((k_3 * x - k_1) * (k_3 * x - k_1) + 4 * k_2 * k_3 * x))
end

function ok_color.toe_inv(x)
    local k_1 = 0.206
    local k_2 = 0.03
    local k_3 = (1.0 + k_1) / (1.0 + k_2)
	return (x * x + k_1 * x) / (k_3 * (x + k_2))
end

function ok_color.to_ST(cusp)
	local L = cusp.L
	local C = cusp.C
    if L ~= 0.0 and L ~= 1.0 then
    	return { S = C / L, T = C / (1.0 - L) }
    else
        return { S = 0.0, T = 0.0 }
    end
end

-- Returns a smooth approximation of the location of the cusp
-- This polynomial was created by an optimization process
-- It has been designed so that S_mid < S_max and T_mid < T_max
function ok_color.get_ST_mid(a_, b_)
    local S = 0.11516993 + 1.0 / (7.4477897 + 4.1590124 * b_
		+ a_ * (-2.19557347 + 1.75198401 * b_
			+ a_ * (-2.13704948 - 10.02301043 * b_
				+ a_ * (-4.24894561 + 5.38770819 * b_ + 4.69891013 * a_))))

	local T = 0.11239642 + 1.0 / (1.6132032 - 0.68124379 * b_
		+ a_ * (0.40370612 + 0.90148123 * b_
			+ a_ * (-0.27087943 + 0.6122399 * b_
				+ a_ * (0.00299215 - 0.45399568 * b_ - 0.14661872 * a_))))

	return { S = S, T = T }
end

function ok_color.get_Cs(L, a_, b_)
    local cusp = ok_color.find_cusp(a_, b_)

    local C_max = ok_color.find_gamut_intersection(a_, b_, L, 1, L, cusp)
    local ST_max = ok_color.to_ST(cusp)

    -- Scale factor to compensate for the curved part of gamut shape:
    local k = 0.0
    local k_denom = math.min(L * ST_max.S, (1.0 - L) * ST_max.T)
	if k_denom ~= 0.0 then k = C_max / k_denom end

    local C_mid = 0.0
    do
        local ST_mid = ok_color.get_ST_mid(a_, b_)

        -- Use a soft minimum function, instead of a sharp triangle shape to get a smooth value for chroma.
        local C_a = L * ST_mid.S
        local C_b = (1.0 - L) * ST_mid.T
        C_mid = 0.9 * k * math.sqrt(math.sqrt(1.0 / (1.0 / (C_a * C_a * C_a * C_a) + 1.0 / (C_b * C_b * C_b * C_b))))
    end

    local C_0 = 0.0
    do
        -- for C_0, the shape is independent of hue, so ST are constant. Values picked to roughly be the average values of ST.
		local C_a = L * 0.4
		local C_b = (1.0 - L) * 0.8

		-- Use a soft minimum function, instead of a sharp triangle shape to get a smooth value for chroma.
		C_0 = math.sqrt(1.0 / (1.0 / (C_a * C_a) + 1.0 / (C_b * C_b)))
    end

    return { C_0 = C_0, C_mid = C_mid, C_max = C_max }
end

function ok_color.okhsl_to_srgb(hsl)
    return ok_color.oklab_to_srgb(ok_color.okhsl_to_oklab(hsl))
end

function ok_color.okhsl_to_oklab(hsl)
	local l = hsl.l
    if l > 0.99999 then return { L = 1.0, a = 0.0, b = 0.0 } end
    if l < 0.00001 then return { L = 0.0, a = 0.0, b = 0.0 } end

    -- TODO: saturation should be found first and
    -- early return for s < eps.
    local h_rad = hsl.h * 6.283185307179586
    local a_ = math.cos(h_rad)
    local b_ = math.sin(h_rad)
    local L = ok_color.toe_inv(l)

    local cs = ok_color.get_Cs(L, a_, b_)
    local C_0 = cs.C_0
	local C_mid = cs.C_mid
	local C_max = cs.C_max

    local mid = 0.8
	local mid_inv = 1.25

    local C = 0.0
    local t = 0.0
    local k_0 = 0.0
    local k_1 = 0.0
    local k_2 = 0.0

    local s = hsl.s
    if s < mid then
        t = mid_inv * s

		k_1 = mid * C_0
		k_2 = (1.0 - k_1 / C_mid)

		C = t * k_1 / (1.0 - k_2 * t)
    else
        t = (s - mid) / (1 - mid)

		k_0 = C_mid
		k_1 = (1.0 - mid) * C_mid * C_mid * mid_inv * mid_inv / C_0
        local C_denom = C_max - C_mid
		k_2 = 1.0
        if C_denom ~= 0.0 then
            k_2 = 1.0 - k_1 / C_denom
        end

		C = k_0 + t * k_1 / (1.0 - k_2 * t)
    end

    return {
        L = L,
        a = C * a_,
        b = C * b_ }
end

function ok_color.srgb_to_okhsl(rgb)
    return ok_color.oklab_to_okhsl(ok_color.srgb_to_oklab(rgb))
end

function ok_color.oklab_to_okhsl(lab)
    local L = lab.L
    if L > 0.99999 then return { h = 0.0, s = 0.0, l = 1.0 } end
    if L < 0.00001 then return { h = 0.0, s = 0.0, l = 0.0 } end

    local Csq = lab.a * lab.a + lab.b * lab.b
    if Csq > 0.0 then
        local C = math.sqrt(Csq)
        local a_ = lab.a / C
        local b_ = lab.b / C

        -- 1.0 / math.pi = 0.3183098861837907
        local h = 0.5 + 0.5 * math.atan(-lab.b, -lab.a) * 0.3183098861837907

        local cs = ok_color.get_Cs(L, a_, b_)
        local C_0 = cs.C_0
        local C_mid = cs.C_mid
        local C_max = cs.C_max

        -- Inverse of the interpolation in okhsl_to_srgb:

        local mid = 0.8
        local mid_inv = 1.25

        local s = 0.0
        if C < C_mid then
            local k_1 = mid * C_0
            local k_2 = (1.0 - k_1 / C_mid)

            local t = C / (k_1 + k_2 * C)
            s = t * mid
        else
            local k_0 = C_mid
            local k_1 = 0.0
            -- if C_0 ~= 0.0 then
            k_1 = (1.0 - mid) * C_mid * C_mid * mid_inv * mid_inv / C_0
            -- end
            local C_denom = C_max - C_mid
            local k_2 = 1.0
            -- if C_denom ~= 0.0 then
            k_2 = 1.0 - k_1 / C_denom
            -- end

            local t_denom = k_1 + k_2 * (C - k_0)
            local t = 0.0
            -- if t_denom ~= 0.0 then
            t = (C - k_0) / t_denom
            -- end
            s = mid + (1.0 - mid) * t
        end

        return { h = h, s = s, l = ok_color.toe(L) }
    else
        return { h = 0.0, s = 0.0, l = L }
    end
end

function ok_color.okhsv_to_srgb(hsv)
    return ok_color.oklab_to_srgb(ok_color.okhsv_to_oklab(hsv))
end

function ok_color.okhsv_to_oklab(hsv)
	local v = hsv.v
    if v < 0.00001 then return { L = 0.0, a = 0.0, b = 0.0 } end

    -- TODO: saturation should be found first and
    -- early return for s < eps.
    local s = hsv.s

    local h_rad = hsv.h * 6.283185307179586
    local a_ = math.cos(h_rad)
    local b_ = math.sin(h_rad)

    local cusp = ok_color.find_cusp(a_, b_)
	local ST_max = ok_color.to_ST(cusp)
	local S_max = ST_max.S
	local T_max = ST_max.T
	local S_0 = 0.5
    local k = 1.0
    if S_max ~= 0.0 then
	    k = 1.0 - S_0 / S_max
    end

    -- first we compute L and V as if the gamut is a perfect triangle:

	-- L, C when v==1:
    local L_v = 1.0 - s * S_0 / (S_0 + T_max - T_max * k * s)
	local C_v = s * T_max * S_0 / (S_0 + T_max - T_max * k * s)

    local L = v * L_v
	local C = v * C_v

    --then we compensate for both toe and the curved top part of the triangle:
    local L_vt = ok_color.toe_inv(L_v)
    local C_vt = C_v * L_vt / L_v

    local L_new = ok_color.toe_inv(L)
    C = C * L_new / L
    L = L_new

    local rgb_scale = ok_color.oklab_to_linear_srgb({ L = L_vt, a = a_ * C_vt, b = b_ * C_vt })
	local scale_L = (1.0 / math.max(rgb_scale.r, rgb_scale.g, rgb_scale.b, 0.0)) ^ 0.3333333333333333

	C = C * scale_L
    return {
        L = L * scale_L,
        a = C * a_,
        b = C * b_ }
end

function ok_color.srgb_to_okhsv(rgb)
    return ok_color.oklab_to_okhsv(ok_color.srgb_to_oklab(rgb))
end

function ok_color.oklab_to_okhsv(lab)
    local Csq = lab.a * lab.a + lab.b * lab.b
    if Csq > 0.0 then
        local C = math.sqrt(Csq)
        local a_ = lab.a / C
        local b_ = lab.b / C

        -- 1.0 / math.pi = 0.3183098861837907
        local h = 0.5 + 0.5 * math.atan(-lab.b, -lab.a) * 0.3183098861837907

        local cusp = ok_color.find_cusp(a_, b_)
        local ST_max = ok_color.to_ST(cusp)
        local S_max = ST_max.S
        local T_max = ST_max.T
        local S_0 = 0.5
        local k = 1.0
        -- if S_max ~= 0.0 then
        k = 1.0 - S_0 / S_max
        -- end

        -- first we find L_v, C_v, L_vt and C_vt
        local L = lab.L
        local t_denom = C + L * T_max
        local t = 0.0
        -- if t_denom ~= 0.0 then
        t = T_max / t_denom
        -- end
        local L_v = t * L
        local C_v = t * C

        local L_vt = ok_color.toe_inv(L_v)
        local C_vt = 0.0
        -- if L_v ~= 0.0 then
        C_vt = C_v * L_vt / L_v
        -- end

        -- we can then use these to invert the step that compensates for the toe and the curved top part of the triangle:
        local rgb_scale = ok_color.oklab_to_linear_srgb({ L = L_vt, a = a_ * C_vt, b = b_ * C_vt })
        local scale_denom = math.max(rgb_scale.r, rgb_scale.g, rgb_scale.b, 0.0)
        local scale_L = 0.0
        -- if scale_denom ~= 0.0 then
        scale_L = (1.0 / scale_denom) ^ 0.3333333333333333
        -- end

        -- if scale_L ~= 0.0 then
        L = L / scale_L
        C = C / scale_L
        -- else
            -- L = 0.0
            -- C = 0.0
        -- end

        local toel = ok_color.toe(L)
        -- if L ~= 0.0 then
        C = C * toel / L
        -- else
            -- C = 0.0
        -- end
        L = toel

        -- we can now compute v and s:
        local v = 0.0
        -- if L_v ~= 0.0 then
        v = L / L_v
        -- end

        local s = 0.0
        local s_denom = ((T_max * S_0) + T_max * k * C_v)
        -- if s_denom ~= 0.0 then
        s = (S_0 + T_max) * C_v / s_denom
        -- end

        return { h = h, s = s, v = v }
    else
        return { h = 0.0, s = 0.0, v = ok_color.clamp(lab.L, 0.0, 1.0) }
    end
end

return ok_color