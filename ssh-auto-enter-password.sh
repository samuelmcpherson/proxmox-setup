#!/usr/bin/expect

# This is useful to script SSH connections, it allows for SSH password authentication to be sent allong with the SSH command without requiring additional prompting. 
# Usage ./ssh-auto-enter-password <password> <full ssh command>
  
set timeout 20

set cmd [lrange $argv 1 end]
set password [lindex $argv 0]

eval spawn $cmd
expect "assword:"
send "$password\r";
interact