\l qzmq.q 
\l qcrypt.q 


.kernel.init:{[]
  .kernel.priv.ctx: zctx.new[];
  .kernel.priv.loop: zloop.new[];
  .kernel.priv.exiting: 0b;
  .kernel.priv.sockets: ();
  .kernel.priv.log_level: 0;
  .kernel.priv.DELIM: "<IDS|MSG>";
  .kernel.priv.engine_id: string first 1?0Ng;
  .kernel.priv.execnt: 0;
  }

.kernel.clean_up:{[]
  zsocket.destroy each .kernel.priv.sockets;
  zloop.destroy .kernel.priv.loop;
  zctx.destroy .kernel.priv.ctx;
  }

.kernel.set_log_level:{[level]
  zloop.set_verbose[.kernel.priv.loop;level>0];
  .kernel.priv.log_level: level;
  }

.kernel.add_execnt:{[]
  .kernel.priv.execnt+:1;
  }

.kernel.log:{[level;msg]
  m: $[10h=type msg;msg;.Q.s msg];
  if[level<=.kernel.priv.log_level;1 "DEBUG: ", m];
  }

.kernel.priv.create_master_handler:{[handlers]
  mh:{[handlers;loop;item;arg]
     qarg: zloop.get_arg arg;
     handler: handlers qarg;
     handler[loop;item;arg]
     }[handlers;;;];
  .kernel.master_handler: mh;
  }

.kernel.heartbeat_loop:{[args;ctx;pipe]
  .kernel.log[1;"Starting loop for Heartbeat...\n"];
  while[1b and not .kernel.priv.exiting;
    / rc:libzmq.device[zmq.FORWARDER;heartbeat_socket;heartbeat_socket]
    .kernel.log[3;"Receiving message from heartbeat_socket...\n"];
    msg: zstr.recv[.kernel.priv.sockets`hb];
    .kernel.log[3;msg, "\n"];
    .kernel.log[3;"Sending message from heartbeat_socket...\n"];
    zstr.send[.kernel.priv.sockets`hb;msg];
    ];
  }

.kernel.iopub_handler:{[loop;item;arg]
  show "iopub";
  }

.kernel.control_handler:{[loop;item;arg]
  show "control";
  }

.kernel.stdin_handler:{[loop;item;arg]
  show "stdin";
  }

.kernel.kernel_info_request_handler: {[socket;msg;identities]
  content: enlist[`]!enlist[::];
  content[`protocal_version]: 4 0;
  content[`ipython_version]: (3;1;0;"");
  content[`language_version]: 3 2;
  content[`language]: "KDB+/Q";
  content: `_ content;
  .kernel.send[socket;"kernel_info_reply";`content`parent_header`identities!(content;msg`header;identities)];
  :0
  }

.kernel.shutdown_request_handler:{[socket;msg;identities]
  .kernel.shutdown[];
  :-1
  }


// simple code executor 
.kernel.code_executor: {[code]
  f: {.Q.s value x};
  r: @[f;code;{`$"'", x}];
  res: `status`val!($[-11h=type r;"error";"ok"];r);
  res
  }

// This is the most important handler
.kernel.execute_request_handler:{[socket;msg;identities]
  .kernel.log[1;"Q kernel executing: ", msg . `content`code];

  content: enlist[`execution_state]!enlist["busy"];
  .kernel.send[.kernel.priv.sockets`iopub;"status";`content`parent_header!(content;msg`header)];

  content: `execution_count`code!(.kernel.priv.execnt;msg . `content`code);
  .kernel.send[.kernel.priv.sockets`iopub;"pyin";`content`parent_header!(content;msg`header)];

  result: .kernel.code_executor msg . `content`code;
  content: `execution_count`data`metadata!(.kernel.priv.execnt;enlist[`$"text/plain"]!enlist[result`val];()!());
  .kernel.send[.kernel.priv.sockets`iopub;"pyout";`content`parent_header!(content;msg`header)];

  content: enlist[`execution_state]!enlist["idle"];
  .kernel.send[.kernel.priv.sockets`iopub;"status";`content`parent_header!(content;msg`header)];

  metadata: enlist[`]!enlist[::];
  metadata[`dependencies_met]: 1b;
  metadata[`engine]: .kernel.priv.engine_id;
  metadata[`status]: "ok";
  metadata[`started]: .kernel.iso_format .z.P;
  metadata: `_ metadata;

  content: enlist[`]!enlist[::];
  content[`status]: result`status;
  content[`execution_count]: .kernel.priv.execnt;
  if["error"~content`status;
    content[`ename]: result`val;
    content[`evalue]: result`val;
    content[`traceback]: ()];
  if["ok"~content`status;
    // content[`user_variables]: ()!(); // removed in 5.0
    content[`payload]: ();
    content[`user_expressions]: ()!()];

  content: `_ content;
  
  .kernel.send[.kernel.priv.sockets`shell;"execution_reply";`content`metadata`parent_header`identities!(content;metadata;msg`header;identities)];
  .kernel.add_execnt[];
  :0
  }


.kernel.shell_handler:{[loop;item;arg]
  pollitem: zloop.get_pollitem item;
  shell_socket: pollitem 0;
  msg: zmsg.recv[shell_socket];
  .kernel.log[3;"shell received: \n"];
  / zmsg.dump msg;

  dwm: .kernel.deserialize_wire_msg[msg];
  identities: dwm 0;
  msg: dwm 1;
  msg_type: msg . `header`msg_type;
  
  unknown_msg_handler: {[socket;msg;identities] 
    .kernel.log[3] "unknown msg_type: ", (msg . `header`msg_type), "\n"
    };
  handler_name: `$msg_type, "_handler";
  handler: $[handler_name in key .kernel;.kernel handler_name;unknown_msg_handler];
  rc: handler[shell_socket;msg;identities];
  :rc
  }

.kernel.setup_sockets:{[config]
  if[not `ctx in key .kernel.priv; 'init];
  socket_names: `hb`iopub`control`stdin`shell;
  socket_types: socket_names!`REP`PUB`ROUTER`ROUTER`ROUTER;
  // create sockets (a dictionary)
  sockets: zsocket.new[.kernel.priv.ctx] each zmq socket_types;
  ports: config `$string[socket_names],\:"_port";
  // bind sockets
  connection: config[`transport], "://", config`ip;
  zsocket.bind'[sockets;`$connection,/:":",'string ports];
  // register pollers 
  poller_names: socket_names except `hb;
  pollitems: sockets[poller_names],\:(0;zmq.POLLIN;0);
  // handlers 
  handlers: poller_names!.kernel `$string[poller_names],\:"_handler";
  .kernel.priv.create_master_handler[handlers];
  zloop.poller[.kernel.priv.loop;;`.kernel.master_handler;]'[pollitems;poller_names];
  .kernel.priv.sockets: sockets;
  }

.kernel.start_loop:{[]
  .kernel.log[1;"Starting loop...\n"];
  zloop.start .kernel.priv.loop;
  }

.kernel.start_hb:{[]
  .kernel.log[1;"Starting heartbeat loop...\n"];
  hb_thread: zthread.fork[.kernel.priv.ctx;`.kernel.heartbeat_loop;0];
  }

.kernel.shutdown:{[]
  .kernel.log[1;"Shutting down...\n"];
  .kernel.priv.exiting: 1b;
  }

.kernel.sign: {[msg_lst]
  raze string .qcrypt.hmac_sha256[raze msg_lst;config`key]
  }

.kernel.read_config:{[]
  defconfig: enlist[`]!enlist[::];
  defconfig[`control_port]: 0;
  defconfig[`hb_port]: 0;
  defconfig[`iopub_port]: 0;
  defconfig[`ip]: "127.0.0.1";
  defconfig[`key]: string first 1?0Ng;
  defconfig[`shell_port]: 0;
  defconfig[`stdin_port]: 0;
  defconfig[`transport]: "tcp";
  defconfig: `_ defconfig;
  readconn: {[f] {$[-9h=type x;`int$x;x]} each .j.k "\n" sv read0 hsym`$f};
  config: $[`conn in key cmdl:.Q.opt .z.x;readconn first cmdl`conn;defconfig];
  config
  }

// parse msg sent from front-end
.kernel.deserialize_wire_msg:{[msg]
  frames: ();
  while[zmsg.size[msg];frames,:enlist zframe.strdup zmsg.pop msg];
  delim_idx: frames?.kernel.priv.DELIM;
  identities: delim_idx#frames;
  m_signature: frames delim_idx+1;
  msg_frames: (delim_idx+2)_ frames;

  check_sig: .kernel.sign msg_frames;
  if[not check_sig~m_signature; '"Signatures do not match"];
  m: `header`parent_header`metadata`content!.j.k each 4#msg_frames;
  // Skip checking signature
  (identities;m)
  }

.kernel.iso_format: {"T" sv (ssr[;".";"-"];(::))@'"D" vs -3_ string x};

// make a new header
.kernel.new_header: {[msg_type]
  res: enlist[`]!enlist[::];
  res[`date]: .kernel.iso_format .z.P;
  res[`msg_id]: string first 1?0Ng;
  res[`username]: "kernel-",string .z.u;
  res[`session]: .kernel.priv.engine_id;
  res[`msg_type]: msg_type;
  `_ res
  }


// send a message through a particular socket
.kernel.send: {[socket;msg_type;options]
  header: .kernel.new_header msg_type;
  defopts: `content`parent_header`metadata`identities!(()!();()!();()!();());
  opts: .Q.def[defopts;options];
  msg_list: .j.j each (header;opts`parent_header;opts`metadata;opts`content);
  signature: .kernel.sign msg_list;
  parts: (.kernel.priv.DELIM;signature),msg_list;
  parts: opts[`identities], parts;
  .kernel.log[3;"send parts:\n"];
  .kernel.log[3] each parts,'"\n";
  msg: zmsg.new[];
  zmsg.add[msg;] each zframe.new each parts;
  zmsg.send[msg;socket];
  }


