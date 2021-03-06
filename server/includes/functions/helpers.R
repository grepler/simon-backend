#' @title Checks process is running
#' @description Checks if we can find process by part of this name in running process list
#' @param identifier cron_analysis
#' @return vector
is_process_running <- function(identifier){
    ## Check if some other R CRON process is already running and KILL it
    process_pid <- Sys.getpid()
    process_command <- paste0("ps -ef | awk '$NF~\"",identifier,"\" {print $2}'")
    process_list <- system(process_command, intern = TRUE)
    if(length(process_list) > 0){
        process_list <- setdiff(process_list, process_pid)
    }

    return(process_list)
}
#' @title Kill process
#' @description Kills processes by PIDs
#' @param process_list numeric vector
#' @return
kill_process_pids <- function(process_list){
    if(length(process_list) > 0){
        for(cron_pid in process_list){
            print(paste0("==> Killing process SIGKILL: ", cron_pid))
            tools::pskill(as.numeric(cron_pid), signal = 9)
        }
    }
}

#' @title  which_cmd
#' @description Get path to system bin file
#' @param bin_file exec name ex. tar
#' @return string
which_cmd <- function(bin_file){ 
  path <- system(paste(unname(Sys.which("which")), bin_file), TRUE)
  return(path)
}

#' @title  getExtension
#' @description Extract file extension from file path
#' @param file file path
#' @return string
getExtension <- function(file){ 
    ex <- strsplit(basename(file), split="\\.")[[1]]
    return(ex[-1])
}

#' @title calculateTimeDifference
#' @description Returns the time difference in different units
#' @param start_time Object returned from Sys.time()
#' @param unit secs or ms
#' @return numeric
calculateTimeDifference <- function(start_time, unit = "ms"){
    current_time <- Sys.time()
    time_passed <- as.numeric(difftime(current_time, start_time,  units = c("secs")))
    if(unit == "ms"){
        time_passed <- ceiling(time_passed * 1000)  
    }
    return (time_passed)
}

#' @title create_directory
#' @description create directory recursively if directory does not exists
#' @param path Full directory path
#' @return null
create_directory <- function(path){
    ## Lets split path into vector of all recursive paths and create one by one
    parts <- unlist(strsplit(path, "/", fixed = FALSE, perl = FALSE, useBytes = FALSE))
    parts <- parts[parts != ""]

    ## Construct the vector
    paths <- c()
    i <- 1
    for (part in parts) {
        path_item <- parts[-(i:length(parts)+1 )]
        path <- paste0("/", paste(path_item, collapse = "/"))
        paths <- c(paths, path)
        i <- i +1
    }
    ## Loop paths and create directory
    for(path in unique(paths)){
        if(!dir.exists(path)){
            dir.create(path, showWarnings = FALSE, recursive = TRUE, mode = "0777")
            Sys.chmod(path, "777", use_umask = FALSE)
        }
    }
}

#' @title thisFileLocation
#' @description Returns the location of the current executing script file
#' Full file path is returned with the filename included
#' @return string
thisFileLocation <- function() {
    cmdArgs <- commandArgs(trailingOnly = FALSE)
    needle <- "--file="
    match <- grep(needle, cmdArgs)
    if (length(match) > 0) {
        return(normalizePath(sub(needle, "", cmdArgs[match])))
    } else {
        return(normalizePath(sys.frames()[[1]]$ofile))
    }
}

#' @title has_internet
#' @description Checks if there is Internet connection
#' @return boolean
has_internet <- function(){
    out <-try(is.character(RCurl::getURL("www.google.com"))) == TRUE
    return (out)
}

#' @title getLibraryLicense
#' @description Extracts the license from the R package
#' @param package Valid R installed package name
#' @return string
getLibraryLicense <- function(package){
    license1 <- packageDescription(package, fields="License")
    license2 <- ""
    ## Check if there is additional license in the LICENSE file
    if(grepl("file LICENSE", license1, fixed=TRUE) == TRUE){
      licenseFile <- system.file("LICENSE",package=package)
      if(file.exists(licenseFile)){
        license2 <- paste(readLines(licenseFile), collapse=" ")
      }
      license1 <- gsub(" + file LICENSE","",license1, fixed = TRUE)
      license1 <- gsub(" | file LICENSE","",license1, fixed = TRUE)
      license1 <- gsub(" file LICENSE","",license1, fixed = TRUE)
    }

    if(license2 != ""){
      if(nchar(license2) > 50){
        license2 <- substr(license2, start = 1, stop = 50)
        license2 <- paste(license2, "...", sep = "", collapse = NULL)
      }
      license <- paste(trimws(license1), trimws(license2), sep = " - ", collapse = NULL)
    }else{
      license <- license1
    }
    ## Merge Multiple spaces to single space
    license <- gsub("(?<=[\\s])\\s*|^\\s+|\\s+$", "", license, perl=TRUE)

    return(license)
}

#' @title getFreeMemory
#' @description
#' @param basePoint Get amount of memory in base-point - 1000 = megabytes
#' @param systemReserved How much to reserve additionally for the OS in KB
#' @return numeric
getUseableFreeMemory <- function(basePoint = 1000, systemReserved = 2000000){
    systemReserved <-  round((systemReserved  / basePoint), digits = 0)

    total_free_memory <- as.numeric(system("awk '/MemTotal/ {print $2}' /proc/meminfo", intern=TRUE))
    total_free_memory <- round((total_free_memory  / basePoint), digits = 0)

    memory_free <- (total_free_memory - systemReserved)
    return(memory_free)
}

#' @title get_working_mode
#' @description Returns current mode of operation. So we know what file-system adapter to use
#' @param global_configuration Configuration object from config.yml
#' @return string
get_working_mode <- function(global_configuration){
    working_mode <- "remote"

    IS_DOCKER <- Sys.getenv(c("IS_DOCKER"))
    is_connected <- has_internet()

    if(IS_DOCKER != "" || is_connected == FALSE){
        working_mode <- "local"
    }else{
        if(is.null(global_configuration$storage$s3$secret) || global_configuration$storage$s3$secret == "PLACEHOLDER"){
            working_mode <- "local"
        }
    }

    return(working_mode)
}

#' @title loadRObject
#' @description Load R data file object that is saved using R "save" function
#' Create a new environment, load the .rda file into that environment, and retrieve object
#' @param file_path
#' @return object
loadRObject <- function(file_path)
{
    env <- new.env()
    nm <- load(file_path, env)[1]
    return(env[[nm]])
}
#' @title detach_package
#' @description Detaches package from R session
#' @param pkg
#' @param character.only
#' @return 
detach_package <- function(pkg, character.only = FALSE)
{
    if(!character.only)
    {
        pkg <- deparse(substitute(pkg))
    }
    search_item <- paste("package", pkg, sep = ":")
    while(search_item %in% search())
    {
       suppressWarnings(detach(search_item, unload = TRUE, character.only = TRUE, force = TRUE))
    }
}

#' @title  shortRversion
#' @description Short R version string
#' @return string
shortRversion <- function() {
   rvs <- R.Version()
   return(paste0(rvs$major,".",rvs$minor))
}

#' @title  %!in%
#' @description negation of %in% function in R
#' @return boolean
'%!in%' <- function(x,y)!('%in%'(x,y))

# encrypt the file
hp.write.aes <- function(content, filename, encryptKey) {

    contentRaw <- charToRaw(content)
    # We must add padding since total length has to be divided by 16 at the end
    contentRaw <- c(contentRaw, as.raw( rep(0, 16- length(contentRaw) %% 16) ))
    contentLength <- length(contentRaw)

    aes <- digest::AES(encryptKey, mode="ECB")
    writeBin(aes$encrypt(contentRaw), filename)

    return(contentLength)
}

#' @title hp.read.aes
#' @description read encrypted data frame from file
#' @return string
hp.read.aes <- function(filename, encryptKey, contentLength) {

    dat <- readBin(filename, "raw", n=contentLength)
    aes <- digest::AES(encryptKey, mode="ECB")

    contentRaw <- aes$decrypt(dat, raw=TRUE)
    content <- rawToChar(contentRaw[contentRaw>0])
    return(content)
}  

#' @title checkCachedList
#' @description Check if R object file is already cached and loads it using
#' @param cachePath path to the cached data
#' @return boolean
checkCachedList <- function(cachePath){
    data <- NULL
    if(file.exists(cachePath)){
        data <- loadRObject(cachePath)
    }
    return(data)
}

#' @title saveCachedList
#' @description Saves object using R "save" function 
#' @param cachePath path to the cached data
#' @param data path to the cached data
#' @return boolean
saveCachedList <- function(cachePath, data){    
    save(data, file = cachePath)
}

#' @title Check if All Elements in Character Vector are Numeric
#' @description Tests, without issuing warnings, whether all elements of a character vector are legal numeric values
#' @param x
#' @param extras
#' @return boolean
all.is.numeric <- function(x, extras=c('.','NA'))
{
    x <- sub('[[:space:]]+$', '', x)
    x <- sub('^[[:space:]]+', '', x)
    xs <- x[x %!in% c('',extras)]
    if(! length(xs)) {
        return(FALSE)
    }
    return(suppressWarnings(!any(is.na(as.numeric(xs)))))
}