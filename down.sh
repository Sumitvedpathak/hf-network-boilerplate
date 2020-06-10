echo "#######  Bringing down the network  ##########"
docker stop $(docker ps -a -q) && docker rm $(docker ps -a -q)

echo "#######  Pruning Docker Volumes?  ##########"
docker volume prune

echo "#######    Clearing all crypto material for Network  ##########"
# Delete existing artifacts
rm -rf ./artifacts/channel/crypto-config
rm ./artifacts/channel/Org1MSPanchors.tx
rm ./artifacts/channel/Org2MSPanchors.tx
rm ./artifacts/channel/genesis.block
rm ./artifacts/channel/mychannel.block
rm ./artifacts/channel/mychannel.tx
rm -rf ./artifacts/src/fabcar/fabcar.tar.gz