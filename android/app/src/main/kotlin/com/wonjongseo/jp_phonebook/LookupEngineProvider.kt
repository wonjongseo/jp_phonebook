package com.wonjongseo.jp_phonebook

import android.content.Context
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.Log
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.plugin.common.MethodChannel

object LookupEngineProvider {
    private const val ENGINE_ID = "lookup_engine"
    private const val CHANNEL_NAME = "incoming_lookup"

    private fun ensureLoaderInitialized(context: Context) {
        val loader: FlutterLoader = FlutterInjector.instance().flutterLoader()
        if (!loader.initialized()) {
            loader.startInitialization(context.applicationContext)
            loader.ensureInitializationComplete(context.applicationContext, null)
        }
    }

    fun ensureEngine(context: Context): FlutterEngine {
        val cache = FlutterEngineCache.getInstance()
        cache.get(ENGINE_ID)?.let { return it }

        ensureLoaderInitialized(context)

        val engine = FlutterEngine(context.applicationContext)
        // 커스텀 엔트리포인트: lookupMain
        val appBundlePath = FlutterInjector.instance().flutterLoader().findAppBundlePath()
        val entrypoint = DartExecutor.DartEntrypoint(appBundlePath, "lookupMain")
        engine.dartExecutor.executeDartEntrypoint(entrypoint)

        // 플러그인 등록 (path_provider 등)
        try { GeneratedPluginRegistrant.registerWith(engine) } catch (t: Throwable) {
            Log.w("LookupEngine", "Plugin registration skipped: $t")
        }

        cache.put(ENGINE_ID, engine)
        return engine
    }

    fun channel(context: Context): MethodChannel {
        val engine = ensureEngine(context)
        return MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME)
    }
}