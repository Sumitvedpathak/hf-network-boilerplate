# ./create-artifacts.sh

docker-compose -f ./artifacts/docker-compose.yaml up -d

docker ps

sleep 3

./create-channel.sh

