
# chmod -R 0755 ./artifacts/channel/crypto-config
# Delete existing artifacts
# rm -rf ./crypto-config
# rm genesis.block mychannel.tx
# rm -rf ../../channel-artifacts/*

echo "---------------------------Generating Crypto Material for Orderer and Peers Organizations---------------------------"
#Generate Crypto artifactes for organizations
cryptogen generate --config=./artifacts/crypto-config.yaml --output=./artifacts/channel/crypto-config/



# System channel
SYS_CHANNEL="sys-channel"

# channel name defaults to "mychannel"
CHANNEL_NAME="mychannel"

echo $CHANNEL_NAME

echo "---------------------------Generating Genesis Block---------------------------"
# Generate System Genesis block
configtxgen -profile OrdererGenesis -configPath ./artifacts -channelID $SYS_CHANNEL  -outputBlock ./artifacts/channel/genesis.block

echo "---------------------------Generating Channel Transaction---------------------------"
# Generate channel configuration block
configtxgen -profile BasicChannel -configPath ./artifacts -outputCreateChannelTx ./artifacts/channel/mychannel.tx -channelID $CHANNEL_NAME

echo "---------------------------Generating anchor peer for Org1---------------------------"
configtxgen -profile BasicChannel -configPath ./artifacts -outputAnchorPeersUpdate ./artifacts/channel/Org1MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org1MSP

echo "---------------------------Generating anchor peer for Org2---------------------------"
configtxgen -profile BasicChannel -configPath ./artifacts -outputAnchorPeersUpdate ./artifacts/channel/Org2MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org2MSP
