package com.apoorvdarshan.calorietracker.models

import kotlinx.serialization.Serializable
import java.time.Instant
import java.util.UUID

@Serializable
data class WaterEntry(
    @Serializable(with = UuidSerializer::class)
    val id: UUID = UUID.randomUUID(),
    @Serializable(with = InstantSerializer::class)
    val date: Instant = Instant.now(),
    val milliliters: Int
)
