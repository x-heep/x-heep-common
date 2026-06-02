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
// File: xheep_obi_cdc_src.sv
// Author(s):
//   Michele Caon <michele.caon@epfl.ch>
// Date: 27/04/2026
// Desc: Clock domain crossing modules for OBI protocol
//       Since the OBI protocol does not support backpressure on the response
//       channel, this module does not implement any FIFO or support for
//       oustanding transactions in general. Instead, a new incoming request
//       is granted only once the rvalid is received on the destination CDC.

module xheep_obi_cdc_src #(
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

  // OBI requesto from the source domain
  input  obi_req_t src_req_i,
  output obi_rsp_t src_rsp_o,

  // Asynchronous signals
  output logic     async_req_o,
  input  logic     async_ack_i,
  output obi_req_t async_data_o,
  input  logic     async_req_i,
  output logic     async_ack_o,
  input  obi_rsp_t async_data_i
);
  // INTERNAL SIGNALS
  // --------------------------------------------------------------------------
  // Register interface signals
  obi_req_t src_req;
  obi_rsp_t src_rsp;

  // CDC handshake signals
  logic     src_rsp_gnt;  // grant for source OBI master
  logic     src_rsp_rvalid;  // rvalid for source OBI master
  logic     src_cdc_req_valid;  // valid to source CDC
  logic     src_cdc_rsp_valid;  // valid from source CDC
  logic     src_cdc_req_ready;  // ready from source CDC
  logic     src_cdc_rsp_ready;  // ready to source CDC

  // Source FSM states
  typedef enum logic {
    IDLE,
    BUSY
  } fsm_state_t;
  fsm_state_t fsm_state_d, fsm_state_q;

  // --------------------------------------------------------------------------
  // SOURCE HSNDSHAKE FSM
  // --------------------------------------------------------------------------
  // State progression
  always_comb begin : fsm_state_prog
    unique case (fsm_state_q)
      IDLE: begin
        // Forward an incoming OBI transaction to the CDC module and transition
        // to a BUSY state where new incoming requests are stalled.
        if (src_req_i.req && src_cdc_req_ready) fsm_state_d = BUSY;
        else fsm_state_d = IDLE;
      end
      BUSY: begin
        // Stall incoming requests until the destination CDC sends the response
        // transaction
        if (src_cdc_rsp_valid) fsm_state_d = IDLE;
        else fsm_state_d = BUSY;
      end
      default: fsm_state_d = IDLE;
    endcase
  end

  // Output network
  always_comb begin : fsm_out_net
    src_rsp_gnt       = 1'b0;
    src_rsp_rvalid    = 1'b0;
    src_cdc_req_valid = 1'b0;
    src_cdc_rsp_ready = 1'b0;

    unique case (fsm_state_q)
      IDLE: begin
        // Forward incoming transaction to source CDC
        src_cdc_req_valid = src_req_i.req;  // MEALY!
        // Grant request from source master
        src_rsp_gnt       = src_cdc_req_ready;  // MEALY!
      end
      BUSY: begin
        // Send ready to source CDC
        src_cdc_rsp_ready = 1'b1;
        // Once the response is received, send rvalid to source OBI master
        src_rsp_rvalid    = src_cdc_rsp_valid;
      end
      default: ;  // default values
    endcase
  end

  // State register
  always_ff @(posedge src_clk_i or negedge src_rst_ni) begin : fsm_state_reg
    if (!src_rst_ni) fsm_state_q <= IDLE;
    else fsm_state_q <= fsm_state_d;
  end

  // --------------------------------------------------------------------------
  // SOURCE CDC MODULE
  // --------------------------------------------------------------------------
  // Source request payload
  assign src_req.req      = 1'b0;  // replaced by CDC handshake on destination side
  assign src_req.we       = src_req_i.we;
  assign src_req.be       = src_req_i.be;
  assign src_req.addr     = src_req_i.addr;
  assign src_req.wdata    = src_req_i.wdata;

  // Source response output
  assign src_rsp_o.gnt    = src_rsp_gnt;
  assign src_rsp_o.rvalid = src_rsp_rvalid;
  assign src_rsp_o.rdata  = src_rsp.rdata;

  // Source request CDC
  // --------------------------------------------------------------------------
  generate
    if (CDC_KIND == "cdc_4phase") begin : gen_req_cdc_4phase
      cdc_4phase_src #(
        .T(obi_req_t)
      ) u_req_cdc_src (
        .rst_ni      (src_rst_ni),
        .clk_i       (src_clk_i),
        .data_i      (src_req),
        .valid_i     (src_cdc_req_valid),
        .ready_o     (src_cdc_req_ready),
        .async_req_o (async_req_o),
        .async_ack_i (async_ack_i),
        .async_data_o(async_data_o)
      );
    end else if (CDC_KIND == "cdc_2phase") begin : gen_req_cdc_2phase
      cdc_2phase_src #(
        .T(obi_req_t)
      ) u_req_cdc_src (
        .rst_ni      (src_rst_ni),
        .clk_i       (src_clk_i),
        .data_i      (src_req),
        .valid_i     (src_cdc_req_valid),
        .ready_o     (src_cdc_req_ready),
        .async_req_o (async_req_o),
        .async_ack_i (async_ack_i),
        .async_data_o(async_data_o)
      );
    end else begin : gen_req_elab_error
      $error("Unknown CDC_KIND %s", CDC_KIND);
    end
  endgenerate

  // Source response CDC
  // --------------------------------------------------------------------------
  generate
    if (CDC_KIND == "cdc_4phase") begin : gen_rsp_cdc_4phase
      cdc_4phase_dst #(
        .T(obi_rsp_t)
      ) u_rsp_cdc_dst (
        .rst_ni      (src_rst_ni),
        .clk_i       (src_clk_i),
        .data_o      (src_rsp),
        .valid_o     (src_cdc_rsp_valid),
        .ready_i     (src_cdc_rsp_ready),
        .async_req_i (async_req_i),
        .async_ack_o (async_ack_o),
        .async_data_i(async_data_i)
      );
    end else if (CDC_KIND == "cdc_2phase") begin : gen_rsp_cdc_2phase
      cdc_2phase_dst #(
        .T(obi_rsp_t)
      ) u_rsp_cdc_dst (
        .rst_ni      (src_rst_ni),
        .clk_i       (src_clk_i),
        .data_o      (src_rsp),
        .valid_o     (src_cdc_rsp_valid),
        .ready_i     (src_cdc_rsp_ready),
        .async_req_i (async_req_i),
        .async_ack_o (async_ack_o),
        .async_data_i(async_data_i)
      );
    end else begin : gen_rsp_elab_error
      $error("Unknown CDC_KIND %s", CDC_KIND);
    end
  endgenerate
endmodule
