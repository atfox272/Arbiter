module arbiter_iwrr_1cycle
#(
    // Requester number
    parameter                               P_REQUESTER_NUM     = 3,       
    // Weight value of each requester (requester_weight[0] = max_weight)
    parameter   [0:(P_REQUESTER_NUM*32)-1]  P_REQUESTER_WEIGHT  = {32'd5, 32'd3, 32'd2},
    parameter                               P_WEIGHT_W          = $clog2(P_REQUESTER_WEIGHT[0*32+:32])
)
(   
    // Input declaration
    input                           clk,
    input                           rst_n,
    input   [P_REQUESTER_NUM - 1:0] req_i,
    input   [P_WEIGHT_W - 1:0]      num_grant_req_i,
    input                           grant_ready_i,
    // Output declaration
    output  [P_REQUESTER_NUM - 1:0] grant_valid_o
);
    // Local parameters
    // Arbiter state machine
    localparam GRANT_PROCESS    = 3'd0;
    localparam WEIGHT_UPDATE    = 3'd1;
    // Data width
    localparam REQ_NUM_W        = $clog2(P_REQUESTER_NUM);
    
    // Internal variable
    integer i;
    // Internal signal declaration
    // wire declaration
    reg     [0:P_REQUESTER_NUM*P_WEIGHT_W - 1]  req_weight_nxt;    // requester weight    
    wire    [0:P_REQUESTER_NUM*P_WEIGHT_W - 1]  req_weight_decr;    // requester weight    
    wire    [P_REQUESTER_NUM - 1:0]             req_weight_completed;     // requester weight completed (== 0)
    wire    [REQ_NUM_W - 1:0]                   interleaving_ptr_nxt;   // interleaving pointer next
    wire    [REQ_NUM_W - 1:0]                   interleaving_ptr_incr;  // interleaving pointer increment
    wire                                        round_comp;             // Round completion flag
    wire    [P_REQUESTER_NUM - 1:0]             prior_grant         [0:P_REQUESTER_NUM - 1];
    // reg declaration
//    reg     [P_WEIGHT_W - 1:0]    req_weight_r        [P_REQUESTER_NUM - 1:0];    // requester weight
    reg     [0:P_REQUESTER_NUM*P_WEIGHT_W - 1]  req_weight_r;    // requester weight
    reg     [REQ_NUM_W - 1:0]                   interleaving_ptr_r; // interleaving pointer register 
    
    // combinational logic
    generate
        for(genvar i = 0; i < P_REQUESTER_NUM; i = i + 1) begin
            prior_granter #(
                .P_REQUESTER_NUM(P_REQUESTER_NUM),
                .P_HIGHEST_PRIOR_IDX(i)
            )prior_granter(
                .request(req_i),
                .request_weight_completed(req_weight_completed),
                .prior_grant(prior_grant[i])
            );
        end
    endgenerate
    round_comp_detector #(
        .P_REQUESTER_NUM(P_REQUESTER_NUM),
        .P_WEIGHT_W(P_WEIGHT_W)
    )round_comp_detector(
        // Input
        .req_weight_i(req_weight_r),
        .grant_i(grant_valid_o),
        .num_grant_req_i(num_grant_req_i),
        // Output
        .round_comp_o(round_comp)
    );
    assign grant_valid_o = prior_grant[interleaving_ptr_r];
    assign interleaving_ptr_incr = (interleaving_ptr_r == (P_REQUESTER_NUM - 1)) ? 0 : interleaving_ptr_r + 1'b1;
    assign interleaving_ptr_nxt = interleaving_ptr_incr;
    generate
        for(genvar i = 0; i < P_REQUESTER_NUM; i = i + 1) begin
            assign req_weight_completed[i] = ~|req_weight_r[((i+1)*P_WEIGHT_W-1)-:P_WEIGHT_W];	// (r_weight == 0)
            assign req_weight_decr[((i+1)*P_WEIGHT_W-1)-:P_WEIGHT_W] = req_weight_r[((i+1)*P_WEIGHT_W-1)-:P_WEIGHT_W] - num_grant_req_i;
        end
        
        for(genvar i = 0; i < P_REQUESTER_NUM; i = i + 1) begin
            always @(*) begin
                req_weight_nxt[((i+1)*P_WEIGHT_W-1)-:P_WEIGHT_W] = req_weight_r[((i+1)*P_WEIGHT_W-1)-:P_WEIGHT_W];
                if(round_comp) begin
                    req_weight_nxt[((i+1)*P_WEIGHT_W-1)-:P_WEIGHT_W] = P_REQUESTER_WEIGHT[i*32+:32];
                end 
                else if(grant_valid_o[i]) begin
                    req_weight_nxt[((i+1)*P_WEIGHT_W-1)-:P_WEIGHT_W] = req_weight_decr[((i+1)*P_WEIGHT_W-1)-:P_WEIGHT_W];
                end
            end
        end
    endgenerate
    
    // flip-flop
    always @(posedge clk) begin
        if(~rst_n) begin
            interleaving_ptr_r <= 0;
            for(i = 0; i < P_REQUESTER_NUM; i = i + 1) begin
                req_weight_r[((i+1)*P_WEIGHT_W-1)-:P_WEIGHT_W] <= P_REQUESTER_WEIGHT[i*32+:32];
            end
        end
        else if(grant_ready_i) begin
            interleaving_ptr_r <= interleaving_ptr_nxt;
            for(i = 0; i < P_REQUESTER_NUM; i = i + 1) begin
                req_weight_r[((i+1)*P_WEIGHT_W-1)-:P_WEIGHT_W] <= req_weight_nxt[((i+1)*P_WEIGHT_W-1)-:P_WEIGHT_W];
            end
        end
    end
endmodule