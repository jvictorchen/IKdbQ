# IKdbQ
IKdbQ is a simple kernel for
[Jupyter project](http://ipython.org) that allows you to write
[KDB+/Q](http://kx.com/software.php) code with Jupyter console and notebook. It was initially translated
from [simple_kernel](https://github.com/dsblank/simple_kerne). 

Currently it supports basic code execution and naive code
completion. It's worth mentioning that multi-line input without
trailing semicolons is supported in notebook, as supposed to most
other Q IDE's.

More advanced features are to be done in the future.

# Installation

**Note:** The code is only tested on Ubuntu 14.04.2 i386. For building
the project in 64-bit machines for the free 32-bit of kdb+, -m32 flag
is needed.

## Install kdb+/q

## Install [qzmq](https://github.com/jvictorchen/qzmq)
  This is a modified version of
 [jaeheum's qzmq](https://github.com/jaeheum/qzmq)  
  It requires ZeroMQ (2.2.0) and czmq.  
  **Note:** jaeheum upgraded his qzmq to version 3.0.1 recently. 

## Install [qcrypt](http://code.kx.com/wsvn/code/contrib/aquaqanalytics/Qcrypt/qcrypt.c) (Q interface for OpenSSL)
1. Install
  [OpenSSL](http://geeksww.com/tutorials/libraries/openssl/installation/installing_openssl_on_ubuntu_linux.php)  
  Note: use `sudo make install_sw` (instead of `make install`) if you
  encounter errors like "POD document had syntax errors at /usr/bin/pod2man line 71."

2. Compile qcrypt for Q

	`gcc -DKXVER=3 -shared -fPIC qcrypt.c -o qcrypt.so -Wall -Wextra -I../kx/kdb+3.0/ -L../kx/kdb+3.0/l32 -L/usr/local/openssl/lib -I/usr/local/openssl/include -lssl -lcrypto -ldl`
	`cp qcrypt.so $HOME/q/l32`  
	`cp qcrypt.q $HOME/q/`

## Install IPython 3.1
On Ubuntu:
	`pip install ipython[all]`

## Configuring Jupyter
Create a folder called `q` under `~/.ipython/kernels`, and copy
`kernel.json` there.

	`mkdir -p ~/.ipython/kernels/q && cp ./kernel.json ~/.ipython/kernels/q`

# Start IKdbQ

	`ipython console --kernel q -f connection.json`  
	`ipython qtconsole --kernel q -f connection.json`  
	`ipython notebook` (then choose language KDB+/Q)

