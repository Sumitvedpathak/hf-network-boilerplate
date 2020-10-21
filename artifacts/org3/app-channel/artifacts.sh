
export TEMP_FOLDER_PATH=./channel/temp


export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=${PWD}/../../../artifacts/channel/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export PEER0_ORG1_CA=${PWD}/../../../artifacts/channel/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export PEER0_ORG2_CA=${PWD}/../../../artifacts/channel/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export PEER0_ORG3_CA=${PWD}/channel/crypto-config/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export FABRIC_CFG_PATH=${PWD}/../../../artifacts/config/

export CHANNEL_NAME=mychannel

setGlobalsForOrderer() {
    export CORE_PEER_LOCALMSPID="OrdererMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/../../../artifacts/channel/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    export CORE_PEER_MSPCONFIGPATH=${PWD}/../../../artifacts/channel/crypto-config/ordererOrganizations/example.com/users/Admin@example.com/msp

}

setGlobalsForPeer0Org1() {
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG1_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/../../../artifacts/channel/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051
}

setGlobalsForPeer0Org2() {
    export CORE_PEER_LOCALMSPID="Org2MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG2_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/../../../artifacts/channel/crypto-config/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_ADDRESS=localhost:9051

}

setGlobalsForPeer0Org3() {
    export CORE_PEER_LOCALMSPID="Org3MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG3_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/channel/crypto-config/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
    export CORE_PEER_ADDRESS=localhost:11051

}

generateCryptoMaterial(){
    echo "---------------------------Generating Crypto Material for new Organization 3---------------------------"
    cryptogen generate --config=./crypto-config.yaml --output=./channel/crypto-config/
}
# generateCryptoMaterial

generateDefinition(){
    echo "---------------------------Generate JSON configuration file---------------------------"
    # export FABRIC_CFG_PATH=${PWD}/artifacts/config/ ---------------------Earlier state
    export FABRIC_CFG_PATH=${PWD}/
    echo $FABRIC_CFG_PATH
    configtxgen -printOrg Org3MSP >$TEMP_FOLDER_PATH/org3.json
}
# generateDefinition

extractConfigBlock(){
    setGlobalsForOrderer
    setGlobalsForPeer0Org1

    echo "---------------------------Extract config block from blockchain---------------------------"
    peer channel fetch config $TEMP_FOLDER_PATH/config_block.pb -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    -c $CHANNEL_NAME --tls --cafile $ORDERER_CA

    echo "---------------------------Convert config protobuff to json---------------------------"
    configtxlator proto_decode --input $TEMP_FOLDER_PATH/config_block.pb \
    --type common.Block | jq .data.data[0].payload.data.config > $TEMP_FOLDER_PATH/config_original.json

    echo "---------------------------Create updated Org3 config json file---------------------------"
    jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"Org3MSP":.[1]}}}}}' $TEMP_FOLDER_PATH/config_original.json $TEMP_FOLDER_PATH/org3.json > $TEMP_FOLDER_PATH/org3_modified_config.json
}
extractConfigBlock

createConfigUpdate(){

    CHANNEL="mychannel"

    echo "---------------------------Convert main config json to protobuff format---------------------------"
    configtxlator proto_encode --input $TEMP_FOLDER_PATH/config_original.json --type common.Config > $TEMP_FOLDER_PATH/config_original.pb

    echo "---------------------------Convert modified Org3 config json to protobuff format---------------------------"
    configtxlator proto_encode --input $TEMP_FOLDER_PATH/org3_modified_config.json --type common.Config > $TEMP_FOLDER_PATH/org3_modified_config.pb

    echo $CHANNEL_NAME
    echo "---------------------------Merge to protobuff format---------------------------"
    configtxlator compute_update --channel_id $CHANNEL_NAME --original $TEMP_FOLDER_PATH/config_original.pb --updated $TEMP_FOLDER_PATH/org3_modified_config.pb > $TEMP_FOLDER_PATH/main_updated_config.pb

    echo "---------------------------Convert Merged protobuff to JSON format---------------------------"
    configtxlator proto_decode --input $TEMP_FOLDER_PATH/main_updated_config.pb --type common.ConfigUpdate > $TEMP_FOLDER_PATH/main_updated_config.json

    echo "---------------------------Update wrapper to JSON format---------------------------"
    echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL_NAME'", "type":2}},"data":{"config_update":'$(cat $TEMP_FOLDER_PATH/main_updated_config.json)'}}}' | jq . > $TEMP_FOLDER_PATH/final_envelope.json

    echo "---------------------------Convert final json to protobuff format---------------------------"
    configtxlator proto_encode --input $TEMP_FOLDER_PATH/final_envelope.json --type common.Envelope > $TEMP_FOLDER_PATH/final_envelope.pb
}
# createConfigUpdate

signAndSubmit(){
    setGlobalsForPeer0Org1
    echo "---------------------------Org1 Signing the block for adding new Org---------------------------"
    peer channel signconfigtx -f $TEMP_FOLDER_PATH/final_envelope.pb

    setGlobalsForPeer0Org2

    echo "---------------------------Org2 Signing and Submitting the block for adding new Org to Orderer---------------------------"
    peer channel update -f $TEMP_FOLDER_PATH/final_envelope.pb -c ${CHANNEL_NAME} \
        -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
        --tls --cafile ${ORDERER_CA}
}
# signAndSubmit

# removeFiles(){
    
# }

BringUpOrg3Containers(){
    echo "---------------------------Bringing up Org 3 containers---------------------------"
    source .env
    docker-compose -f ./docker-compose.yaml up -d
}
# BringUpOrg3Containers



joinChannel(){
    setGlobalsForPeer0Org3
    echo "---------------------------Extract channel Block for Org 3---------------------------"
    peer channel fetch 0 $TEMP_FOLDER_PATH/$CHANNEL_NAME.block -o localhost:7050 \
        --ordererTLSHostnameOverride orderer.example.com \
        -c $CHANNEL_NAME \
        --tls --cafile $ORDERER_CA 
        # >&$TEMP_FOLDER_PATH/log.txt

    sleep 5

    setGlobalsForPeer0Org3
    echo "---------------------------Org 3 Joining mychannel channel ---------------------------"
    peer channel join -b $TEMP_FOLDER_PATH/$CHANNEL_NAME.block
}
# joinChannel

chaincodeQuery() {
    echo "---------------------------Quering Chaincode by Peer 0 of Org 3---------------------------"
    setGlobalsForPeer0Org3
    CC_NAME="fabcar"
    peer chaincode query -C $CHANNEL_NAME -n ${CC_NAME} -c '{"function": "queryCar","Args":["CAR0"]}'
}
# chaincodeQuery

# generateCryptoMaterial
# generateDefinition
# extractConfigBlock
# createConfigUpdate
# signAndSubmit
# BringUpOrg3Containers
# joinChannel
# sleep 5
# chaincodeQuery