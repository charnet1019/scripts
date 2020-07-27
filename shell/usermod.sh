#!/bin/sh

hostname="$1"
[ -z "$hostname" ] && { echo "Use: $0 hostname"; exit 1; }

case "`id -nu`" in
        root)
                echo "Entering root"
                adduser cds
                usermod -a -G sudo cds
                usermod -a -G docker cds
                sed -i.bak \
                        '/ChallengeResponseAuthentication/ s/.*/ChallengeResponseAuthentication yes/' \
                        /etc/ssh/sshd_config
                ;;
        *)
                echo "Running as `id -nu`"
                sudo "$0" "$@";;
esac
