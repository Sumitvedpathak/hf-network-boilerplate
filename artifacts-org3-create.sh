
echo "---------------------------Generating Crypto Material for new Organization 3---------------------------"
#Generate Crypto artifactes for organizations
cryptogen generate --config=./artifacts/org3/crypto-config-org3.yaml --output=./artifacts/org3/crypto-config/


echo "---------------------------Copying orderers in Org 3 folder---------------------------"
cp -r ./artifacts/channel/crypto-config/ordererOrganizations ./artifacts/org3/crypto-config/


echo "---------------------------Generate JSON configuration file---------------------------"
# export FABRIC_CFG_PATH=${PWD}/artifacts/config/ ---------------------Earlier state
export FABRIC_CFG_PATH=${PWD}/artifacts/org3/
echo $FABRIC_CFG_PATH
configtxgen -printOrg Org3MSP > ./artifacts/org3/org3.json

export FABRIC_CFG_PATH=${PWD}/artifacts/org3/config/
export ORDERER_CA=${PWD}/artifacts/org3/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export CHANNEL_NAME=mychannel

echo "---------------------------Extract config block from blockchain---------------------------"
peer channel fetch newest mychannel.block -c mychannel --orderer orderer.example.com:7050 

# peer channel fetch config config_block.pb -o orderer.example.com:7050 -c $CHANNEL_NAME --tls --cafile $ORDERER_CA