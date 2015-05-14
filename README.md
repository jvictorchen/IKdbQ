# IKdbQ

Install qcrypt to have sha256 function in Q 

1. Install OpenSSL
http://geeksww.com/tutorials/libraries/openssl/installation/installing_openssl_on_ubuntu_linux.php

sudo make install_sw (instead of make install) if you encounter error
like "POD document had syntax errors at /usr/bin/pod2man line 71."

2. Compile qcrypt for Q

	gcc -DKXVER=3 -shared -fPIC qcrypt.c -o qcrypt.so -Wall -Wextra -I../kx/kdb+3.0/ -L../kx/kdb+3.0/l32 -L/usr/local/openssl/lib -I/usr/local/openssl/include -lssl -lcrypto -ldl

	cp qcrypt.so $HOME/q/l32
	cp qcrypt.q $HOME/q/

3. Run Ipython

	ipython console --kernel q -f connection.json 
