#' Snapshot testing
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Snapshot tests (aka golden tests) are similar to unit tests except that the
#' expected result is stored in a separate file that is managed by testthat.
#' Snapshot tests are useful for when the expected value is large, or when
#' the intent of the code is something that can only be verified by a human
#' (e.g. this is a useful error message). Learn more in
#' `vignette("snapshotting")`.
#'
#' * `expect_snapshot()` captures all messages, warnings, errors, and
#'    output from code.
#' * `expect_snapshot_output()` captures just output printed to the console.
#' * `expect_snapshot_error()` captures just error messages.
#' * `expect_snapshot_value()` captures the return value.
#'
#' (These functions supersede [verify_output()], [expect_known_output()],
#' [expect_known_value()], and [expect_known_hash()].)
#'
#' @section Workflow:
#' The first time that you run a snapshot expectation it will run `x`,
#' capture the results, and record in `tests/testthat/snap/{test}.json`.
#' Each test file gets its own snapshot file, e.g. `test-foo.R` will get
#' `snap/foo.json`.
#'
#' It's important to review the JSON files and commit them to git. They are
#' designed to be human readable, and you should always review new additions
#' to ensure that the salient information has been captured. They should also
#' be carefully reviewed in pull requests, to make sure that snapshots have
#' updated in the expected way.
#'
#' On subsequent runs, the result of `x` will be compared to the value stored
#' on disk. If it's different, the expectation will fail, and a new file
#' `snap/{test}.new.json` will be created. If the change was deliberate,
#' you can approve the change with [snapshot_accept()] and then the tests will
#' pass the next time you run them.
#'
#' Note that snapshotting can only work when executing a complete test file
#' (with [test_file()], [test_dir()], or friends) because there's otherwise
#' no way to figure out the snapshot path. If you run snapshot tests
#' interactively, they'll just display the current value.
#'
#' @param x Code to evaluate.
#' @param cran Should these expectations be verified on CRAN? By default,
#'   they are not, because snapshot tests tend to be fragile because they
#'   often rely on minor details of dependencies.
#' @param error Do you expect the code to throw an error? The expectation
#'   will fail (even on CRAN) if an unexpected error is thrown or the
#'   expected error is not thrown.
#' @export
expect_snapshot <- function(x, cran = FALSE, error = FALSE) {
  edition_require(3, "expect_snapshot()")

  x <- enquo(x)

  # Execute code, capturing last error
  state <- new_environment(list(error = NULL))
  out <- verify_exec(quo_get_expr(x), quo_get_env(x), {
    function(x) snapshot_replay(x, state)
  })

  # Use expect_error() machinery to confirm that error is as expected
  msg <- compare_condition_3e("error", state$error, quo_label(x), error)
  if (!is.null(msg)) {
    if (error) {
      expect(FALSE, msg, trace = state$error[["trace"]])
    } else {
      exp_signal(expectation("error", msg, trace = state$error[["trace"]]))
    }
    return()
  }

  expect_snapshot_helper("code", out, cran = cran,
    save = function(x) paste0(x, collapse = "\n"),
    load = function(x) split_by_line(x)[[1]]
  )
}

snapshot_replay <- function(x, state) {
  UseMethod("snapshot_replay", x)
}
#' @export
snapshot_replay.character <- function(x, state) {
  c(snap_header(state, "Output"), indent(split_lines(x)))
}
#' @export
snapshot_replay.source <- function(x, state) {
  c(snap_header(state, "Code"), indent(split_lines(x$src)))
}
#' @export
snapshot_replay.condition <- function(x, state) {
  msg <- cnd_message(x)
  if (inherits(x, "error")) {
    state$error <- x
    type <- "Error"
  } else if (inherits(x, "warning")) {
    type <- "Warning"
  } else if (inherits(x, "message")) {
    type <- "Message"
    msg <- sub("\n$", "", msg)
  } else {
    type <- "Condition"
  }

  class <- paste0(type, " <", class(x)[[1]], ">")

  c(snap_header(state, class), indent(split_lines(msg)))
}

snap_header <- function(state, header) {
  if (!identical(state$header, header)) {
    state$header <- header
    header
  }
}

#' @export
#' @rdname expect_snapshot
expect_snapshot_output <- function(x, cran = FALSE) {
  edition_require(3, "expect_snapshot_output()")

  lab <- quo_label(enquo(x))
  val <- capture_output_lines(x, print = TRUE, width = NULL)

  expect_snapshot_helper(lab, val, cran = cran,
    save = function(x) paste0(x, collapse = "\n"),
    load = function(x) split_by_line(x)[[1]]
  )
}

#' @param class Expected class of condition, e.g. use `error` for errors,
#'   `warning` for warnings, `message` for messages. The expectation will
#'   always fail (even on CRAN) if a condition of this class isn't seen
#'   when executing `x`.
#' @export
#' @rdname expect_snapshot
expect_snapshot_error <- function(x, class = "error", cran = FALSE) {
  edition_require(3, "expect_snapshot_error()")

  lab <- quo_label(enquo(x))
  val <- capture_matching_condition(x, cnd_matcher(class))
  if (is.null(val)) {
    fail(sprintf("%s did not throw error of class '%s'", lab, class))
  }

  expect_snapshot_helper(lab, conditionMessage(val), cran = cran)
}

#' @param style Serialization style to use:
#'   * `json` uses [jsonlite::fromJSON()] and [jsonlite::toJSON()]. This
#'      produces the simplest output but only works for relatively simple
#'      objects.
#'   * `json2` uses [jsonlite::serializeJSON()] and [jsonlite::unserializeJSON()]
#'     which are more verbose but work for a wider range of type.
#'   * `deparse` uses [deparse()], which generates a depiction of the object
#'     using R code.
#'   * `serialize()` produces a binary serialization of the object using
#'     [serialize()]. This is all but guaranteed to work for any R object,
#'     but produces a completely opaque serialization.
#' @param ... For `expect_snapshot_value()` only, passed on to
#'   [waldo::compare()] so you can control the details of the comparison.
#' @export
#' @rdname expect_snapshot
expect_snapshot_value <- function(x,
                                  style = c("json", "json2", "deparse", "serialize"),
                                  cran = FALSE,
                                  ...) {
  edition_require(3, "expect_snapshot_value()")
  lab <- quo_label(enquo(x))

  style <- arg_match(style)

  save <- switch(style,
    json = function(x) jsonlite::toJSON(x, auto_unbox = TRUE, pretty = TRUE),
    json2 = function(x) jsonlite::serializeJSON(x, pretty = TRUE),
    deparse = function(x) paste0(deparse(x), collapse = "\n"),
    serialize = function(x) jsonlite::base64_enc(serialize(x, NULL, version = 2))
  )
  load <- switch(style,
    json = function(x) jsonlite::fromJSON(x, simplifyVector = FALSE),
    json2 = function(x) jsonlite::unserializeJSON(x),
    deparse = function(x) reparse(x),
    serialize = function(x) unserialize(jsonlite::base64_dec(x))
  )

  expect_snapshot_helper(lab, x, save = save, load = load, cran = cran, ...)
}

# Safe environment for evaluating deparsed objects, based on inspection of
# https://github.com/wch/r-source/blob/5234fe7b40aad8d3929d240c83203fa97d8c79fc/src/main/deparse.c#L845
reparse <- function(x) {
  env <- env(emptyenv(),
    c = c,
    list = list,
    quote = quote,
    structure = structure,
    expression = expression,
    `function` = `function`,
    new = methods::new,
    getClass = methods::getClass,
    pairlist = pairlist,
    alist = alist,
    as.pairlist = as.pairlist
  )

  eval(parse(text = x), env)
}

expect_snapshot_helper <- function(lab, val,
                                   cran = FALSE,
                                   save = identity,
                                   load = identity,
                                   ...) {
  if (!cran && !interactive() && on_cran()) {
    skip("On CRAN")
  }

  snapshotter <- get_snapshotter()
  if (is.null(snapshotter)) {
    snapshot_not_available(paste0("Current value:\n", save(val)))
    return(invisible())
  }

  comp <- snapshotter$take_snapshot(val, save = save, load = load, ...)
  hint <- paste0("Run `snapshot_accept('", snapshotter$file, "')` if this is a deliberate change")

  expect(
    length(comp) == 0,
    sprintf(
      "Snapshot of %s has changed:\n%s\n\n%s",
      lab,
      paste0(comp, collapse = "\n\n"),
      hint
    ),
    trace_env = caller_env()
  )
}

snapshot_not_available <- function(message) {
  inform(c(
    crayon::bold("Can't compare snapshot to reference when testing interactively"),
    i = "Run `devtools::test()` or `testthat::test_file()` to see changes",
    i = message
  ))
}

local_snapshot_dir <- function(snap_names, .env = parent.frame()) {
  path <- tempfile()
  withr::defer(unlink(path))

  dir.create(file.path(path, "_snaps"), recursive = TRUE)

  snap_paths <- file.path(
    path, "_snaps",
    c(paste0(snap_names, ".new.md"), paste0(snap_names, ".md"))
  )
  lapply(snap_paths, write_lines, text = "")

  path
}

indent <- function(x) paste0("  ", x)
