# test_dir() --------------------------------------------------------------

test_that("stops on failure", {
  withr::local_envvar(TESTTHAT_PARALLEL = "FALSE")
  expect_error(
    test_dir(test_path("test_dir"), reporter = "silent")
  )
})

test_that("runs all tests and records output", {
  withr::local_envvar(TESTTHAT_PARALLEL = "FALSE")
  res <- test_dir(test_path("test_dir"), reporter = "silent", stop_on_failure = FALSE)
  df <- as.data.frame(res)
  df$user <- df$system <- df$real <- df$result <- NULL

  local_reproducible_output(width = 200)
  local_edition(3) # set to 2 in ./test_dir
  expect_snapshot_output(print(df))
})

test_that("complains if no files", {
  withr::local_envvar(TESTTHAT_PARALLEL = "FALSE")
  path <- withr::local_tempfile()
  dir.create(path)

  expect_error(test_dir(path), "test files")
})

test_that("can control if failures generate errors", {
  withr::local_envvar(TESTTHAT_PARALLEL = "FALSE")
  test_error <- function(...) {
    test_dir(test_path("test-error"), reporter = "silent", ...)
  }

  expect_error(test_error(stop_on_failure = TRUE), "Test failures")
  expect_error(test_error(stop_on_failure = FALSE), NA)
})

test_that("can control if warnings errors", {
  withr::local_envvar(TESTTHAT_PARALLEL = "FALSE")
  test_warning <- function(...) {
    test_dir(test_path("test-warning"), reporter = "silent", ...)
  }

  expect_error(test_warning(stop_on_warning = TRUE), "Tests generated warnings")
  expect_error(test_warning(stop_on_warning = FALSE), NA)
})

# test_file ---------------------------------------------------------------

test_that("can test single file", {
  out <- test_file(test_path("test_dir/test-basic.R"), reporter = "silent")
  expect_length(out, 5)
})

test_that("complains if file doesn't exist", {
  expect_error(test_file("DOESNTEXIST"), "does not exist")
})


# setup-teardown ----------------------------------------------------------

test_that("files created by setup still exist", {
  # These files should be created/delete by package-wide setup/teardown
  # We check that they exist here to make sure that they're not cleaned up
  # too early
  expect_true(file.exists("DELETE-ME"))
  expect_true(file.exists("DELETE-ME-2"))
})

# helpers -----------------------------------------------------------------

test_that("can filter test scripts", {
  x <- c("test-a.R", "test-b.R", "test-c.R")
  expect_equal(filter_test_scripts(x), x)
  expect_equal(filter_test_scripts(x, "a"), x[1])
  expect_equal(filter_test_scripts(x, "a", invert = TRUE), x[-1])

  # Strips prefix/suffix
  expect_equal(filter_test_scripts(x, "test"), character())
  expect_equal(filter_test_scripts(x, ".R"), character())
})

# ----------------------------------------------------------------------

test_that("can configure `load_all()` (#1636)", {
  path <- test_path("testConfigLoadAll")

  args <- find_load_all_args(path)
  expect_equal(args, list(export_all = FALSE, helpers = FALSE))

  results <- test_local(path, reporter = "silent")
  for (res in results) {
    expect_equal(sum(res[["failed"]]), 0)
  }
})

test_that("helpers are included in the testing environment", {
  expect_true("abcdefghi" %in% names(the$testing_env))
})
