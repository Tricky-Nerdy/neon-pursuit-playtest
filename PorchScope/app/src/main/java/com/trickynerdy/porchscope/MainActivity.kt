package com.trickynerdy.porchscope

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat

class MainActivity : AppCompatActivity() {
    private lateinit var locationReadout: TextView

    private val requestLocation = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { updateLocation() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val root = FrameLayout(this).apply { setBackgroundColor(0xFF050A0D.toInt()) }
        val cameraHost = FrameLayout(this).apply { id = View.generateViewId() }
        root.addView(cameraHost, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))

        locationReadout = TextView(this).apply {
            setTextColor(0xFFD6F6FF.toInt())
            textSize = 13f
            setPadding(24, 20, 24, 20)
            text = "GPS: waiting…\nHeading: calibrating…"
            setBackgroundColor(0x99050A0D.toInt())
        }
        root.addView(locationReadout, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.TOP or Gravity.START
        ))

        setContentView(root)
        supportFragmentManager.beginTransaction()
            .replace(cameraHost.id, PorchCameraFragment())
            .commit()

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
            updateLocation()
        } else {
            requestLocation.launch(arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            ))
        }
    }

    private fun updateLocation() {
        val manager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val location: Location? = runCatching {
            manager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                ?: manager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
        }.getOrNull()

        locationReadout.text = if (location == null) {
            "GPS: unavailable\nPlug in webcam, then use the controls below."
        } else {
            "GPS: %.5f, %.5f\nAltitude: %.0f m\nLandscape / Sky mode".format(
                location.latitude, location.longitude, location.altitude
            )
        }
    }
}
