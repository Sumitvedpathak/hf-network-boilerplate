export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=${PWD}/../../artifacts/channel/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export PEER0_ORG1_CA=${PWD}/../../artifacts/channel/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export PEER0_ORG2_CA=${PWD}/../../artifacts/channel/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export PEER0_ORG3_CA=${PWD}/crypto-config/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export FABRIC_CFG_PATH=${PWD}/../../artifacts/config/

export CHANNEL_NAME=mychannel

setGlobalsForOrderer() {
    export CORE_PEER_LOCALMSPID="OrdererMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/../../artifacts/channel/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    export CORE_PEER_MSPCONFIGPATH=${PWD}/../../artifacts/channel/crypto-config/ordererOrganizations/example.com/users/Admin@example.com/msp

}

setGlobalsForPeer0Org1() {
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG1_CA
    export CORE_PEER_MSPCONFIGPATH=../../artifacts/channel/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051
}

setGlobalsForPeer0Org2() {
    export CORE_PEER_LOCALMSPID="Org2MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG2_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/../../artifacts/channel/crypto-config/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_ADDRESS=localhost:9051

}

setGlobalsForPeer0Org3() {
    export CORE_PEER_LOCALMSPID="Org3MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG3_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/crypto-config/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
    export CORE_PEER_ADDRESS=localhost:11051

}

generateCryptoMaterial(){
    echo "---------------------------Generating Crypto Material for new Organization 3---------------------------"
    cryptogen generate --config=./crypto-config-org3.yaml --output=./crypto-config/
}
# generateCryptoMaterial

generateDefinition(){
    echo "---------------------------Generate JSON configuration file---------------------------"
    # export FABRIC_CFG_PATH=${PWD}/artifacts/config/ ---------------------Earlier state
    export FABRIC_CFG_PATH=./
    # echo $FABRIC_CFG_PATH
    echo $FABRIC_CFG_PATH
    configtxgen -printOrg Org3MSP >./org3.json
}
# generateDefinition

extractConfigBlock(){
    # export FABRIC_CFG_PATH=${PWD}/../../artifacts/config/
    # export ORDERER_CA=${PWD}/../../artifacts/channel/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    # export CHANNEL_NAME=mychannel

    # export CORE_PEER_LOCALMSPID="Org1MSP"
    # export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/../../artifacts/channel/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    # export CORE_PEER_MSPCONFIGPATH=${PWD}/../../artifacts/channel/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    # export CORE_PEER_ADDRESS=localhost:7051
    # export CORE_PEER_LOCALMSPID="OrdererMSP"
    # export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/../../artifacts/channel/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    # export CORE_PEER_MSPCONFIGPATH=${PWD}/../../artifacts/channel/crypto-config/ordererOrganizations/example.com/users/Admin@example.com/msp
    echo $FABRIC_CFG_PATH
    setGlobalsForOrderer
    setGlobalsForPeer0Org1
    echo "---------------------------Extract config block from blockchain---------------------------"
    peer channel fetch config ./config_block.pb -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    -c $CHANNEL_NAME --tls --cafile $ORDERER_CA

    echo "---------------------------Convert config protobuff to json---------------------------"
    configtxlator proto_decode --input ./config_block.pb \
    --type common.Block | jq .data.data[0].payload.data.config > ./config.json

    echo "---------------------------Create updated Org3 config json file---------------------------"
    jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"Org3MSP":.[1]}}}}}' ./config.json ./org3.json > ./org3_config.json
}
# extractConfigBlock

createConfigUpdate(){

    CHANNEL="mychannel"

    echo "---------------------------Convert main config json to protobuff format---------------------------"
    configtxlator proto_encode --input ./config.json --type common.Config > ./original_config.pb

    echo "---------------------------Convert modified Org3 config json to protobuff format---------------------------"
    configtxlator proto_encode --input ./org3_config.json --type common.Config > ./modified_config.pb

    echo "---------------------------Merge to protobuff format---------------------------"
    configtxlator compute_update --channel_id $CHANNEL_NAME --original ./original_config.pb --updated ./modified_config.pb > ./config_update.pb

    echo "---------------------------Convert Merged protobuff to JSON format---------------------------"
    configtxlator proto_decode --input ./modified_config.pb --type common.ConfigUpdate > ./modified_config.json

    echo "---------------------------Update wrapper to JSON format---------------------------"
    echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL_NAME'", "type":2}},"data":{"config_update":'$(cat ./modified_config.json)'}}}' | jq . > ./final_envelope.json

    echo "---------------------------Convert final json to protobuff format---------------------------"
    configtxlator proto_encode --input ./final_envelope.json --type common.Envelope > ./final_envelope.pb
}
# createConfigUpdate

signAndSubmit(){
    # export ORDERER_CA=${PWD}/../../artifacts/channel/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    # export FABRIC_CFG_PATH=${PWD}/../../artifacts/config/
    # export CHANNEL_NAME=mychannel

    # export CORE_PEER_LOCALMSPID="Org1MSP"
    # export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/../../artifacts/channel/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    # export CORE_PEER_MSPCONFIGPATH=${PWD}/../../artifacts/channel/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    # export CORE_PEER_ADDRESS=localhost:7051

    echo "---------------------------Convert final json to protobuff format---------------------------"
    configtxlator proto_encode --input ./final_envelope.json --type common.Envelope > ./final_envelope.pb
    
    setGlobalsForPeer0Org1
    echo "---------------------------Org1 Signing the block for adding new Org---------------------------"
    peer channel signconfigtx -f ./final_envelope.pb

    # export CORE_PEER_LOCALMSPID="Org2MSP"
    # export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/../../artifacts/channel/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
    # export CORE_PEER_MSPCONFIGPATH=${PWD}/../../artifacts/channel/crypto-config/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    # export CORE_PEER_ADDRESS=localhost:9051

    setGlobalsForPeer0Org2
    echo "---------------------------Org2 Signing and Submitting the block for adding new Org to Orderer---------------------------"
    peer channel update -f ./final_envelope.pb -c ${CHANNEL_NAME} \
        -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
        --tls --cafile ${ORDERER_CA}
}
# signAndSubmit


# generateCryptoMaterial
# generateDefinition
# extractConfigBlock
# createConfigUpdate
signAndSubmit