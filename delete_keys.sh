# /bin/bash

RIAK_SERVER="rdb.parallelcompute.net"
RIAK_PORT="8098"
BUCKET_NAME="locations"

# Perform the GET request and store the response in a variable
response=$(curl -s http://$RIAK_SERVER:$RIAK_PORT/buckets/$BUCKET_NAME/keys?keys=true)

# Parse the JSON response and extract the list of IDs
keys=$(echo "$response" | jq -r '.keys[]')

for key in $keys; do
    # Execute cURL DELETE request to delete the key
    curl -XDELETE "http://$RIAK_SERVER:$RIAK_PORT/buckets/$BUCKET_NAME/keys/$key"
done
