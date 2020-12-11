export TEMP_FOLDER_PATH1=./channel/temp1
export TEMP_FOLDER_PATH2=./channel/temp2
export TEMP_FOLDER_PATH3=./channel/temp3
export TEMP_FOLDER_PATH4=./channel/temp4

export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=${PWD}/../../artifacts/channel/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export FABRIC_CFG_PATH=${PWD}/../../artifacts/config/
export ORDERER4_TLS_FILE=${PWD}/channel/crypto-config/ordererOrganizations/example.com/orderers/orderer4.example.com/tls/server.crt

export CHANNEL_NAME=mychannel
export SYSTEM_CHANNEL_NAME=sys-channel

setGlobalsForOrderer() {
    export CORE_PEER_LOCALMSPID="OrdererMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/../../artifacts/channel/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    export CORE_PEER_MSPCONFIGPATH=${PWD}/../../artifacts/channel/crypto-config/ordererOrganizations/example.com/users/Admin@example.com/msp
}

generateCryptoMaterial(){
    echo "---------------------------Generating Crypto Material for new Organization 3---------------------------"
    cryptogen generate --config=./crypto-config.yaml --output=./channel/crypto-config/
}
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

addOrderer4AddressAndInSystemChannel
