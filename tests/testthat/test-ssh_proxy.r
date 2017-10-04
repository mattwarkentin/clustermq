context("proxy")

context = rzmq::init.context()

start_proxy = function(socket) {
    port = bind_avail(socket, 50000:55000)
    Sys.sleep(0.5)
    p = parallel::mcparallel(ssh_proxy(port, port, 'multicore'))
}

setup_proxy = function(socket) {
    msg = recv(socket)
    expect_equal(msg$id, "PROXY_UP")

    common_data = list(id="DO_SETUP", fun = function(x) x*2,
            const=list(), export=list(), seed=1)
    send(socket, common_data)
    msg = recv(socket)
    expect_equal(msg$id, "PROXY_READY")
    expect_true("data_url" %in% names(msg))
    expect_true("token" %in% names(msg))
    msg
}

stop_proxy = function(socket, p) {
    msg = list(id = "PROXY_STOP")
    send(socket, msg)
    Sys.sleep(0.5)

    collect = parallel::mccollect(p)
    expect_equal(as.integer(names(collect)), p$pid)
}

test_that("control flow between proxy and master", {
    skip_on_os("windows")

    socket = rzmq::init.socket(context, "ZMQ_REP")
    p = start_proxy(socket)
    msg = setup_proxy(socket)
    proxy = msg$data_url
    token = msg$token

    # command execution
    cmd = methods::Quote(Sys.getpid())
    send(socket, list(id="PROXY_CMD", exec=cmd))
    msg = recv(socket)
    expect_equal(msg$id, "PROXY_CMD")
    expect_equal(msg$reply, p$pid)

    stop_proxy(socket, p)
})

test_that("multicore via SSH", {
    skip_on_os("windows")

    socket = rzmq::init.socket(context, "ZMQ_REP")
    p = start_proxy(socket)
    msg = setup_proxy(socket)
    proxy = msg$data_url
    token = msg$token

    # multicore via SSH
    cmd = methods::Quote(qsys$submit_jobs(1))
    send(socket, list(id="PROXY_CMD", exec=cmd))
    msg = recv(socket)
    expect_equal(msg$id, "PROXY_CMD")
    expect_null(msg$reply)

    #TODO: actually evaluate a function call (and check token)

    stop_proxy(socket, p)
})

#    # common data
#    worker = rzmq::init.socket(context, "ZMQ_REQ")
#    rzmq::connect.socket(worker, proxy)
#
#    send(worker, list(id="WORKER_UP"))
#    msg = recv(worker)
#    testthat::expect_equal(msg$id, "DO_SETUP")
#    testthat::expect_equal(msg$token, token)
#    testthat::expect_equal(msg[names(common_data)], common_data)
