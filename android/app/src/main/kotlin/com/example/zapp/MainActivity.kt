package com.zapp.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.content.Context
import android.app.AppOpsManager
import android.text.TextUtils
import android.widget.Toast
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import com.zapp.app.services.ZappOverlayService
import com.zapp.app.services.ZappAccessibilityService

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.zapp.app/platform_features"
    private val EVENT_CHANNEL = "com.zapp.app/selected_text"
    private val OVERLAY_PERMISSION_REQUEST_CODE = 1234
    private val ACCESSIBILITY_PERMISSION_REQUEST_CODE = 1235
    
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up MethodChannel for platform-specific calls
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            handleMethodCall(call, result)
        }
        
        // Set up EventChannel for selected text streaming
        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
        eventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                ZappAccessibilityService.setEventSink(events)
            }
            
            override fun onCancel(arguments: Any?) {
                ZappAccessibilityService.setEventSink(null)
            }
        })
    }
    
    private fun handleMethodCall(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasOverlayPermission" -> {
                result.success(hasOverlayPermission())
            }
            
            "requestOverlayPermission" -> {
                requestOverlayPermission()
                result.success(true)
            }
            
            "hasAccessibilityPermission" -> {
                result.success(hasAccessibilityPermission())
            }
            
            "requestAccessibilityPermission" -> {
                requestAccessibilityPermission()
                result.success(true)
            }
            
            "startOverlayService" -> {
                val success = startOverlayService()
                result.success(success)
            }
            
            "stopOverlayService" -> {
                val success = stopOverlayService()
                result.success(success)
            }
            
            "isOverlayServiceRunning" -> {
                result.success(ZappOverlayService.isRunning())
            }
            
            "processAction" -> {
                val arguments = call.arguments as? Map<String, Any>
                val success = processAction(arguments)
                result.success(success)
            }
            
            "getDeviceInfo" -> {
                result.success(getDeviceInfo())
            }
            
            else -> {
                result.notImplemented()
            }
        }
    }
    
    /**
     * Check if SYSTEM_ALERT_WINDOW permission is granted
     */
    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            // Permission is automatically granted on API < 23
            true
        }
    }
    
    /**
     * Request SYSTEM_ALERT_WINDOW permission
     * Opens Android Settings for manual permission grant
     */
    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(this)) {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
                try {
                    startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST_CODE)
                } catch (e: Exception) {
                    // Handle devices that might not support this intent
                    Toast.makeText(
                        this,
                        "Please grant overlay permission in Settings > Apps > Special access",
                        Toast.LENGTH_LONG
                    ).show()
                }
            }
        }
    }
    
    /**
     * Check if Accessibility Service is enabled
     * Uses AppOpsManager to check accessibility service status
     */
    private fun hasAccessibilityPermission(): Boolean {
        return isAccessibilityServiceEnabled(this, ZappAccessibilityService::class.java)
    }
    
    /**
     * Request Accessibility Service permission
     * Opens Android Accessibility Settings
     */
    private fun requestAccessibilityPermission() {
        if (!hasAccessibilityPermission()) {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            try {
                startActivityForResult(intent, ACCESSIBILITY_PERMISSION_REQUEST_CODE)
                Toast.makeText(
                    this,
                    "Please enable Zapp Accessibility Service in Downloaded apps section",
                    Toast.LENGTH_LONG
                ).show()
            } catch (e: Exception) {
                Toast.makeText(
                    this,
                    "Please enable Accessibility Service in Settings",
                    Toast.LENGTH_LONG
                ).show()
            }
        }
    }
    
    /**
     * Start the overlay service
     */
    private fun startOverlayService(): Boolean {
        return if (hasOverlayPermission()) {
            val intent = Intent(this, ZappOverlayService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            true
        } else {
            false
        }
    }
    
    /**
     * Stop the overlay service
     */
    private fun stopOverlayService(): Boolean {
        val intent = Intent(this, ZappOverlayService::class.java)
        stopService(intent)
        return true
    }
    
    /**
     * Process action with selected content
     */
    private fun processAction(arguments: Map<String, Any>?): Boolean {
        if (arguments == null) return false
        
        val selectedContent = arguments["selectedContent"] as? String ?: ""
        val userIntent = arguments["userIntent"] as? String ?: ""
        val action = arguments["action"] as? String ?: ""
        
        // Log the action for debugging
        println("=== ZAPP ACTION EXECUTION ===")
        println("Selected Content: $selectedContent")
        println("User Intent: $userIntent")
        println("Chosen Action: $action")
        println("Timestamp: ${System.currentTimeMillis()}")
        println("=============================")
        
        // TODO: Implement actual action processing
        // This would include:
        // - Encrypting content with PGP
        // - Sending to linked devices
        // - Executing specific actions (copy, search, etc.)
        
        return true
    }
    
    /**
     * Get device information for fingerprinting
     */
    private fun getDeviceInfo(): Map<String, String> {
        return mapOf(
            "deviceModel" to Build.MODEL,
            "deviceManufacturer" to Build.MANUFACTURER,
            "androidVersion" to Build.VERSION.RELEASE,
            "sdkVersion" to Build.VERSION.SDK_INT.toString(),
            "packageName" to packageName
        )
    }
    
    /**
     * Handle activity results from permission requests
     */
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        when (requestCode) {
            OVERLAY_PERMISSION_REQUEST_CODE -> {
                if (hasOverlayPermission()) {
                    Toast.makeText(this, "Overlay permission granted!", Toast.LENGTH_SHORT).show()
                    // Notify Flutter that permission status changed
                    methodChannel?.invokeMethod("onOverlayPermissionChanged", true)
                } else {
                    Toast.makeText(this, "Overlay permission is required for Zapp to work", Toast.LENGTH_LONG).show()
                }
            }
            
            ACCESSIBILITY_PERMISSION_REQUEST_CODE -> {
                if (hasAccessibilityPermission()) {
                    Toast.makeText(this, "Accessibility service enabled!", Toast.LENGTH_SHORT).show()
                    // Notify Flutter that permission status changed
                    methodChannel?.invokeMethod("onAccessibilityPermissionChanged", true)
                } else {
                    Toast.makeText(this, "Accessibility service is required to capture selected text", Toast.LENGTH_LONG).show()
                }
            }
        }
    }
    
    /**
     * Utility function to check if accessibility service is enabled
     */
    private fun isAccessibilityServiceEnabled(context: Context, service: Class<*>): Boolean {
        val accessibilityManager = context.getSystemService(Context.ACCESSIBILITY_SERVICE)
        val settingValue = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        )
        
        if (settingValue != null) {
            val splitter = TextUtils.SimpleStringSplitter(':')
            splitter.setString(settingValue)
            
            while (splitter.hasNext()) {
                val accessibilityService = splitter.next()
                if (accessibilityService.equals("${context.packageName}/${service.name}", ignoreCase = true)) {
                    return true
                }
            }
        }
        
        return false
    }
    
    override fun onDestroy() {
        super.onDestroy()
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
    }
}
