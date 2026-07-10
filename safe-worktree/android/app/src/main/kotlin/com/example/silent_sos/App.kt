package com.example.silent_sos

import android.app.Application
import androidx.room.Room
import com.example.silent_sos.data.AppDatabase

class App : Application() {
    companion object {
        lateinit var instance: App
        lateinit var db: AppDatabase
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        db = Room.databaseBuilder(applicationContext, AppDatabase::class.java, "sos_db").build()
    }
}
