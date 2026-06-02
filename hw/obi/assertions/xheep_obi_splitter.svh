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
  // M_DW and S_DW must be power of two higher than 8
  if ((M_DW & (M_DW - 1)) != 0 || M_DW < 8)
    $fatal(1, "The bitwidth of master_req_i.wdata must be a power of 2 and > 8, got %d!", M_DW);
  if ((S_DW & (S_DW - 1)) != 0 || S_DW < 8)
    $fatal(1, "The bitwidth of slave_req_o.wdata must be a power of 2 and > 8, got %d!", S_DW);

  // M_DW must be a multiple of S_DW
  if (M_DW % S_DW != 0)
    $fatal(1, "The bitwidth of master_req_i.wdata must be a multiple of slave_req_o.wdata, got %d and %d respectively!", M_DW, S_DW);

  // The slave address width must be larger than the master address width
  if (M_AW > S_AW)
    $fatal(1, "The bitwidth of master_req_i.addr must be <= slave_req_o.addr, got %d and %d respectively!", M_AW, S_AW);

  return 1'b0;
endfunction: xheep_obi_splitter_check_params

// Dummy localparam to trigger check at elaboration time
localparam bit _ = xheep_obi_splitter_check_params();

`endif /* XHEEP_OBI_SPLITTER_SVH_ */
