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
// File: xheep_mem_demux.svh
// Author(s):
//   Michele Caon <michele.caon@epfl.ch>
// Date: 08/09/2025
// Description: Assertions for xheep_mem_demux module.

`ifndef XHEEP_MEM_DEMUX_SVH_
`define XHEEP_MEM_DEMUX_SVH_

function automatic bit xheep_mem_demux();
  // Memory data width must be a multiple of 8
  if (MemDataW % 8 != 0)
    $fatal(1, "MemDataW (%d) must be a multiple of 8!", MemDataW);

  // VRF data width must be a multiple of memory data width
  if (VrfDataW % MemDataW != 0)
    $fatal(1, "VrfDataW (%d) must be a multiple of MemDataW (%d)!", VrfDataW, MemDataW);

  return 1'b0;
endfunction: xheep_mem_demux

localparam bit _ = xheep_mem_demux();

`endif /* XHEEP_MEM_DEMUX_SVH_ */

