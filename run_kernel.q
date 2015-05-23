// script to run Q kernel 

\l kernel.q
\c 100 200

.kernel.init[];
.kernel.read_config[];
.kernel.set_log_level 0;
.kernel.setup_sockets[];
.kernel.start_hb[];
.kernel.start_loop[];
.kernel.clean_up[];