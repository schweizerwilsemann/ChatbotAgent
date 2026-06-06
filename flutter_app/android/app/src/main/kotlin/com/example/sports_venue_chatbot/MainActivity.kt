package com.example.sports_venue_chatbot

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "sports_venue_chatbot/notifications"
    private val vnpayChannelName = "sports_venue_chatbot/vnpay"
    private val notificationChannelId = "operations_notifications"
    private val notificationPermissionRequestCode = 1701

    private var vnpayResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ensureNotificationChannel()
        requestNotificationPermissionIfNeeded()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showOperationNotification" -> {
                        val title = call.argument<String>("title") ?: "Thông báo mới"
                        val body = call.argument<String>("body") ?: ""
                        Log.d("MainActivity", "showOperationNotification called: title=$title, body=$body")
                        showOperationNotification(title, body)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, vnpayChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openVnpaySdk" -> {
                        val paymentUrl = call.argument<String>("paymentUrl") ?: ""
                        val tmnCode = call.argument<String>("tmnCode") ?: ""
                        val isSandbox = call.argument<Boolean>("isSandbox") ?: true
                        openVnpaySdk(paymentUrl, tmnCode, isSandbox, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun openVnpaySdk(
        paymentUrl: String,
        tmnCode: String,
        isSandbox: Boolean,
        result: MethodChannel.Result
    ) {
        vnpayResult = result

        try {
            val callbackClass = Class.forName("com.vnpay.authentication.VNP_SdkCompletedCallback")
            val activityClass = Class.forName("com.vnpay.authentication.VNP_AuthenticationActivity")

            val callbackInstance = java.lang.reflect.Proxy.newProxyInstance(
                callbackClass.classLoader,
                arrayOf(callbackClass)
            ) { _, method, args ->
                if (method.name == "sdkAction") {
                    val action = args[0] as String
                    Log.wtf("VNPay", "action: $action")
                    val res = vnpayResult ?: return@newProxyInstance null
                    vnpayResult = null

                    when (action) {
                        "SuccessBackAction" -> res.success("success")
                        "FaildBackAction" -> res.success("failed")
                        "AppBackAction" -> res.success("cancelled")
                        "WebBackAction" -> res.success("cancelled")
                        "CallMobileBankingApp" -> res.success("processing")
                        else -> res.success("unknown")
                    }
                }
                null
            }

            val setCallbackMethod = activityClass.getMethod("setSdkCompletedCallback", callbackClass)
            setCallbackMethod.invoke(null, callbackInstance)

            val intent = Intent(this, activityClass)
            intent.putExtra("url", paymentUrl)
            intent.putExtra("tmn_code", tmnCode)
            intent.putExtra("scheme", "sportsvenuechatbot")
            intent.putExtra("is_sandbox", isSandbox)
            startActivity(intent)

        } catch (e: Exception) {
            Log.e("VNPay", "Error opening VNPay SDK", e)
            vnpayResult?.error("VNPAY_ERROR", e.message, null)
            vnpayResult = null
        }
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            notificationChannelId,
            "Thông báo vận hành",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Thông báo đặt sân, đặt món và yêu cầu hỗ trợ"
            enableLights(true)
            lightColor = Color.RED
            enableVibration(true)
        }
        manager.createNotificationChannel(channel)
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            notificationPermissionRequestCode
        )
    }

    private fun showOperationNotification(title: String, body: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            Log.w("MainActivity", "POST_NOTIFICATIONS permission not granted")
            return
        }

        Log.d("MainActivity", "Building notification: title=$title")
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(this, 0, intent, flags)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, notificationChannelId)
        } else {
            Notification.Builder(this)
        }

        val notification = builder
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setWhen(System.currentTimeMillis())
            .setShowWhen(true)
            .build()

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notifId = System.currentTimeMillis().toInt()
        manager.notify(notifId, notification)
        Log.d("MainActivity", "Notification shown with id=$notifId")
    }
}
