# MCP WALTER and custom-control contract (REAPER 7.77+)

Research date: 2026-07-12. Target baseline: REAPER 7.77. Sources are Cockos's current developer reference and first-party release history only.

## Executive answer

Cockos documents a stable WALTER surface for ordinary track MCP (`mcp.*`), Master MCP (`master.mcp.*`), and the extended-mixer placement rectangles belonging to each. It also documents a `custom` command introduced in REAPER 7.0, but the published grammar and examples name only `tcp.custom.*`. The documentation does **not** explicitly guarantee that custom controls can be declared in `mcp.*`, `master.mcp.*`, or inside the extended-mixer area. Those three applicability questions require prototypes before ReaLayout Studio treats them as supported.

The custom-control contract itself is small: five positional arguments; a name containing `custom.`; ordinary WALTER placement/Z-order; optional text styling; and button creation only when both a valid action identifier and valid image name are supplied. Cockos does not document accepted action-ID forms, action section, action context/track targeting, toggle-state feedback, `_on` image selection, missing-state fallback, or display-scale asset lookup for custom buttons. Those behaviors also require prototypes.

## Documented stable MCP surface

WALTER lives in a theme's `rtconfig.txt`, defines visual layout/appearance, and provides `clear`, `reset`, `set`, static `front` Z-order, macros, layouts, and conditional expressions. Layouts inherit their parent/default layout and may use an image subdirectory. Coordinate lists normally contain `[left top width height left-attach top-attach right-attach bottom-attach]`; the last four values determine how geometry responds to parent resizing. Conditions can branch on comparisons, zero/nonzero tests, bitwise AND, and arithmetic composition. ([WALTER reference: commands, layouts, expressions, and edge attachment](https://www.reaper.fm/sdk/walter/walter.php))

### Track MCP

The documented `mcp.*` elements include:

- panel sizing and structure: `mcp.size`, `mcp.margin`, `mcp.label`, `mcp.trackidx`, `mcp.folder`;
- track operations: `mcp.env`, `mcp.fx`, `mcp.fxbyp`, `mcp.fxin`, `mcp.io`, `mcp.phase`, `mcp.recarm`, `mcp.recinput`, `mcp.recmode`, `mcp.recmon`, `mcp.mute`, and `mcp.solo`;
- continuous controls/readouts: `mcp.volume`, `mcp.pan`, `mcp.width`, their label/color/font/margin fields, and documented fader-vs-knob mode;
- metering: `mcp.meter` and its documented input-label, readout, scale-color, and channel-division fields;
- extended-mixer typography/layout fields for FX, FX parameters, and sends.

The complete authoritative member list and per-coordinate meanings live in the `Mixer Control Panel (mcp.*)` section. ([WALTER UI elements: track MCP](https://www.reaper.fm/sdk/walter/walter.php))

### Master MCP

The distinct `master.mcp.*` namespace documents size, margin, label, menu button, FX/bypass, I/O, envelope mode, mute, solo, mono, pan, width, volume, meter, and extended-mixer list typography/layout. It is not simply promised to mirror every track-MCP element; consumers should use the enumerated Master MCP surface. ([WALTER UI elements: Master MCP](https://www.reaper.fm/sdk/walter/walter.php))

### Extended Mixer

For a track MCP, `mcp.extmixer.mode [1]` makes `mcp.extmixer.position` the position of extended-mixer elements (FX, sends, FX parameters). Mode `[-1]` retains default handling but uses that position as a margin. The same documented contract exists at `master.mcp.extmixer.mode` and `master.mcp.extmixer.position`. The reference separately exposes font and margin controls for `mcp.fxlist`, `mcp.fxparm`, `mcp.sendlist` and their `master.mcp.*` counterparts. ([WALTER UI elements: extended mixer](https://www.reaper.fm/sdk/walter/walter.php))

The theme-image reference documents extended-mixer backgrounds and per-slot images, including track/master FX-list fallback: omitted master FX-list images use the normal track images. It describes per-slot images as three equal-height vertical slices for normal, hover, and pressed states. ([Theme images: Extended mixer views](https://www.reaper.fm/sdk/walter/images.php))

## Exact documented custom-control contract

Introduced in REAPER 7.0, the published syntax is:

```text
custom tcp.custom.xyz text_label command_id accessibility_description button_image
```

The documented guarantees are:

1. The element name must contain `custom.`.
2. It becomes a normal member of the containing layout and can be operated on by `set`, `front`, and related WALTER commands. REAPER 7.07 additionally documents wildcard setting/clearing such as `clear tcp.custom.*` and `clear tcp.*`.
3. If `command_id` is specified and valid **and** `button_image` is a valid image name, the element is a button. Otherwise it is a static text element showing `text_label`.
4. The element may have `.font`, `.color`, and `.margin` fields. General WALTER rules define `.margin` as left/top/right/bottom plus optional text justification, and `.color` as RGBA in its first four coordinates (with a possible second color in the remaining four).
5. The accessibility-description argument is part of the declared syntax; Cockos does not document further semantics on the WALTER page.

Sources: [current WALTER `custom` command reference](https://www.reaper.fm/sdk/walter/walter.php); [REAPER 7.0 and 7.07 first-party release notes](https://www.reaper.fm/download-old.php).

### Geometry and conditions

Because custom elements are documented as normal layout elements, their rectangle uses the ordinary `set` coordinate-list contract and may use ordinary WALTER expressions. Setting a placement to `[0]` is the documented idiom used elsewhere to hide an element conditionally; `clear` removes an attribute and `reset` restores its default. `front` changes a custom element's static Z-order, but Z-order cannot itself vary dynamically. ([WALTER commands and expressions](https://www.reaper.fm/sdk/walter/walter.php))

This guarantees geometry driven by the documented parent dimensions (`w`, `h`), documented scalar conditions, user variables, and edge attachment. It does not guarantee a custom control can query the state of its bound action: no such scalar or custom-control state field is documented.

### Action identifiers and state

The WALTER page requires a valid `command_id` but does not define its lexical form or section. Cockos's ReaScript reference establishes elsewhere that REAPER distinguishes numeric built-in command IDs and string custom-action IDs, and that action toggle state is section-specific (`GetToggleCommandStateEx` documents main, alternate main, MIDI-editor, Media Explorer, and other sections). That API documentation does **not** say which of those forms/sections the WALTER `custom` argument accepts, so it cannot be promoted into the WALTER contract by inference. ([REAPER ReaScript API: command IDs and toggle state](https://www.reaper.fm/sdk/reascript/reascripthelp.html))

Likewise, neither the WALTER reference nor the 7.x release notes document:

- whether a custom button reflects action toggle state;
- how indeterminate or unavailable state is rendered;
- whether its action runs against the clicked track, selected tracks, or current project focus;
- whether command IDs from extension actions, ReaScripts, named/custom actions, or non-main sections are accepted;
- whether modifiers, right-click, double-click, or drag have a contract.

All are prototype questions.

### Image states, fallback, and display scale

The only custom-specific guarantee is that `button_image` must be a valid image name for button creation. General theme documentation says a `sliced-button` is a horizontal three-slice image (normal, mouseover, pressed), stretched to fit, with optional `_ol.png` overlay when `use_overlays 1` is enabled. It does not explicitly classify arbitrary custom button images as `sliced-button`, define the filename extension rule, define an `_on` toggle variant, or specify a custom-image fallback chain. Therefore those details require a prototype rather than borrowing contracts from built-in named images. ([Theme image types](https://www.reaper.fm/sdk/walter/images.php))

The current `rtconfig.txt` reference documents theme-wide DPI mechanisms: `misc_dpi_translate`, `global_scale`, and `layout_dpi_translate`. It does not document `100/`, `150/`, or `200/` subdirectory lookup for arbitrary custom-control images. Layouts may select an image subdirectory, and a whole layout may be remapped by DPI, but automatic custom-button asset variants remain unguaranteed. ([Theme structure and `rtconfig.txt`](https://www.reaper.fm/sdk/walter/images.php))

## Required prototypes before product support

1. **Namespace/context matrix:** declare the same control under `mcp.custom.*`, `master.mcp.custom.*`, and candidate extended-mixer placement; test parse warnings, rendering, hit testing, and layout inheritance.
2. **Action-ID matrix:** numeric built-in IDs, underscore-prefixed named IDs, custom actions, ReaScripts, extension actions, invalid IDs, and actions from every relevant action section.
3. **Target/context matrix:** click controls on selected/unselected track MCPs and Master MCP, across projects and dock/floating mixer contexts.
4. **State matrix:** actions returning off/on/indeterminate/no toggle state; observe redraw timing and any image/text change.
5. **Image matrix:** extension/no extension, missing image, malformed slice, normal/hover/pressed, `_on`, `_ol`, and fallback behavior.
6. **Scale matrix:** OS display scales and REAPER UI scales using root assets, likely scale subdirectories, `global_scale`, `misc_dpi_translate`, and DPI-remapped layouts.
7. **Geometry matrix:** zero/negative dimensions, clipping to MCP and extended-mixer rectangles, edge attachment, overlap/Z-order, and resizing.

Until these prototypes pass, a conservative editor/parser should recognize and preserve custom declarations but label MCP, Master MCP, extended-mixer placement, action-state previews, and scale-variant resolution as experimental rather than part of the stable documented surface.
