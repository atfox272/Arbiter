module arbiter_iwrr
#(
    // Requester number
    parameter       P_REQUESTER_NUM                             = 3,       
    // Weight value of each requester (RCM: requester_weight[0] = max_weight)
    parameter   int P_REQUESTER_WEIGHT  [0:P_REQUESTER_NUM-1]   = {5, 3, 2}
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
    localparam GRANT_PROCESS = 3'd0;
    localparam WEIGHT_UPDATE = 3'd1;
    // Data width
    localparam REQ_NUM_W    = $clog2(P_REQUESTER_NUM);
    localparam MAX_WEIGHT_W = $clog2(P_REQUESTER_WEIGHT[0]);
    
    // Internal signal declaration
    // wire declaration
    reg     [3:0]                   arbiter_state_nxt;
    reg     [MAX_WEIGHT_W - 1:0]    r_weight_nxt        [P_REQUESTER_NUM - 1:0];    // requester weight
    wire    [MAX_WEIGHT_W - 1:0]    r_weight_decr       [P_REQUESTER_NUM - 1:0];    // requester weight decrement
    wire    [P_REQUESTER_NUM - 1:0] r_weight_completed  ;    // requester weight completed (== 0)
    reg     [P_REQUESTER_NUM - 1:0] grant_nxt;              // grant next
    reg     [REQ_NUM_W - 1:0]       interleaving_ptr_nxt;   // interleaving pointer next
    reg     [REQ_NUM_W - 1:0]       interleaving_ptr_incr;  // interleaving pointer increment
    wire    [REQ_NUM_W - 1:0]       prior_enc_req       [P_REQUESTER_NUM - 1:0];    // Priority encoder (the highest priority requester of prior_enc_req[0 -> n] is REQ[0 -> n])
    // reg declaration
    reg     [3:0]                   arbiter_state_r;    // arbiter state
    reg     [MAX_WEIGHT_W - 1:0]    r_weight_r          [P_REQUESTER_NUM - 1:0];    // requester weight
    reg     [P_REQUESTER_NUM - 1:0] grant_r;            // grant register
    reg     [REQ_NUM_W - 1:0]       interleaving_ptr_r; // interleaving pointer register 
    
    // combinational logic
    generate
        for(genvar i = 0; i < P_REQUESTER_NUM; i = i + 1) begin
            assign r_weight_completed[i] = ~|r_weight_r[i];	// (r_weight == 0)
            assign r_weight_decr[i] = r_weight_r[i] - 1'b1;
            assign prior_enc_req[i] = (request[i]) ? i : (request[(i+1)%P_REQUESTER_NUM]) ? (i+1)%P_REQUESTER_NUM : (i+2)%P_REQUESTER_NUM;
        end
    endgenerate
    assign grant_valid[P_REQUESTER_NUM - 1:0] = grant_r[P_REQUESTER_NUM - 1:0];
    assign interleaving_ptr_incr = (interleaving_ptr_r == (P_REQUESTER_NUM - 1)) ? 0 : interleaving_ptr_r + 1'b1;
    always @(*) begin
        // Default value
        arbiter_state_nxt = arbiter_state_r;
        interleaving_ptr_nxt = interleaving_ptr_r;
        grant_nxt = grant_r;
        for(int i = 0; i < P_REQUESTER_NUM; i = i + 1) begin
            r_weight_nxt[i] = r_weight_r[i];
        end
        case(arbiter_state_r)
            GRANT_PROCESS: begin
//                for(int i = 0; i < P_REQUESTER_NUM; i = i + 1) begin
//                    if(interleaving_ptr_r == i) begin
//                        // lowest priority (lowest MUX)
//                        if (|request[P_REQUESTER_NUM - 1:0]) begin
//                            arbiter_state_nxt = WEIGHT_UPDATE;
//                            //  Priority Encoder 3to2 (~4to2)
//                            //  Req[0]  Req[1]  Req[2]  |   grant_index[1:0]
//                            //  0       0       0       |   1   1
//                            //  0       0       1       |   0   0
//                            //  0       1       x       |   0   1
//                            //  1       x       x       |   1   0    
//                            grant_nxt[prior_enc_req[i]] = 1'b1;
//                        end
//                        // Reverse priority of MUX
//                        for(int n = P_REQUESTER_NUM; n >= 0; n = n - 1) begin
//                            if(request[(i+n)%P_REQUESTER_NUM] & ~r_weight_completed[(i+n)%P_REQUESTER_NUM]) begin
//                                // State update
//                                arbiter_state_nxt = WEIGHT_UPDATE;
//                                // Set grant 
//                                grant_nxt[(i+n)%P_REQUESTER_NUM] = 1'b1;
//                                // Update weight
//                                r_weight_nxt[(i+n)%P_REQUESTER_NUM] = r_weight_decr[0];
//                            end
//                        end
//                    end
//                end
                if(interleaving_ptr_r == 0) begin
                    if(request[0] & ~r_weight_completed[0]) begin
                        // State update
                        arbiter_state_nxt = WEIGHT_UPDATE;
                        // Set grant 
                        grant_nxt[0] = 1'b1;
                        // Update weight
                        r_weight_nxt[0] = r_weight_decr[0];
                    end
                    else if(request[1] & ~r_weight_completed[1]) begin
                        // State update
                        arbiter_state_nxt = WEIGHT_UPDATE;
                        // Set grant 
                        grant_nxt[1] = 1'b1;
                        // Update weight
                        r_weight_nxt[1] = r_weight_decr[1];
                    end
                    else if(request[2] & ~r_weight_completed[2]) begin
                        // State update
                        arbiter_state_nxt = WEIGHT_UPDATE;
                        // Set grant 
                        grant_nxt[2] = 1'b1;
                        // Update weight
                        r_weight_nxt[2] = r_weight_decr[2];
                    end
                    // Any master does not have enough weight to take a turn, but it's requesting
                    else if (|request[P_REQUESTER_NUM - 1:0]) begin
                        arbiter_state_nxt = WEIGHT_UPDATE;
                        //  Priority Encoder 3to2 (~4to2)
                        //  Req[0]  Req[1]  Req[2]  |   grant_index[1:0]
                        //  0       0       0       |   1   1
                        //  0       0       1       |   0   0
                        //  0       1       x       |   0   1
                        //  1       x       x       |   1   0    
                        grant_nxt[prior_enc_req[0]] = 1'b1;
                    end
                end
                else if (interleaving_ptr_r == 1) begin
                    if(request[1] & ~r_weight_completed[1]) begin
                        // State update
                        arbiter_state_nxt = WEIGHT_UPDATE;
                        // Set grant 
                        grant_nxt[1] = 1'b1;
                        // Update weight
                        r_weight_nxt[1] = r_weight_decr[1];
                    end
                    else if(request[2] & ~r_weight_completed[2]) begin
                        // State update
                        arbiter_state_nxt = WEIGHT_UPDATE;
                        // Set grant 
                        grant_nxt[2] = 1'b1;
                        // Update weight
                        r_weight_nxt[2] = r_weight_decr[2];
                    end
                    else if(request[0] & ~r_weight_completed[0]) begin
                        // State update
                        arbiter_state_nxt = WEIGHT_UPDATE;
                        // Set grant 
                        grant_nxt[0] = 1'b1;
                        // Update weight
                        r_weight_nxt[0] = r_weight_decr[0];
                    end
                    // Any master does not have enough weight to take a turn, but it's requesting
                    else if (|request[P_REQUESTER_NUM - 1:0]) begin
                        arbiter_state_nxt = WEIGHT_UPDATE;
                        //  Priority Encoder 3to2 (~4to2)
                        //  Req[0]  Req[1]  Req[2]  |   grant_index[1:0]
                        //  0       0       0       |   1   1 (3)
                        //  0       0       1       |   0   0 (0)
                        //  0       1       x       |   0   1 (1)
                        //  1       x       x       |   1   0 (2)
                        grant_nxt[prior_enc_req[1]] = 1'b1;
                    end
                end
                else if (interleaving_ptr_r == 2) begin
                    if(request[2] & ~r_weight_completed[2]) begin
                        // State update
                        arbiter_state_nxt = WEIGHT_UPDATE;
                        // Set grant 
                        grant_nxt[2] = 1'b1;
                        // Update weight
                        r_weight_nxt[2] = r_weight_decr[2];
                    end
                    else if(request[0] & ~r_weight_completed[0]) begin
                        // State update
                        arbiter_state_nxt = WEIGHT_UPDATE;
                        // Set grant 
                        grant_nxt[0] = 1'b1;
                        // Update weight
                        r_weight_nxt[0] = r_weight_decr[0];
                    end
                    else if(request[1] & ~r_weight_completed[1]) begin
                        // State update
                        arbiter_state_nxt = WEIGHT_UPDATE;
                        // Set grant 
                        grant_nxt[1] = 1'b1;
                        // Update weight
                        r_weight_nxt[1] = r_weight_decr[1];
                    end
                    // Any master does not have enough weight to take a turn, but it's requesting
                    else if (|request[P_REQUESTER_NUM - 1:0]) begin
                        arbiter_state_nxt = WEIGHT_UPDATE;
                        //  Priority Encoder 3to2 (~4to2)
                        //  Req[0]  Req[1]  Req[2]  |   grant_index[1:0]
                        //  0       0       0       |   1   1 (3)
                        //  0       0       1       |   0   0 (0)
                        //  0       1       x       |   0   1 (1)
                        //  1       x       x       |   1   0 (2)
                        grant_nxt[prior_enc_req[2]] = 1'b1;
                    end
                end
            end
            WEIGHT_UPDATE: begin
                if(grant_valid) begin
                    // State update
				    arbiter_state_nxt = GRANT_PROCESS;
				    // Rotate
				    if (|grant_r[(P_REQUESTER_NUM-1):0]) begin
					   interleaving_ptr_nxt = interleaving_ptr_incr;
				    end
				    // Reset grant 
				    grant_nxt[(P_REQUESTER_NUM-1):0] = {P_REQUESTER_NUM{1'b0}};
                end
                // Finish 1 round
                for(int i = 0; i < P_REQUESTER_NUM; i = i + 1) begin
                    r_weight_nxt[i] = (&r_weight_completed[P_REQUESTER_NUM - 1:0]) ? P_REQUESTER_WEIGHT[i] : r_weight_r[i];
                end
            end
            default: begin
            
            end
        endcase  
    end
    
    // flip-flop
    always @(posedge clk) begin
        if(~rst_n) begin
            arbiter_state_r <= GRANT_PROCESS;
            grant_r[P_REQUESTER_NUM - 1:0] <= 1'b0;
            interleaving_ptr_r <= 0;
            for(int i = 0; i < P_REQUESTER_NUM; i = i + 1) begin
                r_weight_r[i] <= P_REQUESTER_WEIGHT[i];
            end
        end
        else begin
            arbiter_state_r <= arbiter_state_nxt;
            grant_r[P_REQUESTER_NUM - 1:0] <= grant_nxt[P_REQUESTER_NUM - 1:0];
            interleaving_ptr_r <= interleaving_ptr_nxt;
            for(int i = 0; i < P_REQUESTER_NUM; i = i + 1) begin
                r_weight_r[i] <= r_weight_nxt[i];
            end
        end
    end

endmodule
