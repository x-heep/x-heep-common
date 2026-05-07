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
// File: xheep_mem_demux.sv
// Author(s):
//   Michele Caon <michele.caon@epfl.ch>
// Date: 09/09/2025
// Description: SRAM-like memory request demultiplexer.

// This module is an adapter from a master with a narrow M_DW-bit payload
// (wdata) to a slave with a wider S_DW data payload, where S_DW is a power of
// two and multiple of M_DW. M_DW and S_DW are inferred from the master_req_t
// and slave_req_t data types (see parameters below).

module xheep_mem_demux #(
  // Memory master request type, expected to contain:
  //    logic              req     > request
  //    logic              we      > write enable
  //    logic [M_DW/8-1:0] be      > byte enable
  //    logic   [M_AW-1:0] addr    > target address
  //    logic   [M_DW-1:0] wdata   > data to write
  parameter type master_req_t = logic,
  // Memory response type, expected to contain:
  //    logic   [M_DW-1:0] rdata   > read data
  parameter type master_rsp_t = logic,
  // VRF request type, expected to contain:
  //    logic              req     > request
  //    logic              we      > write enable
  //    logic [S_DW/8-1:0] be      > byte enable
  //    logic   [S_AW-1:0] addr    > target address
  //    logic   [S_DW-1:0] wdata   > data to write
  parameter type slave_req_t = logic,
  // VRF response type, expected to contain:
  //    logic   [S_DW-1:0] rdata   > read data
  parameter type slave_rsp_t = logic,
  parameter int unsigned DELAY = 'd1  // SRAM read delay
) (
  input logic clk_i,
  input logic rst_ni,

  // Memory interface
  input  master_req_t mem_req_i,  // SRAM-like memory request
  output master_rsp_t mem_rsp_o,  // SRAM-like memory response

  // VRF interface
  output slave_req_t vrf_req_o,  // VRF request
  input  slave_rsp_t vrf_rsp_i   // VRF response
);
  // PARAMETERS
  localparam int unsigned MemDataW = $bits(type (mem_req_i.wdata));
  localparam int unsigned VrfDataW = $bits(type (vrf_req_o.wdata));
  localparam int unsigned MemWordNumBytes = MemDataW / 8;
  localparam int unsigned MemByteOffsW = $clog2(MemWordNumBytes);
  localparam int unsigned VrfLineWordNum = VrfDataW / MemDataW;
  localparam int unsigned VrfLineWordAddrW = (VrfLineWordNum > 1) ? unsigned'($clog2(VrfLineWordNum)) : 'd1;

  // INTERNAL SIGNALS
  // ----------------
  logic [VrfLineWordAddrW-1:0]               vrf_word_addr[DELAY+1];
  logic [  VrfLineWordNum-1:0][MemDataW-1:0] vrf_rdata;
  logic [  VrfLineWordNum-1:0][MemDataW-1:0] vrf_wdata;

  // In case the VRF data width is larger (i.e., a multiple) than the OBI data
  // width, the OBI word offset within the VRF word must be delayed as well.
  generate
    if (VrfDataW > MemDataW) begin : gen_addr_delay
      assign vrf_word_addr[0] = mem_req_i.addr[MemByteOffsW+:$clog2(VrfLineWordNum)];
      for (genvar i = 1; unsigned'(i) <= DELAY; i++) begin : gen_addr_delay_ff
        always_ff @(posedge clk_i or negedge rst_ni) begin
          if (!rst_ni) begin
            vrf_word_addr[i] <= '0;
          end else begin
            vrf_word_addr[i] <= vrf_word_addr[i-1];
          end
        end
      end
    end else begin : gen_no_addr_delay
      for (genvar i = 0; unsigned'(i) <= DELAY; i++) begin : gen_no_addr_delay_ff
        assign vrf_word_addr[i] = '0;
      end
    end
  endgenerate

  // VRF request alignment
  // ---------------------
  // VRF request data replication
  generate
    for (genvar i = 0; unsigned'(i) < VrfDataW / MemDataW; i++) begin : gen_wdata_rep
      assign vrf_wdata[i] = mem_req_i.wdata;
    end
  endgenerate

  // VRF request byte enable encoding
  always_comb begin : vrf_be_encoding
    vrf_req_o.be                                                    = '0;
    vrf_req_o.be[vrf_word_addr[0]*MemWordNumBytes+:MemWordNumBytes] = mem_req_i.be;
  end

  // VRF response alignment
  // ----------------------
  assign vrf_rdata       = vrf_rsp_i.rdata;
  assign mem_rsp_o.rdata = vrf_rdata[vrf_word_addr[DELAY]];

  // OUTPUT EVALUATION
  // -----------------

  // OBI request to SRAM request
  assign vrf_req_o.req   = mem_req_i.req;
  assign vrf_req_o.we    = mem_req_i.we;
  assign vrf_req_o.addr  = mem_req_i.addr;
  assign vrf_req_o.wdata = vrf_wdata;

  // ----------
  // ASSERTIONS
  // ----------
`ifndef SYNTHESIS
  `include "xheep_mem_demux.svh"
`endif  // SYNTHESIS
endmodule
