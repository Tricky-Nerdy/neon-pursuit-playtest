package com.trickynerdy.porchscope

import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.SeekBar
import android.widget.TextView
import com.jiangdg.ausbc.base.CameraFragment
import com.jiangdg.ausbc.camera.ICamera
import com.jiangdg.ausbc.camera.bean.CameraRequest
import com.jiangdg.ausbc.camera.callback.ICameraStateCallBack
import com.jiangdg.ausbc.widget.AspectRatioTextureView
import com.jiangdg.ausbc.widget.IAspectRatio

/**
 * USB-webcam finder view. AUSBC owns USB permission and attaches any UVC camera.
 * Controls call genuine UVC properties when the camera provides them.
 */
class PorchCameraFragment : CameraFragment() {
    private lateinit var root: FrameLayout
    private lateinit var previewContainer: FrameLayout
    private lateinit var status: TextView

    override fun getRootView(inflater: LayoutInflater, container: ViewGroup?): View {
        root = FrameLayout(requireContext())
        previewContainer = FrameLayout(requireContext())
        root.addView(previewContainer, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))
        root.addView(makeReticle(), FrameLayout.LayoutParams(180, 180, Gravity.CENTER))
        root.addView(makeControls(), FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.BOTTOM
        ))
        return root
    }

    override fun getCameraView(): IAspectRatio = AspectRatioTextureView(requireContext())

    override fun getCameraViewContainer(): ViewGroup = previewContainer

    override fun getCameraRequest(): CameraRequest = CameraRequest.CameraRequestBuilder()
        .setPreviewWidth(1920)
        .setPreviewHeight(1080)
        .setPreviewFormat(CameraRequest.PreviewFormat.FORMAT_MJPEG)
        .setAspectRatioShow(true)
        .create()

    override fun onCameraState(
        self: ICamera,
        code: ICameraStateCallBack.State,
        msg: String?
    ) {
        when (code) {
            ICameraStateCallBack.State.OPENED -> status.text = "UVC camera live — tune it for ocean, sky, or telescope"
            ICameraStateCallBack.State.CLOSED -> status.text = "Webcam unplugged"
            ICameraStateCallBack.State.ERROR -> status.text = "Camera error: ${msg ?: "unknown"}"
        }
    }

    private fun makeControls(): View {
        val panel = LinearLayout(requireContext()).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(22, 16, 22, 18)
            setBackgroundColor(0xD9050A0D.toInt())
        }
        status = TextView(requireContext()).apply {
            setTextColor(Color.WHITE)
            textSize = 13f
            text = "Connect a UVC USB webcam through an OTG adapter"
        }
        panel.addView(status)

        panel.addView(control("Brightness", 128) { mCameraClient?.setBrightness(it) })
        panel.addView(control("Contrast", 128) { mCameraClient?.setContrast(it) })
        panel.addView(control("Gain", 0) { mCameraClient?.setGain(it) })
        panel.addView(control("Gamma", 128) { mCameraClient?.setGamma(it) })

        val buttons = LinearLayout(requireContext()).apply { gravity = Gravity.CENTER_VERTICAL }
        buttons.addView(Button(requireContext()).apply {
            text = "DAY / OCEAN"
            setOnClickListener {
                mCameraClient?.setBrightness(115)
                mCameraClient?.setContrast(145)
                mCameraClient?.setGain(0)
                status.text = "Day preset: protects bright water and clouds"
            }
        })
        buttons.addView(Button(requireContext()).apply {
            text = "NIGHT / STARS"
            setOnClickListener {
                mCameraClient?.setBrightness(150)
                mCameraClient?.setGain(180)
                mCameraClient?.setGamma(180)
                status.text = "Night preset: raise gain slowly to avoid noisy stars"
            }
        })
        panel.addView(buttons)
        return panel
    }

    private fun control(label: String, initial: Int, apply: (Int) -> Unit): View {
        val row = LinearLayout(requireContext()).apply {
            gravity = Gravity.CENTER_VERTICAL
            orientation = LinearLayout.HORIZONTAL
        }
        val title = TextView(requireContext()).apply {
            setTextColor(0xFFD6F6FF.toInt())
            textSize = 12f
            text = label
        }
        val slider = SeekBar(requireContext()).apply {
            max = 255
            progress = initial
            contentDescription = label
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(bar: SeekBar?, value: Int, byUser: Boolean) { if (byUser) apply(value) }
                override fun onStartTrackingTouch(bar: SeekBar?) = Unit
                override fun onStopTrackingTouch(bar: SeekBar?) = Unit
            })
        }
        row.addView(title, LinearLayout.LayoutParams(92, LinearLayout.LayoutParams.WRAP_CONTENT))
        row.addView(slider, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        return row
    }

    private fun makeReticle(): View = TextView(requireContext()).apply {
        text = "+\n  ───"
        gravity = Gravity.CENTER
        textSize = 30f
        setTextColor(0xAA72E3FF.toInt())
    }
}
