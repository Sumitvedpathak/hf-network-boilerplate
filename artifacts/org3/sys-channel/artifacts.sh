
export TEMP_FOLDER_PATH=../channel/sys-ch/temp


export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=${PWD}/../../../artifacts/channel/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export PEER0_ORG1_CA=${PWD}/../../../artifacts/channel/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export PEER0_ORG2_CA=${PWD}/../../../artifacts/channel/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export PEER0_ORG3_CA=${PWD}/../channel/sys-ch/crypto-config/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
export FABRIC_CFG_PATH=${PWD}/../../../artifacts/config/

export CHANNEL_NAME=org1-org3-channel
export SYSTEM_CHANNEL_NAME=sys-channel

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
    export CORE_PEER_MSPCONFIGPATH=${PWD}/../channel/sys-ch/crypto-config/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
    export CORE_PEER_ADDRESS=localhost:11051

}

generateArtifacts(){
    echo "---------------------------Generating Crypto Material for new Organization 3---------------------------"
    cryptogen generate --config=./crypto-config.yaml --output=../channel/sys-ch/crypto-config/

    CHANNEL_NAME="org1-org3-channel"
    echo "---------------------------Generating Channel Artifacts for new Organization 3---------------------------"
    configtxgen -profile org1-org3-channel -configPath . -outputCreateChannelTx ../channel/sys-ch/org1-org3-channel.tx -channelID $CHANNEL_NAME

    echo "---------------------------Generating Anchor Peer updates for Org1---------------------------"
    configtxgen -profile org1-org3-channel -configPath . -outputAnchorPeersUpdate ../channel/sys-ch/Org1MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org1MSP

    echo "---------------------------Generating Anchor Peer updates for Org3---------------------------"
    configtxgen -profile org1-org3-channel -configPath . -outputAnchorPeersUpdate ../channel/sys-ch/Org3MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org3MSP

}
# generateArtifacts

generateDefinition(){
    echo "---------------------------Generate JSON configuration file---------------------------"
    # export FABRIC_CFG_PATH=${PWD}/artifacts/config/ ---------------------Earlier state
    export FABRIC_CFG_PATH=${PWD}/
    echo ${FABRIC_CFG_PATH}
    configtxgen -printOrg Org3MSP >$TEMP_FOLDER_PATH/org3.json
}
# generateDefinition

extractConfigBlock(){
    
    setGlobalsForOrderer

    echo "---------------------------Extract config block from blockchain---------------------------"
    peer channel fetch config $TEMP_FOLDER_PATH/config_block.pb -o localhost:7050 \
    --ordererTLSHostnameOverride orderer.example.com \
    -c $SYSTEM_CHANNEL_NAME --tls --cafile $ORDERER_CA
    

    echo "---------------------------Convert config protobuff to json---------------------------"
    configtxlator proto_decode --input $TEMP_FOLDER_PATH/config_block.pb \
    --type common.Block | jq .data.data[0].payload.data.config > $TEMP_FOLDER_PATH/config_original.json

    echo "---------------------------Create updated Org3 config json file---------------------------"
    echo "This is the main change where we are adding Org 3 in consortium instead of Application channel"
    jq -s  '.[0] * {"channel_group":{"groups":{"Consortiums":{"groups":{"SampleConsortium":{"groups": {"Org3MSP":.[1]}}}}}}}'  $TEMP_FOLDER_PATH/config_original.json $TEMP_FOLDER_PATH/org3.json > $TEMP_FOLDER_PATH/org3_modified_config.json
}
# extractConfigBlock

createConfigUpdate(){

    CHANNEL="sys-channel"

    echo "---------------------------Convert main config json to protobuff format---------------------------"
    configtxlator proto_encode --input $TEMP_FOLDER_PATH/config_original.json --type common.Config > $TEMP_FOLDER_PATH/config_original.pb

    echo "---------------------------Convert modified Org3 config json to protobuff format---------------------------"
    configtxlator proto_encode --input $TEMP_FOLDER_PATH/org3_modified_config.json --type common.Config > $TEMP_FOLDER_PATH/org3_modified_config.pb

    echo $SYSTEM_CHANNEL_NAME
    echo "---------------------------Merge to protobuff format---------------------------"
    configtxlator compute_update --channel_id $SYSTEM_CHANNEL_NAME --original $TEMP_FOLDER_PATH/config_original.pb --updated $TEMP_FOLDER_PATH/org3_modified_config.pb > $TEMP_FOLDER_PATH/main_updated_config.pb

    echo "---------------------------Convert Merged protobuff to JSON format---------------------------"
    configtxlator proto_decode --input $TEMP_FOLDER_PATH/main_updated_config.pb --type common.ConfigUpdate > $TEMP_FOLDER_PATH/main_updated_config.json

    echo "---------------------------Update wrapper to JSON format---------------------------"
    echo '{"payload":{"header":{"channel_header":{"channel_id":"'$SYSTEM_CHANNEL_NAME'", "type":2}},"data":{"config_update":'$(cat $TEMP_FOLDER_PATH/main_updated_config.json)'}}}' | jq . > $TEMP_FOLDER_PATH/final_envelope.json

    echo "---------------------------Convert final json to protobuff format---------------------------"
    configtxlator proto_encode --input $TEMP_FOLDER_PATH/final_envelope.json --type common.Envelope > $TEMP_FOLDER_PATH/final_envelope.pb
}
# createConfigUpdate

signAndSubmit(){
    setGlobalsForOrderer

    echo "---------------------------Sign Config as Orderer Org---------------------------"
    peer channel update -f $TEMP_FOLDER_PATH/final_envelope.pb -c ${SYSTEM_CHANNEL_NAME} \
        -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
        --tls --cafile ${ORDERER_CA}
}
# signAndSubmit


BringUpOrg3Containers(){
    echo "---------------------------Bringing up Org 3 containers---------------------------"
    source .env
    docker-compose -f ./docker-compose.yaml up -d
}
# BringUpOrg3Containers


createChannel(){
    setGlobalsForPeer0Org3
    
    peer channel create -o localhost:7050 -c $CHANNEL_NAME \
    --ordererTLSHostnameOverride orderer.example.com \
    -f ../channel/sys-ch/${CHANNEL_NAME}.tx --outputBlock ../channel/sys-ch//${CHANNEL_NAME}.block \
    --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA
}

createChannel

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