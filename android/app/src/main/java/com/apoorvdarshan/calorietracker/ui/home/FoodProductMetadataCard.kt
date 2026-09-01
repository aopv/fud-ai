package com.apoorvdarshan.calorietracker.ui.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.apoorvdarshan.calorietracker.R
import com.apoorvdarshan.calorietracker.models.FoodProductMetadata

@Composable
internal fun FoodProductMetadataCard(metadata: FoodProductMetadata) {
    val rows = buildList {
        add(stringResource(R.string.product_barcode) to metadata.barcode)
        metadata.packageQuantity?.let { add(stringResource(R.string.product_package) to it) }
        metadata.nutriScore?.let { add(stringResource(R.string.product_nutri_score) to it) }
        metadata.novaGroup?.let { add(stringResource(R.string.product_nova_group) to it.toString()) }
        metadata.ecoScore?.let { add(stringResource(R.string.product_eco_score) to it) }
        metadata.allergens.takeIf { it.isNotEmpty() }?.let {
            add(stringResource(R.string.product_allergens) to it.joinToString(", "))
        }
        metadata.traces.takeIf { it.isNotEmpty() }?.let {
            add(stringResource(R.string.product_may_contain) to it.joinToString(", "))
        }
        metadata.labels.takeIf { it.isNotEmpty() }?.let {
            add(stringResource(R.string.product_labels) to it.joinToString(", "))
        }
        metadata.categories.takeIf { it.isNotEmpty() }?.let {
            add(stringResource(R.string.product_categories) to it.joinToString(", "))
        }
    }

    SheetPillCard {
        rows.forEachIndexed { index, (label, value) ->
            if (index > 0) SheetHairline()
            ProductMetadataRow(label = label, value = value)
        }
        metadata.ingredientsText?.let { ingredients ->
            if (rows.isNotEmpty()) SheetHairline()
            Column(
                modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(
                    stringResource(R.string.product_ingredient_label),
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold
                )
                Text(
                    ingredients,
                    fontSize = 14.sp,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.68f)
                )
            }
        }
    }
}

@Composable
private fun ProductMetadataRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
        verticalAlignment = Alignment.Top
    ) {
        Text(label, fontSize = 15.sp)
        Spacer(Modifier.weight(1f))
        Text(
            value,
            modifier = Modifier.weight(1.6f),
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.68f),
            fontSize = 15.sp,
            textAlign = TextAlign.End
        )
    }
}
