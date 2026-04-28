// Copyright (c) 2026 EPFL and Politecnico di Torino.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 2.0 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-2.0. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// File: xheep_obi_to_sram.sv
// Author(s):
//   Michele Caon <michele.caon@epfl.ch>
// Date: 06/12/2022
// Description: OBI to SRAM-like memory bridge

module xheep_obi_to_sram #(
  // Memory latency in cycles from input request to output data
  parameter int unsigned LATENCY = 'd1,  // match this to your memory model
  // OBI request type, expected to contain:
  //    logic           req     > request
  //    logic           we      > write enable
  //    logic [BEW-1:0] be      > byte enable
  //    logic  [AW-1:0] addr    > target address
  //    logic  [DW-1:0] wdata   > data to write
  parameter type obi_req_t = logic,
  // OBI response type, expected to contain:
  //    logic           gnt     > request accepted
  //    logic           rvalid  > read data is valid
  //    logic  [DW-1:0] rdata   > read data
  parameter type obi_rsp_t = logic,
  // SRAM request type, expected to contain:
  //    logic           req     > request
  //    logic           we      > write enable
  //    logic [BEW-1:0] be      > byte enable
  //    logic  [AW-1:0] addr    > target address
  //    logic  [DW-1:0] wdata   > data to write
  parameter type sram_req_t = logic,
  // SRAM response type, expected to contain:
  //    logic  [DW-1:0] rdata   > read data
  parameter type sram_rsp_t = logic
) (
  input logic clk_i,
  input logic rst_ni,

  // OBI interface
  input  obi_req_t obi_req_i,  // OBI bus request
  output obi_rsp_t obi_rsp_o,  // OBI bus response

  // SRAM interface
  output sram_req_t sram_req_o,  // SRAM request
  input  sram_rsp_t sram_rsp_i   // SRAM response
);
  // INTERNAL SIGNALS
  // ----------------
  logic obi_rvalid[LATENCY+1];

  // OBI rvalid delay chain
  // ----------------------
  // The OBI rvalid signal is asserted when the memory produces the output
  // data, that is a number of clock cycles equal to the memory latency after
  // the input request is accepted (i.e., OBI gnt is asserted).
  // NOTE: OBI expects the rvalid signal to be asserted for each request,
  //       including store request for which no data is provided by the slave.
  assign obi_rvalid[0] = obi_req_i.req;
  generate
    for (genvar i = 1; unsigned'(i) <= LATENCY; i++) begin : gen_rvalid_delay
      always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
          obi_rvalid[i] <= 1'b0;
        end else begin
          obi_rvalid[i] <= obi_rvalid[i-1];
        end
      end
    end
  endgenerate

  // OUTPUT EVALUATION
  // -----------------

  // OBI request to SRAM request
  assign sram_req_o.req   = obi_req_i.req;
  assign sram_req_o.we    = obi_req_i.we;
  assign sram_req_o.be    = obi_req_i.be;
  assign sram_req_o.addr  = obi_req_i.addr;
  assign sram_req_o.wdata = obi_req_i.wdata;

  // SRAM response to OBI response
  assign obi_rsp_o.gnt    = 1'b1;  // SRAM slways ready to accept requests
  assign obi_rsp_o.rvalid = obi_rvalid[LATENCY];
  assign obi_rsp_o.rdata  = sram_rsp_i.rdata;
endmodule
