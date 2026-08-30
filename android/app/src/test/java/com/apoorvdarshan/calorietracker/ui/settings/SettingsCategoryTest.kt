package com.apoorvdarshan.calorietracker.ui.settings

import org.junit.Assert.assertEquals
import org.junit.Test

class SettingsCategoryTest {
    @Test
    fun hubKeepsEveryFocusedCategory() {
        assertEquals(11, SettingsCategory.entries.size)
        assertEquals(11, SettingsCategory.entries.map { it.titleRes }.toSet().size)
    }
}
