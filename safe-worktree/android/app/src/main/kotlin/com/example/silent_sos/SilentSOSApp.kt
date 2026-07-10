package com.example.silent_sos

import android.app.Application
import androidx.room.Room
import com.example.silent_sos.data.AppDatabase

class SilentSOSApp : Application() {
    companion object {
        lateinit var instance: SilentSOSApp
            private set

        lateinit var database: AppDatabase
            private set
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        database = Room.databaseBuilder(
            applicationContext,
            AppDatabase::class.java,
            "sos_db"
        ).fallbackToDestructiveMigration().build()
    }
}
