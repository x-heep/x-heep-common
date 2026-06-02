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
  // These are necessary to avoid errors with using $bits() in QuestaSim
  parameter int unsigned M_DW = 32'd32,  // master data width
  parameter int unsigned S_DW = 32'd32,  // slave data width
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
  input  master_req_t master_req_i,  // SRAM-like master request
  output master_rsp_t master_rsp_o,  // SRAM-like master response

  // VRF interface
  output slave_req_t slave_req_o,  // SRAM-like slave request
  input  slave_rsp_t slave_rsp_i   // SRAM-like slave response
);
  // PARAMETERS
  localparam int unsigned MemWordNumBytes = M_DW / 8;
  localparam int unsigned MemByteOffsW = $clog2(MemWordNumBytes);
  localparam int unsigned VrfLineWordNum = S_DW / M_DW;
  localparam int unsigned VrfLineWordAddrW = (VrfLineWordNum > 1) ? unsigned'($clog2(VrfLineWordNum)) : 'd1;

  // INTERNAL SIGNALS
  // ----------------
  logic [VrfLineWordAddrW-1:0]           vrf_word_addr[DELAY+1];
  logic [  VrfLineWordNum-1:0][M_DW-1:0] vrf_rdata;
  logic [  VrfLineWordNum-1:0][M_DW-1:0] vrf_wdata;

  // In case the VRF data width is larger (i.e., a multiple) than the OBI data
  // width, the OBI word offset within the VRF word must be delayed as well.
  generate
    if (S_DW > M_DW) begin : gen_addr_delay
      assign vrf_word_addr[0] = master_req_i.addr[MemByteOffsW+:$clog2(VrfLineWordNum)];
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
    for (genvar i = 0; unsigned'(i) < VrfLineWordNum; i++) begin : gen_wdata_rep
      assign vrf_wdata[i] = master_req_i.wdata;
    end
  endgenerate

  // VRF request byte enable encoding
  always_comb begin : vrf_be_encoding
    slave_req_o.be                                                    = '0;
    slave_req_o.be[vrf_word_addr[0]*MemWordNumBytes+:MemWordNumBytes] = master_req_i.be;
  end

  // VRF response alignment
  // ----------------------
  assign vrf_rdata          = slave_rsp_i.rdata;
  assign master_rsp_o.rdata = vrf_rdata[vrf_word_addr[DELAY]];

  // OUTPUT EVALUATION
  // -----------------

  // OBI request to SRAM request
  assign slave_req_o.req    = master_req_i.req;
  assign slave_req_o.we     = master_req_i.we;
  assign slave_req_o.addr   = master_req_i.addr;
  assign slave_req_o.wdata  = vrf_wdata;

  // ----------
  // ASSERTIONS
  // ----------
`ifndef SYNTHESIS
  `include "xheep_mem_demux.svh"
`endif  // SYNTHESIS
endmodule
