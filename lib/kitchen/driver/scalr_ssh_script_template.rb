module Kitchen
  module Driver

    SCALR_SSH_SCRIPT = 
    '#!/bin/bash
cat >> /root/.ssh/authorized_keys << EOF
%{ssh_pub_key}
EOF'
  end
end