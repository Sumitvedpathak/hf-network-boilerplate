echo "---------------------------Generating Crypto Material for new Organization 3---------------------------"
cryptogen generate --config=./crypto-config.yaml --output=../channel/sys-ch/crypto-config/

CHANNEL_NAME="org1-org3-channel"
echo "---------------------------Generating Channel Artifacts for new Organization 3---------------------------"
configtxgen -profile org1-org3-channel -configPath . -outputCreateChannelTx ../channel/sys-ch/org1-org3-channel.tx -channelID $CHANNEL_NAME

echo "---------------------------Generating Anchor Peer updates for Org1---------------------------"
configtxgen -profile org1-org3-channel -configPath . -outputAnchorPeersUpdate ../channel/sys-ch/Org1MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org1MSP

echo "---------------------------Generating Anchor Peer updates for Org3---------------------------"
configtxgen -profile org1-org3-channel -configPath . -outputAnchorPeersUpdate ../channel/sys-ch/Org3MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org3MSP
