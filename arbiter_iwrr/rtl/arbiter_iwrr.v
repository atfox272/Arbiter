module arbiter_iwrr
#(
    // Requester number
    parameter                               P_REQUESTER_NUM     = 3,       
    // Weight value of each requester (RCM: requester_weight[0] = max_weight)
    parameter   [0:(P_REQUESTER_NUM*32)-1]  P_REQUESTER_WEIGHT  = {32'd5, 32'd3, 32'd2}
)
(   
    // Input declaration
    input                           clk,
    input                           rst_n,
    input   [P_REQUESTER_NUM - 1:0] request,
    input                           grant_ready,   
    // Output declaration
    output  [P_REQUESTER_NUM - 1:0] grant_valid
);
    // Local parameters
    // Arbiter state machine
    localparam GRANT_PROCESS    = 3'd0;
    localparam WEIGHT_UPDATE    = 3'd1;
    // Data width
    localparam REQ_NUM_W        = $clog2(P_REQUESTER_NUM);
    localparam MAX_WEIGHT_W     = $clog2(P_REQUESTER_WEIGHT[0*32+:32]); // First element 
    
    // Internal variable
    integer i;
    // Internal signal declaration
    // wire declaration
    reg     [3:0]                   arbiter_state_nxt;
    reg     [MAX_WEIGHT_W - 1:0]    r_weight_nxt        [P_REQUESTER_NUM - 1:0];    // requester weight
    wire    [MAX_WEIGHT_W - 1:0]    r_weight_decr       [P_REQUESTER_NUM - 1:0];    // requester weight decrement
    wire    [P_REQUESTER_NUM - 1:0] r_weight_completed;     // requester weight completed (== 0)
    reg     [P_REQUESTER_NUM - 1:0] grant_nxt;              // grant next
    reg     [REQ_NUM_W - 1:0]       interleaving_ptr_nxt;   // interleaving pointer next
    wire    [REQ_NUM_W - 1:0]       interleaving_ptr_incr;  // interleaving pointer increment
    wire                            round_completed;        // Round completion flag
    wire    [P_REQUESTER_NUM - 1:0] prior_grant         [0:P_REQUESTER_NUM - 1];
    // reg declaration
    reg     [3:0]                   arbiter_state_r;    // arbiter state
    reg     [MAX_WEIGHT_W - 1:0]    r_weight_r          [P_REQUESTER_NUM - 1:0];    // requester weight
    reg     [P_REQUESTER_NUM - 1:0] grant_r;            // grant register
    reg     [REQ_NUM_W - 1:0]       interleaving_ptr_r; // interleaving pointer register 
    // combinational logic
    generate
        for(genvar i = 0; i < P_REQUESTER_NUM; i = i + 1) begin
            prior_granter #(
                .P_REQUESTER_NUM(P_REQUESTER_NUM),
                .P_HIGHEST_PRIOR_IDX(i)
            )prior_granter(
                .request(request),
                .request_weight_completed(r_weight_completed),
                .prior_grant(prior_grant[i])
            );
        end
    endgenerate
    assign interleaving_ptr_incr = (interleaving_ptr_r == (P_REQUESTER_NUM - 1)) ? 0 : interleaving_ptr_r + 1'b1;
    assign grant_valid[P_REQUESTER_NUM - 1:0] = grant_r[P_REQUESTER_NUM - 1:0];
    generate
        for(genvar i = 0; i < P_REQUESTER_NUM; i = i + 1) begin
            assign r_weight_completed[i] = ~|r_weight_r[i];	// (r_weight == 0)
            assign r_weight_decr[i] = (r_weight_completed[i]) ? r_weight_r[i] : r_weight_r[i] - 1'b1;
        end
    endgenerate
    
    always @(*) begin
        // Start: Default value //
        arbiter_state_nxt = arbiter_state_r;
        interleaving_ptr_nxt = interleaving_ptr_r;
        grant_nxt = grant_r;
        for(i = 0; i < P_REQUESTER_NUM; i = i + 1) begin
            r_weight_nxt[i] = r_weight_r[i];
        end
        // End: Default value //
        case(arbiter_state_r)
            GRANT_PROCESS: begin
                arbiter_state_nxt = (|request) ? WEIGHT_UPDATE : arbiter_state_r;
                grant_nxt = prior_grant[interleaving_ptr_r];
                for(i = 0; i < P_REQUESTER_NUM; i = i + 1) begin
                    r_weight_nxt[i] = (prior_grant[interleaving_ptr_r][i]) ? r_weight_decr[i] : r_weight_r[i];
                end
            end
            WEIGHT_UPDATE: begin
                if(grant_ready) begin
                    // State update
				    arbiter_state_nxt = GRANT_PROCESS;
				    // Rotate priority (interleaving)
					interleaving_ptr_nxt = interleaving_ptr_incr;
				    // Reset all grants
				    grant_nxt[(P_REQUESTER_NUM-1):0] = {P_REQUESTER_NUM{1'b0}};
                end
                // Finish 1 round
                for(i = 0; i < P_REQUESTER_NUM; i = i + 1) begin
                    r_weight_nxt[i] = (&r_weight_completed[P_REQUESTER_NUM - 1:0]) ? P_REQUESTER_WEIGHT[i*32+:32] : r_weight_r[i];
                end
            end
        endcase  
    end
    
    // flip-flop
    always @(posedge clk) begin
        if(~rst_n) begin
            arbiter_state_r <= GRANT_PROCESS;
            grant_r[P_REQUESTER_NUM - 1:0] <= 1'b0;
            interleaving_ptr_r <= 0;
            for(i = 0; i < P_REQUESTER_NUM; i = i + 1) begin
                r_weight_r[i] <= P_REQUESTER_WEIGHT[i*32+:32];
            end
        end
        else begin
            arbiter_state_r <= arbiter_state_nxt;
            grant_r[P_REQUESTER_NUM - 1:0] <= grant_nxt[P_REQUESTER_NUM - 1:0];
            interleaving_ptr_r <= interleaving_ptr_nxt;
            for(i = 0; i < P_REQUESTER_NUM; i = i + 1) begin
                r_weight_r[i] <= r_weight_nxt[i];
            end
        end
    end

endmodule