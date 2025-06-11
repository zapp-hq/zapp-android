package com.zapp.app.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageButton
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import com.zapp.app.MainActivity
import com.zapp.app.R

class ZappOverlayService : Service() {
    
    companion object {
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "ZappOverlayChannel"
        private var isServiceRunning = false
        private var serviceInstance: ZappOverlayService? = null
        
        fun isRunning(): Boolean = isServiceRunning
        
        fun getInstance(): ZappOverlayService? = serviceInstance
    }
    
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    private var flutterEngine: FlutterEngine? = null
    private var methodChannel: MethodChannel? = null
    
    // Touch handling variables for dragging
    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    
    override fun onCreate() {
        super.onCreate()
        serviceInstance = this
        isServiceRunning = true
        
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        initializeFlutterEngine()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (hasOverlayPermission()) {
            createOverlayView()
            showNotification()
        } else {
            stopSelf()
        }
        
        return START_STICKY // Restart service if killed
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }
    
    private fun initializeFlutterEngine() {
        try {
            flutterEngine = FlutterEngine(this)
            
            // Initialize Flutter engine with default entry point
            flutterEngine?.dartExecutor?.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )
            
            // Set up MethodChannel for overlay communication
            methodChannel = MethodChannel(
                flutterEngine!!.dartExecutor.binaryMessenger,
                "com.zapp.app/overlay_communication"
            )
            
            methodChannel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    "hideOverlay" -> {
                        hideOverlay()
                        result.success(true)
                    }
                    "openActionSelection" -> {
                        openActionSelectionScreen()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        } catch (e: Exception) {
            // Handle Flutter engine initialization failure
            println("Failed to initialize Flutter engine: ${e.message}")
        }
    }
    
    private fun createOverlayView() {
        if (overlayView != null) return
        
        try {
            // Create overlay button layout
            overlayView = createOverlayButton()
            
            // Set up layout parameters for overlay
            layoutParams = createLayoutParams()
            
            // Set up touch listener for dragging and clicking
            overlayView?.setOnTouchListener(createTouchListener())
            
            // Add view to window manager
            windowManager?.addView(overlayView, layoutParams)
            
        } catch (e: Exception) {
            println("Error creating overlay view: ${e.message}")
        }
    }
    
    private fun createOverlayButton(): View {
        // Create a custom overlay button view
        // In a real implementation, you might inflate a custom layout
        val button = ImageButton(this)
        
        // Set button properties
        button.setImageResource(android.R.drawable.ic_menu_send) // Use built-in icon
        button.background = getDrawable(android.R.drawable.btn_default_small)
        
        // Set button dimensions
        val size = (56 * resources.displayMetrics.density).toInt() // 56dp in pixels
        button.layoutParams = WindowManager.LayoutParams(size, size)
        
        return button
    }
    
    private fun createLayoutParams(): WindowManager.LayoutParams {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        
        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 100
            y = 100
        }
    }
    
    private fun createTouchListener(): View.OnTouchListener {
        return View.OnTouchListener { view, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    // Store initial position for dragging
                    initialX = layoutParams?.x ?: 0
                    initialY = layoutParams?.y ?: 0
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    true
                }
                
                MotionEvent.ACTION_UP -> {
                    // Check if this was a click (minimal movement) or drag
                    val xDiff = Math.abs(event.rawX - initialTouchX)
                    val yDiff = Math.abs(event.rawY - initialTouchY)
                    
                    if (xDiff < 10 && yDiff < 10) {
                        // This was a click, not a drag
                        handleOverlayButtonClick()
                    }
                    
                    // Snap to edge of screen
                    snapToEdge()
                    true
                }
                
                MotionEvent.ACTION_MOVE -> {
                    // Update overlay position during drag
                    layoutParams?.x = initialX + (event.rawX - initialTouchX).toInt()
                    layoutParams?.y = initialY + (event.rawY - initialTouchY).toInt()
                    
                    // Update view position
                    windowManager?.updateViewLayout(overlayView, layoutParams)
                    true
                }
                
                else -> false
            }
        }
    }
    
    private fun handleOverlayButtonClick() {
        // Handle overlay button tap - open Action Selection Screen
        openActionSelectionScreen()
        
        // Optionally hide overlay temporarily
        // hideOverlay()
        
        // Log action for debugging
        println("Zapp overlay button clicked")
        
        // Notify Flutter about the click
        methodChannel?.invokeMethod("onOverlayButtonClicked", null)
    }
    
    private fun openActionSelectionScreen() {
        try {
            // Create intent to open Flutter Activity with Action Selection Screen
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("openActionSelection", true)
            }
            startActivity(intent)
        } catch (e: Exception) {
            println("Error opening action selection screen: ${e.message}")
        }
    }
    
    private fun snapToEdge() {
        if (layoutParams == null || windowManager == null) return
        
        try {
            val displayMetrics = resources.displayMetrics
            val screenWidth = displayMetrics.widthPixels
            val currentX = layoutParams!!.x
            
            // Snap to nearest edge (left or right)
            layoutParams!!.x = if (currentX < screenWidth / 2) {
                0 // Snap to left edge
            } else {
                screenWidth - (overlayView?.width ?: 0) // Snap to right edge
            }
            
            // Ensure Y position is within screen bounds
            val screenHeight = displayMetrics.heightPixels
            val statusBarHeight = getStatusBarHeight()
            val navigationBarHeight = getNavigationBarHeight()
            
            layoutParams!!.y = layoutParams!!.y.coerceIn(
                statusBarHeight,
                screenHeight - navigationBarHeight - (overlayView?.height ?: 0)
            )
            
            windowManager?.updateViewLayout(overlayView, layoutParams)
        } catch (e: Exception) {
            println("Error snapping to edge: ${e.message}")
        }
    }
    
    private fun getStatusBarHeight(): Int {
        val resourceId = resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (resourceId > 0) resources.getDimensionPixelSize(resourceId) else 0
    }
    
    private fun getNavigationBarHeight(): Int {
        val resourceId = resources.getIdentifier("navigation_bar_height", "dimen", "android")
        return if (resourceId > 0) resources.getDimensionPixelSize(resourceId) else 0
    }
    
    private fun hideOverlay() {
        try {
            if (overlayView != null) {
                windowManager?.removeView(overlayView)
                overlayView = null
            }
        } catch (e: Exception) {
            println("Error hiding overlay: ${e.message}")
        }
    }
    
    private fun showOverlay() {
        if (overlayView == null && hasOverlayPermission()) {
            createOverlayView()
        }
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Zapp Overlay Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Notification for Zapp overlay service"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun showNotification() {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Zapp Overlay Active")
            .setContentText("Tap to open Zapp or use the floating button")
            .setSmallIcon(android.R.drawable.ic_menu_send) // Use built-in icon
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
        
        startForeground(NOTIFICATION_ID, notification)
    }
    
    override fun onDestroy() {
        super.onDestroy()
        
        isServiceRunning = false
        serviceInstance = null
        
        try {
            hideOverlay()
            flutterEngine?.destroy()
            methodChannel?.setMethodCallHandler(null)
        } catch (e: Exception) {
            println("Error in onDestroy: ${e.message}")
        }
    }
    
    // Public methods for external control
    fun toggleOverlay() {
        if (overlayView != null) {
            hideOverlay()
        } else {
            showOverlay()
        }
    }
    
    fun updateOverlayPosition(x: Int, y: Int) {
        if (layoutParams != null && windowManager != null) {
            layoutParams!!.x = x
            layoutParams!!.y = y
            windowManager?.updateViewLayout(overlayView, layoutParams)
        }
    }
}
