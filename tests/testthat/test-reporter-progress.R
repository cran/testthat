test_that("captures error before first test", {
  local_output_override()

  expect_snapshot_reporter(
    ProgressReporter$new(update_interval = 0, min_time = Inf),
    test_path("reporters/error-setup.R")
  )
})

test_that("gracefully handles multiple contexts", {
  expect_snapshot_reporter(
    ProgressReporter$new(update_interval = 0, min_time = Inf),
    test_path("reporters/context.R")
  )
})

test_that("can control max fails with env var or option", {
  withr::local_envvar(TESTTHAT_MAX_FAILS = 11)
  expect_equal(testthat_max_fails(), 11)

  withr::local_options(testthat.progress.max_fails = 12)
  expect_equal(testthat_max_fails(), 12)
})

test_that("fails after max_fail tests", {
  withr::local_options(testthat.progress.max_fails = 10)
  expect_snapshot_reporter(
    ProgressReporter$new(update_interval = 0, min_time = Inf),
    test_path(c("reporters/fail-many.R", "reporters/fail.R"))
  )
})

test_that("can fully suppress incremental updates", {
  expect_snapshot_reporter(
    ProgressReporter$new(update_interval = 0, min_time = Inf),
    test_path("reporters/successes.R")
  )

  expect_snapshot_reporter(
    ProgressReporter$new(update_interval = Inf, min_time = Inf),
    test_path("reporters/successes.R")
  )
})

test_that("reports backtraces", {
  expect_snapshot_reporter(
    ProgressReporter$new(update_interval = 0, min_time = Inf),
    test_path("reporters/backtraces.R")
  )
})

test_that("records skips", {
  expect_snapshot_reporter(
    ProgressReporter$new(update_interval = 0, min_time = Inf),
    test_path("reporters/skips.R")
  )
})

# compact display ---------------------------------------------------------

test_that("compact display is informative", {
  expect_snapshot_reporter(
    CompactProgressReporter$new(),
    test_path("reporters/tests.R")
  )
})

test_that("display of successes only is compact", {
  expect_snapshot_reporter(
    CompactProgressReporter$new(),
    test_path("reporters/successes.R")
  )

  expect_snapshot_reporter(
    CompactProgressReporter$new(),
    test_path("reporters/skips.R")
  )

  # And even more compact if in RStudio pane
  local_reproducible_output(rstudio = TRUE)
  expect_snapshot_reporter(
    CompactProgressReporter$new(),
    test_path("reporters/successes.R")
  )
})
