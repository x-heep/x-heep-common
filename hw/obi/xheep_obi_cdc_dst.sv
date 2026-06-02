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
// File: xheep_obi_cdc_dst.sv
// Author(s):
//   Michele Caon <michele.caon@epfl.ch>
// Date: 27/04/2026
// Desc: Clock domain crossing modules for OBI protocol
//       Since the OBI protocol does not support backpressure on the response
//       channel, this module does not implement any FIFO or support for
//       oustanding transactions in general. Instead, this module waits for
//       both the `gnt` and the `rvalid` to be asserted by the destination
//       OBI slave before sending the response back to the source CDC.

module xheep_obi_cdc_dst #(
  // Clock domain crossing protocol type
  parameter int unsigned CDC_KIND = 32'd2,  // 2 for "cdc_2phase" or 4 for "cdc_4phase"
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
  // Destination domain clock and reset
  input logic dst_clk_i,
  input logic dst_rst_ni,

  // OBI requesto to the destination domain
  output obi_req_t dst_req_o,
  input  obi_rsp_t dst_rsp_i,

  // Asynchronous signals
  input  logic     async_req_i,
  output logic     async_ack_o,
  input  obi_req_t async_data_i,
  output logic     async_req_o,
  input  logic     async_ack_i,
  output obi_rsp_t async_data_o
);
  // INTERNAL SIGNALS
  // --------------------------------------------------------------------------
  // Internal response data
  obi_req_t dst_req;
  obi_rsp_t dst_rsp_m, dst_rsp;

  // Response data register and mux
  obi_rsp_t dst_rsp_q;
  logic     rsp_reg_en;
  logic     rsp_sel_reg;

  // CDC handshake signals
  logic     dst_req_valid;  // valid for destination OBI slave
  logic     dst_cdc_req_valid;  // valid from destination CDC
  logic     dst_cdc_rsp_valid;  // valid to destination CDC
  logic     dst_cdc_req_ready;  // ready to destination CDC
  logic     dst_cdc_rsp_ready;  // ready from destination CDC

  // Source FSM states
  typedef enum logic [1:0] {
    IDLE,
    WAIT_RVALID,
    WAIT_CDC
  } fsm_state_t;
  fsm_state_t fsm_state_d, fsm_state_q;

  // --------------------------------------------------------------------------
  // SOURCE HSNDSHAKE FSM
  // --------------------------------------------------------------------------
  // State progression
  always_comb begin : fsm_state_prog
    unique case (fsm_state_q)
      IDLE: begin
        // Once a request is received and the destination slave accepts it,
        // transition to a state where to wait for rvalid to be asserted by the
        // OBI slave.
        if (dst_cdc_req_valid && dst_rsp_i.gnt) fsm_state_d = WAIT_RVALID;
        else fsm_state_d = IDLE;
      end
      WAIT_RVALID: begin
        // If response CDC is ready when the slave response arrives, we forward
        // the response to the CDC to handle the async transaction. Otherwise,
        // we sample the response and wait.
        if (dst_rsp_i.rvalid) begin
          if (dst_cdc_rsp_ready) fsm_state_d = IDLE;
          else fsm_state_d = WAIT_CDC;
        end
      end
      WAIT_CDC: begin
        // Wait for the response CDC to be ready and forward the sampled
        // response data to it.
        if (dst_cdc_rsp_ready) fsm_state_d = IDLE;
        else fsm_state_d = WAIT_CDC;
      end
      default: fsm_state_d = IDLE;
    endcase
  end

  // Output network
  always_comb begin : fsm_out_net
    dst_req_valid     = 1'b0;
    dst_cdc_req_ready = 1'b0;
    dst_cdc_rsp_valid = 1'b0;
    rsp_reg_en        = 1'b0;
    rsp_sel_reg       = 1'b0;

    unique case (fsm_state_q)
      IDLE: begin
        // Propagate request to the OBI slave
        dst_req_valid     = dst_cdc_req_valid;
        // Propagate grant to the source request CDC
        dst_cdc_req_ready = dst_rsp_i.gnt;
      end
      WAIT_RVALID: begin
        // Forward OBI slave response to CDC
        dst_cdc_rsp_valid = dst_rsp_i.rvalid;
        // If the destination responce CDC is not ready, sample the response data
        rsp_reg_en        = ~dst_cdc_rsp_ready;
      end
      WAIT_CDC: begin
        // Forward sampled data to response CDC
        dst_cdc_rsp_valid = 1'b1;  // slave rvalid already received
        rsp_sel_reg       = 1'b1;
      end
      default: ;  // default values
    endcase
  end

  // State register
  always_ff @(posedge dst_clk_i or negedge dst_rst_ni) begin : fsm_state_reg
    if (!dst_rst_ni) fsm_state_q <= IDLE;
    else fsm_state_q <= fsm_state_d;
  end

  // --------------------------------------------------------------------------
  // RESPONSE DATA REGISTER AND MULTIPLEXER
  // --------------------------------------------------------------------------
  // Response data register
  always_ff @(posedge dst_clk_i or negedge dst_rst_ni) begin
    if (!dst_rst_ni) dst_rsp_q <= '0;
    else if (rsp_reg_en) dst_rsp_q <= dst_rsp_i;
  end

  // Response data multiplexer
  assign dst_rsp_m       = (rsp_sel_reg) ? dst_rsp_q : dst_rsp_i;

  // --------------------------------------------------------------------------
  // SOURCE CDC MODULE
  // --------------------------------------------------------------------------
  // Request for OBI slave
  assign dst_req_o.req   = dst_req_valid;
  assign dst_req_o.we    = dst_req.we;
  assign dst_req_o.be    = dst_req.be;
  assign dst_req_o.addr  = dst_req.addr;
  assign dst_req_o.wdata = dst_req.wdata;

  // Slave response to response CDC
  assign dst_rsp.gnt     = 1'b0;  // handshaking replaced by source CDC
  assign dst_rsp.rvalid  = 1'b0;  // handshaking replaced by source CDC
  assign dst_rsp.rdata   = dst_rsp_m.rdata;

  // Destination request CDC
  // --------------------------------------------------------------------------
  generate
    if (CDC_KIND == 4) begin : gen_req_cdc_4phase
      cdc_4phase_src #(
        .T(obi_rsp_t)
      ) u_rsp_cdc_src (
        .rst_ni      (dst_rst_ni),
        .clk_i       (dst_clk_i),
        .data_i      (dst_rsp),
        .valid_i     (dst_cdc_rsp_valid),
        .ready_o     (dst_cdc_rsp_ready),
        .async_req_o (async_req_o),
        .async_ack_i (async_ack_i),
        .async_data_o(async_data_o)
      );
    end else if (CDC_KIND == 2) begin : gen_req_cdc_2phase
      cdc_2phase_src #(
        .T(obi_rsp_t)
      ) u_rsp_cdc_src (
        .rst_ni      (dst_rst_ni),
        .clk_i       (dst_clk_i),
        .data_i      (dst_rsp),
        .valid_i     (dst_cdc_rsp_valid),
        .ready_o     (dst_cdc_rsp_ready),
        .async_req_o (async_req_o),
        .async_ack_i (async_ack_i),
        .async_data_o(async_data_o)
      );
    end else begin : gen_req_elab_error
      $error("Unknown CDC_KIND %d", CDC_KIND);
    end
  endgenerate

  // Destination response CDC
  // --------------------------------------------------------------------------
  generate
    if (CDC_KIND == 4) begin : gen_rsp_cdc_4phase
      cdc_4phase_dst #(
        .T(obi_req_t)
      ) u_req_cdc_dst (
        .rst_ni      (dst_rst_ni),
        .clk_i       (dst_clk_i),
        .data_o      (dst_req),
        .valid_o     (dst_cdc_req_valid),
        .ready_i     (dst_cdc_req_ready),
        .async_req_i (async_req_i),
        .async_ack_o (async_ack_o),
        .async_data_i(async_data_i)
      );
    end else if (CDC_KIND == 2) begin : gen_rsp_cdc_2phase
      cdc_2phase_dst #(
        .T(obi_req_t)
      ) u_req_cdc_dst (
        .rst_ni      (dst_rst_ni),
        .clk_i       (dst_clk_i),
        .data_o      (dst_req),
        .valid_o     (dst_cdc_req_valid),
        .ready_i     (dst_cdc_req_ready),
        .async_req_i (async_req_i),
        .async_ack_o (async_ack_o),
        .async_data_i(async_data_i)
      );
    end else begin : gen_rsp_elab_error
      $error("Unknown CDC_KIND %d", CDC_KIND);
    end
  endgenerate
endmodule
