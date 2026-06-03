# JSFX GFX Notes

`Effects/ParallelTap_v1.jsfx` is the current reference for non-flickering custom JSFX UI and non-clicking parameter/audio state handling. New custom editors should use the same loop shape unless there is a measured reason and a note in the file explaining the deviation.

## Hard Rules

- Keep function definitions in `@init`, never inside `@gfx`.
- Keep `@gfx` boring: sync state, compute layout, handle input, update active drags, commit ended drags, redraw dirty cache sections, final blit.
- Do not call `slider_show()` from `@gfx`.
- Do not call `sliderchange()` from custom mouse handling.
- Do not write backing host sliders every graphics frame while dragging.
- Do not let host slider sync overwrite the parameter currently being dragged.
- Treat REAPER host slider/panel updates as expensive host UI changes, not paint-loop work.
- Do not share scratch/global variables between `@gfx` and `@sample`. Per-sample DSP must run through functions with `local(...)` scratch variables, or use audio-only state with names that graphics code never writes.
- Keep `@sample` boring and isolated. A good custom-editor synth/effect has `@sample` reduced to a small call like `process_audio_sample();`, with the real DSP function defined in `@init`.
- Use one persistent offscreen cache image for the whole editor and one visible `gfx_blit()` at the end of `@gfx`.
- Reset presentation color/alpha before the final blit: `gfx_set(1, 1, 1, 1); gfx_blit(IMG_CACHE, 1, 0);`. Otherwise the blit inherits the last offscreen draw alpha and the whole UI can dim/flicker while dragging.
- Do not split one editor across multiple visible blits or multiple per-section image slots unless profiling proves it is necessary.
- Dirty rendering updates bounded sections inside the single cache image; visible presentation is still one final whole-cache blit.
- Active drag state should not repaint panel chrome, borders, or unrelated controls. Only value geometry should move.

## Standard State Model

Use three separate concepts:

- Host slider variables: REAPER-owned backing values declared as `sliderN`.
- Live UI/audio variables: local arrays/scalars read by `@sample` and painted by `@gfx`.
- Dirty flags: local flags that say which cached sections need repainting.

`@slider` clamps host values and syncs them into live UI/audio state. `@gfx` edits live UI/audio state during interaction. `@sample` reads live UI/audio state and smooths any value that can click. On click or drag release, commit the live value back to the host slider once.

During an active drag, sync functions must skip that parameter:

```eel
!(drag_param == DRAG_PARAM_TAP_POS && drag_param_tap == tap_i) ? sync_position_from_host();
drag_tap != tap_i ? sync_level_from_host();
```

That rule is what stops the dragged control from jumping back to the old host value.

## Standard GFX Loop

Use this order:

```eel
@gfx width height

sync_live_state_from_host_sliders();

(layout_dirty || gfx_w != last_layout_w || gfx_h != last_layout_h || ui_scale != last_layout_scale || !cache_ready) ? compute_layout();

mouse_down = mouse_cap & 1;
click = mouse_down && !last_mouse_down;

click ? handle_hit_tests_and_start_drags();

mouse_down && active_drag ? (
  update_drag_live_value();
) : (
  !mouse_down && active_drag ? (
    commit_live_value_to_host_slider_once();
    clear_drag_state();
  );
);

(layout_dirty || gfx_w != last_layout_w || gfx_h != last_layout_h || ui_scale != last_layout_scale || !cache_ready) ? compute_layout();

redraw_cache = bg_dirty || header_dirty || section_dirty_flags;
redraw_cache ? (
  gfx_dest = IMG_CACHE;
  bg_dirty ? render_bg();
  header_dirty ? render_header();
  section_dirty ? render_section();
  gfx_dest = -1;
);

gfx_x = 0;
gfx_y = 0;
gfx_set(1, 1, 1, 1);
gfx_blit(IMG_CACHE, 1, 0);

last_mouse_down = mouse_down;
```

Only the two `gfx_dest` assignments, the presentation `gfx_set(1, 1, 1, 1)`, and the final `gfx_blit()` belong directly in `@gfx`. All drawing lives in render functions defined in `@init`.

## Standard FX Loop

Keep `@sample` independent from `@gfx` and host panel churn:

- Wrap per-sample DSP in an `@init` function with `local(...)` scratch variables. Do not leave loop counters, phases, temporary samples, filter temps, or sums as generic globals such as `i`, `osc_i`, `sample_i`, `sum_l`, or `out_l`.
- Never reuse names between graphics/layout/input scratch and audio scratch. JSFX variables are global unless declared local in a function, so a graphics redraw can corrupt audio state and produce one-sample crackles or low-frequency thumps.
- Use persistent memory/arrays only for intentional audio state: phase, filter state, smoothed targets, delay buffers, envelopes, and committed live parameter values.
- Read live UI/audio state, not raw host sliders, for parameters controlled by custom graphics.
- Smooth frequency, gain, pan, delay, filter cutoff, wave morph, and any gate/output gain that can hard-step.
- Use de-click ramps or one-pole smoothing before a signal can appear/disappear.
- Use band-limited or softened oscillators for hard-edged waveforms, especially when morphing into saw/square.
- Do not allocate graphics resources, compute layout, write host sliders, or call graphics functions from audio sections.
- Keep MIDI/input/event capture in `@block` where possible, and keep per-sample DSP in `@sample`.

The OvumTone crackle bug was caused by `@gfx` and `@sample` sharing generic scratch/global variables. The stable fix was to move the oscillator loop into a `process_audio_sample()` function with local scratch variables and leave `@sample` as a single call.

## ParallelTap Findings

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
