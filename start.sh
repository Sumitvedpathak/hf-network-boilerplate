docker-compose -f ./artifacts/docker-compose.yaml up -d
sleep 3
./channel-create.sh
sleep 3
./chaincode-deploy.sh