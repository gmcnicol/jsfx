# JSFX GFX Notes

Use `Effects/ScaleLane_v1.jsfx` as the golden source for custom JSFX UI structure.

Key rules:

- Keep `@gfx` organized around stable layout state, input handling, and drawing.
- Recompute layout only when `layout_dirty`, `gfx_w`, `gfx_h`, or the UI scale changes.
- Do not call `slider_show()` from `@gfx`.
- Do not call `sliderchange()` continuously from mouse drag handling.
- Do not write backing host sliders every graphics frame while dragging.
- For drag controls, keep live UI/audio state in local variables and commit backing sliders once on click or drag release.
- Treat REAPER host slider/panel updates as expensive host UI changes, not normal paint-loop work.
- If the UI flickers, first audit `@gfx` for a loop that writes host-visible state and triggers REAPER to rebuild or refresh the plugin panel while drawing.
- Avoid multiple visible-surface partial blits from many offscreen image slots for one UI. A single backing image with one final `gfx_blit()` is the stable cache pattern when caching is needed.
- Dirty rendering should update bounded regions inside that one backing image, then present the whole backing image once.

For `ParallelTap_v1.jsfx`, the first bad pattern was writing tap level sliders from the fader drag path on every `@gfx` frame. The second bad pattern was splitting the UI across background/header/ADSR/per-tap image slots and blitting all of those images to the visible surface. The screen recording showed tap regions disappearing independently, so the stable fix is one persistent cache image, dirty section redraws inside that cache, and one final visible blit.

ParallelTap audio/state notes:

- Repeats read from a shared dry stereo delay buffer, then each tap is independently ADSR/trim-shaped and added directly to its selected REAPER output pair.
- Apply ADSR per sample to the delayed tap read, not to the live input before delay. The tap should read the dry delay buffer first, then apply ADSR * trim, then add to the selected output pair.
- The ParallelTap ADSR is a retriggerable one-shot AD shape: attack rises to max trim, decay falls to sustain, and release only handles the sustain tail. Do not let short drum gates abort attack/decay early.
- Use per-tap onset detection as well as gate state, because upstream reverb can hold the gate open and sustain zero would otherwise prevent later hits from retriggering.
- Do not schedule a full ADSR tail for every input sample.
- Position display is 1-based, but delay math is zero-based: position 1 means no grid delay, position 2 means one grid step later.
- Custom UI edits should update live local state immediately and commit backing tap sliders on discrete clicks or drag release, without `sliderchange()`.
- Smooth each tap's target delay before reading the dry delay buffer, and run the final summed per-channel wet output through a tiny de-click ramp so output channels cannot hard-step.
- Keep ParallelTap's input side 16-channel capable. Battery/reverb routing can arrive on pairs other than 1/2; the default input mode must not go silent just because upstream FX pins move the source pair.
