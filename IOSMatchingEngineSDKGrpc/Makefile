# Copyright 2018-2021 MobiledgeX, Inc. All rights and licenses reserved.
# MobiledgeX, Inc. 156 2nd Street #408, San Francisco, CA 94105
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

REPOROOT := ../
SOURCE := $(REPOROOT)/IOSMatchingEngineSDKGrpc/MobiledgeXiOSLibraryGrpc/Classes

PROTOC := protoc
# Run "brew install coreutils" to get "grealpath" for protoc's requirement of absolute paths
ABSOLUTEPATH := $(shell grealpath ../..)
DME_PROTO_PATH = $(ABSOLUTEPATH)/edge-proto/dme
THIRD_PARTY_PROTOS_PATH = $(ABSOLUTEPATH)/edge-proto/third_party

PROTO_INCLUDE_DIRECTORIES := $(DME_PROTO_PATH) $(THIRD_PARTY_PROTOS_PATH)/googleapis
PROTO_INCLUDE_FLAGS += $(addprefix --proto_path ,$(PROTO_INCLUDE_DIRECTORIES))

all: build-proto gen-docs

build-proto:
	@echo Absolute Path for Proto files are: $(ABSOLUTEPATH)
	@echo Generating GRPC source code...
	$(shell protoc $(PROTO_INCLUDE_FLAGS) --swift_opt=Visibility=Public --grpc-swift_out=./MobiledgeXiOSLibraryGrpc/Classes/MatchingEngine/ --swift_out=./MobiledgeXiOSLibraryGrpc/Classes/MatchingEngine/ $(DME_PROTO_PATH)/*.proto --proto_path=$(ABSOLUTEPATH)/edge-proto) 

gen-docs:
ifeq (, $(shell which swift-doc))
	$(error "swift doc is not installed. Go to https://github.com/SwiftDocOrg/swift-doc for directions on how to install.")	
endif
	@echo Generating grpc documentation...
	$(shell rm -rf $(REPOROOT)/docs/grpc)
	$(shell swift doc generate $(SOURCE) --module-name "Swift Grpc SDK" --output $(REPOROOT)/docs/grpc --format html --base-url .)

