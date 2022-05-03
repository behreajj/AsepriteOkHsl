# Okhsl for Aseprite

This is an [Aseprite](https://www.aseprite.org/) dialog that wraps [Okhsl](https://bottosson.github.io/posts/colorpicker/) to provide a color picker and a color wheel generator. Aseprite is an "animated sprite editor & pixel art tool." Okhsl is a color representation developed by Bjorn Ottosson to create an alternative to HSL that is based on human perception. Those interested in an interactive comparison between Okhsl, HSLuv and traditional HSL may reference this [link](https://bottosson.github.io/misc/colorpicker/).

## Installation

To use this script, open Aseprite, go to `File > Scripts > Open Scripts Folder`. Copy and paste the two Lua scripts from this repository into that folder. Return to Aseprite; go to `File > Scripts > Rescan Scripts Folder` (the default hotkey is `F5`). The two scripts should now be listed under `File > Scripts`. Select `ok_picker` to launch the dialog.

To assign a hotkey to the dialog script go to `Edit > Keyboard Shortcuts`.

## Usage

Left click on a color preview window to assign the color to the foreground. Right click to assign to the background. If the alpha channel slider is zero, the color assigned will be transparent black (`0x0` or `Color(0, 0, 0, 0)`).

Hues in Okhsl are not the same as in LCh, HSLuv, or classic HSL. For example, red (`#ff0000`) has a hue of approximately 29 degrees in Okhsl. Do not assume different color representations have the same primaries, or the same spatial relationships between colors.

Beware of drift in hue and other channels when getting and setting colors. For example, getting `#ff0000` will result in (29, 100, 57) in Okhsl. However, setting the picker's sliders to those values manually will yield the hexadecimal `#ff0809`.

![Screen Cap 0](screenCap0.png)

When the `Wheel` button is clicked, a new sprite is created. Use the arrow keys to navigate through each frame and thus change this variable. When saturation varies with frames, the wheel will be white at its center and black at its circumference. The color wheel's hue is shifted by 30 degrees to match the Aseprite convention.

![Saturation Axis](altWheel0.png) ![Hue Remap](altWheel1.png)

Click on the `Wheel Settings` toggle to show more options. For example, the `Sectors` and `Rings` sliders can be used to make the color wheel discrete in a fashion similar to Aseprite's built-in color wheels. The color property that varies with frame index will depend on whether the `Mode` is `HSL` or `HSV`: the choice is between `SATURATION` and `LIGHTNESS` or between `SATURATION` and `VALUE`. The hue can also be remapped to that of a red-yellow-blue color wheel.

![Screen Cap 1](screenCap1.png)

The `Gradient` button creates a new sprite with a horizontal gradient starting with the background color at the left and ending with the foreground color at the right. The sprite's palette is set to a number of swatches. The gradient ignores source color alpha.

Supported harmonies are: analogous, complementary, split, square and triadic. Shading swatches are grouped under harmonies to conserve screen space.

The underlined letters on each button indicate that they work with keyboard shortcuts: `Alt+F` gets the foreground color, `Alt+B` gets the background color, `Alt+C` closes the dialog, `Alt+W` creates a wheel, `Alt+G` creates a gradient. When shading is active, `Alt+A` appends the swatches to the active palette.

This tool -- its harmony and shading features in particular -- is an imperfect aide to artistic judgment, not a replacement for it. See Pixel Parmesan's "[Color Theory for Pixel Artists: It's All Relative](https://pixelparmesan.com/color-theory-for-pixel-artists-its-all-relative/)" on the subject.

A separate dialog allows for cel image adjustment with either `HSV` or `HSL`.

![Hue Adjustment](hueAdjust.png)

The test image above is Caravaggio's [Calling of St. Matthew](https://en.wikipedia.org/wiki/The_Calling_of_St_Matthew).

_This script was tested in Aseprite version 1.3-beta-14._ It assumes that it will be used in RGB color mode, not indexed or gray mode. Furthermore, it assumes that [sRGB](https://www.wikiwand.com/en/SRGB) (standard RGB) is the sprite's working color space.

To modify this script, see Aseprite's [API Reference](https://github.com/aseprite/api).

## Changes

Unused methods have been removed. The original code has been modified to handle edge cases for black, white and grays. There are some measures to prevent the passing of invalid values to division or square-root.

The hue for grays is left at zero to follow convention. However, this will cause problems when, for example, creating a gradient from a gray to a saturated color or when sorting colors by hue.

## License

This repository uses the MIT License associated with the original implementation in C++ in Ottosson's article.

> Copyright(c) 2021 Bjorn Ottosson
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of
> this software and associated documentation files(the "Software"), to deal in
> the Software without restriction, including without limitation the rights to
> use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
> of the Software, and to permit persons to whom the Software is furnished to do
> so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all
> copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.