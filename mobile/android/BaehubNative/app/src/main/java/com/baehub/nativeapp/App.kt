package com.baehub.nativeapp

import android.app.Application
import dev.hotwire.navigation.Hotwire
import dev.hotwire.navigation.config.PathConfiguration

class App : Application() {
  // Emulator: http://10.0.2.2:3000
  // Device:   http://<your-lan-ip>:3000
  private val ROOT_URL = "http://10.0.2.2:3000"

  override fun onCreate() {
    super.onCreate()

    Hotwire.loadPathConfiguration(
      context = this,
      location = PathConfiguration.Location(
        assetFilePath = "json/configuration.json",
        remoteFileUrl = "$ROOT_URL/configurations/android_v1.json"
      )
    )
  }
}
