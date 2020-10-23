docker-compose -f ./artifacts/docker-compose.yaml up -d
sleep 5
./channel-create.sh
sleep 5
./chaincode-deploy.sh