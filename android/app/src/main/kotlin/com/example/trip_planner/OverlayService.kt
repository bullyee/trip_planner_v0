package com.example.trip_planner

import android.app.Service
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView

class OverlayService : Service() {
    private val TAG = "AnimeOverlay"
    private var windowManager: WindowManager? = null
    private var overlayView: ImageView? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val imagePath = intent?.getStringExtra("imagePath")
        if (imagePath == null) {
            Log.e(TAG, "No image path provided")
            stopSelf()
            return START_NOT_STICKY
        }

        showOverlay(imagePath)
        return START_NOT_STICKY
    }

    private fun showOverlay(imagePath: String) {
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        // Create ImageView with the reference image
        val imageView = ImageView(this).apply {
            val bitmap = BitmapFactory.decodeFile(imagePath)
            if (bitmap != null) {
                setImageBitmap(bitmap)
                scaleType = ImageView.ScaleType.FIT_CENTER
                alpha = 0.6f
            } else {
                Log.e(TAG, "Failed to decode image: $imagePath")
                stopSelf()
                return
            }
        }

        // Window layout params — floating overlay
        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            360,  // width in px
            480,  // height in px
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = 24
            y = 120
        }

        // Make it draggable
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f

        imageView.setOnTouchListener { view, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    params.x = initialX - (event.rawX - initialTouchX).toInt()
                    params.y = initialY + (event.rawY - initialTouchY).toInt()
                    windowManager?.updateViewLayout(view, params)
                    true
                }
                else -> false
            }
        }

        overlayView = imageView

        try {
            windowManager?.addView(imageView, params)
            Log.d(TAG, "Overlay added successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add overlay: ${e.message}", e)
            stopSelf()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            overlayView?.let { windowManager?.removeView(it) }
        } catch (e: Exception) {
            Log.e(TAG, "Error removing overlay: ${e.message}")
        }
        overlayView = null
        windowManager = null
        Log.d(TAG, "Overlay removed")
    }
}
