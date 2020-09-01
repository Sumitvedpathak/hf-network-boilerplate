export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=${PWD}/artifacts/channel/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export PEER2_ORG1_CA=${PWD}/artifacts/channel/crypto-config/peerOrganizations/org1.example.com/peers/peer2.org1.example.com/tls/ca.crt
export FABRIC_CFG_PATH=${PWD}/artifacts/config/

export CHANNEL_NAME=mychannel
CC_NAME="fabcar"

setGlobalsForPeer2Org1(){
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER2_ORG1_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/artifacts/channel/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:11051
}

AddNewPeer(){
    setGlobalsForPeer2Org1
    echo "---------------------------Join Org1 Peer 2 to mychannel channel---------------------------"
    peer channel join -b ./artifacts/channel/mychannel.block
}

InstallChaincode(){
    echo "---------------------------Installing Chaincode on Peer 2 of Org 1---------------------------"
    setGlobalsForPeer2Org1

    peer lifecycle chaincode install ./src/${CC_NAME}.tar.gz

}

ChaincodeQuery() {
    echo "---------------------------Quering Chaincode by Peer 2 of Org 1---------------------------"
    setGlobalsForPeer2Org1

    peer chaincode query -C $CHANNEL_NAME -n ${CC_NAME} -c '{"function": "queryCar","Args":["CAR0"]}'
}

#AddNewPeer
ChaincodeQuery
# InstallChaincode
# ChaincodeQuery