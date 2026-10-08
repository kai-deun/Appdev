# ==============================================================================
# Baguio Barangay Dengue Surveillance & Hotspot Monitor
# Automated Epidemiological Analysis & Hotspot Detection Report
# ==============================================================================

# 1. Load Data
surveillance_file <- file.path("datasets", "baguio_dengue_surveillance_synthetic.csv")
geo_file <- file.path("datasets", "baguio_barangays_geo.csv")

if (!file.exists(surveillance_file)) {
  stop("Surveillance CSV file not found: ", surveillance_file)
}

df <- read.csv(surveillance_file, stringsAsFactors = FALSE)
geo <- if (file.exists(geo_file)) read.csv(geo_file, stringsAsFactors = FALSE) else NULL

cat("===============================================================\n")
cat("       BAGUIO DENGUE SURVEILLANCE & HOTSPOT MONITOR           \n")
cat("===============================================================\n\n")

# Summary Key Indicators
total_cases <- nrow(df)
years <- sort(unique(df$morbidity_year))
active_cases <- sum(df$outcome == "Active")
deaths <- sum(df$outcome == "Died")
cfr <- (deaths / total_cases) * 100
severe_cases <- sum(df$clinical_classification == "Severe Dengue")
warning_cases <- sum(df$clinical_classification == "Dengue with Warning Signs")

cat(sprintf("Surveillance Period: %d - %d\n", min(years), max(years)))
cat(sprintf("Total Recorded Cases: %s\n", format(total_cases, big.mark = ",")))
cat(sprintf("Current Active Cases: %d\n", active_cases))
cat(sprintf("Total Fatalities: %d (CFR: %.2f%%)\n", deaths, cfr))
cat(sprintf("Severe Cases: %d (%.1f%%) | With Warning Signs: %d (%.1f%%)\n\n",
            severe_cases, (severe_cases/total_cases)*100,
            warning_cases, (warning_cases/total_cases)*100))

source("hotspot_utils.R")

# ------------------------------------------------------------------------------
# 2. Barangay Morbidity & Hotspot Classification
# ------------------------------------------------------------------------------
brgy_stats <- calculate_barangay_hotspots(df, geo)

cat("--- TOP 10 DENGUE HOTSPOT BARANGAYS ---\n")
print(head(brgy_stats[, c("barangay", "total_cases", "severe_cases", "deaths", "attack_rate_10k", "risk_tier")], 10), row.names = FALSE)
cat("\n")

# ------------------------------------------------------------------------------
# 3. Demographic Analysis (Age & Sex)
# ------------------------------------------------------------------------------
df$age_group <- cut(df$age,
                    breaks = c(0, 5, 12, 18, 35, 60, Inf),
                    labels = c("0-5 (Infants/Toddlers)", "6-12 (Children)", "13-18 (Teens)", "19-35 (Young Adults)", "36-60 (Adults)", "60+ (Seniors)"),
                    right = TRUE)

cat("--- AGE GROUP VULNERABILITY DISTRIBUTION ---\n")
age_dist <- table(df$age_group, df$clinical_classification)
print(age_dist)
cat("\n")

# ------------------------------------------------------------------------------
# 4. Save Hotspot Summary Report
# ------------------------------------------------------------------------------
output_report <- file.path("datasets", "baguio_dengue_hotspot_summary.csv")
write.csv(brgy_stats, output_report, row.names = FALSE)
cat(sprintf("=> Saved complete Hotspot & Incidence summary to: %s\n", output_report))
