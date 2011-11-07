#!/bin/bash -ue

# Copyright (C) 2010 Codership Oy
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; see the file COPYING. If not, write to the
# Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston
# MA  02110-1301  USA.

# This is a reference script for rsync-based state snapshot tansfer

RSYNC_PID=
RSYNC_CONF=

cleanup_joiner()
{
#set -x
    local PID=$(cat "$RSYNC_PID" 2>/dev/null || echo 0)
    [ "0" != "$PID" ] && kill $PID && (kill $PID && kill -9 $PID) || :
    rm -rf "$RSYNC_CONF"
    rm -rf "$MAGIC_FILE"
    rm -rf "$RSYNC_PID"
#set +x
}

check_pid()
{
    local pid_file=$1
    [ -r $pid_file ] && ps -p $(cat $pid_file) >/dev/null 2>&1
}

ROLE=$1
ADDR=$2
AUTH=$3
DATA=$4

MAGIC_FILE="$DATA/rsync_sst_complete"
rm -rf "$MAGIC_FILE"

if [ "$ROLE" = "donor" ]
then
    UUID=$5
    SEQNO=$6
    BYPASS=$7

    if [ $BYPASS -eq 0 ]
    then

        FLUSHED="$DATA/tables_flushed"
        rm -rf "$FLUSHED"

        # Use deltaxfer only for WAN
        inv=$(basename $0)
        [ "$inv" = "wsrep_sst_rsync_wan" ] && WHOLE_FILE_OPT="" \
                                           || WHOLE_FILE_OPT="--whole-file"

        echo "flush tables"

        # wait for tables flushed and state ID written to the file
        while [ ! -r "$FLUSHED" ] && ! grep -q ':' "$FLUSHED" >/dev/null 2>&1
        do
            sleep 0.2
        done

        STATE="$(cat $FLUSHED)"
        rm -rf "$FLUSHED"

        sync

        # Old filter - include everything except selected
        # FILTER=(--exclude '*.err' --exclude '*.pid' --exclude '*.sock' \
        #         --exclude '*.conf' --exclude core --exclude 'galera.*' \
        #         --exclude grastate.txt --exclude '*.pem' \
        #         --exclude '*.[0-9][0-9][0-9][0-9][0-9][0-9]' --exclude '*.index')

        # New filter - exclude everything except dirs (schemas) and innodb files
        FILTER=(-f '+ /ibdata*' -f '+ /ib_logfile*' -f '+ */' -f '-! */*')

        rsync --archive --no-times --ignore-times --inplace --delete --quiet \
              $WHOLE_FILE_OPT "${FILTER[@]}" "$DATA" rsync://$ADDR

    else # BYPASS
        STATE="$UUID:$SEQNO"
    fi

    echo "continue" # now server can resume updating data

    echo "$STATE" > "$MAGIC_FILE"
    rsync -aqc "$MAGIC_FILE" rsync://$ADDR

    echo "done $STATE"

elif [ "$ROLE" = "joiner" ]
then
    MYSQLD_PID=$5

    MODULE="rsync_sst"

    RSYNC_PID="$DATA/$MODULE.pid"

    if check_pid $RSYNC_PID
    then
        echo "rsync daemon already running."
        exit 114 # EALREADY
    fi
    rm -rf "$RSYNC_PID"

    RSYNC_PORT=$(echo $ADDR | awk -F ':' '{ print $2 }')
    if [ -z "$RSYNC_PORT" ]
    then
        RSYNC_PORT=4444
        ADDR="$(echo $ADDR | awk -F ':' '{ print $1 }'):$RSYNC_PORT"
    fi

    trap "exit 32" HUP PIPE
    trap "exit 3"  INT TERM
    trap cleanup_joiner EXIT

    MYUID=$(id -u)
    MYGID=$(id -g)
    RSYNC_CONF="$DATA/$MODULE.conf"
    echo "pid file = $RSYNC_PID" >  "$RSYNC_CONF"
    echo "use chroot = no"       >> "$RSYNC_CONF"
    echo "[${MODULE}]"           >> "$RSYNC_CONF"
    echo "	path = $DATA"    >> "$RSYNC_CONF"
    echo "	read only = no"  >> "$RSYNC_CONF"
    echo "	timeout = 300"   >> "$RSYNC_CONF"
    echo "	uid = $MYUID"    >> "$RSYNC_CONF"
    echo "	gid = $MYGID"    >> "$RSYNC_CONF"

#    rm -rf "$DATA"/ib_logfile* # we don't want old logs around

    # listen at all interfaces (for firewalled setups)
    rsync --daemon --port $RSYNC_PORT --config "$RSYNC_CONF"

    until [ -r "$RSYNC_PID" ]
    do
        sleep 0.2
    done

    echo "ready $ADDR/$MODULE"

    # wait for SST to complete by monitoring magic file
    while [ ! -r "$MAGIC_FILE" ] && check_pid "$RSYNC_PID" && \
          ps -p $MYSQLD_PID >/dev/null
    do
        sleep 1
    done

    if ! ps -p $MYSQLD_PID >/dev/null
    then
        echo "Parent mysqld process (PID:$MYSQLD_PID) terminated unexpectedly." >&2
        exit 32
    fi

    if [ -r "$MAGIC_FILE" ]
    then
        cat "$MAGIC_FILE" # output UUID:seqno
    else
        # this message should cause joiner to abort
        echo "rsync process ended without creating '$MAGIC_FILE'"
    fi

#    cleanup_joiner
else
    echo "Unrecognized role: $ROLE"
    exit 22 # EINVAL
fi

exit 0
