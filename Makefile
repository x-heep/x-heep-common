# Copyright 2026 EPFL.
# Copyright and related rights are licensed under the Solderpad Hardware
# License, Version 2.0 (the "License"); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
# http://solderpad.org/licenses/SHL-2.0. Unless required by applicable law
# or agreed to in writing, software, hardware and materials distributed under
# this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied. See the License for the
# specific language governing permissions and limitations under the License.
#
# File: Makefile
# Author(s):
#   Michele Caon <michele.caon@epfl.ch>
# Date: 08/04/2026
# Description: Makefile for X-HEEP Common Modules

#############################
# ----- CONFIGURATION ----- #
#############################

# Buffer output from parallel jobs and check undefined variables
MAKEFLAGS 	+= --output-sync=target \
			 --warn-undefined-variables

# ROOT DIRECTORY
ROOT		:= $(shell git rev-parse --show-toplevel)

# VENDOR FILES
VENDOR_FILES	:= $(shell find hw/vendor -maxdepth 1 -type f -name "*.vendor.hjson" -print)
VENDOR_LOCKS	:= $(subst .vendor.hjson,.lock.hjson,$(VENDOR_FILES))

#######################
# ----- TARGETS ----- #
#######################

# Default Target
# --------------
.PHONY: all
all: format lint

# Help
# ----
.PHONY: help
help:
	@printf "Available targets:\\n"
	@printf "  all:      Run format and lint targets (default)\\n"
	@printf "  format:   Format SystemVerilog source files using Verible\\n"
	@printf "  lint:     Perform static analysis using Verible\\n"
	@printf "  help:     Print this help message\\n"

# Code formatting and linting
# ---------------------------
# Code formatting
.PHONY: format
format: | .check-verible-format
	fusesoc run --no-export --target format xheep:common:all

# Static analysis (linting)
.PHONY: lint
lint: | .check-verible-lint
	fusesoc run --no-export --target lint xheep:common:all

# Vendor third-party dependencies
# --------------------------------------------------------------------------
.PHONY: vendor-update
vendor-update: $(VENDOR_LOCKS)
	python3 hw/vendor/x-heep/util/check-vendor.py

$(VENDOR_LOCKS): %.lock.hjson: %.vendor.hjson hw/vendor/x-heep/util/vendor.py
	@echo "### Updating vendored IP '$(notdir $*)'..."
	python3 hw/vendor/x-heep/util/vendor.py -vU $<

.PHONY: vendor-clean
vendor-clean:
	@echo "### Cleaning vendor IPs..."
	$(RM) $(VENDOR_LOCKS)

# Utilities
# ---------
# Check if a program is available in PATH
define CHECK_PROGRAM
.PHONY: .check-$(1)
.check-$(1):
	@command -v $(2) >/dev/null 2>&1 || { \
		printf "### ERROR: '%s' is not in PATH.\\n" "$(2)" >&2; \
		exit 1; \
	}
endef
$(eval $(call CHECK_PROGRAM,verible-format,verible-verilog-format))
$(eval $(call CHECK_PROGRAM,verible-lint,verible-verilog-lint))
