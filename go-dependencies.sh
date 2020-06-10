presetup() {
    echo Vendoring Go dependencies ...
    pushd ./artifacts/src/fabcar/go
    GO111MODULE=on go mod vendor
    popd
    echo Finished vendoring Go dependencies
}
presetup