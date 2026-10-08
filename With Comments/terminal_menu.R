# ==============================================================================
# BAGUIO DENGUE SURVEILLANCE & HOTSPOT TERMINAL SYSTEM
# Interactive Console Application (CLI)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. FILE PATHS & DATA INITIALIZATION
# ------------------------------------------------------------------------------
SURVEILLANCE_FILE <- file.path("datasets", "baguio_dengue_surveillance_synthetic.csv")
GEO_FILE          <- file.path("datasets", "baguio_barangays_geo.csv")
SUMMARY_FILE      <- file.path("datasets", "baguio_dengue_hotspot_summary.csv")

if (!file.exists(SURVEILLANCE_FILE)) {
  stop(sprintf("Error: Surveillance dataset not found at '%s'.", SURVEILLANCE_FILE))
}

df  <- read.csv(SURVEILLANCE_FILE, stringsAsFactors = FALSE)
geo <- if (file.exists(GEO_FILE)) read.csv(GEO_FILE, stringsAsFactors = FALSE) else NULL

# Age stratification categories
df$age_group <- cut(
  df$age,
  breaks = c(0, 5, 12, 18, 35, 60, Inf),
  labels = c("0-5 (Infants)", "6-12 (Children)", "13-18 (Teens)", 
             "19-35 (Young Adults)", "36-60 (Adults)", "60+ (Seniors)"),
  right = TRUE
)

# ------------------------------------------------------------------------------
# 2. HELPER UTILITIES
# ------------------------------------------------------------------------------
prompt_input <- function(label) {
  if (interactive()) {
    ans <- readline(prompt = label)
  } else {
    cat(label)
    ans <- readLines(con = "stdin", n = 1)
  }
  trimws(ans)
}

clear_screen <- function() {
  if (.Platform$OS.type == "windows") {
    tryCatch(shell("cls"), error = function(e) cat("\014"))
  } else {
    tryCatch(system("clear"), error = function(e) cat("\014"))
  }
}

pause_screen <- function() {
  cat("\nPress [ENTER] to return to the menu...")
  if (interactive()) {
    invisible(readline())
  } else {
    invisible(readLines(con = "stdin", n = 1))
  }
  clear_screen()
}

print_header <- function(title) {
  divider <- paste0(rep("=", 72), collapse = "")
  cat("\n", divider, "\n", sep = "")
  cat(sprintf("  %s\n", title))
  cat(divider, "\n\n", sep = "")
}

source("hotspot_utils.R")


# ------------------------------------------------------------------------------
# 3. MENU ACTION HANDLERS
# ------------------------------------------------------------------------------

# [1] Summary Overview
action_overview <- function() {
  print_header("EPIDEMIOLOGICAL SUMMARY OVERVIEW")
  
  total_cases <- nrow(df)
  years       <- sort(unique(df$morbidity_year))
  active      <- sum(df$outcome == "Active", na.rm = TRUE)
  recovered   <- sum(df$outcome == "Recovered", na.rm = TRUE)
  deaths      <- sum(df$outcome == "Died", na.rm = TRUE)
  cfr         <- (deaths / total_cases) * 100
  severe      <- sum(df$clinical_classification == "Severe Dengue", na.rm = TRUE)
  warning     <- sum(df$clinical_classification == "Dengue with Warning Signs", na.rm = TRUE)
  no_warning  <- sum(df$clinical_classification == "Dengue without Warning Signs", na.rm = TRUE)
  
  cat(sprintf("Surveillance Period:        %d - %d\n", min(years), max(years)))
  cat(sprintf("Total Cumulative Cases:     %s\n", format(total_cases, big.mark = ",")))
  cat(sprintf("Active Cases:               %s (%.1f%%)\n", format(active, big.mark = ","), (active / total_cases) * 100))
  cat(sprintf("Recoveries:                 %s (%.1f%%)\n", format(recovered, big.mark = ","), (recovered / total_cases) * 100))
  cat(sprintf("Fatalities (Deaths):        %d (CFR: %.2f%%)\n", deaths, cfr))
  cat(paste0(rep("-", 72), collapse = ""), "\n")
  cat("Clinical Classifications:\n")
  cat(sprintf("  * Severe Dengue:           %5d (%5.2f%%)\n", severe, (severe / total_cases) * 100))
  cat(sprintf("  * With Warning Signs:      %5d (%5.2f%%)\n", warning, (warning / total_cases) * 100))
  cat(sprintf("  * Without Warning Signs:   %5d (%5.2f%%)\n", no_warning, (no_warning / total_cases) * 100))
}

# [2] Hotspot Rankings
action_hotspots <- function() {
  print_header("BARANGAY HOTSPOT & RISK RANKINGS")
  cat("View Filter Options:\n")
  cat("  [1] Top 10 Hotspots\n")
  cat("  [2] Top 25 Hotspots\n")
  cat("  [3] High Risk (Epidemic) Only\n")
  cat("  [4] All Barangays\n\n")
  
  choice <- prompt_input("Select filter [1-4, Default=1]: ")
  metrics <- calculate_barangay_hotspots(df, geo)
  
  filtered <- switch(
    choice,
    "2" = head(metrics, 25),
    "3" = subset(metrics, risk_tier == "HIGH (EPIDEMIC)"),
    "4" = metrics,
    head(metrics, 10)
  )
  
  row_fmt <- "%-3s | %-24s | %6s | %6s | %6s | %10s | %-16s\n"
  cat("\n")
  cat(sprintf(row_fmt, "#", "Barangay", "Cases", "Severe", "Deaths", "Rate/10k", "Risk Status"))
  cat(paste0(rep("-", 80), collapse = ""), "\n")
  
  for (i in seq_len(nrow(filtered))) {
    r <- filtered[i, ]
    rate_str <- ifelse(is.na(r$attack_rate_10k), "-", sprintf("%.1f", r$attack_rate_10k))
    cat(sprintf(row_fmt, i, substr(r$barangay, 1, 24), format(r$total_cases, big.mark = ","),
                r$severe_cases, r$deaths, rate_str, r$risk_tier))
  }
  cat(paste0(rep("-", 80), collapse = ""), "\n")
  cat(sprintf("Total entries displayed: %d\n", nrow(filtered)))
}

# [3] Search Barangay
action_search <- function() {
  print_header("BARANGAY SURVEILLANCE PROFILE LOOKUP")
  query <- prompt_input("Enter barangay name: ")
  if (nchar(query) == 0) return()
  
  metrics <- calculate_barangay_hotspots(df, geo)
  matched <- metrics[grepl(query, metrics$barangay, ignore.case = TRUE), ]
  
  if (nrow(matched) == 0) {
    cat(sprintf("\nNo barangay record matched '%s'.\n", query))
    return()
  }
  
  for (i in seq_len(nrow(matched))) {
    b_name <- matched$barangay[i]
    b_df   <- subset(df, barangay == b_name)
    
    cat("\n--------------------------------------------------------------------\n")
    cat(sprintf("BARANGAY: %s\n", toupper(b_name)))
    cat("--------------------------------------------------------------------\n")
    cat(sprintf("  Risk Status:             %s\n", matched$risk_tier[i]))
    cat(sprintf("  Cumulative Cases:        %s\n", format(matched$total_cases[i], big.mark = ",")))
    if (!is.na(matched$estimated_population[i])) {
      cat(sprintf("  Estimated Population:    %s\n", format(matched$estimated_population[i], big.mark = ",")))
      cat(sprintf("  Attack Rate (per 10k):   %.1f\n", matched$attack_rate_10k[i]))
    }
    cat(sprintf("  Active Cases:            %d\n", sum(b_df$outcome == "Active", na.rm = TRUE)))
    cat(sprintf("  Recovered:               %d\n", sum(b_df$outcome == "Recovered", na.rm = TRUE)))
    cat(sprintf("  Severe Dengue Cases:     %d\n", matched$severe_cases[i]))
    cat(sprintf("  Fatalities (Deaths):     %d\n", matched$deaths[i]))
    
    cat("\n  Age Distribution Breakdown:\n")
    age_tbl <- table(b_df$age_group)
    for (grp in names(age_tbl)) {
      count <- age_tbl[[grp]]
      pct   <- ifelse(matched$total_cases[i] > 0, (count / matched$total_cases[i]) * 100, 0)
      cat(sprintf("    - %-22s: %4d (%5.1f%%)\n", grp, count, pct))
    }
    
    cat("\n  Annual Morbidity Trajectory:\n")
    yr_tbl <- table(b_df$morbidity_year)
    for (yr in names(yr_tbl)) {
      cat(sprintf("    - Year %s: %d cases\n", yr, yr_tbl[[yr]]))
    }
  }
}

# [4] Demographic & Clinical Analysis
action_demographics <- function() {
  print_header("DEMOGRAPHIC & CLINICAL PROFILE ANALYSIS")
  
  cat("--- SEX RATIO ---\n")
  sex_tbl <- table(df$sex)
  for (s in names(sex_tbl)) {
    cat(sprintf("  %-8s: %5d cases (%5.1f%%)\n", s, sex_tbl[[s]], (sex_tbl[[s]] / nrow(df)) * 100))
  }
  
  cat("\n--- AGE GROUP BY CLINICAL CLASSIFICATION ---\n")
  print(table(df$age_group, df$clinical_classification))
  
  cat("\n--- AGE GROUP BY OUTCOME ---\n")
  print(table(df$age_group, df$outcome))
}

# [5] Annual & Weekly Trend Analysis
action_trends <- function() {
  print_header("ANNUAL & WEEKLY TREND ANALYSIS")
  
  cat("--- ANNUAL CASE TRAJECTORY ---\n")
  yr_counts <- table(df$morbidity_year)
  max_count <- max(yr_counts, na.rm = TRUE)
  
  for (yr in names(yr_counts)) {
    cnt <- yr_counts[[yr]]
    bar_len <- if (max_count > 0) round((cnt / max_count) * 40) else 0
    bar_str <- paste0(rep("#", bar_len), collapse = "")
    cat(sprintf("  Year %s | %5d cases | %s\n", yr, cnt, bar_str))
  }
  
  cat("\n--- TOP 5 PEAK MORBIDITY WEEKS ---\n")
  weekly_stats <- aggregate(case_id ~ morbidity_year + morbidity_week, data = df, FUN = length)
  names(weekly_stats) <- c("morbidity_year", "morbidity_week", "total_cases")
  weekly_stats <- weekly_stats[order(-weekly_stats$total_cases), ]
  
  top5 <- head(weekly_stats, 5)
  row_fmt <- "  %-3s | %-6s | %-6s | %11s\n"
  cat(sprintf(row_fmt, "#", "Year", "Week", "Total Cases"))
  cat("  --------------------------------------\n")
  for (i in seq_len(nrow(top5))) {
    cat(sprintf(row_fmt, i, top5$morbidity_year[i], paste0("W", top5$morbidity_week[i]), format(top5$total_cases[i], big.mark = ",")))
  }
}

# ------------------------------------------------------------------------------
# 4. MAIN TERMINAL MENU LOOP
# ------------------------------------------------------------------------------
main <- function() {
  clear_screen()
  repeat {
    cat("====================================================================\n")
    cat("        BAGUIO DENGUE SURVEILLANCE & HOTSPOT TERMINAL SYSTEM        \n")
    cat("====================================================================\n")
    cat("  [1] Overview & Key Epidemiological Indicators\n")
    cat("  [2] Barangay Hotspot Rankings & Risk Status\n")
    cat("  [3] Search Barangay Surveillance Profile\n")
    cat("  [4] Demographic & Clinical Analysis\n")
    cat("  [5] Annual & Weekly Trend Analysis\n")
    cat("  [0] Exit\n")
    cat("====================================================================\n")
    
    choice <- prompt_input("Enter choice [0-5]: ")
    
    switch(
      choice,
      "1" = { action_overview(); pause_screen() },
      "2" = { action_hotspots(); pause_screen() },
      "3" = { action_search(); pause_screen() },
      "4" = { action_demographics(); pause_screen() },
      "5" = { action_trends(); pause_screen() },
      "0" = {
        cat("\nExiting Baguio Dengue Surveillance Terminal. Stay safe!\n\n")
        break
      },
      "q" = {
        cat("\nExiting Baguio Dengue Surveillance Terminal. Stay safe!\n\n")
        break
      },
      cat("\n[!] Invalid input. Please enter an option from 0 to 5.\n")
    )
  }
}

# Auto-execute
main()
