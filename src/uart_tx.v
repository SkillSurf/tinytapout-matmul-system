module uart_tx #(
  parameter   CLOCKS_PER_PULSE = 4, //200_000_000/9600
              BITS_PER_WORD    = 8,
              PACKET_SIZE      = BITS_PER_WORD+5,
              W_OUT = 24, //R*C*W_K + C*W_X
  
  localparam  NUM_WORDS   = W_OUT/BITS_PER_WORD
)(
  input  wire clk, rstn, s_valid, 
  input  wire [NUM_WORDS-1:0][BITS_PER_WORD-1:0] s_data,
  output reg  tx, s_ready
);  
  localparam END_BITS = PACKET_SIZE-BITS_PER_WORD-1;
  reg [NUM_WORDS-1:0][PACKET_SIZE-1:0] s_packets;
  reg [NUM_WORDS*PACKET_SIZE     -1:0] m_packets;

  genvar n;
  generate
    for (n=0; n<NUM_WORDS; n=n+1)
      assign s_packets[n] = { ~(END_BITS'(0)), s_data[n], 1'b0};
  endgenerate
    
  assign tx = m_packets[0];

  // Counters
  reg [$clog2(NUM_WORDS*PACKET_SIZE)-1:0] c_pulses;
  reg [$clog2(CLOCKS_PER_PULSE)     -1:0] c_clocks;

  // State Machine

  localparam IDLE=0, SEND=1;
  reg state;

  always @(posedge clk or negedge rstn) begin

    if (!rstn) begin
      state     <= IDLE;
      m_packets <= '1;
      {c_pulses, c_clocks} <= 0;
    end else
      case (state)
        IDLE :  if (s_valid) begin                  
                  state      <= SEND;
                  m_packets  <= s_packets;
                end

        SEND :  if (c_clocks == CLOCKS_PER_PULSE-1) begin
                  c_clocks <= 0;

                  if (c_pulses == NUM_WORDS*PACKET_SIZE-1) begin
                    c_pulses  <= 0;
                    m_packets <= '1;
                    state     <= IDLE;

                  end else begin
                    c_pulses <= c_pulses + 1;
                    m_packets <= (m_packets >> 1);
                  end

                end else c_clocks <= c_clocks + 1;
      endcase
  end

  assign s_ready = (state == IDLE);

endmodule