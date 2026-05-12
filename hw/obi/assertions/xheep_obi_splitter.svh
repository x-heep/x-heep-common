// Copyright 2025 EPFL.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 2.0 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-2.0. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// File: xheep_obi_splitter.svh
// Author(s):
//   Michele Caon <michele.caon@epfl.ch>
// Date: 16/09/2025
// Description: Assertions for the xheep_obi_splitter module

`ifndef XHEEP_OBI_SPLITTER_SVH_
`define XHEEP_OBI_SPLITTER_SVH_

function automatic bit xheep_obi_splitter_check_params();
  // MasterDataW and SlaveDataW must be power of two higher than 8
  if ((MasterDataW & (MasterDataW - 1)) != 0 || MasterDataW < 8)
    $fatal(1, "The bitwidth of master_req_i.wdata must be a power of 2 and > 8, got %d!", MasterDataW);
  if ((SlaveDataW & (SlaveDataW - 1)) != 0 || SlaveDataW < 8)
    $fatal(1, "The bitwidth of slave_req_o.wdata must be a power of 2 and > 8, got %d!", SlaveDataW);

  // MasterDataW must be a multiple of SlaveDataW
  if (MasterDataW % SlaveDataW != 0)
    $fatal(1, "The bitwidth of master_req_i.wdata must be a multiple of slave_req_o.wdata, got %d and %d respectively!", MasterDataW, SlaveDataW);

  // The slave address width must be larger than the master address width
  if (MasterAddrW > SlaveAddrW)
    $fatal(1, "The bitwidth of master_req_i.addr must be <= slave_req_o.addr, got %d and %d respectively!", MasterAddrW, SlaveAddrW);

  return 1'b0;
endfunction: xheep_obi_splitter_check_params

// Dummy localparam to trigger check at elaboration time
localparam bit _ = xheep_obi_splitter_check_params();

`endif /* XHEEP_OBI_SPLITTER_SVH_ */
