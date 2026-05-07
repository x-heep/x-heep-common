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
// File: xheep_obi_splitter.sv
// Author(s):
//   Michele Caon <michele.caon@epfl.ch>
// Date: 15/09/2025
// Description: OBI request splitter

// This module splits an OBI request with M_DW-bit payload (`wdata`) into
// multiple OBI requests, each with S_DW-bit payload. M_DW and S_DW are
// inferred from the master_req_t and slave_req_t data types (see parameters
// below).

module xheep_obi_splitter #(
  // OBI master request type, expected to contain:
  //    logic              req     > request
  //    logic              we      > write enable
  //    logic [M_DW/8-1:0] be      > byte enable
  //    logic   [M_AW-1:0] addr    > target address
  //    logic   [M_DW-1:0] wdata   > data to write
  parameter type master_req_t = logic,
  // OBI master response type, expected to contain:
  //    logic              gnt     > request accepted
  //    logic              rvalid  > read data is valid
  //    logic   [M_DW-1:0] rdata   > read data
  parameter type master_rsp_t = logic,
  // OBI master request type, expected to contain:
  //    logic              req     > request
  //    logic              we      > write enable
  //    logic [S_DW/8-1:0] be      > byte enable
  //    logic   [S_AW-1:0] addr    > target address
  //    logic   [S_DW-1:0] wdata   > data to write
  parameter type slave_req_t  = logic,
  // OBI master response type, expected to contain:
  //    logic              gnt     > request accepted
  //    logic              rvalid  > read data is valid
  //    logic   [S_DW-1:0] rdata   > read data
  parameter type slave_rsp_t  = logic
) (
  input logic clk_i,
  input logic rst_ni,

  // Master interface
  input  master_req_t master_req_i,
  output master_rsp_t master_rsp_o,

  // Slave interface
  output slave_req_t slave_req_o,
  input  slave_rsp_t slave_rsp_i
);
  // PARAMETERS
  localparam int unsigned MasterDataW = $bits(type(master_req_i.wdata));
  localparam int unsigned MasterAddrW = $bits(type(master_req_i.addr));
  localparam int unsigned SlaveAddrW = $bits(type(slave_req_o.addr));
  localparam int unsigned SlaveDataW = $bits(type(slave_req_o.wdata));
  localparam int unsigned SlaveWordByteNum = SlaveDataW / 8;
  localparam int unsigned WordNum = MasterDataW / SlaveDataW;
  localparam int unsigned WordIdxW = unsigned'($clog2(WordNum));
  localparam int unsigned WordByteOffsW = unsigned'($clog2(SlaveWordByteNum));

  // INTERNAL SIGNALS
  // ----------------
  // Splitter FSM
  typedef enum logic [1:0] {
    RESET,
    IDLE,
    PENDING
  } fsm_state_t;
  fsm_state_t curr_state, next_state;
  logic                                         fsm_req;
  logic                                         fsm_gnt;
  logic                                         fsm_sel_buff;
  logic                                         next_req_valid;

  // Word selector
  logic [    WordNum-1:0]                       req_valid_d;
  logic [    WordNum-2:0]                       req_valid_q;
  logic [    WordNum-1:0]                       req_valid;
  logic [   WordIdxW-1:0]                       req_idx;
  logic [    WordNum-1:0]                       req_mask;

  // Master request register
  logic                                         master_req_reg_en;
  logic [    WordNum-2:0][SlaveWordByteNum-1:0] master_req_be_q;
  logic                                         master_req_we_q;
  logic [MasterAddrW-1:0]                       master_req_addr_q;
  logic [    WordNum-2:0][      SlaveDataW-1:0] master_req_wdata_q;
  logic [    WordNum-1:0][SlaveWordByteNum-1:0] master_req_be;
  logic [    WordNum-1:0][      SlaveDataW-1:0] master_req_wdata;

  // Last word flip-flop
  logic                                         req_reg_en;
  logic                                         req_reg_clr;
  logic                                         last_word_q;

  // Master response data register
  logic [   WordIdxW-1:0]                       rsp_idx_q;
  logic                                         rsp_reg_en;
  logic                                         rsp_reg_clr;
  logic [    WordNum-2:0][      SlaveDataW-1:0] rdata_q;
  logic [    WordNum-1:0][      SlaveDataW-1:0] master_rdata;

  // ----------------------
  // SPLITTER CONTROL LOGIC
  // ----------------------

  // Splitter FSM
  // ------------
  // State progression network
  always_comb begin : fsm_state_prog
    unique case (curr_state)
      RESET:   next_state = IDLE;
      IDLE: begin
        // If the request was accepted, move to the next byte
        if (master_req_i.req && slave_rsp_i.gnt && next_req_valid) begin
          next_state = PENDING;
        end else next_state = IDLE;
      end
      PENDING: begin
        // If the request was accepted, move to the next byte
        if (slave_rsp_i.gnt && !next_req_valid) begin
          // If no rvalid from the previous request is received, stall
          next_state = IDLE;
        end else next_state = PENDING;
      end
      default: next_state = RESET;
    endcase
  end

  // Output network
  // NOTE: to support the maximum throughput of one transaction per cycle, this
  // FSM uses Mealy states for the handshaking signals.
  always_comb begin : fsm_output_net
    // Default values
    fsm_req           = 1'b0;
    fsm_gnt           = 1'b0;
    master_req_reg_en = 1'b0;
    fsm_sel_buff      = 1'b0;

    unique case (curr_state)
      IDLE: begin
        // Propagate request to the downstream hardware
        fsm_req           = master_req_i.req;  // MEALY!
        fsm_gnt           = slave_rsp_i.gnt;  // MEALY!
        // Register the current request if the first word is accepted
        master_req_reg_en = master_req_i.req & slave_rsp_i.gnt & next_req_valid;  // MEALY!
      end
      PENDING: begin
        // Send the current word and stall new requests
        fsm_req      = 1'b1;
        fsm_gnt      = 1'b0;
        // Select buffered request data
        fsm_sel_buff = 1'b1;
      end
      default: ;  // use default values
    endcase
  end

  // FSM state register
  always_ff @(posedge clk_i or negedge rst_ni) begin : fsm_state_reg
    if (!rst_ni) curr_state <= RESET;
    else curr_state <= next_state;
  end

  // Splitter static control
  // -----------------------
  assign req_reg_en  = fsm_req & slave_rsp_i.gnt;
  assign req_reg_clr = slave_rsp_i.gnt & ~next_req_valid;
  assign rsp_reg_en  = slave_rsp_i.rvalid;
  assign rsp_reg_clr = slave_rsp_i.rvalid & last_word_q;

  // Last word register
  always_ff @(posedge clk_i or negedge rst_ni) begin : last_word_ff
    if (!rst_ni) last_word_q <= 1'b0;
    else if (req_reg_en) last_word_q <= ~next_req_valid;
  end

  // Next master word is valid
  assign next_req_valid = |(req_valid_d & req_mask);

  // --------------
  // SPLITTER LOGIC
  // --------------

  // Word selector
  // -------------
  // Byte-enable mask and multiplexer
  always_comb begin : be_mask_enc
    req_mask          = '1;
    req_mask[req_idx] = 1'b0;  // consume current slave request
  end

  // Slave valid requests (words whose byte enable is non-zero)
  always_comb begin : req_valid_enc
    for (int unsigned i = 0; i < WordNum; i++) begin
      req_valid[i] = |master_req_i.be[i*SlaveWordByteNum+:SlaveWordByteNum];
    end
  end

  // Request data multiplexer
  always_comb begin : req_be_mux
    if (fsm_sel_buff) begin
      req_valid_d = {req_valid_q, 1'b0};
    end else begin
      req_valid_d = req_valid;
    end
  end

  // Slave valid request register
  always_ff @(posedge clk_i or negedge rst_ni) begin : req_valid_reg
    if (!rst_ni) req_valid_q <= '0;
    else if (req_reg_clr) req_valid_q <= '0;
    else if (req_reg_en) req_valid_q <= req_valid_d[WordNum-1:1] & req_mask[WordNum-1:1];
  end

  // Request selector
  // NOTE: a priority encoder is used to select the current word instead of
  // iterating across all the input words. This makes it possible to generate
  // the minimum number of slave requests, depending on the input byte enable.
  // However, when the master word size is much larger than the slave one, this
  // solution may result in a significant delay.
  always_comb begin : word_valid_enc
    req_idx = '0;
    for (int unsigned i = WordNum - 1; i != '1; i--) begin
      if (req_valid_d[i]) req_idx = i[WordIdxW-1:0];
    end
  end

  // Master request register
  // -----------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin : req_reg
    if (!rst_ni) begin
      master_req_we_q    <= '0;
      master_req_be_q    <= '0;
      master_req_addr_q  <= '0;
      master_req_wdata_q <= '0;
    end else if (master_req_reg_en) begin
      master_req_we_q    <= master_req_i.we;
      master_req_be_q    <= master_req_i.be[WordNum*SlaveWordByteNum-1:SlaveWordByteNum];
      master_req_addr_q  <= master_req_i.addr;
      master_req_wdata_q <= master_req_i.wdata[WordNum*SlaveDataW-1:SlaveDataW];
    end
  end
  assign master_req_be    = {master_req_be_q, {SlaveWordByteNum{1'b0}}};
  assign master_req_wdata = {master_req_wdata_q, {SlaveDataW{1'b0}}};

  // Slave request multiplexer
  // -------------------------
  always_comb begin : slave_req_mux
    if (fsm_sel_buff) begin
      slave_req_o.we = master_req_we_q;
      slave_req_o.be = master_req_be[req_idx];
      slave_req_o.addr = {
        {SlaveAddrW - MasterAddrW{1'b0}},
        master_req_addr_q[MasterAddrW-1:WordByteOffsW+WordIdxW],
        req_idx,
        master_req_addr_q[WordByteOffsW-1:0]
      };
      slave_req_o.wdata = master_req_wdata[req_idx];
    end else begin
      slave_req_o.we = master_req_i.we;
      slave_req_o.be = master_req_i.be[req_idx*SlaveWordByteNum+:SlaveWordByteNum];
      slave_req_o.addr = {
        {SlaveAddrW - MasterAddrW{1'b0}},
        master_req_i.addr[MasterAddrW-1:WordByteOffsW+WordIdxW],
        req_idx,
        master_req_i.addr[WordByteOffsW-1:0]
      };
      slave_req_o.wdata = master_req_i.wdata[req_idx*SlaveDataW+:SlaveDataW];
    end
  end
  assign slave_req_o.req = fsm_req;

  // Slave response data register
  // ----------------------------
  // Response word index register
  always_ff @(posedge clk_i or negedge rst_ni) begin : rsp_idx_reg
    if (!rst_ni) rsp_idx_q <= '0;
    else if (req_reg_en) rsp_idx_q <= req_idx;
  end

  // rdata register
  always_ff @(posedge clk_i or negedge rst_ni) begin : master_rsp_reg
    if (!rst_ni) begin
      rdata_q <= '0;
    end else if (rsp_reg_clr) begin
      rdata_q <= '0;
    end else if (rsp_reg_en) begin
      rdata_q[rsp_idx_q] <= slave_rsp_i.rdata;
    end
  end

  // Master response generation
  always_comb begin : master_rdata_enc
    master_rdata            = {{SlaveDataW{1'b0}}, rdata_q};
    master_rdata[rsp_idx_q] = slave_rsp_i.rdata;
  end

  assign master_rsp_o.gnt    = fsm_gnt;
  assign master_rsp_o.rvalid = slave_rsp_i.rvalid & last_word_q;
  assign master_rsp_o.rdata  = master_rdata;

  // ----------
  // ASSERTIONS
  // ----------
`ifndef SYNTHESIS
  `include "xheep_obi_splitter.svh"
`endif  /* SYNTHESIS */
endmodule
