# =============================================================================
# phaseZ-model-record.R - stage 16 writes a Build result's model record (to-do 14)
# =============================================================================
# On a library with a Build result: a "Model Record (test)" scenario depending on it, pipeline stage 16 alone. Passes when the run succeeds, Model
# Record has one row for that result, its XML is in the result's folder and holds one source per dataset in the Build's Data Sources Used, and the
# stage's checks pass. Writes to the library it is given: use a copy, never the P26 guide library.
# Usage: Rscript tests/phaseZ-model-record.R "<library.ssim>" --build=<result id>
# =============================================================================
suppressPackageStartupMessages({ library(rsyncrosim); library(data.table) })
a <- commandArgs(TRUE); lib <- a[!startsWith(a, "--")][1]; id <- as.integer(sub("^--build=", "", grep("^--build=", a, value = TRUE)))
L <- suppressWarnings(ssimLibrary(lib)); P <- rsyncrosim::project(L, 1)
S <- rsyncrosim::scenario(P, "Model Record (test)")
dependency(S) <- id
saveDatasheet(S, data.frame(StageNameId = "16 - Model Record", RunOrder = 1L), "core_Pipeline")
R <- run(S)
capture.output(rl <- runLog(R)); lg <- trimws(strsplit(paste(rl, collapse = "\n"), "\n")[[1]])
cat(unique(lg[grepl("Model record|Still placeholder|had to infer|16 Model Record -|Failure", lg)]), sep = "\n")
rec <- as.data.table(datasheet(R, "lucasCore_OutputModelRecord", lookupsAsFactors = FALSE))
v <- as.data.table(datasheet(R, "lucasCore_OutputValidation"))[Stage == "16 Model Record"]
used <- unique(as.data.table(datasheet(rsyncrosim::scenario(L, id), "lucasCore_OutputDataSources", lookupsAsFactors = FALSE))$DataSource)
print(rec[, .(BuildResult, File = basename(FileName), Mp)])
x <- if (nrow(rec) == 1 && file.exists(rec$FileName)) xml2::read_xml(rec$FileName) else NULL
ok <- !is.null(x) && rec$BuildResult == id && length(xml2::xml_find_all(x, ".//srcinfo")) == length(used) && nrow(v) == 2 && all(v$Status == "Pass") && !any(grepl("[Failure]", lg, fixed = TRUE))
cat("native:", if (!is.null(x)) xml2::xml_text(xml2::xml_find_first(x, ".//native")), "\n")
# the record belongs to whoever runs the model: blank, it names no one; with the page, it names them
tx <- function(d, p) xml2::xml_text(xml2::xml_find_all(d, p))
blank <- !is.null(x) && all(grepl("PLACEHOLDER", c(tx(x, ".//idinfo/citation/citeinfo/origin"), tx(x, ".//ptcontac//cntper")))) && any(grepl("placeholder: Originator", rec$ToSupply, fixed = TRUE))
cat("page blank: names no one, and says so:", blank, "\n")
saveDatasheet(P, data.frame(Name = "Tester, A.", Organization = "Test Science Center", Address = "1 Test Road", City = "Testville", State = "WA", PostalCode = "98000", Phone = "555-555-0100", Email = "tester@example.org"), "lucasCore_Person")
S2 <- rsyncrosim::scenario(P, "Model Record (test, person)"); dependency(S2) <- id
saveDatasheet(S2, data.frame(StageNameId = "16 - Model Record", RunOrder = 1L), "core_Pipeline")
saveDatasheet(S2, data.frame(PersonId = "Tester, A.", SortOrder = 1L), "lucasCore_ReleaseOriginator")
saveDatasheet(S2, data.frame(ContactPersonId = "Tester, A."), "lucasCore_ReleaseInformation")
R2 <- run(S2); rec2 <- as.data.table(datasheet(R2, "lucasCore_OutputModelRecord", lookupsAsFactors = FALSE)); x2 <- xml2::read_xml(rec2$FileName)
person <- identical(tx(x2, ".//idinfo/citation/citeinfo/origin"), "Tester, A.") && tx(x2, ".//ptcontac//cntper") == "Tester, A." && tx(x2, ".//ptcontac//cntorg") == "Test Science Center" && tx(x2, ".//ptcontac//cntemail") == "tester@example.org" && !grepl("placeholder: Originator|placeholder: ContactOrg", rec2$ToSupply)
cat("page filled: names that person:", person, "\n"); cat("still to supply:", rec2$ToSupply, "\n")
ok <- ok && blank && person
cat(if (ok) "MODEL RECORD OK\n" else "MODEL RECORD FAILED\n")
