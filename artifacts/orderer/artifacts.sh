export TEMP_FOLDER_PATH1=./channel/temp1
export TEMP_FOLDER_PATH2=./channel/temp2
export TEMP_FOLDER_PATH3=./channel/temp3
export TEMP_FOLDER_PATH4=./channel/temp4

export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=${PWD}/../../artifacts/channel/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export PEER0_ORG1_CA=${PWD}/../../artifacts/channel/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export PEER0_ORG2_CA=${PWD}/../../artifacts/channel/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export FABRIC_CFG_PATH=${PWD}/../../artifacts/config/
export ORDERER4_TLS_FILE=${PWD}/../../artifacts/channel/crypto-config/ordererOrganizations/example.com/orderers/orderer4.example.com/tls/server.crt

export CHANNEL_NAME=mychannel
export SYSTEM_CHANNEL_NAME=sys-channel

setGlobalsForOrderer() {
    export CORE_PEER_LOCALMSPID="OrdererMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/../../artifacts/channel/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    export CORE_PEER_MSPCONFIGPATH=${PWD}/../../artifacts/channel/crypto-config/ordererOrganizations/example.com/users/Admin@example.com/msp
}

setGlobalsForPeer0Org2() {
    export CORE_PEER_LOCALMSPID="Org2MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG2_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/../../artifacts/channel/crypto-config/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_ADDRESS=localhost:9051
}

# generateCryptoMaterial(){
#     echo "---------------------------Generating Crypto Material for new Organization 4---------------------------"
#     cryptogen generate --config=./crypto-config.yaml --output=./channel/crypto-config/
# }
# generateCryptoMaterial

addOrderer4ToConcenterListAndSystemChannel() {
    echo "---------------------------Updating Concenter list with new Orderer 4 and adding it into System Channel---------------------------"
    setGlobalsForOrderer
    peer channel fetch config $TEMP_FOLDER_PATH1/config_block.pb -o localhost:7050 \
        --ordererTLSHostnameOverride orderer.example.com \
        -c $SYSTEM_CHANNEL_NAME --tls --cafile $ORDERER_CA

    configtxlator proto_decode --input $TEMP_FOLDER_PATH1/config_block.pb \
    --type common.Block | jq .data.data[0].payload.data.config >$TEMP_FOLDER_PATH1/config.json

    echo "{\"client_tls_cert\":\"$(cat $ORDERER4_TLS_FILE | base64 -w 0)\",\"host\":\"orderer4.example.com\",\"port\":10050,\"server_tls_cert\":\"$(cat $ORDERER4_TLS_FILE | base64 -w 0)\"}" >$TEMP_FOLDER_PATH1/org4consenter.json
    jq ".channel_group.groups.Orderer.values.ConsensusType.value.metadata.consenters += [$(cat $TEMP_FOLDER_PATH1/org4consenter.json)]" $TEMP_FOLDER_PATH1/config.json >$TEMP_FOLDER_PATH1/modified_config.json
    configtxlator proto_encode --input $TEMP_FOLDER_PATH1/config.json --type common.Config --output $TEMP_FOLDER_PATH1/config.pb
    configtxlator proto_encode --input $TEMP_FOLDER_PATH1/modified_config.json --type common.Config --output $TEMP_FOLDER_PATH1/modified_config.pb
    configtxlator compute_update --channel_id $SYSTEM_CHANNEL_NAME --original $TEMP_FOLDER_PATH1/config.pb --updated $TEMP_FOLDER_PATH1/modified_config.pb --output $TEMP_FOLDER_PATH1/config_update.pb
    configtxlator proto_decode --input $TEMP_FOLDER_PATH1/config_update.pb --type common.ConfigUpdate --output $TEMP_FOLDER_PATH1/config_update.json
    echo "{\"payload\":{\"header\":{\"channel_header\":{\"channel_id\":\"sys-channel\", \"type\":2}},\"data\":{\"config_update\":"$(cat $TEMP_FOLDER_PATH1/config_update.json)"}}}" | jq . >$TEMP_FOLDER_PATH1/config_update_in_envelope.json
    configtxlator proto_encode --input $TEMP_FOLDER_PATH1/config_update_in_envelope.json --type common.Envelope --output $TEMP_FOLDER_PATH1/config_update_in_envelope.pb

    peer channel update -f $TEMP_FOLDER_PATH1/config_update_in_envelope.pb -c $SYSTEM_CHANNEL_NAME -o localhost:7050 --tls --cafile $ORDERER_CA
}
# addOrderer4ToConcenterListAndSystemChannel

getOrdererGenesisBlock() {
    echo "---------------------------Fetching Genesis Block---------------------------"
    setGlobalsForOrderer
    peer channel fetch config ./channel/genesis.block -o localhost:7050 -c $SYSTEM_CHANNEL_NAME --tls --cafile $ORDERER_CA
}
# getOrdererGenesisBlock

runOrderere4Container(){
    echo "---------------------------Running Orderer 4 Containers---------------------------"
    source .env
    docker-compose -f ./docker-compose.yaml up -d
}
# runOrderere4Container

addOrderer4AddressAndInSystemChannel() {
    echo "---------------------------Updating Address list with new Orderer 4 address and adding it into System Channel---------------------------"

    setGlobalsForOrderer

    peer channel fetch config $TEMP_FOLDER_PATH2/config_block.pb -o localhost:7050 -c $SYSTEM_CHANNEL_NAME --tls --cafile $ORDERER_CA

    configtxlator proto_decode --input $TEMP_FOLDER_PATH2/config_block.pb --type common.Block | jq .data.data[0].payload.data.config >$TEMP_FOLDER_PATH2/config.json
    
    jq ".channel_group.values.OrdererAddresses.value.addresses += [\"orderer4.example.com:10050\"]" $TEMP_FOLDER_PATH2/config.json >$TEMP_FOLDER_PATH2/modified_config.json
    
    configtxlator proto_encode --input $TEMP_FOLDER_PATH2/config.json --type common.Config --output $TEMP_FOLDER_PATH2/config.pb
    configtxlator proto_encode --input $TEMP_FOLDER_PATH2/modified_config.json --type common.Config --output $TEMP_FOLDER_PATH2/modified_config.pb
    
    configtxlator compute_update --channel_id $SYSTEM_CHANNEL_NAME --original $TEMP_FOLDER_PATH2/config.pb --updated $TEMP_FOLDER_PATH2/modified_config.pb --output $TEMP_FOLDER_PATH2/config_update.pb
    configtxlator proto_decode --input $TEMP_FOLDER_PATH2/config_update.pb --type common.ConfigUpdate --output $TEMP_FOLDER_PATH2/config_update.json
    
    echo "{\"payload\":{\"header\":{\"channel_header\":{\"channel_id\":\"sys-channel\", \"type\":2}},\"data\":{\"config_update\":"$(cat $TEMP_FOLDER_PATH2/config_update.json)"}}}" | jq . >$TEMP_FOLDER_PATH2/config_update_in_envelope.json
    
    configtxlator proto_encode --input $TEMP_FOLDER_PATH2/config_update_in_envelope.json --type common.Envelope --output $TEMP_FOLDER_PATH2/config_update_in_envelope.pb
    
    peer channel update -f $TEMP_FOLDER_PATH2/config_update_in_envelope.pb -c $SYSTEM_CHANNEL_NAME -o localhost:7050 --tls true --cafile $ORDERER_CA

}

# addOrderer4AddressAndInSystemChannel

addOrderer4ToConcenterListAndApplicationChannel(){
    setGlobalsForOrderer

    echo "---------------------------Updating Concenter list with new Orderer 4 and adding it into Application Channel---------------------------"

    peer channel fetch config $TEMP_FOLDER_PATH3/config_block.pb -o localhost:7050 -c $CHANNEL_NAME --tls --cafile $ORDERER_CA

    configtxlator proto_decode --input $TEMP_FOLDER_PATH3/config_block.pb --type common.Block | jq .data.data[0].payload.data.config >$TEMP_FOLDER_PATH3/config.json

    echo "{\"client_tls_cert\":\"$(cat $ORDERER4_TLS_FILE | base64 -w 0)\",\"host\":\"orderer4.example.com\",\"port\":10050,\"server_tls_cert\":\"$(cat $ORDERER4_TLS_FILE | base64 -w 0)\"}" >$TEMP_FOLDER_PATH3/orderer4consenter.json

    jq ".channel_group.groups.Orderer.values.ConsensusType.value.metadata.consenters += [$(cat $TEMP_FOLDER_PATH3/orderer4consenter.json)]" $TEMP_FOLDER_PATH3/config.json >$TEMP_FOLDER_PATH3/modified_config.json
    
    configtxlator proto_encode --input $TEMP_FOLDER_PATH3/config.json --type common.Config --output $TEMP_FOLDER_PATH3/config.pb
    configtxlator proto_encode --input $TEMP_FOLDER_PATH3/modified_config.json --type common.Config --output $TEMP_FOLDER_PATH3/modified_config.pb
    configtxlator compute_update --channel_id $CHANNEL_NAME --original $TEMP_FOLDER_PATH3/config.pb --updated $TEMP_FOLDER_PATH3/modified_config.pb --output $TEMP_FOLDER_PATH3/config_update.pb
    
    configtxlator proto_decode --input $TEMP_FOLDER_PATH3/config_update.pb --type common.ConfigUpdate --output $TEMP_FOLDER_PATH3/config_update.json
    
    echo "{\"payload\":{\"header\":{\"channel_header\":{\"channel_id\":\"mychannel\", \"type\":2}},\"data\":{\"config_update\":"$(cat $TEMP_FOLDER_PATH3/config_update.json)"}}}" | jq . >$TEMP_FOLDER_PATH3/config_update_in_envelope.json
    
    configtxlator proto_encode --input $TEMP_FOLDER_PATH3/config_update_in_envelope.json --type common.Envelope --output $TEMP_FOLDER_PATH3/config_update_in_envelope.pb
    peer channel update -f $TEMP_FOLDER_PATH3/config_update_in_envelope.pb -c mychannel -o localhost:7050 --tls true --cafile $ORDERER_CA
}
# addOrderer4ToConcenterListAndApplicationChannel

addOrderer4AddressAndInApplicationhannel() {
    echo "---------------------------Updating Address list with new Orderer 4 address and adding it into Application Channel---------------------------"

    setGlobalsForOrderer

    peer channel fetch config $TEMP_FOLDER_PATH4/config_block.pb -o localhost:7050 -c $CHANNEL_NAME --tls --cafile $ORDERER_CA

    configtxlator proto_decode --input $TEMP_FOLDER_PATH4/config_block.pb --type common.Block | jq .data.data[0].payload.data.config >$TEMP_FOLDER_PATH4/config.json
    
    jq ".channel_group.values.OrdererAddresses.value.addresses += [\"orderer4.example.com:10050\"]" $TEMP_FOLDER_PATH4/config.json >$TEMP_FOLDER_PATH4/modified_config.json
    
    configtxlator proto_encode --input $TEMP_FOLDER_PATH4/config.json --type common.Config --output $TEMP_FOLDER_PATH4/config.pb
    configtxlator proto_encode --input $TEMP_FOLDER_PATH4/modified_config.json --type common.Config --output $TEMP_FOLDER_PATH4/modified_config.pb
    
    configtxlator compute_update --channel_id $CHANNEL_NAME --original $TEMP_FOLDER_PATH4/config.pb --updated $TEMP_FOLDER_PATH4/modified_config.pb --output $TEMP_FOLDER_PATH4/config_update.pb
    configtxlator proto_decode --input $TEMP_FOLDER_PATH4/config_update.pb --type common.ConfigUpdate --output $TEMP_FOLDER_PATH4/config_update.json
    
    echo "{\"payload\":{\"header\":{\"channel_header\":{\"channel_id\":\"$CHANNEL_NAME\", \"type\":2}},\"data\":{\"config_update\":"$(cat $TEMP_FOLDER_PATH4/config_update.json)"}}}" | jq . >$TEMP_FOLDER_PATH4/config_update_in_envelope.json
    
    configtxlator proto_encode --input $TEMP_FOLDER_PATH4/config_update_in_envelope.json --type common.Envelope --output $TEMP_FOLDER_PATH4/config_update_in_envelope.pb
    
    peer channel update -f $TEMP_FOLDER_PATH4/config_update_in_envelope.pb -c $CHANNEL_NAME -o localhost:7050 --tls true --cafile $ORDERER_CA

}
# addOrderer4ToConcenterListAndApplicationChannel

chaincodeQuery() {
    echo "---------------------------Quering Chaincode by Peer 0 of Org 2---------------------------"
    setGlobalsForPeer0Org2

    # export CAR=$(echo -n "{\"key\":\"1111\", \"make\":\"Hyundai\",\"model\":\"Tucson\",\"color\":\"Gray\",\"owner\":\"Sumit\",\"price\":\"22000\"}" | base64 | tr -d \\n)
    peer chaincode invoke -o localhost:7050 \
        --ordererTLSHostnameOverride orderer.example.com \
        --tls $CORE_PEER_TLS_ENABLED \
        --cafile $ORDERER_CA \
        -C $CHANNEL_NAME -n "fabcar" \
        --peerAddresses localhost:7051 \
        --tlsRootCertFiles $PEER0_ORG1_CA \
        --peerAddresses localhost:9051 \
        --tlsRootCertFiles $PEER0_ORG2_CA \
        -c '{"function": "createCar", "Args":["CAR_ls","Hyundai", "Palisade", "Gray", "Sumit"]}'

    # Query Car by Id
    peer chaincode query -C $CHANNEL_NAME -n "fabcar" -c '{"function": "queryCar","Args":["CAR_ls"]}'


}

# generateCryptoMaterial


addOrderer4ToConcenterListAndSystemChannel
getOrdererGenesisBlock
runOrderere4Container
addOrderer4AddressAndInSystemChannel
addOrderer4ToConcenterListAndApplicationChannel

# chaincodeQuery


