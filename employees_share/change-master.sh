#!/bin/bash
# usage: 在从库上执行, 自动执行CHANGE MASTER使其形成主从链路
# author: prontera@github

#set -x
set -eo pipefail
shopt -s nullglob

# 定时清除relaylogs
cd /etc/cron.d/
touch purge_relay_logs
cat > purge_relay_logs <<EOF
        0 4 * * * /usr/bin/purge_relay_logs --user=root --password=${MYSQL_ROOT_PASSWORD} --disable_relay_log_purge --port=3306 --workdir=/var/lib/mysql/ >>/usr/local/
mha/logs/purge_relay_logs.log 2>&1
EOF
service cron start

if [[ -z "$MYSQL_ROOT_PASSWORD" ]]; then
    echo "$HOSTNAME please set the environment variable MYSQL_ROOT_PASSWORD first!"
    exit 1
fi
mysql=( mysql -p"$MYSQL_ROOT_PASSWORD" )

for i in {30..0}; do
	if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null; then
		break
	fi
	echo "$HOSTNAME MySQL init process in progress..."
	sleep 2
done
if [ "$i" = 0 ]; then
	echo >&2 "$HOSTNAME MySQL init process failed."
	exit 1
fi

"${mysql[@]}" <<-EOSQL
	STOP SLAVE;
	CHANGE MASTER TO MASTER_HOST="master", MASTER_USER="${MYSQL_REPL_NAME}", MASTER_PASSWORD="${MYSQL_REPL_PASSWORD:-}", MASTER_AUTO_POSITION=1;
        START SLAVE;
        SET GLOBAL READ_ONLY = 1;
EOSQL

exit 0
