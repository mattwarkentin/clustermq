#' Process on multiple cores on one machine
#'
#' This makes use of rzmq messaging and sends requests via TCP/IP
MULTICORE = R6::R6Class("MULTICORE",
    inherit = QSys,

    public = list(
        initialize = function(..., protocol="inproc") {
            if (protocol == "inproc")
                super$initialize(..., protocol="inproc", node="cmq_local", threads=0)
            else
                super$initialize(..., node="localhost")
        },

        submit_jobs = function(n_jobs, template=list(), log_worker=FALSE) {
            cmd = Quote(clustermq:::worker(private$master))
            for (i in seq_len(n_jobs))
                parallel::mcparallel(cmd)
        },

        cleanup = function(dirty=FALSE) {
            super$cleanup()
#            parallel::stopCluster(private$cluster)
        }
    ),

    private = list(
#        cluster = NULL
    )
)
