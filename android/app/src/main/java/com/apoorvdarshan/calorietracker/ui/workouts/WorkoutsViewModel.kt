package com.apoorvdarshan.calorietracker.ui.workouts

import android.app.Application
import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import com.apoorvdarshan.calorietracker.data.ExerciseSort

/**
 * Holds the Workouts library filter/sort/search state, mirroring the iOS browser.
 * Persisted to SharedPreferences (the analog of iOS's ExerciseFilterStateStore) so
 * it survives process death, not just tab switches.
 */
class WorkoutsViewModel(app: Application) : AndroidViewModel(app) {
    private val prefs = app.getSharedPreferences("fudai_workouts", Context.MODE_PRIVATE)

    private val _search = mutableStateOf(prefs.getString(K_SEARCH, "") ?: "")
    var search: String
        get() = _search.value
        set(v) { _search.value = v; prefs.edit().putString(K_SEARCH, v).apply() }

    private val _levels = mutableStateOf(loadSet(K_LEVELS))
    var levels: Set<String>
        get() = _levels.value
        set(v) { _levels.value = v; saveSet(K_LEVELS, v) }

    private val _equipment = mutableStateOf(loadSet(K_EQUIPMENT))
    var equipment: Set<String>
        get() = _equipment.value
        set(v) { _equipment.value = v; saveSet(K_EQUIPMENT, v) }

    private val _primary = mutableStateOf(loadSet(K_PRIMARY))
    var primaryMuscles: Set<String>
        get() = _primary.value
        set(v) { _primary.value = v; saveSet(K_PRIMARY, v) }

    private val _secondary = mutableStateOf(loadSet(K_SECONDARY))
    var secondaryMuscles: Set<String>
        get() = _secondary.value
        set(v) { _secondary.value = v; saveSet(K_SECONDARY, v) }

    private val _forces = mutableStateOf(loadSet(K_FORCES))
    var forces: Set<String>
        get() = _forces.value
        set(v) { _forces.value = v; saveSet(K_FORCES, v) }

    private val _mechanics = mutableStateOf(loadSet(K_MECHANICS))
    var mechanics: Set<String>
        get() = _mechanics.value
        set(v) { _mechanics.value = v; saveSet(K_MECHANICS, v) }

    private val _categories = mutableStateOf(loadSet(K_CATEGORIES))
    var categories: Set<String>
        get() = _categories.value
        set(v) { _categories.value = v; saveSet(K_CATEGORIES, v) }

    private val _sort = mutableStateOf(
        runCatching { ExerciseSort.valueOf(prefs.getString(K_SORT, "") ?: "") }.getOrDefault(ExerciseSort.NAME)
    )
    var sort: ExerciseSort
        get() = _sort.value
        set(v) { _sort.value = v; prefs.edit().putString(K_SORT, v.name).apply() }

    /** Currently open exercise (by id), or null for the list. Not persisted. */
    var openExerciseId by mutableStateOf<String?>(null)

    val hasActiveFilters: Boolean
        get() = search.isNotEmpty() || levels.isNotEmpty() || equipment.isNotEmpty() ||
            primaryMuscles.isNotEmpty() || secondaryMuscles.isNotEmpty() || forces.isNotEmpty() ||
            mechanics.isNotEmpty() || categories.isNotEmpty() || sort != ExerciseSort.NAME

    fun reset() {
        search = ""
        levels = emptySet()
        equipment = emptySet()
        primaryMuscles = emptySet()
        secondaryMuscles = emptySet()
        forces = emptySet()
        mechanics = emptySet()
        categories = emptySet()
        sort = ExerciseSort.NAME
    }

    private fun loadSet(key: String): Set<String> = prefs.getStringSet(key, emptySet())?.toSet() ?: emptySet()
    private fun saveSet(key: String, v: Set<String>) { prefs.edit().putStringSet(key, v).apply() }

    private companion object {
        const val K_SEARCH = "search"
        const val K_LEVELS = "levels"
        const val K_EQUIPMENT = "equipment"
        const val K_PRIMARY = "primary"
        const val K_SECONDARY = "secondary"
        const val K_FORCES = "forces"
        const val K_MECHANICS = "mechanics"
        const val K_CATEGORIES = "categories"
        const val K_SORT = "sort"
    }
}
