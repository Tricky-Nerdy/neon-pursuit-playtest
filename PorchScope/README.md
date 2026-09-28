# PorchScope

An Android porch viewer/finder for a UVC USB webcam connected by USB-C OTG.
It is intentionally built for three uses:

- **Day / ocean:** boats, coast, clouds, wildlife, and distant landscape.
- **Sky:** the Moon, bright planets, stars, and a telescope finder camera.
- **Orientation:** GPS position plus a central reticle, ready for a later stars/aircraft/boat map overlay.

## Why this should solve the OpenLiveStacker problem

OpenLiveStacker focuses on astronomy capture. PorchScope exposes UVC camera controls directly: **brightness, contrast, gain, and gamma**, plus quick Day/Ocean and Night/Stars presets. If a slider does nothing, the connected webcam does not advertise that hardware control; a software-only adjustment can still be added in the next pass.

No app can recover sky or water detail that was already clipped to pure white by the webcam. For daytime ocean use, reduce gain first, then brightness; adjust contrast last. For stars, increase exposure (if available), then gain slowly.

## Build and install

1. Install Android Studio on a computer.
2. Open this `PorchScope` folder and let Gradle sync.
3. Plug the Android phone in by USB, enable Developer Options → USB debugging, then select **Run**.
4. Connect a UVC webcam using a USB-C OTG adapter. A powered hub is recommended for a large webcam or a telescope camera.

The project uses AndroidUSBCamera/AUSBC `3.3.0` for UVC support. Its preview and camera-control APIs support normal UVC webcams, but every webcam exposes a different set of hardware controls.

## Next pass

- Implement the horizon map: GPS + compass, with a target direction arrow.
- Add live aircraft from ADS-B and boats from AIS where available.
- Add a Stellarium-style sky overlay and star calibration.
- Add software-only brightness/gamma so unsupported webcams still look good.

