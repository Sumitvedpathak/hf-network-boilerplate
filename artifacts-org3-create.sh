export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=${PWD}/artifacts/channel/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export PEER0_ORG1_CA=${PWD}/artifacts/channel/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export PEER0_ORG2_CA=${PWD}/artifacts/channel/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export PEER0_ORG3_CA=${PWD}/artifacts/org3/crypto-config/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export FABRIC_CFG_PATH=${PWD}/artifacts/channel/config/

export CHANNEL_NAME=mychannel

setGlobalsForOrderer() {
    export CORE_PEER_LOCALMSPID="OrdererMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/artifacts/channel/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    export CORE_PEER_MSPCONFIGPATH=${PWD}/artifacts/channel/crypto-config/ordererOrganizations/example.com/users/Admin@example.com/msp

}

setGlobalsForPeer0Org1() {
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG1_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/artifacts/channel/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051
}

setGlobalsForPeer0Org2() {
    export CORE_PEER_LOCALMSPID="Org2MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG2_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/artifacts/channel/crypto-config/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_ADDRESS=localhost:9051

}

setGlobalsForPeer0Org3() {
    export CORE_PEER_LOCALMSPID="Org3MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG3_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/artifacts/org3/crypto-config/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
    export CORE_PEER_ADDRESS=localhost:11051

}

generateCryptoMaterial(){
    echo "---------------------------Generating Crypto Material for new Organization 3---------------------------"
    cryptogen generate --config=./artifacts/org3/crypto-config-org3.yaml --output=./artifacts/org3/crypto-config/
}
# generateCryptoMaterial

generateDefinition(){
    echo "---------------------------Generate JSON configuration file---------------------------"
    # export FABRIC_CFG_PATH=${PWD}/artifacts/config/ ---------------------Earlier state
    export FABRIC_CFG_PATH=${PWD}/artifacts/org3/
    echo $FABRIC_CFG_PATH
    configtxgen -printOrg Org3MSP >./artifacts/org3/org3.json
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
    --type common.Block | jq .data.data[0].payload.data.config > ./artifacts/org3/config.json

    echo "---------------------------Create updated Org3 config json file---------------------------"
    jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"Org3MSP":.[1]}}}}}' ./artifacts/org3/config.json ./artifacts/org3/org3.json > ./artifacts/org3/org3_config.json
}
# extractConfigBlock

createConfigUpdate(){

    CHANNEL="mychannel"



    echo "---------------------------Convert main config json to protobuff format---------------------------"
    configtxlator proto_encode --input ./artifacts/org3/config.json --type common.Config > ./artifacts/org3/original_config.pb

    echo "---------------------------Convert modified Org3 config json to protobuff format---------------------------"
    configtxlator proto_encode --input ./artifacts/org3/org3_config.json --type common.Config > ./artifacts/org3/modified_config.pb

    echo $CHANNEL_NAME
    echo "---------------------------Merge to protobuff format---------------------------"
    configtxlator compute_update --channel_id $CHANNEL_NAME --original ./artifacts/org3/original_config.pb --updated ./artifacts/org3/modified_config.pb > ./artifacts/org3/config_update.pb

    echo "---------------------------Convert Merged protobuff to JSON format---------------------------"
    configtxlator proto_decode --input ./artifacts/org3/config_update.pb --type common.ConfigUpdate > ./artifacts/org3/config_update.json

    echo "---------------------------Update wrapper to JSON format---------------------------"
    echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL_NAME'", "type":2}},"data":{"config_update":'$(cat ./artifacts/org3/config_update.json)'}}}' | jq . > ./artifacts/org3/final_envelope.json

    echo "---------------------------Convert final json to protobuff format---------------------------"
    configtxlator proto_encode --input ./artifacts/org3/final_envelope.json --type common.Envelope > ./artifacts/org3/final_envelope.pb
}
# createConfigUpdate

signAndSubmit(){
    export ORDERER_CA=${PWD}/artifacts/channel/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    export FABRIC_CFG_PATH=${PWD}/artifacts/config/
    export CHANNEL_NAME=mychannel

    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/artifacts/channel/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/artifacts/channel/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051

    echo "---------------------------Org1 Signing the block for adding new Org---------------------------"
    peer channel signconfigtx -f ./artifacts/org3/final_envelope.pb

    export CORE_PEER_LOCALMSPID="Org2MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/artifacts/channel/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/artifacts/channel/crypto-config/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_ADDRESS=localhost:9051

    echo "---------------------------Org2 Signing and Submitting the block for adding new Org to Orderer---------------------------"
    peer channel update -f ./artifacts/org3/final_envelope.pb -c ${CHANNEL_NAME} \
        -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
        --tls --cafile ${ORDERER_CA}
}
# signAndSubmit


generateCryptoMaterial
generateDefinition
extractConfigBlock
createConfigUpdate
signAndSubmit