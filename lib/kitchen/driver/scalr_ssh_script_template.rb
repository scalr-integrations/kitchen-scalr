require 'kitchen'

module Kitchen
  module Driver
    SCALR_SSH_ROOT_ENABLE_SCRIPT = '#!/bin/bash
cat >> /root/.ssh/authorized_keys << EOF
%{ssh_pub_key}
EOF
sed -i \'s/^\(PermitRootLogin\)\s*no/\1 yes/g\' /etc/ssh/sshd_config
systemctl restart sshd'

    SCALR_SSH_SCRIPT = '#!/bin/bash
cat >> /root/.ssh/authorized_keys << EOF
%{ssh_pub_key}
EOF'
  end
end
