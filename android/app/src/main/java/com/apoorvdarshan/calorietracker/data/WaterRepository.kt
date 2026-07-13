package com.apoorvdarshan.calorietracker.data

import com.apoorvdarshan.calorietracker.models.WaterEntry
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import java.util.UUID

class WaterRepository(private val prefs: PreferencesStore) {
    val entries: Flow<List<WaterEntry>> = prefs.waterEntries.map { list -> list.sortedBy { it.date } }

    suspend fun add(entry: WaterEntry) {
        if (entry.milliliters <= 0) return
        prefs.setWaterEntries(prefs.waterEntries.first() + entry)
    }

    suspend fun delete(id: UUID) {
        prefs.setWaterEntries(prefs.waterEntries.first().filter { it.id != id })
    }
}
