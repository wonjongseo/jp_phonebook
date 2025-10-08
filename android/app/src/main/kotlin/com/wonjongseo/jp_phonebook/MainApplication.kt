package com.wonjongseo.jp_phonebook


import android.app.Application
import android.content.Context
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterLoader

class MainApplication : Application() {

    companion object {
        @Volatile
        private var backgroundEngine: FlutterEngine? = null


        @Synchronized
        fun engine(context: Context): FlutterEngine {
            backgroundEngine?.let { return it }

            val appCtx = context.applicationContext
            val loader: FlutterLoader = FlutterInjector.instance().flutterLoader()

            if (!loader.initialized()) {
                loader.startInitialization(appCtx)
                loader.ensureInitializationComplete(appCtx, null)
            }

            val engine = FlutterEngine(appCtx)
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(),
                    "overlayDispatcher" // lib/main.dart @pragma('vm:entry-point')
                )
            )

            backgroundEngine = engine
            return engine
        }
    }

    override fun onCreate() {
        super.onCreate()
        // engine(this)
    }
}
