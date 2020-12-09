generateCryptoMaterial(){
    echo "---------------------------Generating Crypto Material for new Organization 3---------------------------"
    cryptogen generate --config=./crypto-config.yaml --output=./channel/crypto-config/
}

generateCryptoMaterial