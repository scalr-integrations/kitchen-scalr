require 'kitchen'

module Kitchen
  module Driver

    SCALR_SSH_SCRIPT = '#!/bin/bash
cat >> /root/.ssh/authorized_keys << EOF
%{ssh_pub_key}
EOF
'

    SCALR_SSH_ROOT_PERMIT_SCRIPT = '
sed -i \'s/^\(PermitRootLogin\)\s*no/\1 yes/g\' /etc/ssh/sshd_config

if command -v systemctl >/dev/null 2>&1; then
    systemctl restart sshd
elif [ -f /etc/init.d/ssh ]; then
    /etc/init.d/ssh restart
elif [ -f /etc/init.d/sshd ]; then
    /etc/init.d/sshd restart
fi
'

  end
end
