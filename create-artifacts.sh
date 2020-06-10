
echo "#######    Generating crypto material for Network  ##########"
#Generate Crypto artifactes for organizations
cryptogen generate --config=./artifacts/crypto-config.yaml --output=./artifacts/channel/crypto-config/

chmod -R 0755 ./artifacts/channel/crypto-config

# System channel
SYS_CHANNEL="sys-channel"

# channel name defaults to "mychannel"
CHANNEL_NAME="mychannel"

echo $CHANNEL_NAME

echo "#######    Generating Genesis block   ##########"
# Generate System Genesis block
configtxgen -profile OrdererGenesis -configPath ./artifacts -channelID $SYS_CHANNEL  -outputBlock ./artifacts/channel/genesis.block

echo "#######    Generating channel configuration block  ##########"
# Generate channel configuration block
configtxgen -profile BasicChannel -configPath ./artifacts -outputCreateChannelTx ./artifacts/channel/mychannel.tx -channelID $CHANNEL_NAME

echo "#######    Generating anchor peer update for Org1MSP  ##########"
configtxgen -profile BasicChannel -configPath ./artifacts -outputAnchorPeersUpdate ./artifacts/channel/Org1MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org1MSP

echo "#######    Generating anchor peer update for Org2MSP  ##########"
configtxgen -profile BasicChannel -configPath ./artifacts -outputAnchorPeersUpdate ./artifacts/channel/Org2MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org2MSP

echo "#######    Booting up the network      #########"
docker-compose -f ./artifacts/docker-compose.yaml up -d

echo "#######    Network containers are up      #########"
docker ps