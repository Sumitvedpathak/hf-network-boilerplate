
generateCryptoMaterial(){
    echo "---------------------------Generating Crypto Material for new Organization 3---------------------------"
    #Generate Crypto artifactes for organizations
    cryptogen generate --config=./artifacts/org3/crypto-config-org3.yaml --output=./artifacts/org3/crypto-config/
    # echo "---------------------------Copying orderers in Org 3 folder---------------------------"
    # cp -r ./artifacts/channel/crypto-config/ordererOrganizations ./artifacts/org3/crypto-config/
}
# generateCryptoMaterial

generateDefinition(){
    echo "---------------------------Generate JSON configuration file---------------------------"
    # export FABRIC_CFG_PATH=${PWD}/artifacts/config/ ---------------------Earlier state
    export FABRIC_CFG_PATH=${PWD}/artifacts/org3/
    echo $FABRIC_CFG_PATH
    configtxgen -printOrg Org3MSP > ./artifacts/org3/org3.json
}
# generateDefinition

extractConfigBlock(){
    export FABRIC_CFG_PATH=${PWD}/artifacts/config/
    export ORDERER_CA=${PWD}/artifacts/channel/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    export CHANNEL_NAME=mychannel

    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/artifacts/channel/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/artifacts/channel/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051
    export CORE_PEER_LOCALMSPID="OrdererMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/artifacts/channel/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    export CORE_PEER_MSPCONFIGPATH=${PWD}/artifacts/channel/crypto-config/ordererOrganizations/example.com/users/Admin@example.com/msp

    echo "---------------------------Extract config block from blockchain---------------------------"
    peer channel fetch config ./artifacts/org3/config_block.pb -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    -c $CHANNEL_NAME --tls --cafile $ORDERER_CA

    echo "---------------------------Convert config protobuff to json---------------------------"
    configtxlator proto_decode --input ./artifacts/org3/config_block.pb \
    --type common.Block | jq .data.data[0].payload.data.config >./artifacts/org3/config.json

    
}
extractConfigBlock