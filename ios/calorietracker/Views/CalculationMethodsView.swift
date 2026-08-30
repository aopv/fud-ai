import SwiftUI

/// Apple Guideline 1.4.1 (Safety: Physical Harm) requires apps with health
/// or medical calculations to cite their sources. This sheet documents every
/// formula Fud AI uses to derive BMR, TDEE, calorie targets, and macro splits,
/// with links to the original peer-reviewed sources where available. Reachable
/// from the onboarding Plan step ("How is this calculated?") and from
/// Settings → Goals & Nutrition → Calculation Methods.
struct CalculationMethodsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    intro

                    section(title: "Resting metabolism (BMR)") {
                        formulaCard(
                            name: "Mifflin-St Jeor equation",
                            usedWhen: "Default formula for resting metabolism. Used when body fat is unavailable.",
                            formula: "Men: 10×weight(kg) + 6.25×height(cm) − 5×age + 5\nWomen: 10×weight(kg) + 6.25×height(cm) − 5×age − 161",
                            citation: "Mifflin MD, St Jeor ST, et al. (1990). “A new predictive equation for resting energy expenditure in healthy individuals.” Am J Clin Nutr 51(2):241–247.",
                            url: URL(string: "https://pubmed.ncbi.nlm.nih.gov/2305711/")
                        )
                        formulaCard(
                            name: "Katch-McArdle equation",
                            usedWhen: "Used whenever you’ve entered a body fat %. It derives BMR from lean body mass instead of total weight.",
                            formula: "BMR = 370 + 21.6 × LBM(kg)\nLBM = weight × (1 − bodyFat%)",
                            citation: "McArdle WD, Katch FI, Katch VL. Exercise Physiology: Nutrition, Energy, and Human Performance, 7th ed. Lippincott Williams & Wilkins, 2010.",
                            url: nil
                        )
                    }

                    section(title: "Daily energy expenditure (TDEE)") {
                        formulaCard(
                            name: "Activity-multiplier method",
                            usedWhen: "TDEE = BMR × activity multiplier. The multiplier corresponds to your selected activity level. This is the maintenance baseline the AI starts from (unless Energy Burn supplies a measured one).",
                            formula: "Sedentary: 1.2  ·  Light: 1.375  ·  Moderate: 1.465  ·  Active: 1.55  ·  Very Active: 1.725  ·  Extra Active: 1.9",
                            citation: "Standard PAL (Physical Activity Level) coefficients from FAO/WHO/UNU joint expert consultation on human energy requirements (2001). Also widely used by ACSM and USDA Dietary Guidelines.",
                            url: URL(string: "https://www.fao.org/3/y5686e/y5686e00.htm")
                        )
                    }

                    section(title: "Calorie target for goal") {
                        formulaCard(
                            name: "Maintenance & goal adjustment",
                            usedWhen: "Maintenance starts from your TDEE — or, when Energy Burn is on, from Apple Health’s recent measured-energy window instead of the formula estimate: measured total energy when enough days are available; otherwise, average measured active energy + formula BMR. The AI refines maintenance against your logged intake and weight trend, then applies your goal: a weekly weight-change rate becomes a daily calorie deficit (Lose) or surplus (Gain).",
                            formula: "1 lb of body fat ≈ 3,500 kcal · 1 kg ≈ 7,700 kcal\nYour weekly rate ÷ 7 is subtracted from (Lose) or added to (Gain) maintenance to set the daily calorie target.",
                            citation: "Hall KD, et al. (2011). “Quantification of the effect of energy imbalance on bodyweight.” Lancet 378(9793):826–837. The classic 3,500-kcal-per-pound rule originates from Wishnofsky M (1958), Am J Clin Nutr 6:542–546.",
                            url: URL(string: "https://www.thelancet.com/journals/lancet/article/PIIS0140-6736(11)60812-X/fulltext")
                        )
                    }

                    section(title: "Macronutrient split") {
                        formulaCard(
                            name: "Protein, carbs, fat targets",
                            usedWhen: "The AI fits protein, carbs, and fat to your calorie target, using these references as a guide. Protein uses activity-based full-bodyweight rates; fat is set from bodyweight; carbs fill the rest. You can lock any value or edit it yourself in Settings.",
                            formula: "Protein: ~0.8–2.2 g per kg by activity level (raised slightly when losing)\nFat: ~0.6 g per kg bodyweight\nCarbs: remaining calories ÷ 4 kcal/g",
                            citation: "Morton RW, et al. (2018). “A systematic review, meta-analysis and meta-regression of the effect of protein supplementation on resistance training-induced gains in muscle mass and strength.” Br J Sports Med 52(6):376–384.",
                            url: URL(string: "https://bjsm.bmj.com/content/52/6/376")
                        )
                    }

                    section(title: "Micronutrient values") {
                        formulaCard(
                            name: "Per-meal estimates",
                            usedWhen: "Calorie, macro, fiber, sugar, saturated fat, cholesterol, caffeine, sodium, potassium and other detailed nutrition values returned per meal are AI-generated estimates from the food image, voice transcript, or text description, using the AI provider you selected.",
                            formula: nil,
                            citation: "Estimates rely on the underlying AI model's training data (USDA FoodData Central, manufacturer panels, scientific literature). Accuracy varies by food, portion-size visibility, and provider model. Always cross-check labels for foods you log frequently.",
                            url: URL(string: "https://fdc.nal.usda.gov/")
                        )
                    }

                    disclaimer

                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(AppColors.appBackground)
            .navigationTitle("Calculation Methods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How Fud AI sets your numbers")
                .font(.system(.title3, design: .rounded, weight: .bold))
            Text("Your daily calorie and macro targets are set by AI. When you tap Recalculate Goals — or automatically about once a week if Adaptive Goals is on — Fud AI sends your profile, the reference equations below, privacy-safe daily nutrition totals, exact dated weight, body-fat, and tape measurements, aggregate workout counts, duration, sets, and reps, and optional Apple Health energy to your AI provider. Food names, notes, photos, ingredients, and exercise names are not sent for this calculation. It starts from these peer-reviewed formulas, then adjusts them to your real data to estimate your true maintenance and targets.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Not medical advice")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
            Text("Fud AI is an estimation tool, not a clinical instrument. Predictive equations carry inherent error (typically ±10% for BMR). Consult a registered dietitian, physician, or sports medicine professional before significant diet changes — especially if you have a medical condition, are pregnant or breastfeeding, are under 18, or are managing an eating disorder.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func section<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .padding(.horizontal, 4)
            content()
        }
    }

    private func formulaCard(
        name: LocalizedStringKey,
        usedWhen: LocalizedStringKey,
        formula: LocalizedStringKey?,
        citation: LocalizedStringKey,
        url: URL?
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(name)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))

            Text(usedWhen)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let formula {
                Text(formula)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.85))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Source")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                Text(citation)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let url {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 11))
                            Text("Open source")
                                .font(.system(.caption, design: .rounded, weight: .medium))
                        }
                        .foregroundStyle(AppColors.calorie)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.appCard, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    CalculationMethodsView()
}
