#! /bin/sh

if [ "$1" = "test" ]; then
    LAST_DATA_TIMESTAMP=$(date -d '6 minutes ago' --rfc-3339=ns)
else
    LAST_DATA_TIMESTAMP=$(curl -s 'http://localhost:8086/query?pretty=true' --data-urlencode "db=tag_data" --data-urlencode 'q=SELECT time,last(temperature) FROM ruuvitag WHERE time > now()-1h GROUP BY mac LIMIT 1' | jq '[.results[0].series[].values[0][0]] | min' | tr -d '"')
fi

LAST_DATA_SEC=$(date -d "$LAST_DATA_TIMESTAMP" +%s)
ALERT_LIMIT_SEC=$(date -d '5 minutes ago' +%s)

ALERT_STATE_FILE="/tmp/alert-data-flow"
if [ "$ALERT_LIMIT_SEC" -gt "$LAST_DATA_SEC" ]; then
    if [ ! -f "$ALERT_STATE_FILE" ]; then
        curl -s -X POST -H 'Content-type: application/json' --data '{"text":"Alert, no InluxDB data for 5 minutes"}' "$SLACK_POST_URL" > /dev/null 2>&1 && touch "$ALERT_STATE_FILE"
            
    fi
else
    if [ -f "$ALERT_STATE_FILE" ]; then
        curl -s -X POST -H 'Content-type: application/json' --data '{"text":"Alert cleared, new InluxDB data found"}' "$SLACK_POST_URL" > /dev/null 2>&1
    fi
    
    rm -f "$ALERT_STATE_FILE"
fi

