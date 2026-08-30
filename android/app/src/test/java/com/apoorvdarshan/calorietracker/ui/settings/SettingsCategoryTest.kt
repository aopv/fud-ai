package com.apoorvdarshan.calorietracker.ui.settings

import com.apoorvdarshan.calorietracker.ui.about.AboutSettingsCategory
import org.junit.Assert.assertEquals
import org.junit.Test

class SettingsCategoryTest {
    @Test
    fun hubKeepsEveryFocusedCategory() {
        assertEquals(11, SettingsCategory.entries.size)
        assertEquals(11, SettingsCategory.entries.map { it.titleRes }.toSet().size)
    }

    @Test
    fun aboutHubKeepsEveryFocusedCategory() {
        assertEquals(5, AboutSettingsCategory.entries.size)
        assertEquals(5, AboutSettingsCategory.entries.map { it.titleRes }.toSet().size)
    }
}
