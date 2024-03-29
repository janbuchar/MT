library("knitr")
library("magrittr")
library("boot")

cv <- function(data) {
	return((sd(data) * 100) / mean(data))
}

span <- function(data) {
	return(max(data) / min(data))
}

range <- function(data) {
	return(max(data) - min(data))
}

filename.from.args <- function () {
	args <- commandArgs(trailingOnly=TRUE)

	if (length(args) == 0) {
		stop("Please, supply a result file as a CLI argument")
	}

	return(args[1])
}

load.stability.results <- function(file) {
	values <- read.csv(file, header=FALSE, stringsAsFactors=FALSE)
	names(values) = c("isolation", "setup_type", "setup_size", "worker", "workload", "input_size", "iteration", "metric", "value")
	values$value <- as.numeric(values$value)
	values$setup <- paste(values$setup_type, values$setup_size, sep=",")
	values$taskset <- grepl("taskset", values$setup)
	values$multi <- grepl("taskset-multi", values$setup)
	values$numa <- grepl("numa", values$setup)
	values$noht <- grepl("-noht", values$setup)
	values$wl.short <- gsub("^[^/]*/", "", values$workload)
	values$wl.short.safe <- tex.safe(values$wl.short)
	values$isolation.short <- values$isolation %>%
		gsub("^bare$", "B", .) %>%
		gsub("^isolate$", "I", .) %>%
		gsub("^docker-bare$", "D", .) %>%
		gsub("^docker-isolate$", "D+I", .) %>%
		gsub("^vbox-bare$", "V", .) %>%
		gsub("^vbox-isolate$", "V+I", .)
	return(values)
}

load.lb.results <- function(file) {
	values <- read.csv(file, header=FALSE, stringsAsFactors=FALSE)
	names(values) = c("queue.manager", "setup", "workload", "job.id", "arrival", "processing.time", "processing.start")

	return (values)
}

mkdir <- function(dir) {
	dir.create(file.path(".", dir), showWarnings=FALSE)
}

ci.compare <- function (boot1, boot2) {
	ci1 <- boot.ci(boot1, type="perc")
	lower1 <- ci1$perc[1, 4]
	upper1 <- ci1$perc[1, 5]

	ci2 <- boot.ci(boot2, type="perc")
	lower2 <- ci2$perc[1, 4]
	upper2 <- ci2$perc[1, 5]

	if (lower1 > upper2) {
		return("higher")
	}

	if (lower2 > upper1) {
		return("lesser")
	}

	if ((lower1 > lower2 & upper1 < upper2) | (lower2 > lower1 & upper2 < upper1)) {
		return("same")
	}

	return ("overlap")
}

compare.fnc.boot <- function (fnc, data1, data2) {
	if (length(data1) == 0 | length(data2) == 0) {
		return(NA)
	}

	boot1 <- boot(data1, fnc, R=1000)
	boot2 <- boot(data2, fnc, R=1000)

	return(ci.compare(boot1, boot2))
}

my.kable <- function(df, col.names=NA) {
	return (kable(df, col.names=col.names, row.names=F, digits=3))
}

wl.labels <- function(labels) {
	return(lapply(labels, function(wl) {
		if (wl == "exp_float") {
			return("exp\\_float")
		}

		if (wl == "qsort_java.sh") {
			return("qsort.java")
		}

		return(wl)
	}))
}

tex.safe <- function(val) gsub('_', '\\\\_', val)
tex.unsafe <- function(val) gsub('\\\\_', '_', val)
