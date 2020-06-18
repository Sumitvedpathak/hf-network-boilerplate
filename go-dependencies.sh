presetup() {
    echo Vendoring Go dependencies ...
    pushd ./artifacts/src/fabcar
    GO111MODULE=on go mod vendor
    popd
    echo Finished vendoring Go dependencies
}
presetup