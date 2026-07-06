package com.apoorvdarshan.calorietracker.export

import com.apoorvdarshan.calorietracker.R

import com.apoorvdarshan.calorietracker.models.FoodEntry
import com.apoorvdarshan.calorietracker.models.FoodSource
import com.apoorvdarshan.calorietracker.models.MealType
import com.apoorvdarshan.calorietracker.models.UserProfile
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlin.math.max
import kotlin.math.roundToInt

enum class DiaryFormat(val label: String, val ext: String, val mime: String) {
    JSON("JSON", "json", "application/json"),
    MARKDOWN("Markdown", "md", "text/markdown"),
    CSV("CSV", "csv", "text/csv"),
}

enum class DiaryRange(val label: String, val labelRes: Int) {
    TODAY("Today", R.string.export_range_today),
    THIS_WEEK("This week", R.string.export_range_week),
    THIS_MONTH("This month", R.string.export_range_month),
    ALL_TIME("All time", R.string.export_range_all),
    CUSTOM("Custom", R.string.export_range_custom),
}

/**
 * Builds a shareable food-diary file (JSON / Markdown / CSV) from the local log.
 * Pure logic — the caller supplies the entries, the current profile, and a meal
 * display-name resolver (so string resources stay in the UI layer).
 */
object DiaryExporter {

    private val zone: ZoneId get() = ZoneId.systemDefault()
    private val dayFmt: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")
    private val timeFmt: DateTimeFormatter = DateTimeFormatter.ofPattern("HH:mm")

    private fun LocalDate.of(entry: FoodEntry): Boolean =
        entry.timestamp.atZone(zone).toLocalDate() == this

    fun resolveRange(
        range: DiaryRange,
        customStart: LocalDate,
        customEnd: LocalDate,
        entries: List<FoodEntry>,
    ): Pair<LocalDate, LocalDate> {
        val today = LocalDate.now()
        return when (range) {
            DiaryRange.TODAY -> today to today
            DiaryRange.THIS_WEEK -> today.with(DayOfWeek.MONDAY) to today
            DiaryRange.THIS_MONTH -> today.withDayOfMonth(1) to today
            DiaryRange.ALL_TIME -> {
                val earliest = entries.minOfOrNull { it.timestamp.atZone(zone).toLocalDate() } ?: today
                earliest to today
            }
            DiaryRange.CUSTOM -> customStart to customEnd
        }
    }

    /** Returns (filename, content) or null if nothing is logged in the range. */
    fun build(
        entries: List<FoodEntry>,
        start: LocalDate,
        end: LocalDate,
        format: DiaryFormat,
        profile: UserProfile?,
        mealDisplay: (MealType) -> String,
    ): Pair<String, String>? {
        val lo = if (start.isAfter(end)) end else start
        val hi = if (start.isAfter(end)) start else end

        val byDay: Map<LocalDate, List<FoodEntry>> = entries
            .filter {
                val d = it.timestamp.atZone(zone).toLocalDate()
                !d.isBefore(lo) && !d.isAfter(hi)
            }
            .groupBy { it.timestamp.atZone(zone).toLocalDate() }
            .toSortedMap()
        if (byDay.isEmpty()) return null

        val targets = Targets(
            calories = profile?.effectiveCalories ?: 0,
            protein = (profile?.effectiveProtein ?: 0).toDouble(),
            carbs = (profile?.effectiveCarbs ?: 0).toDouble(),
            fat = (profile?.effectiveFat ?: 0).toDouble(),
        )

        val content = when (format) {
            DiaryFormat.JSON -> json(byDay, lo, hi, targets)
            DiaryFormat.MARKDOWN -> markdown(byDay, lo, hi, targets, mealDisplay)
            DiaryFormat.CSV -> csv(byDay)
        }
        val name = "Fud-Food-Diary-${dayFmt.format(lo)}_to_${dayFmt.format(hi)}.${format.ext}"
        return name to content
    }

    // --- internal helpers ---

    private data class Targets(val calories: Int, val protein: Double, val carbs: Double, val fat: Double)

    /** A day's entries grouped by meal in enum order, each sorted by time ascending. */
    private fun meals(dayEntries: List<FoodEntry>): List<Pair<MealType, List<FoodEntry>>> =
        MealType.values().mapNotNull { mt ->
            val items = dayEntries.filter { it.mealType == mt }.sortedBy { it.timestamp }
            if (items.isEmpty()) null else mt to items
        }

    private fun totals(dayEntries: List<FoodEntry>): DoubleArray {
        var cal = 0.0; var p = 0.0; var c = 0.0; var f = 0.0
        for (e in dayEntries) { cal += e.calories; p += e.protein; c += e.carbs; f += e.fat }
        return doubleArrayOf(cal, p, c, f)
    }

    fun sourceLabel(source: FoodSource): String =
        if (source == FoodSource.MANUAL) "manually_edited" else "ai_estimated"

    private fun r1(x: Double): Double = (x * 10).roundToInt() / 10.0
    private fun time(entry: FoodEntry): String = timeFmt.format(entry.timestamp.atZone(zone))

    // --- JSON ---

    @Serializable private data class Macro(val calories: Int, val protein_g: Double, val carbs_g: Double, val fat_g: Double)
    @Serializable private data class ItemDto(
        val name: String, val quantity_g: Double? = null, val calories: Int,
        val protein_g: Double, val carbs_g: Double, val fat_g: Double,
        val time: String, val source: String, val note: String? = null,
    )
    @Serializable private data class MealDto(val type: String, val items: List<ItemDto>)
    @Serializable private data class DayDto(val date: String, val totals: Macro, val targets: Macro, val remaining: Macro, val meals: List<MealDto>)
    @Serializable private data class RangeDto(val start: String, val end: String)
    @Serializable private data class MetaDto(val app: String, val format_version: String, val date_range: RangeDto)
    @Serializable private data class Doc(val export: MetaDto, val days: List<DayDto>)

    private val jsonPretty = Json { prettyPrint = true; encodeDefaults = true }

    private fun json(byDay: Map<LocalDate, List<FoodEntry>>, lo: LocalDate, hi: LocalDate, t: Targets): String {
        val days = byDay.map { (date, dayEntries) ->
            val tot = totals(dayEntries)
            val mealDtos = meals(dayEntries).map { (mt, items) ->
                MealDto(
                    type = mt.name.lowercase(),
                    items = items.map { e ->
                        ItemDto(
                            name = e.name,
                            quantity_g = e.servingSizeGrams?.let { r1(it) },
                            calories = e.calories,
                            protein_g = r1(e.protein), carbs_g = r1(e.carbs), fat_g = r1(e.fat),
                            time = time(e), source = sourceLabel(e.source),
                            note = e.customNote?.takeIf { it.isNotBlank() },
                        )
                    },
                )
            }
            DayDto(
                date = dayFmt.format(date),
                totals = Macro(tot[0].roundToInt(), r1(tot[1]), r1(tot[2]), r1(tot[3])),
                targets = Macro(t.calories, t.protein, t.carbs, t.fat),
                remaining = Macro(
                    max(0, t.calories - tot[0].roundToInt()),
                    r1(max(0.0, t.protein - tot[1])),
                    r1(max(0.0, t.carbs - tot[2])),
                    r1(max(0.0, t.fat - tot[3])),
                ),
                meals = mealDtos,
            )
        }
        val doc = Doc(
            export = MetaDto("Fud AI", "1.0", RangeDto(dayFmt.format(lo), dayFmt.format(hi))),
            days = days,
        )
        return jsonPretty.encodeToString(Doc.serializer(), doc)
    }

    // --- Markdown ---

    private fun markdown(
        byDay: Map<LocalDate, List<FoodEntry>>,
        lo: LocalDate, hi: LocalDate, t: Targets,
        mealDisplay: (MealType) -> String,
    ): String {
        val sb = StringBuilder()
        sb.append("# Food diary export\n")
        sb.append("Date range: ${dayFmt.format(lo)} to ${dayFmt.format(hi)}\n")
        sb.append("Generated by Fud AI\n")
        for ((date, dayEntries) in byDay) {
            val tot = totals(dayEntries)
            sb.append("\n## ${dayFmt.format(date)}\n")
            sb.append("Totals:\n")
            sb.append("- Calories: ${tot[0].roundToInt()} / ${t.calories} kcal\n")
            sb.append("- Protein: ${r1(tot[1])} / ${t.protein.roundToInt()} g\n")
            sb.append("- Carbs: ${r1(tot[2])} / ${t.carbs.roundToInt()} g\n")
            sb.append("- Fat: ${r1(tot[3])} / ${t.fat.roundToInt()} g\n")
            for ((mt, items) in meals(dayEntries)) {
                sb.append("### ${mealDisplay(mt)}\n")
                sb.append("| Time | Food | Weight | Calories | Protein | Carbs | Fat | Source |\n")
                sb.append("|---|---|---:|---:|---:|---:|---:|---|\n")
                for (e in items) {
                    val weight = e.servingSizeGrams?.let { "${it.roundToInt()} g" } ?: "-"
                    val food = e.name.replace("|", "/")
                    val cells = listOf(
                        time(e), food, weight, e.calories.toString(),
                        "${r1(e.protein)} g", "${r1(e.carbs)} g", "${r1(e.fat)} g", sourceLabel(e.source),
                    )
                    sb.append("| ").append(cells.joinToString(" | ")).append(" |\n")
                }
            }
        }
        return sb.toString()
    }

    // --- CSV ---

    private fun csv(byDay: Map<LocalDate, List<FoodEntry>>): String {
        val sb = StringBuilder()
        sb.append("date,meal,time,food,weight_g,calories,protein_g,carbs_g,fat_g,source,note\n")
        for ((date, dayEntries) in byDay) {
            val d = dayFmt.format(date)
            for ((mt, items) in meals(dayEntries)) {
                for (e in items) {
                    val cols = listOf(
                        d, mt.name.lowercase(), time(e), e.name,
                        e.servingSizeGrams?.roundToInt()?.toString() ?: "",
                        e.calories.toString(), r1(e.protein).toString(), r1(e.carbs).toString(), r1(e.fat).toString(),
                        sourceLabel(e.source), e.customNote ?: "",
                    )
                    sb.append(cols.joinToString(",") { csvEscape(it) }).append("\n")
                }
            }
        }
        return sb.toString()
    }

    private fun csvEscape(field: String): String =
        if (field.contains(',') || field.contains('"') || field.contains('\n')) {
            "\"" + field.replace("\"", "\"\"") + "\""
        } else field
}
