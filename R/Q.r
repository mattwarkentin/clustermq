#' Queue function calls on the cluster
#'
#' @param fun             A function to call
#' @param ...             Objects to be iterated in each function call
#' @param const           A list of constant arguments passed to each function call
#' @param export          List of objects to be exported to the worker
#' @param expand_grid     Use all combinations of arguments in `...`
#' @param seed            A seed to set for each function call
#' @param memory          Short for scheduler_args=list(memory=value)
#' @param scheduler_args  A named list of values to fill in template
#' @param n_jobs          The number of LSF jobs to submit; upper limit of jobs
#'                        if job_size is given as well
#' @param job_size        The number of function calls per job
#' @param split_array_by  The dimension number to split any arrays in `...`; default: last
#' @param fail_on_error   If an error occurs on the workers, continue or fail?
#' @param log_worker      Write a log file for each worker
#' @param wait_time       Time to wait between messages; set 0 for short calls
#'                        defaults to 1/sqrt(number_of_functon_calls)
#' @param chunk_size      Number of function calls to chunk together
#'                        defaults to 100 chunks per worker or max. 10 kb per chunk
#' @return                A list of whatever `fun` returned
#' @export
Q = function(fun, ..., const=list(), export=list(), expand_grid=FALSE, seed=128965,
        memory=NULL, scheduler_args=list(), n_jobs=NULL, job_size=NULL,
        split_array_by=-1, fail_on_error=TRUE,
        log_worker=FALSE, wait_time=NA, chunk_size=NA) {

    fun = match.fun(fun)
    iter = Q_check(fun, list(...), const, split_array_by)
    seed = as.integer(seed)
    if (expand_grid)
        iter = do.call(expand.grid, c(iter, list(KEEP.OUT.ATTRS=FALSE,
                       stringsAsFactors=FALSE)))

    # check job number and memory
    if (qsys_id != "LOCAL" && is.null(n_jobs) && is.null(job_size))
        stop("n_jobs or job_size is required")
    if (!is.null(memory))
        scheduler_args$memory = memory
    if (!is.null(scheduler_args$memory) && scheduler_args$memory < 500)
        stop("Worker needs about 230 MB overhead, set memory>=500")
    if (is.na(seed) || length(seed) != 1)
        stop("'seed' needs to be a length-1 integer")

    # create call index
    call_index = as.data.frame(do.call(tibble::data_frame, iter))
    n_calls = nrow(call_index)
    n_jobs = Reduce(min, c(ceiling(n_calls / job_size), n_jobs, n_calls))

    # use heuristic for wait and chunk size
    if (is.na(wait_time))
        wait_time = ifelse(n_calls < 5e5, 1/sqrt(n_calls), 0)
    if (is.na(chunk_size))
        chunk_size = ceiling(min(
            n_calls / n_jobs / 100,
            1e4 * n_calls / utils::object.size(call_index)[[1]]
        ))

    if (n_jobs == 0 || qsys_id == "LOCAL")
        work_chunk(df=call_index, fun=fun, const_args=const, common_seed=seed)
    else
        master(fun=fun, iter=call_index, const=const, export=export, seed=seed,
               scheduler_args=scheduler_args, n_jobs=n_jobs,
               fail_on_error=fail_on_error, log_worker=log_worker,
               wait_time=wait_time, chunk_size=chunk_size)
}
