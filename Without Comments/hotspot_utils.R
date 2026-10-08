calculate_barangay_hotspots <- function(df, geo = NULL) {
  brgy_cases <- aggregate(case_id ~ barangay, data = df, FUN = length)
  names(brgy_cases) <- c("barangay", "total_cases")
  
  brgy_severe <- aggregate(case_id ~ barangay, data = subset(df, clinical_classification == "Severe Dengue"), FUN = length)
  names(brgy_severe) <- c("barangay", "severe_cases")
  
  brgy_deaths <- aggregate(case_id ~ barangay, data = subset(df, outcome == "Died"), FUN = length)
  names(brgy_deaths) <- c("barangay", "deaths")
  
  metrics <- merge(brgy_cases, brgy_severe, by = "barangay", all.x = TRUE)
  metrics <- merge(metrics, brgy_deaths, by = "barangay", all.x = TRUE)
  metrics$severe_cases[is.na(metrics$severe_cases)] <- 0
  metrics$deaths[is.na(metrics$deaths)] <- 0
  
  if (!is.null(geo)) {
    metrics <- merge(metrics, geo[, c("barangay", "estimated_population")], by = "barangay", all.x = TRUE)
    metrics$attack_rate_10k <- round((metrics$total_cases / metrics$estimated_population) * 10000, 1)
  } else {
    metrics$estimated_population <- NA
    metrics$attack_rate_10k <- NA
  }
  
  metrics$risk_tier <- ifelse(
    metrics$total_cases >= 200 | (!is.na(metrics$attack_rate_10k) & metrics$attack_rate_10k >= 150),
    "HIGH (EPIDEMIC)",
    ifelse(
      metrics$total_cases >= 80 | (!is.na(metrics$attack_rate_10k) & metrics$attack_rate_10k >= 80),
      "ALERT (ELEVATED)", 
      "CONTROLLED"
    )
  )
  
  metrics[order(-metrics$total_cases), ]
}
