scalr_ssh_script = 
"
#!/bin/bash
echo >> /root/.ssh/authorized_keys << EOF
%{ssh_pub_key}
EOF
"