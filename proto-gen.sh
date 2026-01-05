#!/bin/bash
shopt -s globstar

echo "Cleaning up old proto and lib directories..."
rm -rf proto &
rm -rf lib &

GO_BIN_PATH=$(go env GOPATH)/bin
PRO_7_PATH=/Applications/ProPresenter.app

echo "Grabbing protos from ProPresenter 7..."
$GO_BIN_PATH/protodump -file $PRO_7_PATH/Contents/Frameworks/ProCore.framework/Versions/A/ProCore -output ./proto
echo "Protos grabbed. Generating ruby code..."
mkdir lib
protoc -I ./proto --ruby_out ./lib proto/**/*.proto
echo "Ruby code generated in ./lib"
