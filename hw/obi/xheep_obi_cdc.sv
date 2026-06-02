// Copyright (c) 2026 EPFL.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 2.0 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-2.0. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// File: xheep_obi_cdc.sv
// Author(s):
//   Michele Caon <michele.caon@epfl.ch>
// Date: 28/04/2026
// Description: Complete OBI clock domain crossing

module xheep_obi_cdc #(
  // Clock domain crossing protocol type
  parameter CDC_KIND = "cdc_2phase",  // "cdc_2phase" or "cdc_4phase"
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
  parameter type obi_rsp_t = logic
) (
  // Source domain clock and reset
  input logic src_clk_i,
  input logic src_rst_ni,

  // Destination domain clock and reset
  input logic dst_clk_i,
  input logic dst_rst_ni,

  // OBI requesto from the source domain
  input  obi_req_t src_req_i,
  output obi_rsp_t src_rsp_o,

  // OBI requesto to the destination domain
  output obi_req_t dst_req_o,
  input  obi_rsp_t dst_rsp_i
);
  // INTERNAL SIGNALS
  // --------------------------------------------------------------------------
  logic     src_req;
  logic     src_ack;
  obi_req_t src_data;
  logic     dst_req;
  logic     dst_ack;
  obi_rsp_t dst_data;

  // --------------------------------------------------------------------------
  // SOURCE AND DESTINATION CDC
  // --------------------------------------------------------------------------
  // Source CDC
  xheep_obi_cdc_src #(
    .CDC_KIND(CDC_KIND)
  ) u_cdc_src (
    .src_clk_i   (src_clk_i),
    .src_rst_ni  (src_rst_ni),
    .src_req_i   (src_req_i),
    .src_rsp_o   (src_rsp_o),
    .async_req_o (src_req),
    .async_ack_i (src_ack),
    .async_data_o(src_data),
    .async_req_i (dst_req),
    .async_ack_o (dst_ack),
    .async_data_i(dst_data)
  );

  // Destination CDC
  xheep_obi_cdc_dst #(
    .CDC_KIND(CDC_KIND)
  ) u_cdc_dst (
    .dst_clk_i   (dst_clk_i),
    .dst_rst_ni  (dst_rst_ni),
    .dst_req_o   (dst_req_o),
    .dst_rsp_i   (dst_rsp_i),
    .async_req_i (src_req),
    .async_ack_o (src_ack),
    .async_data_i(src_data),
    .async_req_o (dst_req),
    .async_ack_i (dst_ack),
    .async_data_o(dst_data)
  );
endmodule
