package com.zapp.app.services

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.util.Log
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.ConcurrentHashMap

class ZappAccessibilityService : AccessibilityService() {
    
    companion object {
        private const val TAG = "ZappAccessibilityService"
        private var serviceInstance: ZappAccessibilityService? = null
        private var eventSink: EventChannel.EventSink? = null
        private val capturedTextHistory = ConcurrentHashMap<String, Long>()
        private const val TEXT_HISTORY_DURATION = 5000L // 5 seconds
        
        fun setEventSink(sink: EventChannel.EventSink?) {
            eventSink = sink
        }
        
        fun getInstance(): ZappAccessibilityService? = serviceInstance
        
        fun isServiceEnabled(): Boolean = serviceInstance != null
    }
    
    private var isCapturingEnabled = false
    private var lastCapturedText = ""
    private var lastCaptureTime = 0L
    
    override fun onCreate() {
        super.onCreate()
        serviceInstance = this
        Log.d(TAG, "ZappAccessibilityService created")
    }
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "ZappAccessibilityService connected")
        
        // Configure the service dynamically if needed
        // val config = AccessibilityServiceInfo()
        // config.eventTypes = AccessibilityEvent.TYPE_VIEW_TEXT_SELECTION_CHANGED or 
        //                     AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED
        // config.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        // config.flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
        // serviceInfo = config
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || !isCapturingEnabled) return
        
        try {
            when (event.eventType) {
                AccessibilityEvent.TYPE_VIEW_TEXT_SELECTION_CHANGED -> {
                    handleTextSelectionChanged(event)
                }
                
                AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> {
                    handleTextChanged(event)
                }
                
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                    handleWindowContentChanged(event)
                }
                
                AccessibilityEvent.TYPE_VIEW_FOCUSED -> {
                    handleViewFocused(event)
                }
                
                AccessibilityEvent.TYPE_VIEW_CLICKED -> {
                    handleViewClicked(event)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing accessibility event", e)
        }
    }
    
    private fun handleTextSelectionChanged(event: AccessibilityEvent) {
        val source = event.source ?: return
        val packageName = event.packageName?.toString() ?: ""
        
        // Skip our own app to avoid loops
        if (packageName == this.packageName) return
        
        try {
            val selectedText = extractSelectedText(source)
            if (selectedText.isNotEmpty() && selectedText != lastCapturedText) {
                
                // Check if this text was recently captured to avoid duplicates
                if (isRecentlyCaptured(selectedText)) return
                
                lastCapturedText = selectedText
                lastCaptureTime = System.currentTimeMillis()
                
                // Add to history
                capturedTextHistory[selectedText] = lastCaptureTime
                cleanupOldHistory()
                
                Log.d(TAG, "Text selection captured from $packageName: $selectedText")
                
                // Send to Flutter via EventChannel
                sendTextToFlutter(selectedText, packageName)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error extracting selected text", e)
        } finally {
            source.recycle()
        }
    }
    
    private fun handleTextChanged(event: AccessibilityEvent) {
        // Handle text changes in input fields
        if (event.text?.isNotEmpty() == true) {
            val changedText = event.text.joinToString(" ")
            Log.d(TAG, "Text changed: $changedText")
            
            // Only capture if it's a significant change (more than 3 characters)
            if (changedText.length > 3 && changedText != lastCapturedText) {
                val packageName = event.packageName?.toString() ?: ""
                sendTextToFlutter(changedText, packageName)
            }
        }
    }
    
    private fun handleWindowContentChanged(event: AccessibilityEvent) {
        // Handle window content changes that might indicate new selectable content
        if (event.contentChangeTypes and AccessibilityEvent.CONTENT_CHANGE_TYPE_TEXT != 0) {
            Log.d(TAG, "Window content changed with text changes")
        }
    }
    
    private fun handleViewFocused(event: AccessibilityEvent) {
        // Handle view focus changes
        val source = event.source
        if (source != null) {
            try {
                val focusedText = source.text?.toString() ?: ""
                if (focusedText.isNotEmpty()) {
                    Log.d(TAG, "View focused with text: $focusedText")
                }
            } finally {
                source.recycle()
            }
        }
    }
    
    private fun handleViewClicked(event: AccessibilityEvent) {
        // Handle view clicks that might reveal selectable content
        Log.d(TAG, "View clicked in ${event.packageName}")
    }
    
    private fun extractSelectedText(nodeInfo: AccessibilityNodeInfo): String {
        val selectedText = StringBuilder()
        
        try {
            // Method 1: Check if node has selected text directly
            val nodeText = nodeInfo.text?.toString() ?: ""
            if (nodeText.isNotEmpty()) {
                selectedText.append(nodeText)
            }
            
            // Method 2: Traverse child nodes for selected text
            for (i in 0 until nodeInfo.childCount) {
                val child = nodeInfo.getChild(i)
                if (child != null) {
                    try {
                        val childText = child.text?.toString() ?: ""
                        if (childText.isNotEmpty() && child.isSelected) {
                            if (selectedText.isNotEmpty()) selectedText.append(" ")
                            selectedText.append(childText)
                        }
                        
                        // Recursive check for nested selections
                        val nestedText = extractSelectedText(child)
                        if (nestedText.isNotEmpty()) {
                            if (selectedText.isNotEmpty()) selectedText.append(" ")
                            selectedText.append(nestedText)
                        }
                    } finally {
                        child.recycle()
                    }
                }
            }
            
            // Method 3: Check content description
            val contentDesc = nodeInfo.contentDescription?.toString() ?: ""
            if (contentDesc.isNotEmpty() && selectedText.isEmpty()) {
                selectedText.append(contentDesc)
            }
            
            // Method 4: Try to get text from focused nodes
            if (selectedText.isEmpty() && nodeInfo.isFocused) {
                val focusedText = nodeInfo.text?.toString() ?: ""
                if (focusedText.isNotEmpty()) {
                    selectedText.append(focusedText)
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error extracting text from node", e)
        }
        
        return selectedText.toString().trim()
    }
    
    private fun isRecentlyCaptured(text: String): Boolean {
        val lastTime = capturedTextHistory[text] ?: return false
        return (System.currentTimeMillis() - lastTime) < TEXT_HISTORY_DURATION
    }
    
    private fun cleanupOldHistory() {
        val currentTime = System.currentTimeMillis()
        val iterator = capturedTextHistory.entries.iterator()
        
        while (iterator.hasNext()) {
            val entry = iterator.next()
            if (currentTime - entry.value > TEXT_HISTORY_DURATION) {
                iterator.remove()
            }
        }
    }
    
    private fun sendTextToFlutter(text: String, packageName: String) {
        try {
            eventSink?.success(mapOf(
                "text" to text,
                "packageName" to packageName,
                "timestamp" to System.currentTimeMillis()
            ))
            
            Log.d(TAG, "Sent text to Flutter: $text from $packageName")
        } catch (e: Exception) {
            Log.e(TAG, "Error sending text to Flutter", e)
        }
    }
    
    override fun onInterrupt() {
        Log.d(TAG, "ZappAccessibilityService interrupted")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        serviceInstance = null
        eventSink = null
        capturedTextHistory.clear()
        Log.d(TAG, "ZappAccessibilityService destroyed")
    }
    
    // Public methods for external control
    fun enableTextCapturing(enable: Boolean) {
        isCapturingEnabled = enable
        Log.d(TAG, "Text capturing ${if (enable) "enabled" else "disabled"}")
    }
    
    fun isCapturingEnabled(): Boolean = isCapturingEnabled
    
    fun getLastCapturedText(): String = lastCapturedText
    
    fun getCapturedTextHistory(): Map<String, Long> = capturedTextHistory.toMap()
    
    // Advanced text extraction methods
    fun findSelectableNodes(): List<AccessibilityNodeInfo> {
        val selectableNodes = mutableListOf<AccessibilityNodeInfo>()
        val rootNode = rootInActiveWindow
        
        if (rootNode != null) {
            try {
                findSelectableNodesRecursive(rootNode, selectableNodes)
            } finally {
                rootNode.recycle()
            }
        }
        
        return selectableNodes
    }
    
    private fun findSelectableNodesRecursive(node: AccessibilityNodeInfo, result: MutableList<AccessibilityNodeInfo>) {
        try {
            // Check if node contains selectable text
            if (node.text != null && node.text.isNotEmpty()) {
                if (node.isSelected || node.isFocusable || node.isClickable) {
                    result.add(node)
                }
            }
            
            // Recursively check children
            for (i in 0 until node.childCount) {
                val child = node.getChild(i)
                if (child != null) {
                    try {
                        findSelectableNodesRecursive(child, result)
                    } finally {
                        child.recycle()
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error finding selectable nodes", e)
        }
    }
    
    // Method to perform actions on accessibility nodes
    fun performNodeAction(nodeId: Int, action: Int): Boolean {
        try {
            val rootNode = rootInActiveWindow ?: return false
            val targetNode = findNodeById(rootNode, nodeId)
            
            return if (targetNode != null) {
                try {
                    targetNode.performAction(action)
                } finally {
                    targetNode.recycle()
                }
            } else {
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error performing node action", e)
            return false
        }
    }
    
    private fun findNodeById(root: AccessibilityNodeInfo, targetId: Int): AccessibilityNodeInfo? {
        try {
            if (root.hashCode() == targetId) {
                return root
            }
            
            for (i in 0 until root.childCount) {
                val child = root.getChild(i)
                if (child != null) {
                    try {
                        val found = findNodeById(child, targetId)
                        if (found != null) return found
                    } finally {
                        child.recycle()
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error finding node by ID", e)
        }
        
        return null
    }
}
