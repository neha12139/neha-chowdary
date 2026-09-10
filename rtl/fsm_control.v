`timescale 1ns / 1ps

module fsm_control (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    input  wire       update_rdy,

    output reg        rd_en,
    output reg        accum_en,
    output reg        clear_en,
    output reg        update_en,
    output reg        wr_en,
    output reg [1:0]  wr_sel,
    output reg [9:0]  pixel_addr,
    output reg        done,
    output reg [2:0]  state_out
);

    // ----------------------------------------------------------
    // FSM states
    // ----------------------------------------------------------
    localparam IDLE    = 3'd0;
    localparam LOAD    = 3'd1;
    localparam COMPUTE = 3'd2;
    localparam UPDATE  = 3'd3;
    localparam WRITE   = 3'd4;
    localparam CLEAR   = 3'd5;
    localparam DONE    = 3'd6;

    reg [2:0] state;
    reg [2:0] next_state;

    // 20 iterations: 0 to 19
    reg [4:0] iter_count;

    // Four centroid write-back cycles
    reg [1:0] wr_phase;

    // Handles synchronous pixel-memory latency
    reg accum_delay;

    // Ensures update_en is issued only once
    reg update_fired;


    // ----------------------------------------------------------
    // Sequential logic
    // ----------------------------------------------------------
    always @(posedge clk) begin

        if (rst) begin
            state        <= IDLE;
            state_out    <= IDLE;
            iter_count   <= 5'd0;
            wr_phase     <= 2'd0;
            pixel_addr   <= 10'd0;
            accum_delay  <= 1'b0;
            update_fired <= 1'b0;
        end

        else begin

            state     <= next_state;
            state_out <= state;

            // LOAD: start reading pixels from address 0
            if (state == LOAD) begin
                pixel_addr  <= 10'd0;
                accum_delay <= 1'b0;
            end

            // COMPUTE: process all 1024 pixels
            else if (state == COMPUTE) begin
                accum_delay <= 1'b1;

                if (pixel_addr < 10'd1023)
                    pixel_addr <= pixel_addr + 1'b1;
            end

            // UPDATE: centroid calculation has been requested
            else if (state == UPDATE) begin
                update_fired <= 1'b1;
            end

            // WRITE: write C0, C1, C2, C3
            else if (state == WRITE) begin
                if (wr_phase < 2'd3)
                    wr_phase <= wr_phase + 1'b1;
            end

            // CLEAR: prepare accumulator for next iteration
            else if (state == CLEAR) begin
                pixel_addr   <= 10'd0;
                wr_phase     <= 2'd0;
                accum_delay  <= 1'b0;
                update_fired <= 1'b0;

                if (iter_count < 5'd19)
                    iter_count <= iter_count + 1'b1;
            end

        end
    end


    // ----------------------------------------------------------
    // Next-state logic
    // ----------------------------------------------------------
    always @(*) begin

        next_state = state;

        case (state)

            IDLE: begin
                if (start)
                    next_state = LOAD;
            end

            LOAD: begin
                next_state = COMPUTE;
            end

            COMPUTE: begin
                if ((pixel_addr == 10'd1023) && accum_delay)
                    next_state = UPDATE;
            end

            UPDATE: begin
                if (update_fired && update_rdy)
                    next_state = WRITE;
            end

            WRITE: begin
                if (wr_phase == 2'd3)
                    next_state = CLEAR;
            end

            CLEAR: begin
                if (iter_count == 5'd19)
                    next_state = DONE;
                else
                    next_state = COMPUTE;
            end

            DONE: begin
                next_state = DONE;
            end

            default: begin
                next_state = IDLE;
            end

        endcase
    end


    // ----------------------------------------------------------
    // Output/control logic
    // ----------------------------------------------------------
    always @(*) begin

        rd_en     = 1'b0;
        accum_en  = 1'b0;
        clear_en  = 1'b0;
        update_en = 1'b0;
        wr_en     = 1'b0;

        wr_sel = wr_phase;
        done   = 1'b0;

        case (state)

            IDLE: begin
            end

            LOAD: begin
                clear_en = 1'b1;
            end

            COMPUTE: begin
                rd_en    = 1'b1;
                accum_en = accum_delay;
            end

            UPDATE: begin
                if (!update_fired)
                    update_en = 1'b1;
            end

            WRITE: begin
                wr_en  = 1'b1;
                wr_sel = wr_phase;
            end

            CLEAR: begin
                clear_en = 1'b1;
            end

            DONE: begin
                done = 1'b1;
            end

            default: begin
            end

        endcase
    end

endmodule