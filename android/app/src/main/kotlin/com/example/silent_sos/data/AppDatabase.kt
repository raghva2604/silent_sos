package com.example.silent_sos.data

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(entities = [SosEntity::class], version = 1)
abstract class AppDatabase : RoomDatabase() {
    abstract fun sosDao(): SosDao
}
