#!/bin/sh
# Standard script to start and stop Schema Registry

DAEMON_PATH=/confluent/bin
CONFIG_PATH=/confluent/etc/schema-registry
DAEMON_NAME=schema-registry

PATH=$PATH:$DAEMON_PATH

# See how we were called.
case "$1" in
  start)
        # Start daemon.
        pid=`ps ax | grep -i 'schema-registry' | grep -v grep | awk '{print $1}'`
        if [ -n "$pid" ]
          then
            echo "Schema Registry is already running";
        else
          echo "Starting $DAEMON_NAME";
          $DAEMON_PATH/schema-registry-start.sh -daemon $CONFIG_PATH/schema-registry.properties
        fi
        ;;
  stop)
        echo "Shutting down $DAEMON_NAME";
        $DAEMON_PATH/schema-registry-stop.sh
        ;;
  restart)
        $0 stop
        sleep 2
        $0 start
        ;;
  status)
        pid=`ps ax | grep -i 'schema-registry' | grep -v grep | awk '{print $1}'`
        if [ -n "$pid" ]
          then
          echo "Schema Registry is running as PID: $pid"
        else
          echo "Schema Registry is not running"
        fi
        ;;
  *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
esac

exit 0
