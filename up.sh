echo "**********************************Creating Artifacts*************************************"
./create-artifacts.sh

cd ./artifacts/channel

chmod 777 -R *

cd ../..

echo "**********************************Bringing up the network*************************************"
docker-compose -f ./artifacts/docker-compose.yaml up -d

docker ps

sleep 5

echo "**********************************Creating Channel Artifacts*************************************"
./create-channel.sh

echo "**********************************Deploy Chaincodes*************************************"
./deploy-chaincode.sh

docker ps