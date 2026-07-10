package com.example.silent_sos.data

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query

@Dao
interface SosDao {
    @Insert
    fun insert(sos: SosEntity)

    @Query("SELECT * FROM sos_queue")
    fun getAll(): List<SosEntity>

    @Delete
    fun delete(sos: SosEntity)
}
