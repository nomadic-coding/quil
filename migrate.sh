#!/bin/bash
echo "start migration"
#kill -9 $(pgrep node-1.4.18) && service ceremonyclient stop
cd /root/ceremonyclient/node && curl -X GET -s https://raw.githubusercontent.com/nomadic-coding/quil/main/update.sh | bash
kill -9 $(pgrep node-1.4.18) && service ceremonyclient stop
wget --no-cache -O - https://raw.githubusercontent.com/nomadic-coding/quil/main/quilservice.sh | bash
kill -9 $(pgrep node-1.4.18) && service ceremonyclient stop
wget --no-cache -O - https://raw.githubusercontent.com/nomadic-coding/quil/main/listen_tcp.sh | bash
kill -9 $(pgrep node-1.4.18) && service ceremonyclient stop
wget --no-cache -O - https://raw.githubusercontent.com/lamat1111/quilibriumscripts/master/tools/qnode_gRPC_calls_setup.sh | bash
kill -9 $(pgrep node-1.4.18) && service ceremonyclient stop
go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
apt-get y install jq
service ceremonyclient start
echo "migrate done"

