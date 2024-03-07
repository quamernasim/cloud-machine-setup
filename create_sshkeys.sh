cd ~
ssh-keygen -q -b 2048 -P "" -f .ssh/<myhost>_rsa -t rsa
#the copy the .pub file to the remote system