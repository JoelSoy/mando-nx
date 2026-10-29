package org.nxnative.remote_pad

import android.os.Bundle
import android.os.Build
import android.os.Vibrator
import android.os.VibrationEffect
import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"mando/native").setMethodCallHandler { call,result ->
            when(call.method) {
                "demo" -> result.success(false)
                "rumble" -> {
                    val v=getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                    v.cancel()
                    val i=(call.argument<Number>("i")?.toDouble() ?: 0.0).coerceIn(0.0,1.0)
                    val ms=(call.argument<Number>("ms")?.toLong() ?: 0).coerceIn(0,1000)
                    if(i>0 && ms>0 && v.hasVibrator()) {
                        if(Build.VERSION.SDK_INT>=26) v.vibrate(VibrationEffect.createOneShot(ms,(i*255).toInt().coerceIn(1,255)))
                        else { @Suppress("DEPRECATION") v.vibrate(ms) }
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A controller: the screen must not dim or lock while playing
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}
