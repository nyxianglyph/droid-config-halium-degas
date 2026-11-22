// Default Gecko preferences for the Xiaomi 14T (browser and web views).
//
// Without layout.frame_rate Gecko paints from a 60 Hz software timer, which
// judders on the 144 Hz panel. 144 leaves 6.9 ms per refresh tick and pages
// with per-frame scripts then fill the main thread (input and scrolling lag
// by seconds). 72 is half the panel rate: every frame is shown for exactly
// two refreshes and heavy pages keep some headroom.
pref("layout.frame_rate", 72);

// Web content scale. Sailfish derives it from the UI scale and only accepts
// a value that divides both screen dimensions evenly, which for 1220x2712
// leaves 2.0: pages get a 610 px wide viewport and sites serve their tablet
// layout. 3.0 gives 407 px, like other phones with this panel density. The
// pref is locked because the web engine writes its own value at every start.
pref("layout.css.devPixelsPerPx", "3.0", locked);
