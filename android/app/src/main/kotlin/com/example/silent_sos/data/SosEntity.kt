package com.example.silent_sos.data

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "sos_queue")
data class SosEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,

    val payload: String,
    val createdAt: Long = System.currentTimeMillis()
)
