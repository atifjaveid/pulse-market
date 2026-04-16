package com.example.pulsemarket

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

class App : Application() {
    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

            nm.createNotificationChannel(
                NotificationChannel(
                    "pulse_market_bg",
                    "Live Price Tracking",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Keeps live market prices up to date."
                }
            )

            nm.createNotificationChannel(
                NotificationChannel(
                    "price_alerts",
                    "Price Alerts",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Alerts when a price target is hit."
                }
            )
        }
    }
}