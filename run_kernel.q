// script to run Q kernel 

\l qzmq.q
\c 100 200

// Global variables 
debug: 1b;
DELIM:"<IDS|MSG>";
engine_id: string first 1?0Ng;

// Utility functions
dprint:{[msg]
  if[debug; 1 "DEBUG: ", msg];
  }

deserialize_wire_msg:{[msg]
  frames: ();
  while[zmsg.size[msg];frames,:enlist zframe.strdup zmsg.pop msg];
  delim_idx: frames?DELIM;
  identities: delim_idx#frames;
  m_signature: frames delim_idx+1;
  msg_frames: (delim_idx+2)_ frames;

  m: `header`parent_header`metadata`content!.j.k each 4#msg_frames;
  // Skip checking signature
  (identities;m)
  }

iso_format: {"T" sv (ssr[;".";"-"];(::))@'"D" vs -3_ string x};

/ make a new header
new_header: {[msg_type]
  res: enlist[`]!enlist[::];
  res[`date]: iso_format .z.P;
  res[`msg_id]: string first 1?0Ng;
  res[`username]: "kernel";
  res[`session]: engine_id;
  res[`msg_type]: msg_type;
  `_ res
  }

send: {[socket;msg_type;options]
  header: new_header msg_type;
  defopts: `content`parent_header`metadata`identities!(()!();()!();()!();());
  opts: .Q.def[defopts;options];
  msg_list: .j.j each (header;opts`parent_header;opts`metadata;opts`content);
  signature: "";
  parts: (DELIM;signature),msg_list;
  parts: opts[`identities], parts;
  dprint "send parts:\n";
  1 each parts,'"\n";
  msg: zmsg.new[];
  zmsg.add[msg;] each zframe.new each parts;
  zmsg.send[msg;socket];
  }

// Kernel handlers
master_handler:{[loop;item;arg]
  qarg: zloop.get_arg arg;
  handler: $[
    qarg=`iopub; iopub_handler;
    qarg=`control; control_handler;
    qarg=`stdin; stdin_handler;
    qarg=`shell; shell_handler;
    'InvalidArgument];
  :handler[loop;item;qarg];
  }

iopub_handler: {[loop;item;arg]
  show "iopub";
  }

control_handler: {[loop;item;arg]
  show "control";
  }

stdin_handler:{[loop;item;arg]
  show "stdin";
  }

kernel_info_request_handler: {[socket;msg;identities]
  content: enlist[`]!enlist[::];
  content[`protocal_version]: 4 0;
  content[`ipython_version]: (3;1;0;"");
  content[`language_version]: 3 2;
  content[`language]: "KDB+/Q";
  content: `_ content;
  send[socket;"kernel_info_reply";`content`parent_header`identities!(content;msg`header;identities)];
  }

shell_handler:{[loop;item;arg]
  pollitem: zloop.get_pollitem item;
  shell_socket: pollitem 0;
  msg: zmsg.recv[shell_socket];
  dprint "shell received: \n";
  zmsg.dump msg;

  dwm: deserialize_wire_msg[msg];
  identities: dwm 0;
  msg: dwm 1;
  msg_type: msg . `header`msg_type;
  
  unknown_handler: {[socket;msg;identities] 1 "unknown msg_type: ", (msg . `header`msg_type), "\n"};
  handler: $[msg_type~"kernel_info_request"; kernel_info_request_handler;unknown_handler];
  handler[shell_socket;msg;identities];
  }

heartbeat_loop: {[args;ctx;pipe]
  dprint "Starting loop for Heartbeat...\n";
  while[1b and not zctx.interrupted[];
    1 ".";
    / rc:libzmq.device[zmq.FORWARDER;heartbeat_socket;heartbeat_socket]
    dprint "Receiving message from heartbeat_socket...\n";
    msg: zstr.recv[heartbeat_socket];
    show msg;
    1 "Sending message from heartbeat_socket...\n";
    zstr.send[heartbeat_socket;msg];
    ];
  }

defconfig: enlist[`]!enlist[::];
defconfig[`control_port]: 0;
defconfig[`hb_port]: 0;
defconfig[`iopub_port]: 0;
defconfig[`ip]: "127.0.0.1";
/ defconfig[`key]: string first 1?0Ng;
defconfig[`key]: ""; // skip authentication for now 
defconfig[`shell_port]: 0;
defconfig[`stdin_port]: 0;
defconfig[`transport]: "tcp";
defconfig: `_ defconfig;

readconn: {[f] {$[-9h=type x;`int$x;x]} each .j.k "\n" sv read0 hsym`$f};
config: $[`conn in key cmdl:.Q.opt .z.x;readconn first cmdl`conn;defconfig];

connection: config[`transport], "://", config`ip;

ctx: zctx.new[];
loop: zloop.new[];
zloop.set_verbose[loop;1b];

// Heartbeat:
heartbeat_socket: zsocket.new[ctx;zmq.REP];
zsocket.bind[heartbeat_socket;`$connection, ":", string config`hb_port];

// IOPub/Sub:
iopub_socket: zsocket.new[ctx;zmq.PUB];
zsocket.bind[iopub_socket;`$connection, ":", string config`iopub_port];
iopub_pollitem: (iopub_socket;0;zmq.POLLIN;0);
zloop.poller[loop;iopub_pollitem;`master_handler;`iopub];

// Control:
control_socket: zsocket.new[ctx;zmq.ROUTER];
zsocket.bind[control_socket;`$connection, ":", string config`control_port];
control_pollitem: (control_socket;0;zmq.POLLIN;0);
zloop.poller[loop;control_pollitem ;`master_handler;`control];

// Stdin:
stdin_socket: zsocket.new[ctx;zmq.ROUTER];
zsocket.bind[stdin_socket;`$connection,":", string config`stdin_port];
stdin_pollitem: (stdin_socket;0;zmq.POLLIN;0);
zloop.poller[loop;stdin_pollitem;`master_handler;`stdin];

// Shell:
shell_socket: zsocket.new[ctx;zmq.ROUTER];
zsocket.bind[shell_socket;`$connection, ":", string config`shell_port];
shell_pollitem: (shell_socket;0;zmq.POLLIN;0);
zloop.poller[loop;shell_pollitem;`master_handler;`shell];

dprint "Config: \n";
show config;
dprint "Starting loops...\n";

hb_thread: zthread.fork[ctx;`heartbeat_loop;0];
/ heartbeat_loop[`123;ctx;0];

dprint "Ready! Listening...\n";
zloop.start[loop];

zloop.destroy[loop];

zctx.destroy[ctx];
