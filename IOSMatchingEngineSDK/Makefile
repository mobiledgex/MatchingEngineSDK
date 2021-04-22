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
SOURCE := $(REPOROOT)/IOSMatchingEngineSDK/MobiledgeXiOSLibrary/Classes

all: gen-docs

gen-docs:
ifeq (, $(shell which swift-doc))
	$(error "swift doc is not installed. Go to https://github.com/SwiftDocOrg/swift-doc for directions on how to install.")	
endif
	@echo Generating rest documentation...
	$(shell rm -rf $(REPOROOT)/docs/rest)
	$(shell swift doc generate $(SOURCE) --module-name "Swift SDK" --output $(REPOROOT)/docs/rest --format html --base-url .)

