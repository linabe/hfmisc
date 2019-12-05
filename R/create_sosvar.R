#' Calculates comobidites and outcomes from SoS data
#'
#' @description
#' \Sexpr[results=rd, stage=render]{lifecycle::badge("experimental")}
#'
#' Calculates comobidites and outcomes (including time to for the latter)
#'   from DIA, OP and ekod variables from National Patient Registry
#'   or Cause of Death Registry.
#'
#'
#' @param sosdata Data where DIA, OP, Ekod variables are found.
#' @param cohortdata Data containing the cohort with at least columns
#'   patid and indexdate.
#' @param patid Patient identifier. Default is lopnr.
#' @param indexdate Index date for the patient (usually date of admission or
#'   discharge entered into SwedeHF). Default is indexdtm.
#' @param add_unique If patid and indexdate are not unique in cohortdata, this
#'   identifies unique posts.
#' @param sosdate Date of incident (comorbidity or outcome)
#'   in sosdata. Default is sosdtm.
#' @param censdate Only for type = "out". Outcomes are
#'   up until this time point (usually date of death or censoring).
#' @param type Possible values are "out" and "mh".
#'   Is the resulting variable an outcome (and time to is calculated)
#'   or medical history (comorbidity)?
#' @param name Name of resulting variable
#'   (prefix sos_out_ is added to outcome and sos_mh_ to medical history).
#' @param starttime If type = "out" amount of time (in days) AFTER indexdate
#'   to start counted as outcome. If type = "mh" amount of time (in days)
#'   PRIOR to indexdate to . Indexdate = 0, all values prior to
#'   indexdate are negative. Default is 1 ("out") and 0 ("mh").
#' @param stoptime If type = "out" amount of time (in days) AFTER indexdate to
#'   be counted. If type = "mh" amount of time (in days) PRIOR to indexdate
#'   to Indexdate = 0, all values prior to indexdate are negative.
#'   Default is any time prior to starttime is considered a comorbidity
#'   and any time after starttime is considered an outcome.
#' @param diakod String of icd codes as a regular expression
#'   defining the outcome/medical history. Should start
#'   with blank space " ".
#' @param opkod String of procedure codes as a regular expression
#'   defining the outcome/medical history. Should start
#'   with blank space " ".
#' @param ekod String of e codes as a regular expression defining
#'   the outcome/medical history. Should start
#'   with blank space " ".
#' @param diavar Column where diakod is found. All codes should start
#'   with blank space " ". Default is DIA_all.
#' @param opvar Column where opkod is found. All codes should start
#'   with blank space " ". Default is OP_all.
#' @param evar Column where ekod is found. All codes should start
#'   with blank space " ". Default is ekod_all.
#' @param meta_reg Optional argument specifying registries used. Printed in
#'   metadatatable. Default is
#'   "Patientregistret, sluten-, oppenvard- och dagkirurgi".
#' @param meta_pos Optional argument specifying positions used to search for
#'   outcomes/comorbidities. Printed in metadatatable.
#' @param warnings Should warnings be printed. Default is FALSE.
#'
#' @seealso \code{\link{prep_sosdata}}
#'
#' @return dataset with column containing medical history/outcome.
#'   Also dataset metaout that writes directly to global enviroment
#'   with information on constructed variables.
#'
#'
#' @examples
#'
#' sos_data <- prep_sosdata(sos_data)
#'
#' rs_data_test <- create_sosvar(
#'   sosdata = sos_data,
#'   cohortdata = rs_data,
#'   patid = id,
#'   indexdate = indexdtm,
#'   sosdate = sosdtm,
#'   type = "mh",
#'   name = "cv1y",
#'   diakod = " I",
#'   stoptime = -365.25
#' )
#' @import dplyr
#' @import rlang
#'
#' @export

create_sosvar <- function(sosdata,
                          cohortdata,
                          patid = lopnr,
                          indexdate = indexdtm,
                          add_unique,
                          sosdate = sosdtm,
                          censdate,
                          type,
                          name,
                          starttime = ifelse(type == "out", 1, 0),
                          stoptime,
                          diakod,
                          opkod,
                          ekod,
                          diavar = DIA_all,
                          opvar = OP_all,
                          evar = ekod_all,
                          meta_reg =
                            "Patientregistret, sluten-, oppenvard- och dagkirurgi",
                          meta_pos,
                          warnings = FALSE) {
  patid <- enquo(patid)
  indexdate <- enquo(indexdate)
  sosdate <- enquo(sosdate)
  if (!missing(censdate)) censdate <- enquo(censdate)
  if (!missing(add_unique)) add_unique <- enquo(add_unique)

  diavar <- enquo(diavar)
  opvar <- enquo(opvar)
  evar <- enquo(evar)

  # check input arguments ok
  if (!has_name(sosdata, as_name(patid))) {
    stop(paste0(patid, " does not exist in sosdata"))
  }

  if (!has_name(cohortdata, as_name(patid))) {
    stop(paste0(patid, " does not exist in cohortdata"))
  }

  if (!has_name(cohortdata, as_name(indexdate))) {
    stop(paste0(indexdate, " does not exist in cohortdata"))
  }

  if (!has_name(sosdata, as_name(sosdate))) {
    stop(paste0(sosdate, " does not exist in sosdata"))
  }

  if (any(has_name(sosdata, names(cohortdata)[!names(cohortdata) == "id"]))) {
    if (warnings) {
      warning(paste0(
        "cohortdata and sosdata have overlapping columns. Only ",
        patid, " should be the same. This might cause unexpected results."
      ))
    }
  }

  if (!type %in% c("out", "mh")) {
    stop("type should be either 'out' (outcome) or 'mh' (comorbidity).")
  }

  if (type == "out" & missing(censdate)) {
    stop("censdate is needed for variables of type out.")
  }

  if (missing(diakod) & missing(opkod) & missing(ekod)) {
    stop("Either dia, op or ekod must be specified.")
  }

  name2 <- paste0("sos_", type, "_", name)
  if (type == "out") timename2 <- paste0("sos_outtime_", name)

  if (any(has_name(cohortdata, name2))) {
    if (warnings) {
      warning(paste0(
        name2, " already exists in ", rlang::as_name(quo(cohortdata)),
        ". This might cause unexpected results."
      ))
    }
    cohortdata <- cohortdata %>%
      select(-!!enquo(name2))
  }

  if (type == "mh" & !missing(stoptime)) {
    if (stoptime > 0) {
      if (warnings) {
        warning("stoptime for comorbidity is not negative.")
      }
    }
  }

  if (!any(duplicated(cohortdata %>% select(!!patid)))) {
    groupbyvars <- as_name(patid)
  } else {
    if (!any(duplicated(cohortdata %>% select(!!patid, !!indexdate)))) {
      groupbyvars <- c(as_name(patid), as_name(indexdate))
      if (warnings) {
        warning(paste0(
          as_name(patid),
          " is not unique in cohortdata. Output data will be for unique ",
          as_name(patid), " and ", as_name(indexdate), "."
        ))
      }
    } else {
      if (!missing(add_unique)) {
        groupbyvars <- c(as_name(patid), as_name(add_unique))
      } else {
        stop(paste0(
          as_name(patid), " and ", as_name(indexdate),
          " are not unique in cohortdata. Supply additional
          unique column in argument add_unique (for example postnr)."
        ))
      }
    }
  }

  tmp_data <- inner_join(cohortdata %>%
    select(!!patid, !!indexdate, !!!syms(groupbyvars)),
  sosdata,
  by = as_name(patid)
  ) %>%
    mutate(difft = difftime(!!sosdate, !!indexdate,
      units = "days"
    ))


  if (type == "out") tmp_data <- tmp_data %>% dplyr::filter(difft >= starttime)
  if (type == "mh") tmp_data <- tmp_data %>% dplyr::filter(difft <= starttime)

  if (!missing(stoptime)) {
    if (type == "out") tmp_data <- tmp_data %>% dplyr::filter(difft <= stoptime)
    if (type == "mh") tmp_data <- tmp_data %>% dplyr::filter(difft >= stoptime)
  }

  if (!missing(diakod)) {
    tmp_data <- tmp_data %>%
      mutate(name_dia = stringr::str_detect(!!diavar, diakod))
  }
  if (!missing(opkod)) {
    tmp_data <- tmp_data %>%
      mutate(name_op = stringr::str_detect(!!opvar, opkod))
  }
  if (!missing(ekod)) {
    tmp_data <- tmp_data %>%
      mutate(name_ekod = stringr::str_detect(!!evar, ekod))
  }

  tmp_data <- tmp_data %>%
    mutate(!!name2 := ifelse(rowSums(dplyr::select(., contains("name_"))) > 0,
      1, 0
    ))

  tmp_data <- tmp_data %>%
    filter(!!(sym(name2)) == 1) %>%
    group_by(!!!syms(groupbyvars)) %>%
    arrange(!!sosdate) %>%
    slice(1) %>%
    ungroup()

  if (type == "mh") {
    out_data <- left_join(
      cohortdata,
      tmp_data %>% dplyr::select(!!!syms(groupbyvars), !!name2),
      by = groupbyvars
    ) %>%
      mutate(!!name2 := tidyr::replace_na(!!sym(name2), 0))
  }

  if (type == "out") {
    out_data <- left_join(
      cohortdata,
      tmp_data %>% dplyr::select(!!!syms(groupbyvars), !!name2, !!sosdate),
      by = groupbyvars
    ) %>%
      mutate(
        !!name2 := tidyr::replace_na(!!sym(name2), 0),
        !!name2 := ifelse(!is.na(!!sosdate) & !!sosdate > !!censdate, 0,
          !!sym(name2)
        ),
        !!timename2 := as.numeric(pmin(!!sosdate, !!censdate, na.rm = TRUE)
        - !!indexdate)
      ) %>%
      select(-!!sosdate)
  }

  # create meta data to print in table in statistical report
  fixkod <- function(kod) {
    kod <- stringr::str_replace_all(kod, " ", "")
    kod <- stringr::str_replace_all(kod, "\\|", ", ")
    kod <- stringr::str_replace_all(kod, "\\(\\?!", " (excl. ")
    kod <- paste0(kod, collapse = ": ")
  }

  meta_kod <- paste(
    if (!missing(diakod)) {
      paste0("ICD: ", fixkod(diakod))
    },
    if (!missing(opkod)) {
      paste0("OP: ", fixkod(opkod))
    },
    if (!missing(ekod)) {
      paste0("Ekod: ", fixkod(ekod))
    },
    sep = ", "
  )


  meta_time <- paste0(starttime, "-", ifelse(!missing(stoptime), stoptime, ""))

  if (missing(meta_pos)) {
    meta_pos <- paste(
      if (!missing(diakod)) as_name(diavar),
      if (!missing(opkod)) as_name(opvar),
      if (!missing(ekod)) as_name(evar),
      sep = " "
    )
  }

  # paste0(
  # "All positions",
  # if (!is.null(diakod)) " (HDIA+BDIA1-BDIAXX)",
  # if (!is.null(opkod)) " (OP1-OPXX)",
  # if (!is.null(ekod)) " (Ekod1-EkodXX)"
  # )

  metatmp <- data.frame(name2, meta_kod, meta_reg, meta_pos, meta_time)
  colnames(metatmp) <- c("Variable", "Code", "Register", "Position", "Period")

  if (exists("metaout")) {
    metaout <<- rbind(metaout, metatmp) # global variable, writes to global env
  } else {
    metaout <<- metatmp # global variable, writes to global env
  }
  return(out_data)
}