package com.apoorvdarshan.calorietracker.ui.util

import java.text.NumberFormat
import java.util.Locale

/** Locale-aware whole-number formatting for values shown in the UI. */
fun Int.formattedWholeNumber(): String =
    NumberFormat.getIntegerInstance(Locale.getDefault()).format(this)
